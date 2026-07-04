import Foundation

/// Mock project documents and file upload with simulated job polling.
final class MockProjectDocumentsService: ProjectDocumentsServiceProtocol, @unchecked Sendable {

    private var documentsByProject: [String: [ProjectDocument]] = [:]
    private var uploadStates: [String: StatusResponse] = [:]
    private let lock = NSLock()

    init() {
        seedSampleData()
    }

    func fetchDocuments(projectId: String) async throws -> [ProjectDocument] {
        try await MockDelay.simulateNetwork()
        lock.lock()
        defer { lock.unlock() }
        return documentsByProject[projectId] ?? []
    }

    func downloadProjectContent(projectId: String) async throws -> [ChatMessage] {
        try await MockDelay.simulateNetwork()
        return [
            ChatMessage(role: .user, content: "Summarize the documents in this project."),
            ChatMessage(
                role: .assistant,
                content: """
                This is a mock project summary for project \(projectId).

                The documents cover software architecture patterns, dependency injection, \
                and streaming AI responses on iOS.
                """
            )
        ]
    }

    func uploadFile(projectId: String, fileURL: URL) async throws -> String {
        try await MockDelay.simulateShort()
        let jobId = UUID().uuidString
        lock.lock()
        uploadStates[jobId] = StatusResponse(status: "PROCESSING", state: "PROCESSING")
        lock.unlock()

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            lock.lock()
            uploadStates[jobId] = StatusResponse(status: "COMPLETED", state: "COMPLETED")
            lock.unlock()
        }

        return jobId
    }

    func pollUploadStatus(jobId: String) async throws -> UploadStatus {
        try await MockDelay.simulateShort()
        lock.lock()
        defer { lock.unlock() }
        guard let response = uploadStates[jobId], let state = response.state else {
            return .unknown
        }
        return UploadStatus(from: state)
    }

    private func seedSampleData() {
        documentsByProject = [
            "1": [
                ProjectDocument(id: 1, projectId: 1, documentName: "architecture-notes.pdf", documentLocation: "/docs/architecture-notes.pdf", filename: "architecture-notes.pdf"),
                ProjectDocument(id: 2, projectId: 1, documentName: "mvvm-diagram.png", documentLocation: "/docs/mvvm-diagram.png", filename: "mvvm-diagram.png")
            ],
            "2": [
                ProjectDocument(id: 3, projectId: 2, documentName: "async-await-guide.md", documentLocation: "/docs/async-await-guide.md", filename: "async-await-guide.md")
            ],
            "3": [
                ProjectDocument(id: 4, projectId: 3, documentName: "openai-integration.md", documentLocation: "/docs/openai-integration.md", filename: "openai-integration.md")
            ]
        ]
    }
}

private extension UploadStatus {
    init(from state: String) {
        self = UploadStatus(rawValue: state.lowercased()) ?? .unknown
    }
}
