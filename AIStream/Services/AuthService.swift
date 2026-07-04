//
//  AuthService.swift
//  AIStream
//
//  Created by Poonam More on 18/02/26.
//

import Foundation
import  Combine

/// Handles authentication: login, logout, and session state.
final class AuthService: ObservableObject {
    
    static let shared = AuthService()
    
    private let userDefaultsKey = "currentUser"
    
    @Published private(set) var isAuthenticated: Bool = false
    
    private init() {
        isAuthenticated = KeychainHelper.shared.getAccessToken() != nil
    }
    
    // MARK: - Login
    
    /// Performs login and stores token + user
    func login(email: String, password: String) async throws -> LoginResponse {
        let body = LoginRequest(email: email, password: password)
        let urlString = APIClient.baseURL + "/auth/login"
        let url = URL(string: urlString)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let loginResponse = try decoder.decode(LoginResponse.self, from: data)
            try await completeLogin(loginResponse)
            return loginResponse
        case 401:
            throw AuthError.invalidCredentials
        default:
            throw AuthError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    private func completeLogin(_ response: LoginResponse) async throws {
        guard let refresh = response.refreshToken else {
            throw AuthError.invalidResponse
        }

        await TokenManager.shared.updateTokens(
            accessToken: response.accessToken,
            refreshToken: refresh
        )

        let user = User(email: response.email)
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }

        await MainActor.run {
            isAuthenticated = true
        }
    }
    
    // MARK: - Logout
    
    func logout() {
        KeychainHelper.shared.deleteAccessToken()
        KeychainHelper.shared.deleteRefreshToken()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        isAuthenticated = false
    }
    
    // MARK: - User Info
    
    var currentUser: User? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }
    
    /// Call when 401 is received - clears session and updates state
    @MainActor
    func handleUnauthorized() {
        logout()
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidCredentials
    case invalidResponse
    case serverError(statusCode: Int)
    case tokenStorageFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error (\(code)). Please try again."
        case .tokenStorageFailed:
            return "Failed to save session"
        }
    }
}
