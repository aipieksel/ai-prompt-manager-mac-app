import Foundation

public struct PromptArchive: Codable, Equatable {
    public var prompts: [PromptRecord]
    public var folders: [FolderRecord]
    public var importBatches: [ImportBatch]

    public init(prompts: [Prompt], folders: [Folder]) {
        self.prompts = prompts.map(PromptRecord.init)
        self.folders = folders.map(FolderRecord.init)
        self.importBatches = []
    }
}

public struct PromptRecord: Codable, Equatable {
    public var id: UUID
    public var title: String
    public var content: String
    public var folderID: UUID?
    public var isFavorite: Bool
    public var isTemplate: Bool
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var lastOpenedAt: Date?
    public var copyCount: Int
    public var notes: String
    public var type: PromptEntryType
    public var sourceType: String?
    public var primaryCategory: String
    public var categories: [String]
    public var subcategory: String
    public var whenToUse: String
    public var searchTerms: [String]
    public var variables: [VariableDefinition]
    public var variablePresets: [VariablePreset]
    public var isVariablePrompt: Bool?

    public init(_ prompt: Prompt) {
        id = prompt.id
        title = prompt.title
        content = prompt.content
        folderID = prompt.folderID
        isFavorite = prompt.isFavorite
        isTemplate = prompt.isTemplate
        isArchived = prompt.isArchived
        createdAt = prompt.createdAt
        updatedAt = prompt.updatedAt
        lastOpenedAt = prompt.lastOpenedAt
        copyCount = prompt.copyCount
        notes = prompt.notes
        type = prompt.type
        sourceType = prompt.sourceType
        primaryCategory = prompt.primaryCategory
        categories = prompt.categories
        subcategory = prompt.subcategory
        whenToUse = prompt.whenToUse
        searchTerms = prompt.searchTerms
        variables = prompt.variables
        variablePresets = prompt.variablePresets
        isVariablePrompt = prompt.isVariablePrompt
    }
}

public struct FolderRecord: Codable, Equatable {
    public var id: UUID
    public var name: String
    public var parentFolderID: UUID?
    public var sortOrder: Int

    public init(_ folder: Folder) {
        id = folder.id
        name = folder.name
        parentFolderID = folder.parentFolderID
        sortOrder = folder.sortOrder
    }
}

public enum ImportExportService {
    public static func markdown(for prompt: Prompt) -> String {
        var parts = [PromptMarkdownParser.canonicalMarkdown(for: prompt)]
        if !prompt.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(contentsOf: ["", "## Notes", "", prompt.notes])
        }
        return parts.joined(separator: "\n")
    }

    public static func plainText(for prompt: Prompt) -> String {
        prompt.content
    }

    public static func exportJSON(prompts: [Prompt], folders: [Folder]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(PromptArchive(prompts: prompts, folders: folders))
    }

    public static func importTextPrompt(fileName: String, content: String, folderID: UUID? = nil) -> Prompt {
        let title = (fileName as NSString)
            .deletingPathExtension
            .trimmedNonEmpty(defaultValue: "Imported Prompt")
        let normalized = VariableDetector.normalizedContent(content)
        return Prompt(title: title, content: normalized, folderID: folderID, variables: VariableDetector.definitions(in: normalized))
    }
}
