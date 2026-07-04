//
//  UploadResponse.swift
//  AIStream
//
//  Created by Poonam More on 28/02/26.
//

import Foundation

// MARK: - Upload Response (single file)

struct UploadResponse: Codable {
    let task_id: String?
    let status_url: String?
    var resolvedJobId: String? { task_id }
}

// MARK: - Multi-File Upload Response

struct MultiUploadResponse: Codable {
    let task_id: String?
    let status_url: String?
    let saved_files: [String]?
    var resolvedJobId: String? { task_id }
}

// MARK: - Upload Progress Delegate

final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    var onProgress: ((Double) -> Void)?

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async { self.onProgress?(progress) }
    }
}

// MARK: - FileUploadService

final class FileUploadService {
    private let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    // MARK: - Single File Upload (/uploadlf) — uses name="file"

    func uploadFile(
        fileURL: URL,
        projectId: Int,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> String {
        guard let endpoint = URL(string: "\(baseURL)/files/upload") else {
            throw UploadError.invalidURL
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        let fileData = try Data(contentsOf: fileURL)
        var body = Data()
        let lb = "\r\n"

        // project_id field
        body.appendString("--\(boundary)\(lb)")
        body.appendString("Content-Disposition: form-data; name=\"project_id\"\(lb)\(lb)")
        body.appendString("\(projectId)\(lb)")

        // single file field — name="file"
        body.appendString("--\(boundary)\(lb)")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\(lb)")
        body.appendString("Content-Type: \(mimeType(for: fileURL))\(lb)\(lb)")
        body.append(fileData)
        body.appendString(lb)

        body.appendString("--\(boundary)--\(lb)")

        return try await performUpload(
            endpoint: endpoint,
            body: body,
            boundary: boundary,
            onProgress: onProgress,
            decode: { data in
                #if DEBUG
                print("📥 [uploadFile response]: \(String(data: data, encoding: .utf8) ?? "nil")")
                #endif
                let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
                guard let jobId = decoded.resolvedJobId else { throw UploadError.missingJobId }
                return jobId
            }
        )
    }

    // MARK: - Multi-File Upload (/uploadlfs) — uses name="files"

    func uploadFiles(
        fileURLs: [URL],
        projectId: Int,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> String {
        guard let endpoint = URL(string: "\(baseURL)/files/upload/batch") else {
            throw UploadError.invalidURL
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        let lb = "\r\n"

        // project_id field
        body.appendString("--\(boundary)\(lb)")
        body.appendString("Content-Disposition: form-data; name=\"project_id\"\(lb)\(lb)")
        body.appendString("\(projectId)\(lb)")

        // Each file as a separate "files" field — name="files" (plural)
        for fileURL in fileURLs {
            let fileData = try Data(contentsOf: fileURL)
            body.appendString("--\(boundary)\(lb)")
            body.appendString("Content-Disposition: form-data; name=\"files\"; filename=\"\(fileURL.lastPathComponent)\"\(lb)")
            body.appendString("Content-Type: \(mimeType(for: fileURL))\(lb)\(lb)")
            body.append(fileData)
            body.appendString(lb)
        }

        body.appendString("--\(boundary)--\(lb)")

        return try await performUpload(
            endpoint: endpoint,
            body: body,
            boundary: boundary,
            onProgress: onProgress,
            decode: { data in
                #if DEBUG
                print("📥 [uploadFiles response]: \(String(data: data, encoding: .utf8) ?? "nil")")
                #endif
                let decoded = try JSONDecoder().decode(MultiUploadResponse.self, from: data)
                guard let jobId = decoded.resolvedJobId else { throw UploadError.missingJobId }
                return jobId
            }
        )
    }

    // MARK: - Shared Upload Executor

    private func performUpload(
        endpoint: URL,
        body: Data,
        boundary: String,
        onProgress: @escaping @Sendable (Double) -> Void,
        decode: @escaping (Data) throws -> String
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        if let token = await TokenManager.shared.getValidAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let delegate = UploadProgressDelegate()
        delegate.onProgress = onProgress

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 300
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        let (data, response) = try await session.upload(for: request, from: body)

        #if DEBUG
        if let http = response as? HTTPURLResponse {
            print("📡 [\(endpoint.lastPathComponent)] status: \(http.statusCode)")
        }
        if let raw = String(data: data, encoding: .utf8) {
            print("📥 [\(endpoint.lastPathComponent)] body: \(raw)")
        }
        #endif

        guard let http = response as? HTTPURLResponse else { throw UploadError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw UploadError.serverError(statusCode: http.statusCode)
        }

        return try decode(data)
    }

    // MARK: - MIME Type

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":         return "application/pdf"
        case "png":         return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "docx":        return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "doc":         return "application/msword"
        default:            return "application/octet-stream"
        }
    }
}

// MARK: - Errors

enum UploadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case missingJobId

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid upload URL."
        case .invalidResponse:       return "Received an invalid server response."
        case .serverError(let code): return "Server returned error \(code)."
        case .missingJobId:          return "Server did not return a job ID."
        }
    }
}

private extension Data {
    mutating func appendString(_ s: String) {
        if let d = s.data(using: .utf8) { append(d) }
    }
}
