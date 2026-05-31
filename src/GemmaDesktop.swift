import SwiftUI
import Foundation
import AppKit

struct ChatMessage: Identifiable {
    let id = UUID()
    let speaker: String
    let text: String
    let isUser: Bool
    let isError: Bool
}

struct OllamaResponse: Decodable {
    let response: String?
    let error: String?
}

struct BridgeInbox: Codable {
    let prompt: String
}

struct BridgeMessage: Codable {
    let id: String
    let speaker: String
    let text: String
    let isUser: Bool
    let isError: Bool
}

struct BridgeStatus: Codable {
    let model: String
    let status: String
    let repoStatus: String
    let isThinking: Bool
    let isLoadingRepo: Bool
    let bridgeDirectory: String
}

final class FileBridge {
    let directory: URL
    private let encoder: JSONEncoder

    init() throws {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        directory = support
            .appendingPathComponent("Gemma Desktop", isDirectory: true)
            .appendingPathComponent("Bridge", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var inboxURL: URL {
        directory.appendingPathComponent("inbox.json")
    }

    func readInbox() throws -> BridgeInbox? {
        guard FileManager.default.fileExists(atPath: inboxURL.path) else { return nil }
        let data = try Data(contentsOf: inboxURL)
        return try JSONDecoder().decode(BridgeInbox.self, from: data)
    }

    func clearInbox() throws {
        guard FileManager.default.fileExists(atPath: inboxURL.path) else { return }
        try FileManager.default.removeItem(at: inboxURL)
    }

    func writeMessages(_ messages: [BridgeMessage]) throws {
        try write(messages, fileName: "messages.json")
    }

    func writeStatus(_ status: BridgeStatus) throws {
        try write(status, fileName: "status.json")
    }

    private func write<T: Encodable>(_ value: T, fileName: String) throws {
        let data = try encoder.encode(value)
        try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
    }
}

struct RepoFile {
    let path: String
    let text: String
}

struct RepoContext {
    let name: String
    let root: URL
    let files: [RepoFile]
}

enum AppTheme {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.075)
    static let panel = Color(red: 0.086, green: 0.098, blue: 0.118)
    static let panelRaised = Color(red: 0.115, green: 0.129, blue: 0.153)
    static let border = Color(red: 0.23, green: 0.25, blue: 0.29)
    static let text = Color(red: 0.91, green: 0.92, blue: 0.90)
    static let muted = Color(red: 0.58, green: 0.61, blue: 0.65)
    static let terminalGreen = Color(red: 0.38, green: 0.94, blue: 0.64)
    static let codexBlue = Color(red: 0.36, green: 0.62, blue: 1.0)
    static let amber = Color(red: 0.96, green: 0.72, blue: 0.31)
    static let error = Color(red: 1.0, green: 0.36, blue: 0.43)
}

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
    @Published var status = "Local model: gemma4:latest"
    @Published var repoURL = ""
    @Published var repoStatus = "No repo or folder loaded"
    @Published var isThinking = false
    @Published var isLoadingRepo = false
    private var repoContext: RepoContext?
    private var bridge: FileBridge?
    private var bridgeTimer: DispatchSourceTimer?

    init() {
        do {
            bridge = try FileBridge()
            persistBridgeState()
        } catch {
            messages.append(ChatMessage(speaker: "Error", text: "Could not start local file bridge: \(error.localizedDescription)", isUser: false, isError: true))
        }
    }

