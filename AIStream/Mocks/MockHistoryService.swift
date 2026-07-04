import Foundation

/// In-memory history service with realistic network delay simulation.
final class MockHistoryService: HistoryServiceProtocol, @unchecked Sendable {

    private var conversations: [String: (item: HistoryItem, messages: [ChatMessage])] = [:]
    private let lock = NSLock()

    init() {
        seedSampleData()
    }

    func fetchHistory() async throws -> [HistoryItem] {
        try await MockDelay.simulateNetwork()
        lock.lock()
        defer { lock.unlock() }
        return conversations.values.map(\.item).sorted {
            ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
        }
    }

    func fetchConversation(id: String) async throws -> [ChatMessage] {
        try await MockDelay.simulateNetwork()
        lock.lock()
        defer { lock.unlock() }
        guard let entry = conversations[id] else {
            throw MockServiceError.notFound
        }
        return entry.messages
    }

    func saveConversation(id: String, name: String, messages: [ChatMessage]) {
        lock.lock()
        defer { lock.unlock() }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let item = HistoryItem(
            conversation_date: formatter.string(from: Date()),
            conversation_id: id,
            conversation_name: name
        )
        conversations[id] = (item, messages)
    }

    private func seedSampleData() {
        let samples: [(String, String, [ChatMessage])] = [
            (
                "conv-001",
                "Swift Concurrency Overview",
                [
                    ChatMessage(role: .user, content: "What is structured concurrency?"),
                    ChatMessage(
                        role: .assistant,
                        content: "Structured concurrency ties async tasks to a scope, ensuring cancellation propagates and resources are cleaned up predictably.",
                        followups: ["Show an example", "How does TaskGroup work?"]
                    )
                ]
            ),
            (
                "conv-002",
                "MVVM Architecture Tips",
                [
                    ChatMessage(role: .user, content: "How should ViewModels interact with services?"),
                    ChatMessage(
                        role: .assistant,
                        content: "ViewModels should depend on protocols, not concrete service types. Inject dependencies via initializers for testability."
                    )
                ]
            ),
            (
                "conv-003",
                "Streaming Responses",
                [
                    ChatMessage(role: .user, content: "How does SSE streaming work on iOS?"),
                    ChatMessage(
                        role: .assistant,
                        content: "Use URLSession bytes or AsyncThrowingStream to process Server-Sent Events line by line as they arrive."
                    )
                ]
            )
        ]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for (index, sample) in samples.enumerated() {
            let date = Calendar.current.date(byAdding: .hour, value: -(index + 2), to: Date()) ?? Date()
            let item = HistoryItem(
                conversation_date: formatter.string(from: date),
                conversation_id: sample.0,
                conversation_name: sample.1
            )
            conversations[sample.0] = (item, sample.2)
        }
    }
}

enum MockServiceError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "Resource not found."
        }
    }
}

enum MockDelay {
    static func simulateNetwork(
        minNanoseconds: UInt64 = 300_000_000,
        maxNanoseconds: UInt64 = 800_000_000
    ) async throws {
        let range = maxNanoseconds - minNanoseconds
        let jitter = UInt64.random(in: 0...range)
        try await Task.sleep(nanoseconds: minNanoseconds + jitter)
        try Task.checkCancellation()
    }

    static func simulateShort() async throws {
        try await Task.sleep(nanoseconds: 150_000_000)
        try Task.checkCancellation()
    }
}
