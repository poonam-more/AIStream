//
//  RefreshTokenService.swift
//  AIStream
//
//  Created by Poonam More on 16/03/26.
//


import Foundation

final class RefreshTokenService {

    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func refresh(refreshToken: String) async throws -> RefreshTokenResponse {
        var components = URLComponents(string: baseURL.absoluteString)
        components?.path = "/refresh"

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // API expects JSON content-type; body is not required.
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }

        return try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
    }
}
