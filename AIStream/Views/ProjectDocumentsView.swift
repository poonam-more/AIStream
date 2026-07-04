//
//  ProjectDocumentsView.swift
//  AIStream
//
//  Created by Poonam More on 28/02/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ProjectDocumentsView: View {

    let project: Project

    @StateObject private var viewModel: ProjectDocumentsViewModel
    @State private var questionText: String = ""
    @State private var isPickerPresented = false

    init(project: Project) {
        self.project = project
        _viewModel = StateObject(wrappedValue: ServiceContainer.shared.makeProjectDocumentsViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // ── Attachments card ──────────────────────────
                        attachmentsCard
                            .padding(.top, 4)

                        // ── Upload progress (shown while uploading) ───
                        if viewModel.isUploading {
                            uploadProgressCard
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // ── Existing downloaded conversation ──────────
                        if let messages = viewModel.conversationMessages {
                            downloadedConversationSection(messages: messages)
                        }

                        // ── Streaming chat ────────────────────────────
                        if !viewModel.streamMessages.isEmpty {
                            streamChatSection
                        }

                        Color.clear.frame(height: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: viewModel.scrollTrigger) { _, _ in
                    guard let last = viewModel.streamMessages.last else { return }
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
                .onChange(of: viewModel.streamMessages.count) { _, _ in
                    if let last = viewModel.streamMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // ── Question input bar ────────────────────────────────────
            questionInputBar
        }
        .navigationTitle(project.project_name)
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.fetchDocuments(projectId: project.id) }

        // ── File picker — allows multiple selection ───────────────────
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [UTType.pdf, UTType.data],
            allowsMultipleSelection: true
        ) { result in
            handleFilePick(result)
        }

        // ── Upload success alert ──────────────────────────────────────
        .alert("Upload Successful", isPresented: $viewModel.showUploadSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            let names = viewModel.uploadedFileNames.joined(separator: "\n")
            let count = viewModel.uploadedFileNames.count
            Text("\(count) file\(count == 1 ? "" : "s") uploaded and processed successfully:\n\(names)")
        }

        .overlay(alignment: .top) {
            if let msg = viewModel.errorMessage {
                ErrorBannerView(message: msg) { viewModel.clearError() }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .overlay {
            if viewModel.isDownloading { downloadingOverlay }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isUploading)
        .animation(.easeInOut(duration: 0.2),  value: viewModel.errorMessage != nil)
        .onDisappear { viewModel.cancelStream() }
    }

    // MARK: - Attachments Card

    private var attachmentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Attachments:")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()

                Button {
                    isPickerPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Upload Document")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(viewModel.isUploading ? Color(.systemGray3) : Color(red: 0, green: 0, blue: 0))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isUploading)
            }

            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading documents…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 56)
            } else if viewModel.documents.isEmpty {
                Text("No documents attached.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(height: 56)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.documents) { doc in
                            DocumentChip(document: doc)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    // MARK: - Upload Progress Card

    private var uploadProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: uploadStatusIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(uploadStatusColor)
                Text(viewModel.uploadStatus.displayText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(Int(viewModel.uploadProgress * 100))%")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.uploadProgress)
                .tint(uploadStatusColor)
                .animation(.linear(duration: 0.2), value: viewModel.uploadProgress)

            if !viewModel.uploadedFileNames.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.uploadedFileNames, id: \.self) { name in
                        HStack(spacing: 4) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(name)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            if viewModel.uploadStatus == .processing {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.75)
                    Text("Processing your document\(viewModel.uploadedFileNames.count > 1 ? "s" : ""), this may take a moment…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var uploadStatusIcon: String {
        switch viewModel.uploadStatus {
        case .failed:    return "exclamationmark.circle.fill"
        case .processing: return "arrow.triangle.2.circlepath"
        default:         return "arrow.up.circle.fill"
        }
    }

    private var uploadStatusColor: Color {
        switch viewModel.uploadStatus {
        case .failed:    return .red
        case .processing: return .orange
        default:         return .blue
        }
    }

    // MARK: - Downloaded Conversation

    private func downloadedConversationSection(messages: [ChatMessage]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(messages) { message in
                MessageRow(
                    message: message,
                    isStreaming: false,
                    onFollowUpTap: { _ in }
                )
            }
        }
    }

    // MARK: - Streaming Chat

    private var streamChatSection: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.streamMessages) { message in
                MessageRow(
                    message: message,
                    isStreaming: viewModel.isStreaming,
                    onFollowUpTap: { followup in
                        viewModel.sendQuestion(followup, projectId: project.id)
                    }
                )
                .id(message.id)
            }
        }
    }

    // MARK: - Question Input Bar

    private var questionInputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("What would you like to know next?", text: $questionText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...6)
                .disabled(viewModel.isStreaming)
                .onSubmit {
                    if !questionText.contains("\n") { submitQuestion() }
                }

            if viewModel.isStreaming {
                Button {
                    viewModel.cancelStream()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        // Fixed: Color(.label) adapts correctly in both modes
                        .background(Color(.label))
                        .clipShape(Circle())
                        .colorScheme(.dark)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    submitQuestion()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? Color.accentColor : Color(.systemGray4))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var canSend: Bool {
        !questionText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Overlays

    private var downloadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.2).tint(.white)
                Text("Loading conversation…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            // Fixed: secondarySystemGroupedBackground looks correct in both modes
            //    (off-white in light, elevated dark gray in dark — not pure black)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(.systemGray4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func submitQuestion() {
        let text = questionText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        questionText = ""
        viewModel.sendQuestion(text, projectId: project.id)
    }

    private func handleFilePick(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }

            let accessed = urls.map { ($0, $0.startAccessingSecurityScopedResource()) }

            if urls.count == 1, let url = urls.first {
                viewModel.uploadFile(fileURL: url, projectId: project.id)
            } else {
                viewModel.uploadFiles(fileURLs: urls, projectId: project.id)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                accessed.forEach { url, wasAccessed in
                    if wasAccessed { url.stopAccessingSecurityScopedResource() }
                }
            }

        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Error Banner

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.red.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Document Chip

struct DocumentChip: View {
    let document: ProjectDocument

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                VStack(spacing: 1) {
                    Text("PDF")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.gray)
                    Image(systemName: "doc.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            Text(document.documentName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: 140, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                //  Fixed: same pattern as ProjectRow — elevated bg, not pure systemBackground
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(.systemGray4), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
    }
}
