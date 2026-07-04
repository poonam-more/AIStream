import Foundation
import Combine

/// Manages app session state. Replaces client-specific authentication with a simple setup flow.
@MainActor
final class AppSession: ObservableObject {

    static let shared = AppSession()

    private let hasCompletedSetupKey = "hasCompletedSetup"
    private let selectedProviderKey = "selectedProvider"
    private let displayNameKey = "displayName"

    @Published private(set) var isAuthenticated: Bool = false
    @Published var selectedProvider: AppConfiguration.AIProviderKind = .mock
    @Published var displayName: String = ""

    private init() {
        isAuthenticated = UserDefaults.standard.bool(forKey: hasCompletedSetupKey)
        if let raw = UserDefaults.standard.string(forKey: selectedProviderKey),
           let kind = AppConfiguration.AIProviderKind(rawValue: raw) {
            selectedProvider = kind
        }
        displayName = UserDefaults.standard.string(forKey: displayNameKey) ?? ""
    }

    /// Completes onboarding — demo mode works without an API key.
    func completeSetup(provider: AppConfiguration.AIProviderKind, name: String) {
        selectedProvider = provider
        displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        UserDefaults.standard.set(true, forKey: hasCompletedSetupKey)
        UserDefaults.standard.set(provider.rawValue, forKey: selectedProviderKey)
        UserDefaults.standard.set(displayName, forKey: displayNameKey)

        ServiceContainer.shared.updateAIProvider(kind: provider)
        isAuthenticated = true
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: hasCompletedSetupKey)
        UserDefaults.standard.removeObject(forKey: selectedProviderKey)
        UserDefaults.standard.removeObject(forKey: displayNameKey)
        KeychainHelper.shared.deleteAccessToken()
        KeychainHelper.shared.deleteRefreshToken()
        isAuthenticated = false
        selectedProvider = .mock
        displayName = ""
    }

    func handleUnauthorized() {
        logout()
    }
}
