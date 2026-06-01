import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let speaker: String
    var text: String
    let isUser: Bool
    let isError: Bool

    init(id: UUID = UUID(), speaker: String, text: String, isUser: Bool, isError: Bool) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.isUser = isUser
        self.isError = isError
    }
}

struct AppSettings: Codable, Equatable {
    var model: String
    var ollamaBaseURL: String
    var timeoutSeconds: Int
    var numPredict: Int

    static let defaults = AppSettings(
        model: "gemma4:latest",
        ollamaBaseURL: "http://127.0.0.1:11434",
        timeoutSeconds: 300,
        numPredict: 512
    )

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "GemmaDesktop.settings"),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return defaults
        }
        return decoded.normalized()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(normalized()) else { return }
        UserDefaults.standard.set(data, forKey: "GemmaDesktop.settings")
    }

    func normalized() -> AppSettings {
        AppSettings(
            model: model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Self.defaults.model : model.trimmingCharacters(in: .whitespacesAndNewlines),
            ollamaBaseURL: ollamaBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Self.defaults.ollamaBaseURL : ollamaBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            timeoutSeconds: max(30, min(timeoutSeconds, 1800)),
            numPredict: max(64, min(numPredict, 4096))
        )
    }
}

struct BridgeInbox: Codable {
    let prompt: String
}

struct BridgeRequest: Codable {
    let id: String
    let prompt: String
    let createdAt: Date

    init(id: String = UUID().uuidString, prompt: String, createdAt: Date = Date()) {
        self.id = id
        self.prompt = prompt
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        prompt = try container.decode(String.self, forKey: .prompt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

struct BridgeResponse: Codable {
    let id: String
    let ok: Bool
    let text: String
    let completedAt: Date
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
    let pendingBridgeRequests: Int
    let sourceName: String?
    let indexedFiles: Int
    let selectedSnippets: Int
}

struct RepoFile {
    let path: String
    let text: String
    let sizeBytes: Int
}

struct RepoChunk: Identifiable {
    let id = UUID()
    let path: String
    let index: Int
    let text: String
}

struct SourceSkipSummary {
    var tooLarge = 0
    var unsupported = 0
    var unreadable = 0
    var empty = 0
    var overFileLimit = 0

    var total: Int {
        tooLarge + unsupported + unreadable + empty + overFileLimit
    }
}

struct RepoContext {
    let name: String
    let root: URL
    let files: [RepoFile]
    let chunks: [RepoChunk]
    let diskSizeBytes: Int64
    let trackedFileCount: Int?
    let skipped: SourceSkipSummary
    let isTemporaryClone: Bool
}

struct SelectedSnippet: Identifiable {
    let id = UUID()
    let path: String
    let chunkIndex: Int
    let score: Int
    let characterCount: Int
}

struct SourceSelection {
    let sourceName: String
    let snippets: [SelectedSnippet]
    let promptCharacterCount: Int
}
