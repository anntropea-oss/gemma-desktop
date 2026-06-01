import AppKit
import Foundation

@MainActor
final class ChatModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(
            speaker: "Gemma",
            text: "Ask Gemma something. Gemma is running locally through Ollama. I can only use text you type, GitHub repos this app loads, or local folders you choose.",
            isUser: false,
            isError: false
        )
    ]
    @Published var prompt = ""
    @Published var status = "Local model ready"
    @Published var repoURL = ""
    @Published var repoRef = ""
    @Published var repoStatus = "No repo or folder loaded"
    @Published var isThinking = false
    @Published var isLoadingRepo = false
    @Published var isContextVisible = true
    @Published var isSettingsVisible = false
    @Published var settings = AppSettings.load()
    @Published var availableModels: [String] = []
    @Published var lastSelection: SourceSelection?

    private var repoContext: RepoContext?
    private var bridge: FileBridge?
    private var bridgeTimer: DispatchSourceTimer?
    private var generationTask: Task<Void, Never>?

    var sourceName: String? {
        repoContext?.name
    }

    var indexedFiles: [RepoFile] {
        repoContext?.files ?? []
    }

    var indexedChunks: Int {
        repoContext?.chunks.count ?? 0
    }

    var sourceSummary: String {
        guard let repoContext else { return "No source loaded." }
        let tracked = repoContext.trackedFileCount.map(String.init) ?? "unknown"
        return "\(repoContext.name): \(formatBytes(repoContext.diskSizeBytes)), \(repoContext.files.count) files, \(repoContext.chunks.count) chunks, \(tracked) Git-tracked files, \(repoContext.skipped.total) skipped."
    }

    init() {
        do {
            bridge = try FileBridge()
            persistBridgeState()
        } catch {
            messages.append(ChatMessage(speaker: "Error", text: "Could not start local file bridge: \(error.localizedDescription)", isUser: false, isError: true))
        }
    }

    func start() {
        startBridgePolling()
        reloadModels()
    }

    func saveSettings() {
        settings = settings.normalized()
        settings.save()
        status = "Settings saved"
        persistBridgeState()
        reloadModels()
    }

    func reloadModels() {
        let settings = settings.normalized()
        Task {
            do {
                availableModels = try await OllamaClient.fetchModels(settings: settings)
                if !availableModels.contains(self.settings.model), let first = availableModels.first {
                    self.settings.model = first
                    self.settings.save()
                }
                status = "Local model ready"
            } catch {
                status = "Ollama not reachable"
            }
            persistBridgeState()
        }
    }

    func send() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        sendPrompt(trimmed, speaker: "You", clearComposer: true, bridgeRequestID: nil)
    }

    func stopGenerating() {
        generationTask?.cancel()
        generationTask = nil
        isThinking = false
        status = "Stopped"
        persistBridgeState()
    }

    func loadRepo() {
        let trimmed = repoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let ref = repoRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoadingRepo else { return }

        isLoadingRepo = true
        repoStatus = ref.isEmpty ? "Loading repo..." : "Loading repo at \(ref)..."
        messages.append(ChatMessage(speaker: "Gemma", text: "Loading repository from \(trimmed)", isUser: false, isError: false))
        persistBridgeState()

        Task {
            do {
                let context = try await Task.detached {
                    try SourceIndexer.cloneAndIndexRepo(trimmed, ref: ref.isEmpty ? nil : ref)
                }.value
                SourceIndexer.removeTemporarySource(repoContext)
                repoContext = context
                lastSelection = nil
                repoStatus = "Loaded \(context.name) (\(context.files.count) files, \(context.chunks.count) chunks)"
                messages.append(ChatMessage(
                    speaker: "Gemma",
                    text: "Loaded \(context.name). Ask me about its files, structure, or implementation.",
                    isUser: false,
                    isError: false
                ))
                SourceIndexer.cleanOldRepoCaches(keeping: context.root)
            } catch {
                repoStatus = "Repo load failed"
                messages.append(ChatMessage(speaker: "Error", text: error.localizedDescription, isUser: false, isError: true))
            }
            isLoadingRepo = false
            persistBridgeState()
        }
    }

    func chooseLocalFolder() {
        guard !isLoadingRepo else { return }

        let panel = NSOpenPanel()
        panel.title = "Choose a folder Gemma Desktop can read"
        panel.prompt = "Load Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let folder = panel.url else { return }

        isLoadingRepo = true
        repoStatus = "Indexing folder..."
        messages.append(ChatMessage(speaker: "Gemma", text: "Indexing local folder \(folder.path)", isUser: false, isError: false))
        persistBridgeState()

        Task {
            do {
                let context = try await Task.detached {
                    try SourceIndexer.indexLocalFolder(folder)
                }.value
                SourceIndexer.removeTemporarySource(repoContext)
                repoContext = context
                lastSelection = nil
                repoStatus = "Loaded folder \(context.name) (\(context.files.count) files, \(context.chunks.count) chunks)"
                messages.append(ChatMessage(
                    speaker: "Gemma",
                    text: "Loaded local folder \(context.name). Ask me about its readable files.",
                    isUser: false,
                    isError: false
                ))
            } catch {
                repoStatus = "Folder load failed"
                messages.append(ChatMessage(speaker: "Error", text: error.localizedDescription, isUser: false, isError: true))
            }
            isLoadingRepo = false
            persistBridgeState()
        }
    }

    func clearSource() {
        SourceIndexer.removeTemporarySource(repoContext)
        repoContext = nil
        lastSelection = nil
        repoStatus = "No repo or folder loaded"
        messages.append(ChatMessage(speaker: "Gemma", text: "Source cleared.", isUser: false, isError: false))
        persistBridgeState()
    }

    private func sendPrompt(_ trimmed: String, speaker: String, clearComposer: Bool, bridgeRequestID: String?) {
        guard !trimmed.isEmpty, !isThinking else { return }

        messages.append(ChatMessage(speaker: speaker, text: trimmed, isUser: true, isError: false))
        if clearComposer {
            prompt = ""
        }

        if let localAnswer = localRepoAnswer(for: trimmed) {
            messages.append(ChatMessage(speaker: "Gemma", text: localAnswer, isUser: false, isError: false))
            if let bridgeRequestID {
                bridge?.writeResponse(id: bridgeRequestID, ok: true, text: localAnswer)
            }
            persistBridgeState()
            return
        }

        let cleanSettings = settings.normalized()
        let enrichedPrompt = buildPrompt(for: trimmed)
        let replyID = UUID()
        messages.append(ChatMessage(id: replyID, speaker: "Gemma", text: "", isUser: false, isError: false))

        isThinking = true
        status = "Gemma is streaming"
        persistBridgeState()

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let reply = try await OllamaClient.streamGenerate(prompt: enrichedPrompt, settings: cleanSettings) { token in
                    self.appendToMessage(id: replyID, token: token)
                }
                self.finishGeneration(replyID: replyID, bridgeRequestID: bridgeRequestID, reply: reply, errorMessage: nil)
            } catch is CancellationError {
                self.finishGeneration(replyID: replyID, bridgeRequestID: bridgeRequestID, reply: nil, errorMessage: "Stopped.")
            } catch {
                self.finishGeneration(replyID: replyID, bridgeRequestID: bridgeRequestID, reply: nil, errorMessage: error.localizedDescription)
            }
        }
    }

    private func appendToMessage(id: UUID, token: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        var updated = messages[index]
        updated.text += token
        messages[index] = updated
        persistBridgeState()
    }

    private func finishGeneration(replyID: UUID, bridgeRequestID: String?, reply: String?, errorMessage: String?) {
        isThinking = false
        generationTask = nil
        status = "Local model ready"

        if let reply {
            if let bridgeRequestID {
                bridge?.writeResponse(id: bridgeRequestID, ok: true, text: reply)
            }
        } else if let message = errorMessage {
            if let index = messages.firstIndex(where: { $0.id == replyID }), messages[index].text.isEmpty {
                messages.remove(at: index)
            }
            messages.append(ChatMessage(speaker: message == "Stopped." ? "Gemma" : "Error", text: message, isUser: false, isError: message != "Stopped."))
            if let bridgeRequestID {
                bridge?.writeResponse(id: bridgeRequestID, ok: false, text: message)
            }
        }
        persistBridgeState()
    }

    private func startBridgePolling() {
        guard bridgeTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            self?.processBridgeInbox()
        }
        timer.resume()
        bridgeTimer = timer
    }

    private func processBridgeInbox() {
        guard let bridge, !isThinking else {
            persistBridgeState()
            return
        }

        do {
            guard let request = try bridge.readNextRequest() else { return }
            let trimmed = request.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            sendPrompt(trimmed, speaker: "Codex", clearComposer: false, bridgeRequestID: request.id)
        } catch {
            messages.append(ChatMessage(speaker: "Error", text: "Bridge error: \(error.localizedDescription)", isUser: false, isError: true))
            persistBridgeState()
        }
    }

    private func persistBridgeState() {
        guard let bridge else { return }

        do {
            try bridge.writeMessages(messages.map { message in
                BridgeMessage(
                    id: message.id.uuidString,
                    speaker: message.speaker,
                    text: message.text,
                    isUser: message.isUser,
                    isError: message.isError
                )
            })
            try bridge.writeStatus(BridgeStatus(
                model: settings.model,
                status: status,
                repoStatus: repoStatus,
                isThinking: isThinking,
                isLoadingRepo: isLoadingRepo,
                bridgeDirectory: bridge.directory.path,
                pendingBridgeRequests: bridge.pendingRequestCount(),
                sourceName: repoContext?.name,
                indexedFiles: repoContext?.files.count ?? 0,
                selectedSnippets: lastSelection?.snippets.count ?? 0
            ))
        } catch {
            print("Bridge persistence error: \(error.localizedDescription)")
        }
    }

    private func buildPrompt(for userPrompt: String) -> String {
        let baseInstruction = """
        You are Gemma running locally on this Mac through Ollama inside a desktop app.
        You cannot directly browse the user's filesystem, open apps, or access the internet by yourself.
        You can only use the text in this prompt and any repository or local-folder snippets the app explicitly provides.
        If asked whether you are local, say that the model is local, but file access is limited to content selected and provided by the app.
        Answer directly and concisely. Do not claim you are running on remote servers.
        """

        guard let repoContext else {
            lastSelection = nil
            return """
            \(baseInstruction)

            User question:
            \(userPrompt)
            """
        }

        let selection = selectedRepoSnippets(for: userPrompt, context: repoContext)
        lastSelection = selection.selection

        if selection.snippets.isEmpty {
            return """
            \(baseInstruction)

            You are answering questions about a loaded code/text source named \(repoContext.name).
            Source summary:
            \(repoSummary(for: repoContext))

            No readable file snippets were selected for this question.

            User question:
            \(userPrompt)
            """
        }

        return """
        \(baseInstruction)

        You are answering questions about a loaded code/text source named \(repoContext.name).
        Use the file snippets below as your source of truth. If the snippets are not enough, say what file or detail is missing.
        Source summary:
        \(repoSummary(for: repoContext))

        \(selection.snippets)

        User question:
        \(userPrompt)
        """
    }

    private func selectedRepoSnippets(for userPrompt: String, context: RepoContext) -> (snippets: String, selection: SourceSelection) {
        let tokens = Set(userPrompt
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 2 })

        let scored = context.chunks.map { chunk -> (Int, RepoChunk) in
            let lowerPath = chunk.path.lowercased()
            let lowerText = chunk.text.lowercased()
            var score = 0

            if lowerPath.contains("readme") { score += 18 }
            if lowerPath.contains("package.json") || lowerPath.contains("pyproject") || lowerPath.contains("gemfile") || lowerPath.contains("cargo.toml") { score += 12 }
            if lowerPath.contains("src/") || lowerPath.contains("app/") { score += 4 }

            for token in tokens {
                if lowerPath.contains(token) { score += 8 }
                if lowerText.contains(token) { score += 3 }
            }

            return (score, chunk)
        }
        .filter { tokens.isEmpty ? $0.0 > 0 : $0.0 > 0 }
        .sorted { left, right in
            if left.0 == right.0 {
                if left.1.path == right.1.path {
                    return left.1.index < right.1.index
                }
                return left.1.path < right.1.path
            }
            return left.0 > right.0
        }

        let selected = scored.prefix(10)
        var output = ""
        var used = 0
        let maxCharacters = 28_000
        var snippets: [SelectedSnippet] = []

        for (score, chunk) in selected {
            let remaining = maxCharacters - used
            guard remaining > 600 else { break }

            let snippet = String(chunk.text.prefix(min(chunk.text.count, remaining)))
            let section = """

            --- \(chunk.path) [chunk \(chunk.index + 1)] ---
            \(snippet)
            """
            output += section
            used += section.count
            snippets.append(SelectedSnippet(path: chunk.path, chunkIndex: chunk.index, score: score, characterCount: snippet.count))
        }

        return (
            output,
            SourceSelection(sourceName: context.name, snippets: snippets, promptCharacterCount: used)
        )
    }

    private func localRepoAnswer(for userPrompt: String) -> String? {
        guard let repoContext else { return nil }

        let lower = userPrompt.lowercased()
        let asksAboutSize = lower.contains("how big")
            || lower.contains("repo size")
            || lower.contains("repository size")
            || (lower.contains("size") && (lower.contains("repo") || lower.contains("repository") || lower.contains("source")))
        let asksAboutFiles = lower.contains("how many files")
            || lower.contains("file count")
            || lower.contains("files are in")

        guard asksAboutSize || asksAboutFiles else { return nil }

        return "\(repoContext.name) is \(formatBytes(repoContext.diskSizeBytes)) in the indexed source scan. I indexed \(repoContext.files.count) readable text/code files into \(repoContext.chunks.count) chunks. Git reports \(repoContext.trackedFileCount.map { "\($0) tracked files" } ?? "no tracked-file count")."
    }

    private func repoSummary(for context: RepoContext) -> String {
        let tracked = context.trackedFileCount.map(String.init) ?? "unknown"
        return """
        - Indexed source size: \(formatBytes(context.diskSizeBytes))
        - Indexed readable text/code files: \(context.files.count)
        - Text chunks available for retrieval: \(context.chunks.count)
        - Git-tracked files: \(tracked)
        - Skipped files: \(context.skipped.total) (\(context.skipped.tooLarge) too large, \(context.skipped.unsupported) unsupported, \(context.skipped.unreadable) unreadable, \(context.skipped.empty) empty, \(context.skipped.overFileLimit) over limit)
        """
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesActualByteCount = true
        return formatter.string(fromByteCount: bytes)
    }
}
