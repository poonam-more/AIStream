import Foundation
import Combine

/// Central dependency injection container. Wires mock or live services based on configuration.
@MainActor
final class ServiceContainer: ObservableObject {

    static let shared = ServiceContainer()

    // MARK: - Services

    let historyService: any HistoryServiceProtocol
    let projectsService: any ProjectsServiceProtocol
    let projectDocumentsService: any ProjectDocumentsServiceProtocol
    let conversationService: any ConversationServiceProtocol
    let settingsService: any SettingsServiceProtocol

    private(set) var aiProvider: any AIProvider

    // MARK: - Mock references (for in-memory state sharing in demo mode)

    private let mockHistoryService: MockHistoryService?

    // MARK: - Init

    private init() {
        if AppConfiguration.useMockServices {
            let mockHistory = MockHistoryService()
            let mockProjects = MockProjectsService()
            let mockDocuments = MockProjectDocumentsService()

            self.mockHistoryService = mockHistory
            self.historyService = mockHistory
            self.projectsService = mockProjects
            self.projectDocumentsService = mockDocuments
            self.conversationService = MockConversationService(historyService: mockHistory)
            self.settingsService = MockSettingsService()
        } else {
            self.mockHistoryService = nil
            self.historyService = LiveHistoryService()
            self.projectsService = LiveProjectsService()
            self.projectDocumentsService = LiveProjectDocumentsService()
            self.conversationService = LiveConversationService()
            self.settingsService = MockSettingsService()
        }

        self.aiProvider = AIProviderFactory.makeProvider()
    }

    // MARK: - AI Provider

    func updateAIProvider(kind: AppConfiguration.AIProviderKind) {
        aiProvider = AIProviderFactory.makeProvider(for: kind)
    }

    func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(aiProvider: aiProvider)
    }

    func makeHistoryViewModel() -> HistoryViewModel {
        HistoryViewModel(service: historyService)
    }

    func makeProjectsViewModel() -> ProjectsViewModel {
        ProjectsViewModel(service: projectsService)
    }

    func makeHistoryChatViewModel(conversationId: String, conversationName: String) -> HistoryChatViewModel {
        HistoryChatViewModel(
            conversationId: conversationId,
            conversationName: conversationName,
            historyService: historyService,
            conversationService: conversationService,
            aiProvider: aiProvider
        )
    }

    func makeProjectDocumentsViewModel() -> ProjectDocumentsViewModel {
        ProjectDocumentsViewModel(
            documentsService: projectDocumentsService,
            aiProvider: aiProvider
        )
    }
}

// MARK: - Live Service Adapters (delegate to existing implementations when custom backend is configured)

struct LiveHistoryService: HistoryServiceProtocol {
    private let service = HistoryService()

    func fetchHistory() async throws -> [HistoryItem] {
        try await service.fetchHistory()
    }

    func fetchConversation(id: String) async throws -> [ChatMessage] {
        let decoded: DownloadConversationResponse = try await APIClient.request(
            path: "/conversations/\(id)",
            method: "GET",
            requiresAuth: true,
            responseType: DownloadConversationResponse.self
        )
        return decoded.content.map { item in
            ChatMessage(
                role: item.type == "user" ? .user : .assistant,
                content: item.content,
                sources: item.sources,
                followups: item.followups
            )
        }
    }
}

struct LiveProjectsService: ProjectsServiceProtocol {
    private let service = ProjectsService()

    func fetchProjects() async throws -> [Project] {
        try await service.fetchProjects()
    }

    func addProject(name: String) async throws -> Project {
        try await service.addProject(name: name)
    }
}

struct LiveProjectDocumentsService: ProjectDocumentsServiceProtocol {
    func fetchDocuments(projectId: String) async throws -> [ProjectDocument] {
        throw MockServiceError.notFound
    }

    func downloadProjectContent(projectId: String) async throws -> [ChatMessage] {
        throw MockServiceError.notFound
    }

    func uploadFile(projectId: String, fileURL: URL) async throws -> String {
        throw MockServiceError.notFound
    }

    func pollUploadStatus(jobId: String) async throws -> UploadStatus {
        throw MockServiceError.notFound
    }
}

struct LiveConversationService: ConversationServiceProtocol {
    private let service: ConversationUploadService

    init() {
        service = ConversationUploadService(baseURL: AppConfiguration.apiBaseURL ?? "")
    }

    func uploadConversation(conversationId: String, conversationName: String, messages: [ChatMessage]) async throws {
        try await service.uploadConversation(
            conversationId: conversationId,
            conversationName: conversationName,
            messages: messages
        )
    }
}
