import Foundation

/// Streams completions from the Google Gemini API (SSE).
struct GeminiAIProvider: AIProvider {
    let id = "gemini"
    let displayName = "Google Gemini"

    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String = AppConfiguration.geminiModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    func streamResponse(
        prompt: String,
        history: [ChatMessage]
    ) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(AIStreamChunk(kind: .start))

                    let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)"
                    guard let url = URL(string: urlString) else {
                        throw AIProviderError.invalidResponse
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let contents = Self.buildContents(history: history, prompt: prompt)
                    let body: [String: Any] = ["contents": contents]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw AIProviderError.invalidResponse
                    }
                    guard (200...299).contains(http.statusCode) else {
                        throw AIProviderError.httpError(statusCode: http.statusCode)
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))

                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let candidates = json["candidates"] as? [[String: Any]],
                              let content = candidates.first?["content"] as? [String: Any],
                              let parts = content["parts"] as? [[String: Any]],
                              let text = parts.first?["text"] as? String,
                              !text.isEmpty
                        else { continue }

                        continuation.yield(AIStreamChunk(kind: .content(text)))
                    }

                    continuation.yield(AIStreamChunk(kind: .end))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func buildContents(history: [ChatMessage], prompt: String) -> [[String: Any]] {
        var contents: [[String: Any]] = []
        for message in history.suffix(20) {
            let role = message.role == .user ? "user" : "model"
            contents.append(["role": role, "parts": [["text": message.content]]])
        }
        contents.append(["role": "user", "parts": [["text": prompt]]])
        return contents
    }
}
