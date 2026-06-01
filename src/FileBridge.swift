import Foundation

final class FileBridge {
    let directory: URL
    private let requestsDirectory: URL
    private let responsesDirectory: URL
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    init() throws {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        directory = support
            .appendingPathComponent("Gemma Desktop", isDirectory: true)
            .appendingPathComponent("Bridge", isDirectory: true)
        requestsDirectory = directory.appendingPathComponent("requests", isDirectory: true)
        responsesDirectory = directory.appendingPathComponent("responses", isDirectory: true)

        try FileManager.default.createDirectory(at: requestsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: responsesDirectory, withIntermediateDirectories: true)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    var inboxURL: URL {
        directory.appendingPathComponent("inbox.json")
    }

    func writeMessages(_ messages: [BridgeMessage]) throws {
        try write(messages, to: directory.appendingPathComponent("messages.json"))
    }

    func writeStatus(_ status: BridgeStatus) throws {
        try write(status, to: directory.appendingPathComponent("status.json"))
    }

    func writeResponse(id: String, ok: Bool, text: String) {
        let response = BridgeResponse(id: id, ok: ok, text: text, completedAt: Date())
        let url = responsesDirectory.appendingPathComponent("\(id).json")
        try? write(response, to: url)
    }

    func pendingRequestCount() -> Int {
        requestFileURLs().count + (FileManager.default.fileExists(atPath: inboxURL.path) ? 1 : 0)
    }

    func readNextRequest() throws -> BridgeRequest? {
        if FileManager.default.fileExists(atPath: inboxURL.path) {
            do {
                let data = try Data(contentsOf: inboxURL)
                let legacy = try decoder.decode(BridgeInbox.self, from: data)
                try FileManager.default.removeItem(at: inboxURL)
                return BridgeRequest(id: "legacy-\(UUID().uuidString)", prompt: legacy.prompt, createdAt: Date())
            } catch {
                try? FileManager.default.removeItem(at: inboxURL)
                throw error
            }
        }

        guard let next = requestFileURLs().first else { return nil }
        do {
            let data = try Data(contentsOf: next)
            let request = try decoder.decode(BridgeRequest.self, from: data)
            try FileManager.default.removeItem(at: next)
            return request
        } catch {
            try? FileManager.default.removeItem(at: next)
            throw error
        }
    }

    private func requestFileURLs() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: requestsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { left, right in
                let leftDate = (try? left.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                if leftDate == rightDate {
                    return left.lastPathComponent < right.lastPathComponent
                }
                return leftDate < rightDate
            }
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
