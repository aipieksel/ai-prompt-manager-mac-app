import Foundation

public enum PromptEntryType: String, Codable, CaseIterable, Identifiable, Sendable {
    case prompt
    case phrase
    case template
    case workflow
    case checklist
    case system
    case reference

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .prompt: "Prompt"
        case .phrase: "Phrase"
        case .template: "Template"
        case .workflow: "Workflow"
        case .checklist: "Checklist"
        case .system: "System"
        case .reference: "Reference"
        }
    }
}

public enum VariableInputType: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case textarea
    case url
    case number
    case select

    public var id: String { rawValue }
}

public struct VariableDefinition: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var key: String
    public var label: String
    public var type: VariableInputType
    public var required: Bool
    public var description: String
    public var defaultValue: String
    public var options: [String]
    public var sortOrder: Int

    public init(
        id: UUID = UUID(), key: String, label: String? = nil, type: VariableInputType = .textarea,
        required: Bool = true, description: String = "", defaultValue: String = "", options: [String] = [], sortOrder: Int = 0
    ) {
        self.id = id
        self.key = key.variableKey
        self.label = label?.trimmedNonEmpty(defaultValue: key.humanizedTitle) ?? key.humanizedTitle
        self.type = type
        self.required = required
        self.description = description
        self.defaultValue = defaultValue
        self.options = options
        self.sortOrder = sortOrder
    }
}

public struct VariablePreset: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var promptID: UUID
    public var name: String
    public var values: [String: String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), promptID: UUID, name: String, values: [String: String], createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.promptID = promptID
        self.name = name.trimmedNonEmpty(defaultValue: "Untitled Preset")
        self.values = values
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum ImportAuditStatus: String, Codable, Equatable, Sendable {
    case complete = "Complete"
    case fixed = "Fixed"
    case missing = "Missing"
    case needsReview = "Needs Review"
    case duplicate = "Duplicate"
    case error = "Error"
}

public struct ImportBatch: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sourcePath: String
    public var importedCount: Int
    public var skippedCount: Int
    public var phraseCount: Int
    public var promptCount: Int
    public var createdAt: Date
    public var report: String

    public init(
        id: UUID = UUID(), sourcePath: String, importedCount: Int = 0, skippedCount: Int = 0,
        phraseCount: Int = 0, promptCount: Int = 0, createdAt: Date = .now, report: String = ""
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.importedCount = importedCount
        self.skippedCount = skippedCount
        self.phraseCount = phraseCount
        self.promptCount = promptCount
        self.createdAt = createdAt
        self.report = report
    }
}

public struct PromptLibrary: Codable, Equatable, Sendable {
    public var prompts: [Prompt]
    public var folders: [Folder]
    public var importBatches: [ImportBatch]
    public var chains: [PromptChain]
    public var chainRuns: [ChainRun]
    public var aiProviders: [AIProviderConfiguration]
    public var nextPromptNumber: Int
    public var nextChainNumber: Int

    public init(
        prompts: [Prompt] = [],
        folders: [Folder] = [],
        importBatches: [ImportBatch] = [],
        chains: [PromptChain] = [],
        chainRuns: [ChainRun] = [],
        aiProviders: [AIProviderConfiguration] = AIProviderConfiguration.defaults,
        nextPromptNumber: Int? = nil,
        nextChainNumber: Int? = nil
    ) {
        self.prompts = prompts
        self.folders = folders
        self.importBatches = importBatches
        self.chains = chains
        self.chainRuns = chainRuns
        self.aiProviders = aiProviders
        self.nextPromptNumber = max(nextPromptNumber ?? ((prompts.compactMap(\.sequenceID).max() ?? 0) + 1), 1)
        self.nextChainNumber = max(nextChainNumber ?? ((chains.compactMap(\.sequenceID).max() ?? 0) + 1), 1)
    }

    private enum CodingKeys: String, CodingKey { case prompts, folders, importBatches, chains, chainRuns, aiProviders, nextPromptNumber, nextChainNumber }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prompts = try container.decodeIfPresent([Prompt].self, forKey: .prompts) ?? []
        folders = try container.decodeIfPresent([Folder].self, forKey: .folders) ?? []
        importBatches = try container.decodeIfPresent([ImportBatch].self, forKey: .importBatches) ?? []
        chains = try container.decodeIfPresent([PromptChain].self, forKey: .chains) ?? []
        chainRuns = try container.decodeIfPresent([ChainRun].self, forKey: .chainRuns) ?? []
        aiProviders = try container.decodeIfPresent([AIProviderConfiguration].self, forKey: .aiProviders) ?? AIProviderConfiguration.defaults
        nextPromptNumber = try container.decodeIfPresent(Int.self, forKey: .nextPromptNumber) ?? ((prompts.compactMap(\.sequenceID).max() ?? 0) + 1)
        nextChainNumber = try container.decodeIfPresent(Int.self, forKey: .nextChainNumber) ?? ((chains.compactMap(\.sequenceID).max() ?? 0) + 1)
    }
}

public extension String {
    var slugKey: String {
        lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .trimmedNonEmpty(defaultValue: "value")
    }

    var variableKey: String {
        lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .trimmedNonEmpty(defaultValue: "value")
    }

    var humanizedTitle: String {
        split { $0 == "_" || $0 == "-" || $0.isWhitespace }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
            .trimmedNonEmpty(defaultValue: "Value")
    }
}
