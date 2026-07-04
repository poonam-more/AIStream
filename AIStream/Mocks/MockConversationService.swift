import Foundation

/// Mock conversation persistence — stores locally in memory.
final class MockConversationService: ConversationServiceProtocol, @unchecked Sendable {

    private let historyService: MockHistoryService

    init(historyService: MockHistoryService) {
        self.historyService = historyService
    }

    func uploadConversation(
        conversationId: String,
        conversationName: String,
        messages: [ChatMessage]
    ) async throws {
        try await MockDelay.simulateNetwork()
        historyService.saveConversation(id: conversationId, name: conversationName, messages: messages)
    }
}
