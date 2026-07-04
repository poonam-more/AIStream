import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {

    @Published private(set) var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var scrollTrigger: Int = 0
    @Published var currentConversationId: String? = nil

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

    init(aiProvider: any AIProvider) {
        self.aiProvider = aiProvider
    }

    func updateProvider(_ provider: any AIProvider) {
        self.aiProvider = provider
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sendMessage(text: text)
    }

    func sendFollowUp(_ followupText: String) {
        sendMessage(text: followupText)
    }

    private func sendMessage(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        stopStreamingInternal(clearError: false)

        if inputText == text {
            inputText = ""
        }
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: trimmedText)
        messages.append(userMessage)

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)

        scrollTrigger += 1

        let messageIndex = messages.count - 1
        streamBufferMessageIndex = messageIndex
        streamBuffer = ""
        isStreaming = true

        let history = Array(messages.dropLast(2))
        let provider = aiProvider

        streamTask = Task {
            do {
                let stream = provider.streamResponse(prompt: trimmedText, history: history)
                for try await chunk in stream {
                    guard !Task.isCancelled else { break }
                    await handleStreamChunk(chunk, messageIndex: messageIndex)
                }
                await handleStreamComplete(messageIndex: messageIndex)
            } catch is CancellationError {
                await finishStreaming()
            } catch {
                await handleStreamError(error, messageIndex: messageIndex)
            }
        }
    }

    func stopStreaming() {
        stopStreamingInternal(clearError: true)
        isStreaming = false
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private

    private func stopStreamingInternal(clearError: Bool) {
        streamTask?.cancel()
        streamTask = nil
        flushTask?.cancel()
        flushTask = nil
        isFlushScheduled = false
        flushStreamBuffer()
        streamBuffer = ""
        streamBufferMessageIndex = nil
        if clearError { errorMessage = nil }
    }

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
        }
    }

    private func handleStreamComplete(messageIndex: Int) {
        flushStreamBuffer()
        streamBufferMessageIndex = nil
        finishStreaming()
    }

    private func finishStreaming() {
        isStreaming = false
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

    private func handleStreamError(_ error: Error, messageIndex: Int) {
        flushStreamBuffer()
        isStreaming = false
        streamBufferMessageIndex = nil

        if let providerError = error as? AIProviderError, case .cancelled = providerError {
            return
        }

        errorMessage = error.localizedDescription

        if messageIndex < messages.count, messages[messageIndex].content.isEmpty {
            messages[messageIndex].content = "Error: \(error.localizedDescription)"
        }
    }
}
