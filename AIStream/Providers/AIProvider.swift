import Foundation

/// A single chunk emitted during an AI streaming response.
struct AIStreamChunk: Sendable {
    enum Kind: Sendable {
        case start
        case content(String)
        case sources([SourceItem])
        case followups([String])
        case end
    }

    let kind: Kind
}

/// Errors surfaced by AI providers.
enum AIProviderError: LocalizedError, Sendable {
    case missingAPIKey(provider: String)
    case invalidResponse
    case httpError(statusCode: Int)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider) API key is not configured. Add it in Config/Secrets.xcconfig."
        case .invalidResponse:
            return "Received an invalid response from the AI provider."
        case .httpError(let code):
            return "AI provider request failed (\(code))."
        case .cancelled:
            return "Request was cancelled."
        }
    }
}

/// Protocol for AI backends. Add new providers by conforming to this protocol.
protocol AIProvider: Sendable {
    var id: String { get }
    var displayName: String { get }

    /// Streams a response for the given prompt. Yields chunks as they arrive.
    func streamResponse(
        prompt: String,
        history: [ChatMessage]
    ) -> AsyncThrowingStream<AIStreamChunk, Error>
}
