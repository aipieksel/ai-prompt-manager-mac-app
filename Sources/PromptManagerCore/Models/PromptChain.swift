import Foundation

public struct ChainAIModel: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String
    public var displayName: String
    public init(id: String, displayName: String) { self.id = id; self.displayName = displayName }
}

public enum AIProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "openai"
    case groq = "groq"
    case mistral = "mistral"
    case deepSeek = "deepseek"
    case xAI = "xai"
    case togetherAI = "togetherAI"
    case fireworksAI = "fireworksAI"
    case openRouter = "openRouter"
    case perplexity = "perplexity"
    case googleGemini = "googleGemini"
    case anthropic = "anthropic"

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .groq: "Groq"
        case .mistral: "Mistral"
        case .deepSeek: "DeepSeek"
        case .xAI: "xAI (Grok)"
        case .togetherAI: "Together AI"
        case .fireworksAI: "Fireworks AI"
        case .openRouter: "OpenRouter"
        case .perplexity: "Perplexity"
        case .googleGemini: "Google Gemini"
        case .anthropic: "Anthropic"
        }
    }

    public var models: [ChainAIModel] {
        switch self {
        case .openAI:
            return [
                ChainAIModel(id: "gpt-4o", displayName: "GPT-4o"),
                ChainAIModel(id: "gpt-4o-mini", displayName: "GPT-4o Mini"),
                ChainAIModel(id: "gpt-4.1", displayName: "GPT-4.1"),
                ChainAIModel(id: "gpt-4.1-mini", displayName: "GPT-4.1 Mini"),
                ChainAIModel(id: "gpt-4.1-nano", displayName: "GPT-4.1 Nano"),
                ChainAIModel(id: "o3-mini", displayName: "o3 Mini"),
                ChainAIModel(id: "o4-mini", displayName: "o4 Mini")
            ]
        case .groq:
            return [
                ChainAIModel(id: "llama-3.3-70b-versatile", displayName: "Llama 3.3 70B"),
                ChainAIModel(id: "llama-3.1-8b-instant", displayName: "Llama 3.1 8B"),
                ChainAIModel(id: "qwen/qwen3-32b", displayName: "Qwen3 32B")
            ]
        case .mistral:
            return [
                ChainAIModel(id: "mistral-large-latest", displayName: "Mistral Large"),
                ChainAIModel(id: "mistral-medium-latest", displayName: "Mistral Medium"),
                ChainAIModel(id: "mistral-small-latest", displayName: "Mistral Small"),
                ChainAIModel(id: "codestral-latest", displayName: "Codestral")
            ]
        case .deepSeek:
            return [
                ChainAIModel(id: "deepseek-v4-flash", displayName: "DeepSeek V4 Flash"),
                ChainAIModel(id: "deepseek-v4-pro", displayName: "DeepSeek V4 Pro")
            ]
        case .xAI:
            return [
                ChainAIModel(id: "grok-4", displayName: "Grok 4"),
                ChainAIModel(id: "grok-3", displayName: "Grok 3"),
                ChainAIModel(id: "grok-3-mini", displayName: "Grok 3 Mini")
            ]
        case .togetherAI:
            return [
                ChainAIModel(id: "deepseek-ai/DeepSeek-V3.1", displayName: "DeepSeek V3.1"),
                ChainAIModel(id: "meta-llama/Llama-3.3-70B-Instruct-Turbo", displayName: "Llama 3.3 70B Turbo"),
                ChainAIModel(id: "Qwen/Qwen3-235B-A22B-Instruct-2507-tput", displayName: "Qwen3 235B"),
                ChainAIModel(id: "mistralai/Mistral-Small-24B-Instruct-2501", displayName: "Mistral Small 24B")
            ]
        case .fireworksAI:
            return [
                ChainAIModel(id: "accounts/fireworks/models/deepseek-v3p1", displayName: "DeepSeek V3.1"),
                ChainAIModel(id: "accounts/fireworks/models/llama-v3-70b-instruct", displayName: "Llama 3 70B"),
                ChainAIModel(id: "accounts/fireworks/models/qwen2-72b-instruct", displayName: "Qwen2 72B")
            ]
        case .openRouter:
            return [
                ChainAIModel(id: "openai/gpt-4o", displayName: "GPT-4o"),
                ChainAIModel(id: "anthropic/claude-sonnet-4-6", displayName: "Claude Sonnet 4.6"),
                ChainAIModel(id: "google/gemini-2.5-flash", displayName: "Gemini 2.5 Flash"),
                ChainAIModel(id: "deepseek/deepseek-chat", displayName: "DeepSeek Chat"),
                ChainAIModel(id: "meta-llama/llama-3.3-70b-instruct", displayName: "Llama 3.3 70B")
            ]
        case .perplexity:
            return [
                ChainAIModel(id: "sonar", displayName: "Sonar"),
                ChainAIModel(id: "sonar-pro", displayName: "Sonar Pro"),
                ChainAIModel(id: "sonar-reasoning-pro", displayName: "Sonar Reasoning Pro")
            ]
        case .googleGemini:
            return [
                ChainAIModel(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro"),
                ChainAIModel(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash"),
                ChainAIModel(id: "gemini-2.5-flash-lite", displayName: "Gemini 2.5 Flash Lite")
            ]
        case .anthropic:
            return [
                ChainAIModel(id: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6"),
                ChainAIModel(id: "claude-opus-4-1", displayName: "Claude Opus 4.1"),
                ChainAIModel(id: "claude-haiku-3-5", displayName: "Claude Haiku 3.5")
            ]
        }
    }

    public var defaultModelID: String { models.first?.id ?? "" }
}

public enum ChainVariableInputType: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case file
    case folder
    case previousStepOutput
    case loopFeedbackFile
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .text: "Text"
        case .file: "Text File"
        case .folder: "Input Folder"
        case .previousStepOutput: "Step Output"
        case .loopFeedbackFile: "Loop Feedback File"
        }
    }
}

