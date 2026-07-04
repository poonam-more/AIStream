//
//  TokenManager.swift
//  AIStream
//
//  Created by Poonam More on 16/03/26.
//

import Foundation

protocol AuthStateListener: AnyObject {
    func didRequireReauthentication()
}

actor TokenManager {

    static let shared = TokenManager()

    private let keychain = KeychainHelper.shared
    private var tokens: AuthTokens?

    // single-flight refresh
    private var isRefreshing = false
    private var refreshWaiters: [CheckedContinuation<AuthTokens?, Never>] = []

    weak var listener: AuthStateListener?

    private init() {
        tokens = loadFromKeychain()
    }

    // MARK: - Public

    // Listener management
    nonisolated func setListener(_ listener: AuthStateListener?) {
        Task { [weak self] in
            await self?.setListenerIsolated(listener)
        }
    }

    private func setListenerIsolated(_ listener: AuthStateListener?) {
        self.listener = listener
    }

    func currentAccessToken() -> String? {
        tokens?.accessToken
    }

    /// Just returns the current token; refresh is triggered by 401 handling in APIClient.
    func getValidAccessToken() async -> String? {
        return tokens?.accessToken
    }

    func updateTokens(accessToken: String, refreshToken: String) {
        let newTokens = AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
        tokens = newTokens
        saveToKeychain(newTokens)
    }

    func clearTokens() {
        tokens = nil
        keychain.deleteAccessToken()
        keychain.deleteRefreshToken()
    }

    // MARK: - Refresh (only when 401 is detected)

    func refreshIfNeeded(baseURL: URL) async -> AuthTokens? {
        // If we still have tokens, try refresh; if no tokens, nothing to do.
        guard tokens != nil || loadFromKeychain() != nil else {
            return nil
        }

        if isRefreshing {
            return await withCheckedContinuation { continuation in
                refreshWaiters.append(continuation)
            }
        }

        isRefreshing = true
        let result = await performRefresh(baseURL: baseURL)

        let waiters = refreshWaiters
        refreshWaiters.removeAll()
        isRefreshing = false

        for w in waiters {
            w.resume(returning: result)
        }

        return result
    }

    private func performRefresh(baseURL: URL) async -> AuthTokens? {
        guard let current = tokens ?? loadFromKeychain(),
              !current.refreshToken.isEmpty
        else {
            return nil
        }

        let service = RefreshTokenService(baseURL: baseURL)

        do {
            let response = try await service.refresh(refreshToken: current.refreshToken)
            updateTokens(
                accessToken: response.accessToken,
                refreshToken: current.refreshToken
            )
            return tokens
        } catch {
            await handleLogout()
            return nil
        }
    }

    // MARK: - Helpers

    private func saveToKeychain(_ tokens: AuthTokens) {
        _ = keychain.saveAccessToken(tokens.accessToken)
        _ = keychain.saveRefreshToken(tokens.refreshToken)
    }

    private func loadFromKeychain() -> AuthTokens? {
        guard
            let access = keychain.getAccessToken(),
            let refresh = keychain.getRefreshToken()
        else { return nil }

        let loaded = AuthTokens(accessToken: access, refreshToken: refresh)
        tokens = loaded
        return loaded
    }

    private func handleLogout() async {
        clearTokens()
        // Capture the listener inside the actor and then hop to MainActor to notify
        if let listener = self.listener {
            await MainActor.run {
                listener.didRequireReauthentication()
            }
        }
    }
}

