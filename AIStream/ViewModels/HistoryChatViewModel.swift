//
//  HistoryChatViewModel.swift
//  AIStream
//

import Foundation
import Combine

// MARK: - Response Models
//
// Deliberately lenient — all fields except `content` are optional so a
// missing or differently-named key never crashes the decoder.

struct DownloadConversationResponse: Decodable {
    let conversation_id: String?
    let conversation_name: String?
    let module: String?
    let content: [ConversationContent]
    let conversation_date: String?
}

struct ConversationContent: Decodable {
    let type: String
    let content: String
    let followups: [String]?
    let links: [String]?
    // Decode directly as [SourceItem] — its custom init(from:) already handles
    // both plain string values and full objects from the API
    let sources: [SourceItem]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type      = try c.decode(String.self, forKey: .type)
        content   = try c.decode(String.self, forKey: .content)
        followups = try? c.decodeIfPresent([String].self,     forKey: .followups)
        links     = try? c.decodeIfPresent([String].self,     forKey: .links)
        sources   = try? c.decodeIfPresent([SourceItem].self, forKey: .sources)
    }

    enum CodingKeys: String, CodingKey {
        case type, content, followups, links, sources
    }
}

// MARK: - ViewModel

@MainActor
final class HistoryChatViewModel: ObservableObject {

    // MARK: - Published

    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Streaming
    @Published var inputText: String = ""
    @Published private(set) var isStreaming: Bool = false
    @Published var scrollTrigger: Int = 0

    // MARK: - Properties

    let conversationId: String
    let conversationName: String

    private let historyService: any HistoryServiceProtocol
    private let conversationService: any ConversationServiceProtocol
    private var aiProvider: any AIProvider
    private var streamTask: Task<Void, Never>?

    private let streamThrottleInterval: UInt64 = 120_000_000
    private var streamBuffer = ""
    private var streamBufferMessageIndex: Int?
    private var flushTask: Task<Void, Never>?
    private var isFlushScheduled = false

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    var canStop: Bool { isStreaming }

    // MARK: - Init

    init(
        conversationId: String,
        conversationName: String = "Conversation",
        historyService: any HistoryServiceProtocol,
        conversationService: any ConversationServiceProtocol,
        aiProvider: any AIProvider
    ) {
        self.conversationId = conversationId
        self.conversationName = conversationName
        self.historyService = historyService
        self.conversationService = conversationService
        self.aiProvider = aiProvider
    }

    // MARK: - Load Conversation

    func loadConversation() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            messages = try await historyService.fetchConversation(id: conversationId)
        } catch let decodingError as DecodingError {
            // Surface a detailed error message so you know exactly which field failed
            errorMessage = decodingError.detailedDescription
            #if DEBUG
            print("❌ [HistoryChatViewModel] DecodingError: \(decodingError)")
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Streaming

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sendMessage(text: text)
    }

    func sendFollowUp(_ followupText: String) {
        sendMessage(text: followupText)
    }

    private func sendMessage(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        streamTask?.cancel()
        flushTask?.cancel()
        flushTask = nil
        isFlushScheduled = false
        flushStreamBuffer()
        streamBuffer = ""
        streamBufferMessageIndex = nil

        if inputText == text { inputText = "" }
        errorMessage = nil

        messages.append(ChatMessage(role: .user, content: trimmed))
        messages.append(ChatMessage(role: .assistant, content: ""))

        scrollTrigger += 1

        let messageIndex = messages.count - 1
        streamBufferMessageIndex = messageIndex
        streamBuffer = ""
        isStreaming = true

        let history = Array(messages.dropLast(2))
        let provider = aiProvider

        streamTask = Task {
            do {
                let stream = provider.streamResponse(prompt: trimmed, history: history)
                for try await chunk in stream {
                    guard !Task.isCancelled else { break }
                    await handleStreamChunk(chunk, messageIndex: messageIndex)
                }
                await handleStreamComplete(messageIndex: messageIndex)
            } catch is CancellationError {
                await MainActor.run { isStreaming = false }
            } catch {
                await handleStreamError(error, messageIndex: messageIndex)
            }
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        flushTask?.cancel()
        flushTask = nil
        isFlushScheduled = false
        flushStreamBuffer()
        streamBuffer = ""
        streamBufferMessageIndex = nil
        isStreaming = false
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Stream Handlers

    private func handleStreamChunk(_ chunk: AIStreamChunk, messageIndex: Int) {
        guard messageIndex < messages.count else { return }

        switch chunk.kind {
        case .start:
            isStreaming = true
        case .content(let text):
            let normalized = TextNormalizer.normalizeEscapedNewlines(text)
            streamBuffer = TextNormalizer.appendChunk(existing: streamBuffer, chunk: normalized)
            scheduleFlush()
        case .sources(let sources):
            messages[messageIndex].sources = sources
        case .followups(let followups):
            messages[messageIndex].followups = followups
        case .end:
            flushStreamBuffer()
            streamBufferMessageIndex = nil
            isStreaming = false
            uploadConversationSnapshot()
        }
    }

    private func handleStreamComplete(messageIndex: Int) {
        flushStreamBuffer()
        streamBufferMessageIndex = nil
        isStreaming = false
        uploadConversationSnapshot()
    }

    private func handleStreamError(_ error: Error, messageIndex: Int) {
        flushStreamBuffer()
        isStreaming = false
        streamBufferMessageIndex = nil

        if let providerError = error as? AIProviderError, case .cancelled = providerError { return }

        errorMessage = error.localizedDescription

        if messageIndex < messages.count, messages[messageIndex].content.isEmpty {
            messages[messageIndex].content = "Error: \(error.localizedDescription)"
        }
    }

    private func scheduleFlush() {
        guard !isFlushScheduled else { return }
        isFlushScheduled = true

        flushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.streamThrottleInterval ?? 60_000_000)
            guard !Task.isCancelled else { return }
            self?.flushStreamBuffer()
            self?.isFlushScheduled = false
            if self?.streamBuffer.isEmpty == false {
                self?.scheduleFlush()
            }
        }
    }

    private func flushStreamBuffer() {
        guard let idx = streamBufferMessageIndex,
              idx < messages.count,
              !streamBuffer.isEmpty else { return }

        let toFlush = streamBuffer
        streamBuffer = ""
        messages[idx].content = TextNormalizer.appendChunk(existing: messages[idx].content, chunk: toFlush)
        scrollTrigger += 1
    }

    // MARK: - Conversation Upload

    /// Silently uploads the current message history as conversation.json.
    /// Errors are logged in DEBUG but never surfaced to the user.
    private func uploadConversationSnapshot() {
        guard !messages.isEmpty else { return }
        let snapshot = messages
        let convId = conversationId
        let convName = conversationName

        Task {
            do {
                try await conversationService.uploadConversation(
                    conversationId: convId,
                    conversationName: convName,
                    messages: snapshot
                )
                #if DEBUG
                print("✅ [HistoryChatViewModel] Conversation uploaded: \(convId)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ [HistoryChatViewModel] Conversation upload failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Helpers
}

// MARK: - DecodingError helper

private extension DecodingError {
    var detailedDescription: String {
        switch self {
        case .typeMismatch(let type, let ctx):
            return "Type mismatch for \(type): \(ctx.debugDescription) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let ctx):
            return "Value not found for \(type): \(ctx.debugDescription) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .keyNotFound(let key, let ctx):
            return "Key '\(key.stringValue)' not found: \(ctx.debugDescription)"
        case .dataCorrupted(let ctx):
            return "Data corrupted: \(ctx.debugDescription)"
        @unknown default:
            return localizedDescription
        }
    }
}