public enum ChainOutputTransform: String, Codable, CaseIterable, Identifiable, Sendable {
    case rawMarkdown
    case plainText
    public var id: String { rawValue }
    public var displayName: String { self == .rawMarkdown ? "Raw Markdown" : "Plain Text" }
}

public enum ChainOutputPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case viewOnly
    case saveMarkdown
    case saveToHistory
    case saveAndUseNext
    public var id: String { rawValue }
    public static var variablePromptOptions: [ChainOutputPolicy] { [.viewOnly, .saveMarkdown] }
    public var displayName: String {
        switch self {
        case .viewOnly: "View Only"
        case .saveMarkdown: "Auto-save Markdown"
        case .saveToHistory: "Save to History"
        case .saveAndUseNext: "Save Markdown + use output in next step"
        }
    }
}

public enum ChainRunStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case queued
    case running
    case ready
    case complete
    case failed
    case cancelled
    case skipped
    case notRun
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .draft: "Draft"
        case .queued: "Queued"
        case .running: "Running"
        case .ready: "Ready"
        case .complete: "Complete"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .skipped: "Skipped"
        case .notRun: "Not run"
        }
    }
}

public struct ChainCustomStatusSettings: Equatable, Sendable {
    public static let defaults = ["Success", "Stopped"]

    public static func decode(_ raw: String) -> [String] {
        let values: [String]
        if let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            values = decoded
        } else {
            values = raw
                .split(separator: "\n")
                .map { String($0) }
        }
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let combined = cleaned.isEmpty ? defaults : cleaned
        return combined.reduce(into: [String]()) { result, value in
            if !result.contains(value) { result.append(value) }
        }
    }

    public static func encode(_ statuses: [String]) -> String {
        let cleaned = statuses
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, value in
                if !result.contains(value) { result.append(value) }
            }
        let values = cleaned.isEmpty ? defaults : cleaned
        guard let data = try? JSONEncoder().encode(values),
              let raw = String(data: data, encoding: .utf8) else {
            return defaults.joined(separator: "\n")
        }
        return raw
    }
}

