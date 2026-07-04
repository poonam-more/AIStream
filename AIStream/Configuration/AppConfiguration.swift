import Foundation

/// Central configuration loaded from Info.plist (populated via Secrets.xcconfig at build time).
enum AppConfiguration {

    enum AIProviderKind: String, CaseIterable, Sendable {
        case mock
        case openai
        case gemini

        var displayName: String {
            switch self {
            case .mock: return "Demo (Mock)"
            case .openai: return "OpenAI"
            case .gemini: return "Google Gemini"
            }
        }
    }

    static var aiProvider: AIProviderKind {
        let raw = string(for: "AI_PROVIDER") ?? "mock"
        return AIProviderKind(rawValue: raw.lowercased()) ?? .mock
    }

    static var openAIAPIKey: String? {
        nonEmpty(string(for: "OPENAI_API_KEY"))
    }

    static var geminiAPIKey: String? {
        nonEmpty(string(for: "GEMINI_API_KEY"))
    }

    static var apiBaseURL: String? {
        nonEmpty(string(for: "API_BASE_URL"))
    }

    static var openAIModel: String {
        string(for: "OPENAI_MODEL") ?? "gpt-4o-mini"
    }

    static var geminiModel: String {
        string(for: "GEMINI_MODEL") ?? "gemini-2.0-flash"
    }

    /// When true, all backend services use in-memory mock implementations.
    static var useMockServices: Bool {
        apiBaseURL == nil || aiProvider == .mock
    }

    static var appDisplayName: String { "AIStream" }

    static var keychainServiceName: String {
        Bundle.main.bundleIdentifier ?? "com.aistream.app"
    }

    // MARK: - Private

    private static func string(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard var value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        // Strip surrounding quotes from xcconfig values
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }

        let placeholders = ["your_openai_api_key_here", "your_gemini_api_key_here", "$(OPENAI_API_KEY)", "$(GEMINI_API_KEY)"]
        if placeholders.contains(value) { return nil }
        return value.isEmpty ? nil : value
    }
}
