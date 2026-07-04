//
//  KeychainHelper.swift
//  AIStream
//
//  Created by Poonam More on 18/02/26.
//

import Foundation
import Security

/// Secure storage for sensitive data like access tokens.
/// Uses iOS Keychain - never store tokens in UserDefaults.
final class KeychainHelper {

    static let shared = KeychainHelper()

    private var serviceName: String { AppConfiguration.keychainServiceName }
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"   

    private init() {}

    // MARK: - Access Token

    func saveAccessToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        return save(key: accessTokenKey, data: data)
    }

    func getAccessToken() -> String? {
        guard let data = load(key: accessTokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func deleteAccessToken() -> Bool {
        delete(key: accessTokenKey)
    }

    // MARK: - Refresh Token (NEW)

    func saveRefreshToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        return save(key: refreshTokenKey, data: data)
    }

    func getRefreshToken() -> String? {
        guard let data = load(key: refreshTokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func deleteRefreshToken() -> Bool {
        delete(key: refreshTokenKey)
    }

    // MARK: - Generic Keychain Operations
    
    private func save(key: String, data: Data) -> Bool {
        _ = delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