public struct AIProviderConfiguration: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: AIProviderKind
    public var displayName: String
    public var defaultModelID: String
    public var keychainAccountID: String
    public var isConfigured: Bool
    public var lastTestedAt: Date?
    public var lastTestStatus: ChainRunStatus
    public var cachedModels: [String]
    public var lastModelFetchAt: Date?

    public init(id: UUID = UUID(), kind: AIProviderKind, displayName: String? = nil, defaultModelID: String = "auto", keychainAccountID: String? = nil, isConfigured: Bool = false, lastTestedAt: Date? = nil, lastTestStatus: ChainRunStatus = .notRun, cachedModels: [String] = [], lastModelFetchAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.displayName = displayName ?? kind.displayName
        self.defaultModelID = defaultModelID
        self.keychainAccountID = keychainAccountID ?? "aipieksel.promptmanager.ai.\(kind.rawValue)"
        self.isConfigured = isConfigured
        self.lastTestedAt = lastTestedAt
        self.lastTestStatus = lastTestStatus
        self.cachedModels = cachedModels
        self.lastModelFetchAt = lastModelFetchAt
    }

    public static let defaults: [AIProviderConfiguration] = AIProviderKind.allCases.map { provider in
        AIProviderConfiguration(kind: provider, defaultModelID: provider.defaultModelID, cachedModels: provider.models.map(\.id))
    }
}

public struct ChainFileAttachment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var fileName: String
    public var fileExtension: String
    public var byteCount: Int
    public var originalPath: String?
    public var snapshotText: String

    public init(id: UUID = UUID(), fileName: String, fileExtension: String, byteCount: Int, originalPath: String? = nil, snapshotText: String = "") {
        self.id = id
        self.fileName = fileName
        self.fileExtension = fileExtension.lowercased()
        self.byteCount = byteCount
        self.originalPath = originalPath
        self.snapshotText = snapshotText
    }

    public static let supportedExtensions: Set<String> = ["md", "markdown", "txt", "html"]
    public var isSupportedTextAttachment: Bool { Self.supportedExtensions.contains(fileExtension.lowercased()) }
    public var displaySize: String { byteCount < 1024 ? "\(byteCount) B" : "\(byteCount / 1024) KB" }
}


public struct ChainFolderAttachment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var folderName: String
    public var originalPath: String
    public var markdownFileCount: Int

    public init(id: UUID = UUID(), folderName: String, originalPath: String, markdownFileCount: Int = 0) {
        self.id = id
        self.folderName = folderName.trimmedNonEmpty(defaultValue: "Input Folder")
        self.originalPath = originalPath
        self.markdownFileCount = max(0, markdownFileCount)
    }

    public var displayCount: String { "\(markdownFileCount) Markdown file\(markdownFileCount == 1 ? "" : "s")" }
}

public struct ChainVariableBinding: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var variableKey: String
    public var inputType: ChainVariableInputType
    public var textValue: String
    public var fileAttachment: ChainFileAttachment?
    public var folderAttachment: ChainFolderAttachment?
    public var sourceStepID: UUID?
    public var sourceOutputTransform: ChainOutputTransform
    public var sourceOutputTag: String

    public init(id: UUID = UUID(), variableKey: String, inputType: ChainVariableInputType = .text, textValue: String = "", fileAttachment: ChainFileAttachment? = nil, folderAttachment: ChainFolderAttachment? = nil, sourceStepID: UUID? = nil, sourceOutputTransform: ChainOutputTransform = .rawMarkdown, sourceOutputTag: String = "") {
        self.id = id
        self.variableKey = variableKey.variableKey
        self.inputType = inputType
        self.textValue = textValue
        self.fileAttachment = fileAttachment
        self.folderAttachment = folderAttachment
        self.sourceStepID = sourceStepID
        self.sourceOutputTransform = sourceOutputTransform
        self.sourceOutputTag = sourceOutputTag
    }

    private enum CodingKeys: String, CodingKey { case id, variableKey, inputType, textValue, fileAttachment, folderAttachment, sourceStepID, sourceOutputTransform, sourceOutputTag }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            variableKey: try c.decodeIfPresent(String.self, forKey: .variableKey) ?? "value",
            inputType: try c.decodeIfPresent(ChainVariableInputType.self, forKey: .inputType) ?? .text,
            textValue: try c.decodeIfPresent(String.self, forKey: .textValue) ?? "",
            fileAttachment: try c.decodeIfPresent(ChainFileAttachment.self, forKey: .fileAttachment),
            folderAttachment: try c.decodeIfPresent(ChainFolderAttachment.self, forKey: .folderAttachment),
            sourceStepID: try c.decodeIfPresent(UUID.self, forKey: .sourceStepID),
            sourceOutputTransform: try c.decodeIfPresent(ChainOutputTransform.self, forKey: .sourceOutputTransform) ?? .rawMarkdown,
            sourceOutputTag: try c.decodeIfPresent(String.self, forKey: .sourceOutputTag) ?? ""
        )
    }
}

