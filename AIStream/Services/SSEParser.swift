//
//  SSEParser.swift
//  AIStream
//
//  Created by Poonam More on 28/02/26.
//

import Foundation

// MARK: - Reusable SSE Parser

struct SSEParser {
    /// Parses a single SSE line. Returns nil for non-data lines (e.g. `id=...`).
    static func parse(line: String) -> (text: String?, isEnd: Bool)? {
        guard line.hasPrefix("data:") else { return nil }

        let jsonString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard
            let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // Handle both key variants for end-of-stream
        let isEnd = (json["end_of_stream"] as? Bool ?? false)
                 || (json["endofstream"]   as? Bool ?? false)

        if isEnd { return (nil, true) }

        if let text = json["data"] as? String {
            return (text, false)
        }
        return nil
    }
}

// MARK: - ProjectStreamService

final class ProjectStreamService {
    private let baseURL: String
    private let accessToken: String

    init(baseURL: String, accessToken: String) {
        self.baseURL = baseURL
        self.accessToken = accessToken
    }

    /// Starts a streaming request. Returns a cancellable `Task`.
    /// All callbacks fire on the main thread.
    @discardableResult
    func streamResponse(
        question: String,
        projectId: Int,
        onChunk:      @escaping @Sendable (String) -> Void,
        onCompletion: @escaping @Sendable ()       -> Void,
        onError:      @escaping @Sendable (Error)  -> Void
    ) -> Task<Void, Never> {
        Task {
            do {
                try await perform(
                    question: question,
                    projectId: projectId,
                    onChunk: onChunk,
                    onCompletion: onCompletion
                )
            } catch is CancellationError {
                // Intentionally cancelled — no-op
            } catch {
                await MainActor.run { onError(error) }
            }
        }
    }

    // MARK: Private

    private func perform(
        question: String,
        projectId: Int,
        onChunk:      @escaping @Sendable (String) -> Void,
        onCompletion: @escaping @Sendable ()       -> Void
    ) async throws {
        var components = URLComponents(string: "\(baseURL)/projects/stream")!
        components.queryItems = [
            URLQueryItem(name: "question", value: question),
            URLQueryItem(name: "id",       value: "\(projectId)")
        ]
        guard let url = components.url else { throw StreamError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw StreamError.badResponse
        }

        for try await line in asyncBytes.lines {
            try Task.checkCancellation()

            guard let parsed = SSEParser.parse(line: line) else { continue }

            if parsed.isEnd {
                await MainActor.run { onCompletion() }
                return
            }
            if let text = parsed.text, !text.isEmpty {
                await MainActor.run { onChunk(text) }
            }
        }

        // Stream closed without explicit end marker
        await MainActor.run { onCompletion() }
    }
}

// MARK: - Errors

enum StreamError: LocalizedError {
    case invalidURL
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:   return "Could not build a valid stream URL."
        case .badResponse:  return "Stream endpoint returned an error response."
        }
    }
}
