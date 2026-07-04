//
//  ProjectsViewModel.swift
//  AIStream
//
//  Created by Poonam More on 26/02/26.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ProjectsViewModel: ObservableObject {

    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var isAdding  = false
    @Published var showAddModal = false
    @Published var errorMessage: String?

    private let service: any ProjectsServiceProtocol

    init(service: any ProjectsServiceProtocol) {
        self.service = service
    }

    // MARK: - Fetch

    func fetchProjects() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchProjects()
            // Sort newest first
            projects = fetched.sorted {
                ($0.created_on ?? .distantPast) > ($1.created_on ?? .distantPast)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Add

    func addProject(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isAdding = true
        errorMessage = nil
        defer { isAdding = false }

        do {
            let newProject = try await service.addProject(name: trimmed)
            // Insert at top with animation
            withAnimation(Animation.spring(response: 0.4, dampingFraction: 0.8)) {
                projects.insert(newProject, at: 0)
            }
            showAddModal = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