public struct PromptChainStep: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var promptID: UUID?
    public var title: String
    public var sortOrder: Int
    public var variableBindings: [ChainVariableBinding]
    public var outputPolicy: ChainOutputPolicy
    public var providerKind: AIProviderKind
    public var modelID: String
    public var maxTokensOverride: Int?
    public var reasoningModeOverride: String?
    public var lastOutputID: UUID?
    public var status: ChainRunStatus
    public var finalOutputTag: String
    public var customOutputFileName: String
    public var customOutputFilePath: String
    public var overwriteOutputFile: Bool
    public var monitorStatusLabel: String

    public init(id: UUID = UUID(), promptID: UUID? = nil, title: String = "Choose a prompt", sortOrder: Int = 0, variableBindings: [ChainVariableBinding] = [], outputPolicy: ChainOutputPolicy = .saveMarkdown, providerKind: AIProviderKind = .openAI, modelID: String = "auto", maxTokensOverride: Int? = nil, reasoningModeOverride: String? = nil, lastOutputID: UUID? = nil, status: ChainRunStatus = .notRun, finalOutputTag: String = "", customOutputFileName: String = "", customOutputFilePath: String = "", overwriteOutputFile: Bool = true, monitorStatusLabel: String = "") {
        self.id = id
        self.promptID = promptID
        self.title = title
        self.sortOrder = sortOrder
        self.variableBindings = variableBindings
        self.outputPolicy = outputPolicy
        self.providerKind = providerKind
        self.modelID = modelID
        self.maxTokensOverride = maxTokensOverride
        self.reasoningModeOverride = reasoningModeOverride
        self.lastOutputID = lastOutputID
        self.status = status
        self.finalOutputTag = finalOutputTag.sanitizedXMLTagName(defaultValue: "")
        self.customOutputFileName = customOutputFileName
        self.customOutputFilePath = customOutputFilePath
        self.overwriteOutputFile = overwriteOutputFile
        self.monitorStatusLabel = monitorStatusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey { case id, promptID, title, sortOrder, variableBindings, outputPolicy, providerKind, modelID, maxTokensOverride, reasoningModeOverride, lastOutputID, status, finalOutputTag, customOutputFileName, customOutputFilePath, overwriteOutputFile, monitorStatusLabel }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            promptID: try c.decodeIfPresent(UUID.self, forKey: .promptID),
            title: try c.decodeIfPresent(String.self, forKey: .title) ?? "Choose a prompt",
            sortOrder: try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0,
            variableBindings: try c.decodeIfPresent([ChainVariableBinding].self, forKey: .variableBindings) ?? [],
            outputPolicy: try c.decodeIfPresent(ChainOutputPolicy.self, forKey: .outputPolicy) ?? .saveMarkdown,
            providerKind: try c.decodeIfPresent(AIProviderKind.self, forKey: .providerKind) ?? .openAI,
            modelID: try c.decodeIfPresent(String.self, forKey: .modelID) ?? "auto",
            maxTokensOverride: try c.decodeIfPresent(Int.self, forKey: .maxTokensOverride),
            reasoningModeOverride: try c.decodeIfPresent(String.self, forKey: .reasoningModeOverride),
            lastOutputID: try c.decodeIfPresent(UUID.self, forKey: .lastOutputID),
            status: try c.decodeIfPresent(ChainRunStatus.self, forKey: .status) ?? .notRun,
            finalOutputTag: try c.decodeIfPresent(String.self, forKey: .finalOutputTag) ?? "",
            customOutputFileName: try c.decodeIfPresent(String.self, forKey: .customOutputFileName) ?? "",
            customOutputFilePath: try c.decodeIfPresent(String.self, forKey: .customOutputFilePath) ?? "",
            overwriteOutputFile: try c.decodeIfPresent(Bool.self, forKey: .overwriteOutputFile) ?? true,
            monitorStatusLabel: try c.decodeIfPresent(String.self, forKey: .monitorStatusLabel) ?? ""
        )
    }
}

