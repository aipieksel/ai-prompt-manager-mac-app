import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum LiveAIProviderError: Error, LocalizedError, Sendable {
    case missingAPIKey(AIProviderKind)
    case unsupportedProvider(AIProviderKind)
    case invalidResponse
    case httpError(Int, String)
    case emptyContent
    case thinkingReturnedNoFinalContent

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider.displayName). Add it in Settings > AI Providers."
        case .unsupportedProvider(let provider):
            return "Live API calls are not implemented for \(provider.displayName) yet. OpenAI and DeepSeek are available now."
        case .invalidResponse:
            return "Provider returned an invalid response."
        case .httpError(let status, let message):
            return "Provider API error \(status): \(message)"
        case .emptyContent:
            return "Provider returned an empty message."
        case .thinkingReturnedNoFinalContent:
            return "DeepSeek thinking mode returned reasoning but no final answer. Disable Thinking mode for file-output chain steps, or update the prompt to require a final answer."
        }
    }
}

public struct LiveAIProviderClient: ChainProviderClient, @unchecked Sendable {
    public var keychain: AIKeychainService
    public var urlSession: URLSession
    public var userDefaults: UserDefaults

    public init(keychain: AIKeychainService = AIKeychainService(), urlSession: URLSession = .shared, userDefaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.urlSession = urlSession
        self.userDefaults = userDefaults
    }

    public func complete(prompt: String, provider: AIProviderKind, modelID: String) async throws -> String {
        let key = try keychain.readKey(for: provider).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw LiveAIProviderError.missingAPIKey(provider) }
        let request = try makeChatCompletionsRequest(prompt: prompt, provider: provider, modelID: modelID, apiKey: key)
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            AIRequestLogService(userDefaults: userDefaults).append(provider: provider, modelID: modelID, requestText: prompt, responseText: "Invalid provider response", status: "invalid-response")
            throw LiveAIProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = Self.providerErrorMessage(from: data)
            AIRequestLogService(userDefaults: userDefaults).append(provider: provider, modelID: modelID, requestText: prompt, responseText: message, status: "error \(http.statusCode)")
            throw LiveAIProviderError.httpError(http.statusCode, message)
        }
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        let message = decoded.choices.first?.message
        guard let content = message?.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            let reasoning = message?.reasoning_content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if provider == .deepSeek, !reasoning.isEmpty {
                AIRequestLogService(userDefaults: userDefaults).append(provider: provider, modelID: modelID, requestText: prompt, responseText: reasoning, status: "thinking-only")
                throw LiveAIProviderError.thinkingReturnedNoFinalContent
            }
            AIRequestLogService(userDefaults: userDefaults).append(provider: provider, modelID: modelID, requestText: prompt, responseText: "Provider returned an empty message.", status: "empty")
            throw LiveAIProviderError.emptyContent
        }
        AIRequestLogService(userDefaults: userDefaults).append(provider: provider, modelID: modelID, requestText: prompt, responseText: content, status: "success")
        return content
    }

    public func makeChatCompletionsRequest(prompt: String, provider: AIProviderKind, modelID: String, apiKey: String) throws -> URLRequest {
        guard let endpoint = provider.chatCompletionsEndpoint else { throw LiveAIProviderError.unsupportedProvider(provider) }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let thinkingMode = ThinkingModeConfiguration(provider: provider, rawValue: userDefaults.string(forKey: AppSettingsKeys.aiThinkingMode) ?? "Disabled")
        let body = ChatCompletionRequest(
            model: modelID,
            messages: [
                ChatMessage(role: "system", content: "You are a precise assistant running inside Prompt Manager. Return the useful result only."),
                ChatMessage(role: "user", content: prompt)
            ],
            temperature: thinkingMode.omitsTemperature ? nil : userDefaults.double(forKey: AppSettingsKeys.aiTemperature),
            max_tokens: max(1, userDefaults.integer(forKey: AppSettingsKeys.aiMaxTokens)),
            thinking: thinkingMode.deepSeekThinkingPayload,
            reasoning_effort: thinkingMode.deepSeekReasoningEffort
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    public static func providerErrorMessage(from data: Data) -> String {
        if let decoded = try? JSONDecoder().decode(ProviderErrorResponse.self, from: data) {
            return decoded.error.message
        }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).prefix(500).description
    }
}

extension AIProviderKind {
    public var chatCompletionsEndpoint: URL? {
        switch self {
        case .openAI:
            return URL(string: "https://api.openai.com/v1/chat/completions")
        case .deepSeek:
            return URL(string: "https://api.deepseek.com/chat/completions")
        case .groq, .mistral, .xAI, .togetherAI, .fireworksAI, .openRouter, .perplexity, .googleGemini, .anthropic:
            return nil
        }
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let max_tokens: Int
    let thinking: DeepSeekThinkingPayload?
    let reasoning_effort: String?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, max_tokens, thinking, reasoning_effort
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(max_tokens, forKey: .max_tokens)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(thinking, forKey: .thinking)
        try container.encodeIfPresent(reasoning_effort, forKey: .reasoning_effort)
    }
}

private struct DeepSeekThinkingPayload: Encodable {
    let type: String
}

private struct ThinkingModeConfiguration {
    let provider: AIProviderKind
    let rawValue: String

    var deepSeekThinkingPayload: DeepSeekThinkingPayload? {
        guard provider == .deepSeek else { return nil }
        switch rawValue {
        case "Disabled", "Off", "Fast":
            return DeepSeekThinkingPayload(type: "disabled")
        case "Enabled", "Max", "Deep", "High", "Auto":
            return DeepSeekThinkingPayload(type: "enabled")
        default:
            return DeepSeekThinkingPayload(type: "enabled")
        }
    }

    var deepSeekReasoningEffort: String? {
        nil
    }

    var omitsTemperature: Bool {
        guard provider == .deepSeek else { return false }
        return deepSeekThinkingPayload?.type == "enabled"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String?
    let reasoning_content: String?

    init(role: String, content: String?, reasoning_content: String? = nil) {
        self.role = role
        self.content = content
        self.reasoning_content = reasoning_content
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable { let message: ChatMessage }
}

private struct ProviderErrorResponse: Decodable {
    let error: ProviderError
    struct ProviderError: Decodable { let message: String }
}
