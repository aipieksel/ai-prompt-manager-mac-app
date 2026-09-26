import Foundation

public struct Prompt: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sequenceID: Int?
    public var title: String
    public var content: String
    public var previewSnippet: String
    public var folderID: UUID?
    public var isFavorite: Bool
    public var isTemplate: Bool
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var lastOpenedAt: Date?
    public var copyCount: Int
    public var notes: String
    public var sortOrder: Int?
    public var type: PromptEntryType
    public var sourceType: String?
    public var primaryCategory: String
    public var categories: [String]
    public var subcategory: String
    public var whenToUse: String
    public var searchTerms: [String]
    public var variables: [VariableDefinition]
    public var variablePresets: [VariablePreset]
    public var isVariablePrompt: Bool
    public var sourceFilePath: String?
    public var contentHash: String?
    public var lastImportedAt: Date?
    public var importBatchId: UUID?
    public var variableRunStep: PromptChainStep?
    public var variableRunOutputFolderPath: String
    public var variableRunCollapsed: Bool

    public init(
        id: UUID = UUID(), sequenceID: Int? = nil, title: String = "Untitled Prompt", content: String = "",
        previewSnippet: String? = nil, folderID: UUID? = nil,
        isFavorite: Bool = false, isTemplate: Bool = false, isArchived: Bool = false,
        createdAt: Date = .now, updatedAt: Date = .now, lastOpenedAt: Date? = nil,
        copyCount: Int = 0, notes: String = "", sortOrder: Int? = nil,
        type: PromptEntryType = .prompt, sourceType: String? = nil, primaryCategory: String = "uncategorized",
        categories: [String] = [], subcategory: String = "general", whenToUse: String = "",
        searchTerms: [String] = [], variables: [VariableDefinition] = [], variablePresets: [VariablePreset] = [],
        isVariablePrompt: Bool = false, sourceFilePath: String? = nil, contentHash: String? = nil, lastImportedAt: Date? = nil, importBatchId: UUID? = nil,
        variableRunStep: PromptChainStep? = nil, variableRunOutputFolderPath: String = "", variableRunCollapsed: Bool = false
    ) {
        self.id = id
        self.sequenceID = sequenceID
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.content = content
        self.previewSnippet = previewSnippet ?? Prompt.makePreview(from: content)
        self.folderID = folderID
        self.isFavorite = isFavorite
        self.isTemplate = isTemplate || type == .template
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.copyCount = copyCount
        self.notes = notes
        self.sortOrder = sortOrder
        self.type = type
        self.sourceType = sourceType
        self.primaryCategory = primaryCategory.slugKey
        let normalizedCategories = categories.map(\.slugKey).filter { !$0.isEmpty }
        self.categories = normalizedCategories.contains(self.primaryCategory) ? normalizedCategories : [self.primaryCategory] + normalizedCategories
        self.subcategory = subcategory.slugKey
        self.whenToUse = whenToUse
        self.searchTerms = Array(Set(searchTerms.map(\.slugKey).filter { !$0.isEmpty })).sorted()
        self.variables = variables.sorted { $0.sortOrder < $1.sortOrder }
        self.variablePresets = variablePresets
        self.isVariablePrompt = isVariablePrompt || !self.variables.isEmpty
        self.sourceFilePath = sourceFilePath
        self.contentHash = contentHash
        self.lastImportedAt = lastImportedAt
        self.importBatchId = importBatchId
        self.variableRunStep = variableRunStep
        self.variableRunOutputFolderPath = variableRunOutputFolderPath
        self.variableRunCollapsed = variableRunCollapsed
    }

    private enum CodingKeys: String, CodingKey {
        case id, sequenceID, title, content, previewSnippet, folderID, isFavorite, isTemplate, isArchived, createdAt, updatedAt, lastOpenedAt, copyCount, notes, sortOrder
        case type, sourceType, primaryCategory, categories, subcategory, whenToUse, searchTerms, variables, variablePresets, isVariablePrompt, sourceFilePath, contentHash, lastImportedAt, importBatchId
        case variableRunStep, variableRunOutputFolderPath, variableRunCollapsed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTitle = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Prompt"
        let decodedContent = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        let decodedType = try c.decodeIfPresent(PromptEntryType.self, forKey: .type) ?? .prompt
        let decodedVariables = try c.decodeIfPresent([VariableDefinition].self, forKey: .variables) ?? []
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            sequenceID: try c.decodeIfPresent(Int.self, forKey: .sequenceID),
            title: decodedTitle,
            content: decodedContent,
            previewSnippet: try c.decodeIfPresent(String.self, forKey: .previewSnippet),
            folderID: try c.decodeIfPresent(UUID.self, forKey: .folderID),
            isFavorite: try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false,
            isTemplate: try c.decodeIfPresent(Bool.self, forKey: .isTemplate) ?? false,
            isArchived: try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false,
            createdAt: try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now,
            updatedAt: try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now,
            lastOpenedAt: try c.decodeIfPresent(Date.self, forKey: .lastOpenedAt),
            copyCount: try c.decodeIfPresent(Int.self, forKey: .copyCount) ?? 0,
            notes: try c.decodeIfPresent(String.self, forKey: .notes) ?? "",
            sortOrder: try c.decodeIfPresent(Int.self, forKey: .sortOrder),
            type: decodedType,
            sourceType: try c.decodeIfPresent(String.self, forKey: .sourceType),
            primaryCategory: try c.decodeIfPresent(String.self, forKey: .primaryCategory) ?? "uncategorized",
            categories: try c.decodeIfPresent([String].self, forKey: .categories) ?? [],
            subcategory: try c.decodeIfPresent(String.self, forKey: .subcategory) ?? "general",
            whenToUse: try c.decodeIfPresent(String.self, forKey: .whenToUse) ?? "",
            searchTerms: try c.decodeIfPresent([String].self, forKey: .searchTerms) ?? [],
            variables: decodedVariables,
            variablePresets: try c.decodeIfPresent([VariablePreset].self, forKey: .variablePresets) ?? [],
            isVariablePrompt: (try c.decodeIfPresent(Bool.self, forKey: .isVariablePrompt) ?? false) || (!decodedVariables.isEmpty && decodedType != .phrase),
            sourceFilePath: try c.decodeIfPresent(String.self, forKey: .sourceFilePath),
            contentHash: try c.decodeIfPresent(String.self, forKey: .contentHash),
            lastImportedAt: try c.decodeIfPresent(Date.self, forKey: .lastImportedAt),
            importBatchId: try c.decodeIfPresent(UUID.self, forKey: .importBatchId),
            variableRunStep: try c.decodeIfPresent(PromptChainStep.self, forKey: .variableRunStep),
            variableRunOutputFolderPath: try c.decodeIfPresent(String.self, forKey: .variableRunOutputFolderPath) ?? "",
            variableRunCollapsed: try c.decodeIfPresent(Bool.self, forKey: .variableRunCollapsed) ?? false
        )
    }

    public mutating func rename(to newTitle: String, at date: Date = .now) { title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines); touch(at: date) }
    public mutating func updateContent(_ newContent: String, at date: Date = .now) { content = newContent; previewSnippet = Prompt.makePreview(from: newContent); variables = VariableDetector.definitions(in: newContent); touch(at: date) }
    public mutating func updateNotes(_ newNotes: String, at date: Date = .now) { notes = newNotes; touch(at: date) }
    public mutating func toggleFavorite(at date: Date = .now) { isFavorite.toggle(); touch(at: date) }
    public mutating func markOpened(at date: Date = .now) { lastOpenedAt = date }
    public mutating func recordCopy(at date: Date = .now) { copyCount += 1; touch(at: date) }
    public mutating func move(to folderID: UUID?, at date: Date = .now) { self.folderID = folderID; touch(at: date) }
    public mutating func archive(at date: Date = .now) { isArchived = true; touch(at: date) }
    public mutating func restore(at date: Date = .now) { isArchived = false; touch(at: date) }
    public mutating func updateMetadata(type: PromptEntryType, primaryCategory: String, subcategory: String, at date: Date = .now) {
        self.type = type
        self.primaryCategory = primaryCategory.slugKey
        self.categories = Array(Set(categories + [self.primaryCategory])).sorted()
        self.subcategory = subcategory.slugKey
        isTemplate = type == .template || isTemplate
        touch(at: date)
    }
    public mutating func savePreset(name: String, values: [String: String], at date: Date = .now) {
        variablePresets.append(VariablePreset(promptID: id, name: name, values: values, createdAt: date, updatedAt: date))
        touch(at: date)
    }
    public mutating func updatePreset(_ presetID: UUID, values: [String: String], at date: Date = .now) {
        guard let index = variablePresets.firstIndex(where: { $0.id == presetID }) else { return }
        variablePresets[index].values = values
        variablePresets[index].updatedAt = date
        touch(at: date)
    }
    public mutating func renamePreset(_ presetID: UUID, to name: String, at date: Date = .now) {
        guard let index = variablePresets.firstIndex(where: { $0.id == presetID }) else { return }
        variablePresets[index].name = name.trimmedNonEmpty(defaultValue: variablePresets[index].name)
        variablePresets[index].updatedAt = date
        touch(at: date)
    }
    public mutating func deletePreset(_ presetID: UUID, at date: Date = .now) { variablePresets.removeAll { $0.id == presetID }; touch(at: date) }

    public func duplicate(at date: Date = .now) -> Prompt {
        let copyBase = title.trimmedNonEmpty(defaultValue: type == .phrase ? "Untitled Phrase" : "Untitled Prompt")
        return Prompt(title: "\(copyBase) Copy", content: content, folderID: folderID, isFavorite: isFavorite, isTemplate: isTemplate, createdAt: date, updatedAt: date, notes: notes, sortOrder: sortOrder, type: type, sourceType: sourceType, primaryCategory: primaryCategory, categories: categories, subcategory: subcategory, whenToUse: whenToUse, searchTerms: searchTerms, variables: variables, variablePresets: variablePresets, isVariablePrompt: isVariablePrompt)
    }

    public mutating func touch(at date: Date = .now) { updatedAt = date }

    public static func makePreview(from content: String, limit: Int = 100) -> String {
        let compact = content.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > limit else { return compact }
        return String(compact[..<compact.index(compact.startIndex, offsetBy: limit)]) + "…"
    }

    public var wordCount: Int { content.split { $0.isWhitespace || $0.isNewline }.count }
    public var characterCount: Int { content.count }
    public var hasVariables: Bool { isVariablePrompt || !variables.isEmpty }
    public var variableCount: Int { variables.count }
    public var isPhrase: Bool { type == .phrase }
    public var displayTitle: String { title.trimmedNonEmpty(defaultValue: type == .phrase ? "Untitled Phrase" : isTemplate ? "Untitled Template" : "Untitled Prompt") }
    public var stableStorageID: String { "prompt_\(max(sequenceID ?? 0, 0))" }

    public var variableRunnerStep: PromptChainStep {
        if var existing = variableRunStep {
            existing.promptID = id
            existing.title = displayTitle
            existing.variableBindings = Prompt.reconciledVariableBindings(existing.variableBindings, variables: variables)
            return existing
        }
        return PromptChainStep(promptID: id, title: displayTitle, sortOrder: 0, variableBindings: variables.map { ChainVariableBinding(variableKey: $0.key) }, outputPolicy: .saveMarkdown)
    }

    public static func reconciledVariableBindings(_ existing: [ChainVariableBinding], variables: [VariableDefinition]) -> [ChainVariableBinding] {
        let byKey = Dictionary(uniqueKeysWithValues: existing.map { ($0.variableKey, $0) })
        return variables.sorted { $0.sortOrder < $1.sortOrder }.map { variable in
            byKey[variable.key] ?? ChainVariableBinding(variableKey: variable.key)
        }
    }
}

public extension String {
    func trimmedNonEmpty(defaultValue: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }

    func sanitizedXMLTagName(defaultValue: String) -> String {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        let fallback = defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? fallback : normalized
    }
}