public enum ChainMonitorStepScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case anyLoopStep
    case specificStep
    public var id: String { rawValue }
}

public struct ChainOutputMonitorRule: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var isEnabled: Bool
    public var phrase: String
    public var statusLabel: String
    public var stepScope: ChainMonitorStepScope
    public var stepID: UUID?

    public init(id: UUID = UUID(), isEnabled: Bool = true, phrase: String = "", statusLabel: String = "Stopped", stepScope: ChainMonitorStepScope = .anyLoopStep, stepID: UUID? = nil) {
        self.id = id
        self.isEnabled = isEnabled
        self.phrase = phrase
        self.statusLabel = statusLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Stopped" : statusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.stepScope = stepScope
        self.stepID = stepID
    }

    public func matches(output: String, stepID activeStepID: UUID) -> Bool {
        guard isEnabled else { return false }
        let target = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return false }
        if stepScope == .specificStep, stepID != nil, stepID != activeStepID { return false }
        return output.contains(target)
    }
}

public struct PromptChain: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sequenceID: Int?
    public var title: String
    public var description: String
    public var steps: [PromptChainStep]
    public var defaultProviderKind: AIProviderKind
    public var defaultModelID: String
    public var createdAt: Date
    public var updatedAt: Date
    public var lastRunAt: Date?
    public var isArchived: Bool
    public var folderID: UUID?
    public var isDraft: Bool
    public var loopStartStepID: UUID?
    public var loopEndStepID: UUID?
    public var loopCount: Int
    public var lastLoopRunCount: Int
    public var totalLoopRunCount: Int
    public var collapsedStepIDs: [UUID]
    public var collapsedOutputPreviewLineCount: Int
    public var customOutputFolderPath: String
    public var monitorRules: [ChainOutputMonitorRule]
    public var lastMonitorStatusLabel: String
    public var lastMonitorMatchedPhrase: String

    public init(id: UUID = UUID(), sequenceID: Int? = nil, title: String = "Untitled Chain", description: String = "", steps: [PromptChainStep] = [], defaultProviderKind: AIProviderKind = .openAI, defaultModelID: String = "auto", createdAt: Date = .now, updatedAt: Date? = nil, lastRunAt: Date? = nil, isArchived: Bool = false, folderID: UUID? = nil, isDraft: Bool = false, loopStartStepID: UUID? = nil, loopEndStepID: UUID? = nil, loopCount: Int = 1, lastLoopRunCount: Int = 0, totalLoopRunCount: Int = 0, collapsedStepIDs: [UUID] = [], collapsedOutputPreviewLineCount: Int = 0, customOutputFolderPath: String = "", monitorRules: [ChainOutputMonitorRule] = [], lastMonitorStatusLabel: String = "", lastMonitorMatchedPhrase: String = "") {
        self.id = id
        self.sequenceID = sequenceID
        self.title = title.trimmedNonEmpty(defaultValue: "Untitled Chain")
        self.description = description
        self.steps = steps.sorted { $0.sortOrder < $1.sortOrder }
        self.defaultProviderKind = defaultProviderKind
        self.defaultModelID = defaultModelID
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.lastRunAt = lastRunAt
        self.isArchived = isArchived
        self.folderID = folderID
        self.isDraft = isDraft
        self.loopStartStepID = loopStartStepID
        self.loopEndStepID = loopEndStepID
        self.loopCount = max(1, min(loopCount, 100))
        self.lastLoopRunCount = max(0, lastLoopRunCount)
        self.totalLoopRunCount = max(0, totalLoopRunCount)
        self.collapsedStepIDs = collapsedStepIDs
        self.collapsedOutputPreviewLineCount = max(0, min(collapsedOutputPreviewLineCount, 20))
        self.customOutputFolderPath = customOutputFolderPath
        self.monitorRules = monitorRules
        self.lastMonitorStatusLabel = lastMonitorStatusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastMonitorMatchedPhrase = lastMonitorMatchedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey { case id, sequenceID, title, description, steps, defaultProviderKind, defaultModelID, createdAt, updatedAt, lastRunAt, isArchived, folderID, isDraft, loopStartStepID, loopEndStepID, loopCount, lastLoopRunCount, totalLoopRunCount, collapsedStepIDs, collapsedOutputPreviewLineCount, customOutputFolderPath, monitorRules, lastMonitorStatusLabel, lastMonitorMatchedPhrase }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            sequenceID: try c.decodeIfPresent(Int.self, forKey: .sequenceID),
            title: try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Chain",
            description: try c.decodeIfPresent(String.self, forKey: .description) ?? "",
            steps: try c.decodeIfPresent([PromptChainStep].self, forKey: .steps) ?? [],
            defaultProviderKind: try c.decodeIfPresent(AIProviderKind.self, forKey: .defaultProviderKind) ?? .openAI,
            defaultModelID: try c.decodeIfPresent(String.self, forKey: .defaultModelID) ?? "auto",
            createdAt: try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now,
            updatedAt: try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now,
            lastRunAt: try c.decodeIfPresent(Date.self, forKey: .lastRunAt),
            isArchived: try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false,
            folderID: try c.decodeIfPresent(UUID.self, forKey: .folderID),
            isDraft: try c.decodeIfPresent(Bool.self, forKey: .isDraft) ?? false,
            loopStartStepID: try c.decodeIfPresent(UUID.self, forKey: .loopStartStepID),
            loopEndStepID: try c.decodeIfPresent(UUID.self, forKey: .loopEndStepID),
            loopCount: try c.decodeIfPresent(Int.self, forKey: .loopCount) ?? 1,
            lastLoopRunCount: try c.decodeIfPresent(Int.self, forKey: .lastLoopRunCount) ?? 0,
            totalLoopRunCount: try c.decodeIfPresent(Int.self, forKey: .totalLoopRunCount) ?? 0,
            collapsedStepIDs: try c.decodeIfPresent([UUID].self, forKey: .collapsedStepIDs) ?? [],
            collapsedOutputPreviewLineCount: try c.decodeIfPresent(Int.self, forKey: .collapsedOutputPreviewLineCount) ?? 0,
            customOutputFolderPath: try c.decodeIfPresent(String.self, forKey: .customOutputFolderPath) ?? "",
            monitorRules: try c.decodeIfPresent([ChainOutputMonitorRule].self, forKey: .monitorRules) ?? [],
            lastMonitorStatusLabel: try c.decodeIfPresent(String.self, forKey: .lastMonitorStatusLabel) ?? "",
            lastMonitorMatchedPhrase: try c.decodeIfPresent(String.self, forKey: .lastMonitorMatchedPhrase) ?? ""
        )
    }

    public var activeSteps: [PromptChainStep] { steps.sorted { $0.sortOrder < $1.sortOrder } }
    public var stableStorageID: String { "chain_\(max(sequenceID ?? 0, 0))" }
    public var status: ChainRunStatus {
        if isDraft { return .draft }
        if steps.contains(where: { $0.status == .running }) { return .running }
        if steps.contains(where: { $0.status == .failed }) { return .failed }
        if steps.contains(where: { $0.status == .cancelled }) { return .cancelled }
        if steps.contains(where: { $0.status == .complete }) { return .complete }
        return steps.isEmpty ? .draft : .ready
    }

    public mutating func touch(at date: Date = .now) { updatedAt = date; isDraft = false }
}

