//
//  StreamingService.swift
//  AIStream
//
//  Created by Poonam More on 18/02/26.
//

import Foundation

/// Legacy SSE streaming adapter for custom backends. Prefer `AIProvider` for new integrations.
/// Uses URLSessionDataDelegate to receive data incrementally.
final class StreamingService: NSObject {
    
    static let shared = StreamingService()
    
    private var buffer = ""
    private var currentTask: URLSessionDataTask?
    private var session: URLSession!
    
    /// Callbacks - stored for delegate to invoke
    private var onEvent: ((StreamEvent) -> Void)?
    private var onComplete: (() -> Void)?
    private var onError: ((Error) -> Void)?
    private var continuation: CheckedContinuation<Void, Error>?
    
    private let lock = NSLock()
    
    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Public API
    
    /// Streams answer for the given question. Callbacks are invoked on arbitrary queue; caller must dispatch to main if needed.
    /// - Parameters:
    ///   - question: User's question (URL-encoded automatically)
    ///   - onEvent: Called for each parsed SSE event
    ///   - onComplete: Called when stream ends normally
    ///   - onError: Called on failure (401, network error, parse error)
    func streamAnswer(
        question: String,
        onEvent: @escaping (StreamEvent) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        cancel()
        guard let url = buildURL(question: question) else {
            onError(StreamingError.invalidQuestion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let token = KeychainHelper.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        lock.lock()
        self.onEvent = onEvent
        self.onComplete = onComplete
        self.onError = onError
        buffer = ""
        lock.unlock()
        
        let task = session.dataTask(with: request)
        currentTask = task
        task.resume()
    }
    
    /// Cancels any in-flight stream.
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        lock.lock()
        buffer = ""
        onEvent = nil
        onComplete = nil
        onError = nil
        lock.unlock()
    }
    
    // MARK: - Private
    
    private func buildURL(question: String) -> URL? {
        var components = URLComponents(string: APIClient.baseURL)
        components?.path = "/chat/stream"
        components?.queryItems = [URLQueryItem(name: "question", value: question)]
        return components?.url
    }
}

// MARK: - URLSessionDataDelegate

extension StreamingService: URLSessionDataDelegate {
    
    /// Receives data incrementally - parse SSE lines as they arrive.
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        #if DEBUG
        // Raw SSE chunks available in debugger if needed
        _ = string
        #endif
        lock.lock()
        buffer += string
        let lines = buffer.components(separatedBy: "\n")
        buffer = lines.last ?? ""
        let fullLines = lines.dropLast()
        lock.unlock()
        
        for line in fullLines {
            // Preserve whitespace - only check prefix, don't trim
            guard line.hasPrefix("data: ") else { continue }
            
            // Extract JSON string preserving all whitespace and newlines
            let jsonString = String(line.dropFirst(6))
            guard !jsonString.isEmpty else { continue }
            
            if let event = parseEvent(jsonString) {
                lock.lock()
                let callback = onEvent
                lock.unlock()
                callback?(event)
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError?, error.code == NSURLErrorCancelled {
            return
        }
        
        if let error {
            lock.lock()
            let callback = onError
            lock.unlock()
            callback?(error)
        } else {
            lock.lock()
            let callback = onComplete
            lock.unlock()
            callback?()
        }
        
        lock.lock()
        currentTask = nil
        onEvent = nil
        onComplete = nil
        onError = nil
        lock.unlock()
    }
    
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        
        if httpResponse.statusCode == 401 {
            // Attempt token refresh once, then caller can re-start streaming if needed.
            Task {
                let base = URL(string: APIClient.baseURL)!
                _ = await TokenManager.shared.refreshIfNeeded(baseURL: base)
                if KeychainHelper.shared.getAccessToken() == nil {
                    DispatchQueue.main.async { APIClient.onUnauthorized?() }
                }
            }
            lock.lock()
            let callback = onError
            onEvent = nil
            onComplete = nil
            onError = nil
            lock.unlock()
            callback?(StreamingError.unauthorized)
            completionHandler(.cancel)
            return
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            lock.lock()
            let callback = onError
            lock.unlock()
            callback?(StreamingError.httpError(statusCode: httpResponse.statusCode))
            completionHandler(.cancel)
            return
        }
        
        completionHandler(.allow)
    }
    
    /// Safely decodes JSON to StreamEvent. Ignores malformed lines.
    private func parseEvent(_ jsonString: String) -> StreamEvent? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(StreamEvent.self, from: data)
    }
}

// MARK: - Errors

enum StreamingError: LocalizedError {
    case unauthorized
    case invalidQuestion
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please log in again."
        case .invalidQuestion:
            return "Invalid question"
        case .httpError(let code):
            return "Request failed (\(code))"
        }
    }
}
