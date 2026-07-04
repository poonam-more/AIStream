//
//  AddProjectModal.swift
//  AIStream
//
//
//  Created by Poonam More on 26/02/26.
//

import SwiftUI

struct AddProjectModal: View {

    @ObservedObject var viewModel: ProjectsViewModel
    @State private var projectName: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !viewModel.isAdding else { return }
                    dismiss()
                }

            // Modal card
            VStack(alignment: .leading, spacing: 20) {

                // Title
                Text("Add New Project")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                // Text field
                TextField("Enter project name", text: $projectName)
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                            )
                    )
                    .disabled(viewModel.isAdding)
                    .onSubmit {
                        submitIfValid()
                    }

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                // Buttons
                HStack(spacing: 12) {
                    Spacer()

                    // Cancel
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.systemGray5))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isAdding)

                    // Confirm
                    Button {
                        submitIfValid()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(canSubmit ? Color.primary : Color(.systemGray4))

                            if viewModel.isAdding {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Text("Confirm")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 90, height: 40)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || viewModel.isAdding)
                    .animation(.easeInOut(duration: 0.15), value: canSubmit)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 8)
            )
            .padding(.horizontal, 32)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .onAppear { isFocused = true }
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitIfValid() {
        guard canSubmit else { return }
        Task { await viewModel.addProject(name: projectName) }
    }

    private func dismiss() {
        viewModel.errorMessage = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.showAddModal = false
        }
    }
}