public struct ChainStepRun: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var stepID: UUID
    public var resolvedPrompt: String
    public var providerKind: AIProviderKind
    public var modelID: String
    public var inputSnapshot: [String: String]
    public var fileSnapshots: [ChainFileAttachment]
    public var outputText: String
    public var outputFilePath: String?
    public var status: ChainRunStatus
    public var errorMessage: String?
    public var monitorStatusLabel: String
    public var monitorMatchedPhrase: String
    public var startedAt: Date
    public var finishedAt: Date?

    public init(id: UUID = UUID(), stepID: UUID, resolvedPrompt: String, providerKind: AIProviderKind, modelID: String, inputSnapshot: [String: String], fileSnapshots: [ChainFileAttachment] = [], outputText: String = "", outputFilePath: String? = nil, status: ChainRunStatus = .queued, errorMessage: String? = nil, monitorStatusLabel: String = "", monitorMatchedPhrase: String = "", startedAt: Date = .now, finishedAt: Date? = nil) {
        self.id = id
        self.stepID = stepID
        self.resolvedPrompt = resolvedPrompt
        self.providerKind = providerKind
        self.modelID = modelID
        self.inputSnapshot = inputSnapshot
        self.fileSnapshots = fileSnapshots
        self.outputText = outputText
        self.outputFilePath = outputFilePath
        self.status = status
        self.errorMessage = errorMessage
        self.monitorStatusLabel = monitorStatusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.monitorMatchedPhrase = monitorMatchedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    private enum CodingKeys: String, CodingKey { case id, stepID, resolvedPrompt, providerKind, modelID, inputSnapshot, fileSnapshots, outputText, outputFilePath, status, errorMessage, monitorStatusLabel, monitorMatchedPhrase, startedAt, finishedAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            stepID: try c.decode(UUID.self, forKey: .stepID),
            resolvedPrompt: try c.decodeIfPresent(String.self, forKey: .resolvedPrompt) ?? "",
            providerKind: try c.decodeIfPresent(AIProviderKind.self, forKey: .providerKind) ?? .openAI,
            modelID: try c.decodeIfPresent(String.self, forKey: .modelID) ?? "auto",
            inputSnapshot: try c.decodeIfPresent([String: String].self, forKey: .inputSnapshot) ?? [:],
            fileSnapshots: try c.decodeIfPresent([ChainFileAttachment].self, forKey: .fileSnapshots) ?? [],
            outputText: try c.decodeIfPresent(String.self, forKey: .outputText) ?? "",
            outputFilePath: try c.decodeIfPresent(String.self, forKey: .outputFilePath),
            status: try c.decodeIfPresent(ChainRunStatus.self, forKey: .status) ?? .queued,
            errorMessage: try c.decodeIfPresent(String.self, forKey: .errorMessage),
            monitorStatusLabel: try c.decodeIfPresent(String.self, forKey: .monitorStatusLabel) ?? "",
            monitorMatchedPhrase: try c.decodeIfPresent(String.self, forKey: .monitorMatchedPhrase) ?? "",
            startedAt: try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? .now,
            finishedAt: try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        )
    }
}

