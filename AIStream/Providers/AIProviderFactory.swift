import Foundation

/// Factory for creating the active AI provider based on configuration.
enum AIProviderFactory {

    static func makeProvider(kind: AppConfiguration.AIProviderKind? = nil) -> any AIProvider {
        switch kind ?? AppConfiguration.aiProvider {
        case .mock:
            return MockAIProvider()
        case .openai:
            guard let key = AppConfiguration.openAIAPIKey else {
                return MockAIProvider()
            }
            return OpenAIProvider(apiKey: key)
        case .gemini:
            guard let key = AppConfiguration.geminiAPIKey else {
                return MockAIProvider()
            }
            return GeminiAIProvider(apiKey: key)
        }
    }

    static func makeProvider(for kind: AppConfiguration.AIProviderKind) -> any AIProvider {
        switch kind {
        case .mock:
            return MockAIProvider()
        case .openai:
            guard let key = AppConfiguration.openAIAPIKey else {
                return MockAIProvider()
            }
            return OpenAIProvider(apiKey: key)
        case .gemini:
            guard let key = AppConfiguration.geminiAPIKey else {
                return MockAIProvider()
            }
            return GeminiAIProvider(apiKey: key)
        }
    }
}
