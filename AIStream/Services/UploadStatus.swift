//
//  UploadStatus.swift
//  AIStream
//
//  Created by Poonam More on 28/02/26.
//

import Foundation

// MARK: - Status Model

enum UploadStatus: String, Codable {
    case uploading
    case processing
    case completed
    case success       // API returns "SUCCESS"
    case failed
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = UploadStatus(rawValue: raw.lowercased()) ?? .unknown
    }

    var isTerminal: Bool { self == .completed || self == .success || self == .failed }

    var displayText: String {
        switch self {
        case .uploading:        return "Uploading…"
        case .processing:       return "Processing…"
        case .completed,
             .success:          return "Completed"
        case .failed:           return "Failed"
        case .unknown:          return "Checking…"
        }
    }
}

// MARK: - Status Response

struct StatusResponse: Codable {
    let status: String?
    let state: String?
}

// MARK: - UploadStatusService

final class UploadStatusService {
    private let baseURL: String
    
    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func checkStatus(jobId: String) async throws -> StatusResponse {
        do {
            let decoded: StatusResponse = try await APIClient.request(
                path: "/status/\(jobId)",
                method: "GET",
                requiresAuth: true,
                responseType: StatusResponse.self
            )
            return decoded
        } catch {
            throw StatusError.badResponse
        }
    }

    /// Polls every `interval` seconds until a terminal state is reached.
    /// `onUpdate` is always called on the main thread.
    func pollStatus(
        jobId: String,
        interval: TimeInterval = 3,
        onUpdate: @escaping @Sendable (String?) -> Void
    ) async throws {
        while true {
            let result = try await checkStatus(jobId: jobId)
            await MainActor.run { onUpdate(result.state) }
            if isTerminalState(result.state) { return }
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private func isTerminalState(_ state: String?) -> Bool {
        guard let state = state else { return false }
        switch state.uppercased() {
        case "SUCCESS", "COMPLETED", "FAILED", "CANCELLED":
            return true
        default:
            return false
        }
    }
}

// MARK: - Errors

enum StatusError: LocalizedError {
    case invalidURL
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:   return "Invalid status URL."
        case .badResponse:  return "Failed to retrieve upload status."
        }
    }
}
