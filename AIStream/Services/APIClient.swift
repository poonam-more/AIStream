//
//  APIClient.swift
//  AIStream
//
//  Created by Poonam More on 12/02/26.
//

import Foundation

enum APIClient {

    static var baseURL: String {
        AppConfiguration.apiBaseURL ?? "https://api.example.com"
    }
    static var onUnauthorized: (() -> Void)?

    // MARK: - Core request (JSON)

    /// Request without a JSON body (e.g. GET, simple DELETE).
    static func request<T: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        requiresAuth: Bool = true,
        responseType: T.Type = T.self
    ) async throws -> T {
        return try await request(
            path: path,
            method: method,
            queryItems: queryItems,
            bodyData: nil,
            headers: headers,
            requiresAuth: requiresAuth,
            responseType: responseType
        )
    }

    /// Request with a JSON body (e.g. POST, PUT).
    static func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Body,
        headers: [String: String] = [:],
        requiresAuth: Bool = true,
        responseType: T.Type = T.self
    ) async throws -> T {
        return try await request(
            path: path,
            method: method,
            queryItems: queryItems,
            bodyData: JSONEncoder().encode(body),
            headers: headers,
            requiresAuth: requiresAuth,
            responseType: responseType
        )
    }

    // MARK: - Internal implementation

    private static func request<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem]?,
        bodyData: Data?,
        headers: [String: String],
        requiresAuth: Bool,
        responseType: T.Type
    ) async throws -> T {

        guard var components = URLComponents(string: baseURL) else {
            throw URLError(.badURL)
        }
        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }

        if let bodyData = bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }

        let baseURLObject = URL(string: baseURL)!

        if requiresAuth {
            if let token = await TokenManager.shared.getValidAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                await handleUnauthorizedGlobally()
                throw URLError(.userAuthenticationRequired)
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if (200...299).contains(http.statusCode) {
            return try JSONDecoder().decode(T.self, from: data)
        }

        if http.statusCode == 401, requiresAuth {
            // Try refresh then retry once
            let refreshedTokens = await TokenManager.shared.refreshIfNeeded(baseURL: baseURLObject)
            guard refreshedTokens != nil else {
                await handleUnauthorizedGlobally()
                throw URLError(.userAuthenticationRequired)
            }

            var retryRequest = request
            if let newToken = await TokenManager.shared.currentAccessToken() {
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            }

            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            guard let retryHttp = retryResponse as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if (200...299).contains(retryHttp.statusCode) {
                return try JSONDecoder().decode(T.self, from: retryData)
            } else {
                if retryHttp.statusCode == 401 {
                    await handleUnauthorizedGlobally()
                    throw URLError(.userAuthenticationRequired)
                }
                throw URLError(.badServerResponse)
            }
        }

        throw URLError(.badServerResponse)
    }

    @MainActor
    private static func handleUnauthorizedGlobally() async {
        AppSession.shared.handleUnauthorized()
        onUnauthorized?()
    }
}
