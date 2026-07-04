import Foundation

/// In-memory projects service with realistic delay simulation.
final class MockProjectsService: ProjectsServiceProtocol, @unchecked Sendable {

    private var projects: [Project] = []
    private let lock = NSLock()
    private var nextId = 100

    init() {
        seedSampleData()
    }

    func fetchProjects() async throws -> [Project] {
        try await MockDelay.simulateNetwork()
        lock.lock()
        defer { lock.unlock() }
        return projects.sorted {
            ($0.created_on ?? .distantPast) > ($1.created_on ?? .distantPast)
        }
    }

    func addProject(name: String) async throws -> Project {
        try await MockDelay.simulateShort()
        lock.lock()
        defer { lock.unlock() }
        nextId += 1
        let project = Project(
            id: nextId,
            project_name: name,
            user_id: 1,
            created_on: Date()
        )
        projects.insert(project, at: 0)
        return project
    }

    private func seedSampleData() {
        projects = [
            Project(id: 1, project_name: "iOS Architecture", user_id: 1, created_on: Date().addingTimeInterval(-86400 * 3)),
            Project(id: 2, project_name: "Swift Concurrency", user_id: 1, created_on: Date().addingTimeInterval(-86400)),
            Project(id: 3, project_name: "AI Integration", user_id: 1, created_on: Date())
        ]
    }
}
