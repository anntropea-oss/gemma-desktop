import Foundation

struct OllamaTagResponse: Decodable {
    let models: [OllamaModelTag]
}

struct OllamaModelTag: Decodable {
    let name: String
}

struct OllamaStreamChunk: Decodable {
    let response: String?
    let done: Bool?
    let error: String?
}

enum OllamaClient {
    static func fetchModels(settings: AppSettings) async throws -> [String] {
        let url = try endpoint(settings.ollamaBaseURL, path: "api/tags")
        var request = URLRequest(url: url, timeoutInterval: TimeInterval(settings.timeoutSeconds))
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw NSError(domain: "GemmaDesktop", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Ollama returned HTTP \(http.statusCode): \(errorDetail(from: data))"
            ])
        }

        let decoded = try JSONDecoder().decode(OllamaTagResponse.self, from: data)
        return decoded.models.map(\.name).sorted()
    }

    static func streamGenerate(
        prompt: String,
        settings: AppSettings,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let cleanSettings = settings.normalized()
        let url = try endpoint(cleanSettings.ollamaBaseURL, path: "api/generate")
        var request = URLRequest(url: url, timeoutInterval: TimeInterval(cleanSettings.timeoutSeconds))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": cleanSettings.model,
            "prompt": prompt,
            "stream": true,
            "think": false,
            "options": [
                "num_predict": cleanSettings.numPredict,
                "temperature": 0.2,
                "top_p": 0.9
            ]
        ])

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(cleanSettings.timeoutSeconds)
        configuration.timeoutIntervalForResource = TimeInterval(max(cleanSettings.timeoutSeconds, cleanSettings.timeoutSeconds * 2))
        let session = URLSession(configuration: configuration)

        do {
            let (bytes, response) = try await session.bytes(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                var body = ""
                for try await line in bytes.lines {
                    body += line
                    if body.count > 1000 { break }
                }
                throw NSError(domain: "GemmaDesktop", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Ollama returned HTTP \(http.statusCode): \(body.isEmpty ? "No error details were returned by Ollama." : body)"
                ])
            }

            var fullText = ""
            for try await line in bytes.lines {
                try Task.checkCancellation()
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                let data = Data(line.utf8)
                let decoded = try JSONDecoder().decode(OllamaStreamChunk.self, from: data)
                if let error = decoded.error, !error.isEmpty {
                    throw NSError(domain: "GemmaDesktop", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
                }
                if let token = decoded.response, !token.isEmpty {
                    fullText += token
                    await onPartial(token)
                }
                if decoded.done == true {
                    break
                }
            }

            let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                throw NSError(domain: "GemmaDesktop", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Gemma returned an empty response. Try asking again with a shorter prompt."
                ])
            }
            return trimmed
        } catch let error as URLError where error.code == .timedOut {
            throw NSError(
                domain: "GemmaDesktop",
                code: URLError.timedOut.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "The local Gemma request timed out. Try a shorter prompt, or increase the timeout in Settings."]
            )
        }
    }

    private static func endpoint(_ baseURL: String, path: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/\(path)") else {
            throw NSError(domain: "GemmaDesktop", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama URL."])
        }
        return url
    }

    private static func errorDetail(from data: Data) -> String {
        if let decoded = try? JSONDecoder().decode(OllamaStreamChunk.self, from: data),
           let error = decoded.error,
           !error.isEmpty {
            return error
        }
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return String(text.prefix(500))
        }
        return "No error details were returned by Ollama."
    }
}
