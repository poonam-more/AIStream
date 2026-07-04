import Foundation

protocol HistoryServiceProtocol: Sendable {
    func fetchHistory() async throws -> [HistoryItem]
    func fetchConversation(id: String) async throws -> [ChatMessage]
}

protocol ProjectsServiceProtocol: Sendable {
    func fetchProjects() async throws -> [Project]
    func addProject(name: String) async throws -> Project
}

protocol ProjectDocumentsServiceProtocol: Sendable {
    func fetchDocuments(projectId: String) async throws -> [ProjectDocument]
    func downloadProjectContent(projectId: String) async throws -> [ChatMessage]
    func uploadFile(projectId: String, fileURL: URL) async throws -> String
    func pollUploadStatus(jobId: String) async throws -> UploadStatus
}

protocol ConversationServiceProtocol: Sendable {
    func uploadConversation(
        conversationId: String,
        conversationName: String,
        messages: [ChatMessage]
    ) async throws
}

protocol SettingsServiceProtocol: Sendable {
    func fetchSettings() async throws -> AppSettings
    func saveSettings(_ settings: AppSettings) async throws
}

struct AppSettings: Codable, Equatable, Sendable {
    var selectedProvider: String
    var displayName: String
    var enableHaptics: Bool
    var enableMarkdownRendering: Bool

    static let `default` = AppSettings(
        selectedProvider: "mock",
        displayName: "User",
        enableHaptics: true,
        enableMarkdownRendering: true
    )
}