public struct ChainRun: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var chainID: UUID
    public var startedAt: Date
    public var finishedAt: Date?
    public var status: ChainRunStatus
    public var stepRuns: [ChainStepRun]
    public var monitorStatusLabel: String
    public var monitorMatchedPhrase: String

    public init(id: UUID = UUID(), chainID: UUID, startedAt: Date = .now, finishedAt: Date? = nil, status: ChainRunStatus = .draft, stepRuns: [ChainStepRun] = [], monitorStatusLabel: String = "", monitorMatchedPhrase: String = "") {
        self.id = id
        self.chainID = chainID
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.stepRuns = stepRuns
        self.monitorStatusLabel = monitorStatusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.monitorMatchedPhrase = monitorMatchedPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey { case id, chainID, startedAt, finishedAt, status, stepRuns, monitorStatusLabel, monitorMatchedPhrase }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            chainID: try c.decode(UUID.self, forKey: .chainID),
            startedAt: try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? .now,
            finishedAt: try c.decodeIfPresent(Date.self, forKey: .finishedAt),
            status: try c.decodeIfPresent(ChainRunStatus.self, forKey: .status) ?? .draft,
            stepRuns: try c.decodeIfPresent([ChainStepRun].self, forKey: .stepRuns) ?? [],
            monitorStatusLabel: try c.decodeIfPresent(String.self, forKey: .monitorStatusLabel) ?? "",
            monitorMatchedPhrase: try c.decodeIfPresent(String.self, forKey: .monitorMatchedPhrase) ?? ""
        )
    }
}

public extension Array where Element == AIProviderConfiguration {
    func mergedWithProviderDefaults() -> [AIProviderConfiguration] {
        var merged = self
        for provider in AIProviderConfiguration.defaults where !merged.contains(where: { $0.kind == provider.kind }) {
            merged.append(provider)
        }
        return merged
    }

    func redactedForPersistence() -> [AIProviderConfiguration] {
        map { provider in
            var copy = provider
            copy.keychainAccountID = provider.keychainAccountID
            return copy
        }
    }
}
