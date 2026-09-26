import Foundation

public enum AIConnectionValidationStatus: Equatable {
    case missingKey
    case invalidFormat(String)
    case localFormatValid(String)

    public var message: String {
        switch self {
        case .missingKey:
            return "Missing API key"
        case .invalidFormat(let message), .localFormatValid(let message):
            return message
        }
    }

    public var isFailure: Bool {
        switch self {
        case .missingKey, .invalidFormat:
            return true
        case .localFormatValid:
            return false
        }
    }
}

public enum AIConnectionValidator {
    public static func validate(provider: AIProviderKind, apiKey: String) -> AIConnectionValidationStatus {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .missingKey }
        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return .invalidFormat("Invalid key format")
        }
        guard trimmed.count >= 12 else { return .invalidFormat("Invalid key format") }

        switch provider {
        case .openAI, .deepSeek:
            guard trimmed.hasPrefix("sk-") else { return .invalidFormat("Invalid key format") }
        case .anthropic:
            guard trimmed.hasPrefix("sk-ant-") else { return .invalidFormat("Invalid key format") }
        case .googleGemini:
            guard trimmed.count >= 20 else { return .invalidFormat("Invalid key format") }
        case .groq, .mistral, .xAI, .togetherAI, .fireworksAI, .openRouter, .perplexity:
            break
        }

        return .localFormatValid("Key format OK; live test not run")
    }
}
