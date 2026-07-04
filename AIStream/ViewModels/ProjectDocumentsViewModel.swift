//
//  ProjectDocumentsViewModel.swift
//  AIStream
//
//  Created by Poonam More on 28/02/26.
//

import Foundation
import Combine

@MainActor
final class ProjectDocumentsViewModel: ObservableObject {

    // MARK: - Document / Download State

    @Published var documents: [ProjectDocument] = []
    @Published var isLoading = false
    @Published var isDownloading = false
    @Published var conversationMessages: [ChatMessage]? = nil
    @Published var downloadedDocumentName: String = ""

    // MARK: - Upload State

    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var uploadStatus: UploadStatus = .uploading
    @Published var showUploadSuccessAlert = false
    @Published var uploadedFileNames: [String] = []  // shown in success alert

    // MARK: - Stream State

    @Published var streamMessages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var scrollTrigger: UUID = UUID()

    // MARK: - Error

    @Published var errorMessage: String?

    // MARK: - Private

    private let documentsService: any ProjectDocumentsServiceProtocol
    private let aiProvider: any AIProvider

    private var activeStreamTask: Task<Void, Never>?

    init(
        documentsService: any ProjectDocumentsServiceProtocol,
        aiProvider: any AIProvider
    ) {
        self.documentsService = documentsService
        self.aiProvider = aiProvider
    }

    // MARK: - Fetch Documents

    func fetchDocuments(projectId: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            documents = try await documentsService.fetchDocuments(projectId: "\(projectId)")

            if let first = documents.first {
                await downloadConversation(document: first)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Download Conversation

    func downloadConversation(document: ProjectDocument) async {
        isDownloading = true
        errorMessage  = nil
        conversationMessages = nil
        defer { isDownloading = false }

        do {
            let messages = try await documentsService.downloadProjectContent(projectId: "\(document.projectId)")
            downloadedDocumentName = document.documentName
            conversationMessages = messages
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Single File Upload

    func uploadFile(fileURL: URL, projectId: Int) {
        guard !isUploading else { return }
        isUploading       = true
        uploadProgress    = 0
        uploadStatus      = .uploading
        errorMessage      = nil
        uploadedFileNames = [fileURL.lastPathComponent]

        Task {
            do {
                let jobId = try await documentsService.uploadFile(
                    projectId: "\(projectId)",
                    fileURL: fileURL
                )
                uploadProgress = 0.5
                await pollUploadStatus(jobId: jobId, projectId: projectId)
            } catch {
                isUploading  = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Multi-File Upload

    func uploadFiles(fileURLs: [URL], projectId: Int) {
        guard !isUploading, !fileURLs.isEmpty else { return }
        isUploading       = true
        uploadProgress    = 0
        uploadStatus      = .uploading
        errorMessage      = nil
        uploadedFileNames = fileURLs.map { $0.lastPathComponent }

        Task {
            do {
                let jobId = try await documentsService.uploadFile(
                    projectId: "\(projectId)",
                    fileURL: fileURLs[0]
                )
                uploadProgress = 0.5
                await pollUploadStatus(jobId: jobId, projectId: projectId)
            } catch {
                isUploading  = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Poll Upload Status

    private func pollUploadStatus(jobId: String, projectId: Int) async {
        do {
            while true {
                let status = try await documentsService.pollUploadStatus(jobId: jobId)
                uploadStatus = status
                uploadProgress = status.isTerminal ? 1.0 : 0.75

                if status.isTerminal {
                    isUploading = false
                    if status == .completed || status == .success {
                        showUploadSuccessAlert = true
                        await fetchDocuments(projectId: projectId)
                    }
                    return
                }
                try await Task.sleep(nanoseconds: 800_000_000)
            }
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Streaming

    func sendQuestion(_ question: String, projectId: Int) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        cancelStream()

        streamMessages.append(ChatMessage(role: .user, content: trimmed))
        streamMessages.append(ChatMessage(role: .assistant, content: ""))
        let assistantIndex = streamMessages.count - 1
        scrollTrigger = UUID()
        isStreaming = true

        let provider = aiProvider
        let history = Array(streamMessages.dropLast(2))

        activeStreamTask = Task {
            do {
                let stream = provider.streamResponse(prompt: trimmed, history: history)
                for try await chunk in stream {
                    guard !Task.isCancelled else { break }
                    if case .content(let text) = chunk.kind {
                        await MainActor.run {
                            streamMessages[assistantIndex].content += text
                            scrollTrigger = UUID()
                        }
                    }
                }
                await MainActor.run {
                    isStreaming = false
                    activeStreamTask = nil
                    scrollTrigger = UUID()
                }
            } catch {
                await MainActor.run {
                    isStreaming = false
                    activeStreamTask = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelStream() {
        activeStreamTask?.cancel()
        activeStreamTask = nil
        isStreaming = false
    }

    // MARK: - Helpers

    func clearError() { errorMessage = nil }
}

