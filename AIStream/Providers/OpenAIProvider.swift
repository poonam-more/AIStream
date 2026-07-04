import Foundation

/// Streams completions from the OpenAI Chat Completions API (SSE).
struct OpenAIProvider: AIProvider {
    let id = "openai"
    let displayName = "OpenAI"

    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String = AppConfiguration.openAIModel, session: URLSession = .shared) {
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

                    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let messages = Self.buildMessages(history: history, prompt: prompt)
                    let body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "messages": messages
                    ]
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
                        if payload == "[DONE]" { break }

                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String,
                              !content.isEmpty
                        else { continue }

                        continuation.yield(AIStreamChunk(kind: .content(content)))
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

    private static func buildMessages(history: [ChatMessage], prompt: String) -> [[String: String]] {
        var messages: [[String: String]] = [
            ["role": "system", "content": "You are a helpful AI assistant in the AIStream app."]
        ]
        for message in history.suffix(20) {
            let role = message.role == .user ? "user" : "assistant"
            messages.append(["role": role, "content": message.content])
        }
        messages.append(["role": "user", "content": prompt])
        return messages
    }
}
