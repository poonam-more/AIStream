import Foundation

/// Demo provider that simulates realistic streaming without network calls.
struct MockAIProvider: AIProvider {
    let id = "mock"
    let displayName = "Demo"

    private let wordDelayNanoseconds: UInt64 = 45_000_000

    func streamResponse(
        prompt: String,
        history: [ChatMessage]
    ) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(AIStreamChunk(kind: .start))

                    let response = Self.generateResponse(for: prompt, historyCount: history.count)
                    let words = response.split(separator: " ", omittingEmptySubsequences: false)

                    for (index, word) in words.enumerated() {
                        try Task.checkCancellation()
                        let chunk = index == 0 ? String(word) : " \(word)"
                        continuation.yield(AIStreamChunk(kind: .content(chunk)))
                        try await Task.sleep(nanoseconds: wordDelayNanoseconds)
                    }

                    continuation.yield(AIStreamChunk(kind: .sources(Self.sampleSources)))
                    continuation.yield(AIStreamChunk(kind: .followups(Self.sampleFollowups(for: prompt))))
                    continuation.yield(AIStreamChunk(kind: .end))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Sample Data

    private static let sampleSources: [SourceItem] = [
        SourceItem(title: "Swift Concurrency", url: "https://developer.apple.com/documentation/swift/concurrency", snippet: "Structured concurrency in Swift."),
        SourceItem(title: "Server-Sent Events", url: "https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events", snippet: "SSE streaming reference.")
    ]

    private static func sampleFollowups(for prompt: String) -> [String] {
        [
            "Can you explain that in more detail?",
            "What are the trade-offs?",
            "Show me a code example for \(prompt.prefix(30))"
        ]
    }

    private static func generateResponse(for prompt: String, historyCount: Int) -> String {
        """
        Thanks for your question about "\(prompt)".

        AIStream is a portfolio-quality iOS chat app demonstrating **MVVM architecture**, \
        **protocol-oriented design**, and **SSE-style streaming** using Swift Concurrency.

        Key highlights:
        - `AsyncThrowingStream` for word-by-word streaming
        - Pluggable `AIProvider` (Mock, OpenAI, Gemini)
        - Dependency injection via `ServiceContainer`
        - Mock services for offline demo mode

        This is a mock response — no API key required. \
        Configure `AI_PROVIDER` in `Secrets.xcconfig` to use a real provider.

        (Conversation context: \(historyCount) prior message\(historyCount == 1 ? "" : "s").)
        """
    }
}
