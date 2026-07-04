//
//  ProjectsView.swift
//  AIStream
//
//  Created by Poonam More on 17/02/26.
//

import SwiftUI

struct ProjectsView: View {

    @StateObject private var viewModel: ProjectsViewModel

    init() {
        _viewModel = StateObject(wrappedValue: ServiceContainer.shared.makeProjectsViewModel())
    }

    var body: some View {
        ZStack {
            content
                .navigationTitle("My Projects")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { addButton }
                .task { await viewModel.fetchProjects() }
                .refreshable { await viewModel.fetchProjects() }
                .alert("Error", isPresented: .constant(viewModel.errorMessage != nil && !viewModel.showAddModal)) {
                    Button("OK") { viewModel.errorMessage = nil }
                } message: {
                    if let msg = viewModel.errorMessage { Text(msg) }
                }

            // Modal overlay
            if viewModel.showAddModal {
                AddProjectModal(viewModel: viewModel)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.showAddModal)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.projects.isEmpty {
            ProgressView("Loading projects…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.projects.isEmpty {
            emptyState
        } else {
            projectsList
        }
    }

    // MARK: - Projects List

    private var projectsList: some View {
        List {
            // Group by relative date period, same as History
            ForEach(groupKeys, id: \.self) { key in
                Section {
                    ForEach(grouped[key] ?? []) { project in
                        NavigationLink(value: project) {
                            ProjectRow(project: project)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text(key)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .padding(.top, 4)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Grouping (Today / Yesterday / Previous 7 Days / Month Year)

    private var grouped: [String: [Project]] {
        let cal = Calendar.current
        let now = Date()
        var result: [String: [Project]] = [:]
        for p in viewModel.projects {
            let key = bucketKey(p.created_on, cal: cal, now: now)
            result[key, default: []].append(p)
        }
        return result
    }

    private var groupKeys: [String] {
        let fixed = ["Today", "Yesterday", "Previous 7 Days", "Previous 30 Days"]
        let dynamic = grouped.keys.filter { !fixed.contains($0) }
            .sorted { a, b in
                // Sort month-year keys newest first
                grouped[a]?.first?.created_on ?? .distantPast >
                grouped[b]?.first?.created_on ?? .distantPast
            }
        return (fixed + dynamic).filter { grouped[$0] != nil }
    }

    private func bucketKey(_ date: Date?, cal: Calendar, now: Date) -> String {
        guard let date else { return "Unknown" }
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: date, to: now).day ?? 0
        if days <= 7  { return "Previous 7 Days" }
        if days <= 30 { return "Previous 30 Days" }
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    // MARK: - Toolbar

    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    viewModel.showAddModal = true
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add Project")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                )
                .colorScheme(.dark)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No Projects Yet")
                .font(.system(size: 18, weight: .semibold))
            Text("Tap \"+ Add Project\" to create your first project.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Project Row

struct ProjectRow: View {

    let project: Project

    var body: some View {
        HStack(spacing: 0) {
            Text(project.project_name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(project.displayTime)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(.systemGray4), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}
