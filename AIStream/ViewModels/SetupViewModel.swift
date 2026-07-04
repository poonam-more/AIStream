import Foundation
import Combine

@MainActor
final class SetupViewModel: ObservableObject {

    @Published var displayName: String = ""
    @Published var selectedProvider: AppConfiguration.AIProviderKind = .mock
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false

    private let session: AppSession

    init(session: AppSession = .shared) {
        self.session = session
    }

    var canContinue: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    var availableProviders: [AppConfiguration.AIProviderKind] {
        AppConfiguration.AIProviderKind.allCases
    }

    func providerRequiresAPIKey(_ provider: AppConfiguration.AIProviderKind) -> Bool {
        switch provider {
        case .mock: return false
        case .openai: return AppConfiguration.openAIAPIKey == nil
        case .gemini: return AppConfiguration.geminiAPIKey == nil
        }
    }

    func continueToApp() {
        guard canContinue else { return }

        if providerRequiresAPIKey(selectedProvider) {
            errorMessage = "Add your \(selectedProvider.displayName) API key in Config/Secrets.xcconfig, or choose Demo mode."
            showErrorAlert = true
            return
        }

        errorMessage = nil
        isLoading = true

        session.completeSetup(
            provider: selectedProvider,
            name: displayName.trimmingCharacters(in: .whitespaces)
        )
        isLoading = false
    }

    func clearError() {
        errorMessage = nil
        showErrorAlert = false
    }
}
