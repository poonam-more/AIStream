//
//  ConversationUploadPayload.swift
//  AIStream
//
//  Created by Poonam More on 09/03/26.
//

import Foundation

// MARK: - Conversation JSON Models
// Matches the exact shape of the sample conversation.json

struct ConversationUploadPayload: Encodable {
    let conversation_id: String
    let conversation_name: String
    let module: String
    let content: [ConversationUploadItem]
    let conversation_date: String
}

struct ConversationUploadItem: Encodable {
    let type: String        // "user" or "bot"
    let content: String
    let followups: [String]?
    let links: [String]?
    let sources: [String]?
}

// MARK: - Service

final class ConversationUploadService {
    private let baseURL: String
    private let boundary = "Boundary-\(UUID().uuidString)"

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    /// Builds a ConversationUploadPayload from the current messages array and uploads it.
    func uploadConversation(
        conversationId: String,
        conversationName: String,
        messages: [ChatMessage]
    ) async throws {
        let payload = buildPayload(
            conversationId: conversationId,
            conversationName: conversationName,
            messages: messages
        )
        let jsonData = try JSONEncoder().encode(payload)

        #if DEBUG
        if let raw = String(data: jsonData, encoding: .utf8) {
            print("📤 [ConversationUploadService] uploading:\n\(raw)")
        }
        #endif

        guard let endpoint = URL(string: "\(baseURL)/conversations/upload") else {
            throw ConversationUploadError.invalidURL
        }

        var body = Data()
        let lb = "\r\n"

        body.appendString("--\(boundary)\(lb)")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"conversation.json\"\(lb)")
        body.appendString("Content-Type: application/json\(lb)\(lb)")
        body.append(jsonData)
        body.appendString(lb)
        body.appendString("--\(boundary)--\(lb)")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        // Attach latest access token with refresh support
        guard let base = URL(string: baseURL),
              let token = await TokenManager.shared.getValidAccessToken()
        else {
            throw ConversationUploadError.invalidResponse
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)

        #if DEBUG
        if let raw = String(data: data, encoding: .utf8) {
            print("📥 [ConversationUploadService] response:\n\(raw)")
        }
        #endif

        guard let http = response as? HTTPURLResponse else {
            throw ConversationUploadError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw ConversationUploadError.serverError(statusCode: http.statusCode)
        }
    }

    // MARK: - Private

    private func buildPayload(
        conversationId: String,
        conversationName: String,
        messages: [ChatMessage]
    ) -> ConversationUploadPayload {
        let items: [ConversationUploadItem] = messages.map { msg in
            ConversationUploadItem(
                type: msg.role == .user ? "user" : "bot",
                content: msg.content,
                followups: msg.followups,
                links: nil,
                sources: msg.sources?.compactMap { $0.url }
            )
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return ConversationUploadPayload(
            conversation_id: conversationId,
            conversation_name: conversationName,
            module: "chat",
            content: items,
            conversation_date: formatter.string(from: Date())
        )
    }
}

// MARK: - Errors

enum ConversationUploadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid conversation upload URL."
        case .invalidResponse:       return "Received an invalid response from server."
        case .serverError(let code): return "Conversation upload failed (\(code))."
        }
    }
}

// MARK: - Data helper

private extension Data {
    mutating func appendString(_ s: String) {
        if let d = s.data(using: .utf8) { append(d) }
    }
}