    func startBridgePolling() {
        guard bridgeTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            self?.processBridgeInbox()
        }
        timer.resume()
        bridgeTimer = timer
    }

    func send() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        sendPrompt(trimmed, speaker: "You", clearComposer: true)
    }

    private func sendPrompt(_ trimmed: String, speaker: String, clearComposer: Bool) {
        guard !trimmed.isEmpty, !isThinking else { return }

        messages.append(ChatMessage(speaker: speaker, text: trimmed, isUser: true, isError: false))
        if clearComposer {
            prompt = ""
        }
        isThinking = true
        status = "Gemma is thinking"
        persistBridgeState()

        Task {
            do {
                let enrichedPrompt = buildPrompt(for: trimmed)
                let reply = try await askGemma(enrichedPrompt)
                messages.append(ChatMessage(speaker: "Gemma", text: reply, isUser: false, isError: false))
            } catch {
                messages.append(ChatMessage(speaker: "Error", text: error.localizedDescription, isUser: false, isError: true))
            }
            isThinking = false
            status = "Local model: gemma4:latest"
            persistBridgeState()
        }
    }

    func loadRepo() {
        let trimmed = repoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoadingRepo else { return }

        isLoadingRepo = true
        repoStatus = "Loading repo..."
        messages.append(ChatMessage(speaker: "Gemma", text: "Loading repository from \(trimmed)", isUser: false, isError: false))
        persistBridgeState()

        Task {
            do {
                let context = try await Task.detached {
                    try Self.cloneAndIndexRepo(trimmed)
                }.value
                repoContext = context
                repoStatus = "Loaded \(context.name) (\(context.files.count) files)"
                messages.append(ChatMessage(
                    speaker: "Gemma",
                    text: "Loaded \(context.name). Ask me about its files, structure, or implementation.",
                    isUser: false,
                    isError: false
                ))
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
                    try Self.indexLocalFolder(folder)
                }.value
                repoContext = context
                repoStatus = "Loaded folder \(context.name) (\(context.files.count) files)"
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

    private func processBridgeInbox() {
        guard let bridge, !isThinking else {
            return
        }

        do {
            guard let inbox = try bridge.readInbox() else { return }
            try bridge.clearInbox()
            let trimmed = inbox.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            sendPrompt(trimmed, speaker: "Codex", clearComposer: false)
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
                model: "gemma4:latest",
                status: status,
                repoStatus: repoStatus,
                isThinking: isThinking,
                isLoadingRepo: isLoadingRepo,
                bridgeDirectory: bridge.directory.path
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
            return """
            \(baseInstruction)

            User question:
            \(userPrompt)
            """
        }

        let snippets = selectedRepoSnippets(for: userPrompt, context: repoContext)
        if snippets.isEmpty {
            return """
            \(baseInstruction)

            You are answering questions about a loaded code/text source named \(repoContext.name).
            No readable file snippets were selected for this question.

            User question:
            \(userPrompt)
            """
        }

        return """
        \(baseInstruction)

        You are answering questions about a loaded code/text source named \(repoContext.name).
        Use the file snippets below as your source of truth. If the snippets are not enough, say what file or detail is missing.

        \(snippets)

        User question:
        \(userPrompt)
        """
    }

    private func selectedRepoSnippets(for userPrompt: String, context: RepoContext) -> String {
        let tokens = Set(userPrompt
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 2 })

        let scored = context.files.map { file -> (Int, RepoFile) in
            let lowerPath = file.path.lowercased()
            let lowerText = String(file.text.prefix(12_000)).lowercased()
            var score = 0

            if lowerPath.contains("readme") { score += 18 }
            if lowerPath.contains("package.json") || lowerPath.contains("pyproject") || lowerPath.contains("gemfile") || lowerPath.contains("cargo.toml") { score += 12 }
            if lowerPath.contains("src/") || lowerPath.contains("app/") { score += 4 }

            for token in tokens {
                if lowerPath.contains(token) { score += 8 }
                if lowerText.contains(token) { score += 3 }
            }

            return (score, file)
        }
        .filter { $0.0 > 0 }
        .sorted { left, right in
            if left.0 == right.0 {
                return left.1.path < right.1.path
            }
            return left.0 > right.0
        }

        let selected = scored.prefix(8).map(\.1)
        var output = ""
        var used = 0
        let maxCharacters = 22_000

        for file in selected {
            let remaining = maxCharacters - used
            guard remaining > 600 else { break }

            let snippet = String(file.text.prefix(min(5_000, remaining)))
            let section = """

            --- \(file.path) ---
            \(snippet)
            """
            output += section
            used += section.count
        }

        return output
    }

    private func askGemma(_ prompt: String) async throws -> String {
        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else {
            throw NSError(domain: "GemmaDesktop", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama URL."])
        }

        var request = URLRequest(url: url, timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gemma4:latest",
            "prompt": prompt,
            "stream": false,
            "options": [
                "num_predict": 512
            ]
        ])

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 600
        let session = URLSession(configuration: configuration)

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                throw NSError(domain: "GemmaDesktop", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ollama returned HTTP \(http.statusCode)."])
            }

            let decoded = try JSONDecoder().decode(OllamaResponse.self, from: data)
            if let error = decoded.error {
                throw NSError(domain: "GemmaDesktop", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
            }
            let text = decoded.response?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                throw NSError(domain: "GemmaDesktop", code: 4, userInfo: [NSLocalizedDescriptionKey: "Gemma returned an empty response. Try asking again with a shorter prompt."])
            }
            return text
        } catch let error as URLError where error.code == .timedOut {
            throw NSError(
                domain: "GemmaDesktop",
                code: URLError.timedOut.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "The local Gemma request timed out. Try a shorter prompt, or wait for Ollama to finish loading the model and send it again."]
            )
        }
    }

    nonisolated private static func cloneAndIndexRepo(_ rawURL: String) throws -> RepoContext {
        let cloneURL = normalizedGitURL(rawURL)
        let repoName = repoName(from: cloneURL)
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("GemmaDesktopRepos", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let target = base.appendingPathComponent("\(repoName)-\(Int(Date().timeIntervalSince1970))", isDirectory: true)
        try runGit(args: ["clone", "--depth", "1", cloneURL, target.path])

        let files = try indexFiles(at: target)
        if files.isEmpty {
            throw NSError(domain: "GemmaDesktop", code: 3, userInfo: [NSLocalizedDescriptionKey: "The repo was cloned, but no readable text files were found."])
        }

        return RepoContext(name: repoName, root: target, files: files)
    }

    nonisolated private static func indexLocalFolder(_ folder: URL) throws -> RepoContext {
        let files = try indexFiles(at: folder)
        if files.isEmpty {
            throw NSError(domain: "GemmaDesktop", code: 5, userInfo: [NSLocalizedDescriptionKey: "No readable text/code files were found in the selected folder."])
        }
        return RepoContext(name: folder.lastPathComponent, root: folder, files: files)
    }

    nonisolated private static func normalizedGitURL(_ rawURL: String) -> String {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("https://github.com/") && !trimmed.hasSuffix(".git") {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + ".git"
        }
        return trimmed
    }

    nonisolated private static func repoName(from cloneURL: String) -> String {
        let clean = cloneURL
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: ".git", with: "")
        let last = clean.split(separator: "/").last.map(String.init) ?? "repo"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(last.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }

    nonisolated private static func runGit(args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args

        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "git failed"
            throw NSError(domain: "GemmaDesktop", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    nonisolated private static func indexFiles(at root: URL) throws -> [RepoFile] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [RepoFile] = []
        for case let url as URL in enumerator {
            let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
            if shouldSkip(relativePath) { continue }

            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, (values.fileSize ?? 0) <= 250_000 else { continue }
            guard isReadableTextPath(relativePath) else { continue }

            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            files.append(RepoFile(path: relativePath, text: text))

            if files.count >= 300 { break }
        }

        return files
    }

    nonisolated private static func shouldSkip(_ path: String) -> Bool {
        let blocked = [
            ".git/", "node_modules/", "dist/", "build/", ".next/", ".venv/",
            "vendor/", "target/", "coverage/", ".cache/", "__pycache__/"
        ]
        return blocked.contains { path.contains($0) }
    }

    nonisolated private static func isReadableTextPath(_ path: String) -> Bool {
        let fileName = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        if ["readme", "readme.md", "license", "dockerfile", "makefile"].contains(fileName) {
            return true
        }

        let allowedExtensions: Set<String> = [
            "c", "cc", "cpp", "cs", "css", "go", "h", "hpp", "html", "java",
            "js", "json", "jsx", "kt", "m", "md", "mm", "php", "plist", "py",
            "rb", "rs", "scss", "sh", "sql", "swift", "toml", "ts", "tsx",
            "txt", "xml", "yaml", "yml"
        ]
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return allowedExtensions.contains(ext)
    }
}

struct ContentView: View {
    @StateObject private var model = ChatModel()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                repoLoader
                messages
                composer
            }
            .padding(14)
        }
        .frame(minWidth: 760, minHeight: 560)
        .onAppear {
            model.startBridgePolling()
        }
    }

    private var repoLoader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("Paste a GitHub repo URL", text: $model.repoURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(AppTheme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(AppTheme.border)
                    )

                Button {
                    model.loadRepo()
                } label: {
                    Text(model.isLoadingRepo ? "Loading" : "Load Repo")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(width: 92)
                }
                .buttonStyle(TerminalButtonStyle(accent: AppTheme.codexBlue))
                .disabled(model.isLoadingRepo)

                Button {
                    model.chooseLocalFolder()
                } label: {
                    Text("Choose Folder")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(width: 118)
                }
                .buttonStyle(TerminalButtonStyle(accent: AppTheme.terminalGreen))
                .disabled(model.isLoadingRepo)
            }

            HStack(spacing: 8) {
                Text("source")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.terminalGreen)
                Text(model.repoStatus)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
            }
        }
        .padding(12)
        .background(AppTheme.panel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                Circle().fill(Color(red: 1.0, green: 0.34, blue: 0.32)).frame(width: 11, height: 11)
                Circle().fill(Color(red: 1.0, green: 0.78, blue: 0.25)).frame(width: 11, height: 11)
                Circle().fill(Color(red: 0.30, green: 0.84, blue: 0.42)).frame(width: 11, height: 11)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(">_")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.terminalGreen)
                    Text("Gemma Desktop")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.text)
                }
                Text("local coding companion")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            StatusPill(label: "model", value: "gemma4:latest", accent: AppTheme.amber)
            StatusPill(label: "bridge", value: model.isThinking ? "busy" : "ready", accent: model.isThinking ? AppTheme.amber : AppTheme.terminalGreen)
        }
        .padding(14)
        .background(AppTheme.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border)
        )
        .padding(.bottom, 10)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.messages) { message in
                        messageView(message)
                            .id(message.id)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.border)
            )
            .onChange(of: model.messages.count) {
                if let last = model.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func messageView(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Text(promptGlyph(for: message))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor(for: message))
                Text(message.speaker)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accentColor(for: message))
            }
            Text(message.text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppTheme.text)
                .textSelection(.enabled)
        }
        .padding(13)
        .frame(maxWidth: 680, alignment: .leading)
        .background(backgroundColor(for: message))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor(for: message).opacity(0.35))
        )
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }

    private func backgroundColor(for message: ChatMessage) -> Color {
        if message.isError {
            return AppTheme.error.opacity(0.16)
        }
        if message.speaker == "Codex" {
            return AppTheme.codexBlue.opacity(0.15)
        }
        if message.isUser {
            return AppTheme.terminalGreen.opacity(0.12)
        }
        return AppTheme.panelRaised
    }

    private func accentColor(for message: ChatMessage) -> Color {
        if message.isError {
            return AppTheme.error
        }
        if message.speaker == "Codex" {
            return AppTheme.codexBlue
        }
        if message.isUser {
            return AppTheme.terminalGreen
        }
        return AppTheme.amber
    }

    private func promptGlyph(for message: ChatMessage) -> String {
        if message.isError {
            return "!"
        }
        if message.speaker == "Codex" {
            return "◆"
        }
        if message.isUser {
            return "$"
        }
        return "●"
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("prompt")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.terminalGreen)
                Text(model.status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextEditor(text: $model.prompt)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(AppTheme.text)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.background)
                    .frame(minHeight: 76, maxHeight: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.border)
                    )

                Button {
                    model.send()
                } label: {
                    Text(model.isThinking ? "WAIT" : "SEND")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(width: 76)
                }
                .buttonStyle(TerminalButtonStyle(accent: AppTheme.amber))
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.isThinking)
            }
        }
        .padding(14)
        .background(AppTheme.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border)
        )
        .padding(.top, 10)
    }
}

struct StatusPill: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .foregroundStyle(accent)
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(accent.opacity(0.35))
        )
    }
}

struct TerminalButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? AppTheme.background : accent)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? accent : accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(accent.opacity(configuration.isPressed ? 0.9 : 0.45))
            )
    }
}

@main
struct GemmaDesktopApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
    }
}
