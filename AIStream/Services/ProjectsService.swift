//
//  ProjectsService.swift
//  AIStream
//
//
//  Created by Poonam More on 26/02/26.
//

import Foundation

enum ProjectsServiceError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int)
    case decodingFailed(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid URL."
        case .unauthorized:          return "Unauthorized. Please log in again."
        case .serverError(let c):    return "Server error (\(c))."
        case .decodingFailed(let m): return "Failed to decode response: \(m)"
        case .unknown(let e):        return e.localizedDescription
        }
    }
}

final class ProjectsService {

    // MARK: - Fetch Projects

    func fetchProjects() async throws -> [Project] {
        do {
            let wrapper: ProjectsResponse = try await APIClient.request(
                path: "/projects",
                method: "GET",
                requiresAuth: true,
                responseType: ProjectsResponse.self
            )
            return try ProjectsParser.parse(wrapper.projects)
        } catch let e as ProjectsParserError {
            throw ProjectsServiceError.decodingFailed(e.localizedDescription)
        } catch {
            throw ProjectsServiceError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Add Project

    func addProject(name: String) async throws -> Project {
        do {
            struct AddBody: Encodable { let project_name: String }
            let raw: RawProject = try await APIClient.request(
                path: "/projects",
                method: "POST",
                body: AddBody(project_name: name),
                requiresAuth: true,
                responseType: RawProject.self
            )
            // created_on from add response is often "" — use current date as fallback
            let date = raw.created_on.isEmpty ? Date() : nil
            return Project(
                id: raw.id,
                project_name: raw.project_name,
                user_id: raw.user_id,
                created_on: date ?? Date()
            )
        } catch {
            throw ProjectsServiceError.decodingFailed(error.localizedDescription)
        }
    }
}
