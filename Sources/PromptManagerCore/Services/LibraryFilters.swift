import Foundation

public enum LibrarySelection: Hashable, Sendable {
    case all
    case favorites
    case recent
    case templates
    case variablePrompts
    case folder(UUID)
}

public enum LibrarySection: String, CaseIterable, Identifiable, Sendable {
    case prompts = "Prompts"
    case chains = "Chained Prompts"
    case phrases = "Phrases"
    public var id: String { rawValue }
}

public struct MetadataFilterState: Equatable, Sendable {
    public var type: PromptTypeFilter?
    public var category: String?
    public var subcategory: String?

    public init(type: PromptTypeFilter? = nil, category: String? = nil, subcategory: String? = nil) {
        self.type = type
        self.category = category?.slugKey
        self.subcategory = subcategory?.slugKey
    }

    public var isActive: Bool { type != nil || category != nil || subcategory != nil }

    public mutating func clear() {
        type = nil
        category = nil
        subcategory = nil
    }
}

public enum SortMode: String, CaseIterable, Identifiable, Sendable {
    case updated = "Updated"
    case created = "Created"
    case lastOpened = "Last Opened"
    case az = "A-Z"
    case za = "Z-A"
    case favoritesFirst = "Favorites First"
    case mostCopied = "Most Copied"

    public var id: String { rawValue }
}

public enum PromptTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case prompt
    case phrase
    case variablePrompt

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .prompt: "Prompt"
        case .phrase: "Phrase"
        case .variablePrompt: "Variable Prompt"
        }
    }
}

public enum LibraryFilterService {
    public static func visiblePrompts(
        _ prompts: [Prompt],
        folders: [Folder],
        selection: LibrarySelection,
        searchQuery: String,
        sortMode: SortMode,
        section: LibrarySection = .prompts,
        metadataFilters: MetadataFilterState = MetadataFilterState(),
        searchSettings: SearchBehaviorSettings = .defaultValue,
        now: Date = .now
    ) -> [Prompt] {
        let selectedFolderIDs = folderScopeIDs(for: selection, folders: folders)
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = prompts.filter { prompt in
            guard !prompt.isArchived else { return false }
            guard matchesSection(prompt, section: section, filters: metadataFilters) else { return false }
            guard matchesSelection(prompt, selection: selection, folderIDs: selectedFolderIDs, now: now) else { return false }
            guard matchesMetadata(prompt, filters: metadataFilters) else { return false }
            guard !query.isEmpty else { return true }
            return matchesSearch(prompt, folders: folders, query: query, settings: searchSettings)
        }

        return sort(filtered, by: sortMode)
    }

    public static func sort(_ prompts: [Prompt], by mode: SortMode) -> [Prompt] {
        prompts.sorted { lhs, rhs in
            switch mode {
            case .updated:
                return lhs.updatedAt != rhs.updatedAt ? lhs.updatedAt > rhs.updatedAt : lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .created:
                return lhs.createdAt != rhs.createdAt ? lhs.createdAt > rhs.createdAt : lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .lastOpened:
                return (lhs.lastOpenedAt ?? .distantPast) != (rhs.lastOpenedAt ?? .distantPast)
                    ? (lhs.lastOpenedAt ?? .distantPast) > (rhs.lastOpenedAt ?? .distantPast)
                    : lhs.updatedAt > rhs.updatedAt
            case .az:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .za:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending
            case .favoritesFirst:
                return lhs.isFavorite != rhs.isFavorite ? lhs.isFavorite && !rhs.isFavorite : lhs.updatedAt > rhs.updatedAt
            case .mostCopied:
                return lhs.copyCount != rhs.copyCount ? lhs.copyCount > rhs.copyCount : lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    public static func folderScopeIDs(for selection: LibrarySelection, folders: [Folder]) -> Set<UUID> {
        guard case let .folder(rootID) = selection else { return [] }
        var ids: Set<UUID> = [rootID]
        var changed = true
        while changed {
            changed = false
            for folder in folders where folder.parentFolderID.map(ids.contains) == true && !ids.contains(folder.id) {
                ids.insert(folder.id)
                changed = true
            }
        }
        return ids
    }

    public static func availableCategories(in prompts: [Prompt], section: LibrarySection? = nil) -> [String] {
        Array(Set(prompts.filter { prompt in section.map { matchesSection(prompt, section: $0) } ?? true }.map(\.primaryCategory))).filter { !$0.isEmpty }.sorted()
    }

    public static func availableSubcategories(in prompts: [Prompt], category: String? = nil, section: LibrarySection? = nil) -> [String] {
        Array(Set(prompts.filter { prompt in
            (category == nil || prompt.primaryCategory == category?.slugKey) && (section.map { matchesSection(prompt, section: $0) } ?? true)
        }.map(\.subcategory))).filter { !$0.isEmpty }.sorted()
    }

    private static func matchesSection(_ prompt: Prompt, section: LibrarySection, filters: MetadataFilterState = MetadataFilterState()) -> Bool {
        if filters.type == .phrase { return prompt.type == .phrase }
        if filters.type == .variablePrompt { return prompt.type != .phrase && prompt.hasVariables }
        switch section {
        case .prompts, .chains: return prompt.type != .phrase
        case .phrases: return prompt.type == .phrase
        }
    }

    private static func matchesMetadata(_ prompt: Prompt, filters: MetadataFilterState) -> Bool {
        if let type = filters.type {
            switch type {
            case .prompt:
                if prompt.type == .phrase || prompt.hasVariables { return false }
            case .phrase:
                if prompt.type != .phrase { return false }
            case .variablePrompt:
                if prompt.type == .phrase || !prompt.hasVariables { return false }
            }
        }
        if let category = filters.category, prompt.primaryCategory != category { return false }
        if let subcategory = filters.subcategory, prompt.subcategory != subcategory { return false }
        return true
    }

    private static func matchesSelection(_ prompt: Prompt, selection: LibrarySelection, folderIDs: Set<UUID>, now: Date) -> Bool {
        switch selection {
        case .all:
            return true
        case .favorites:
            return prompt.isFavorite
        case .recent:
            let baseline = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? .distantPast
            return prompt.updatedAt >= baseline || (prompt.lastOpenedAt ?? .distantPast) >= baseline
        case .templates:
            return prompt.isTemplate || prompt.type == .template
        case .variablePrompts:
            return prompt.type != .phrase && prompt.hasVariables
        case .folder:
            guard let promptFolderID = prompt.folderID else { return false }
            return folderIDs.contains(promptFolderID)
        }
    }

    private static func matchesSearch(_ prompt: Prompt, folders: [Folder], query: String, settings: SearchBehaviorSettings) -> Bool {
        var haystacks: [String] = []
        let scoped = settings.scope
        if settings.searchInTitle && (scoped == "all" || scoped == "titles") { haystacks.append(prompt.title) }
        if settings.searchInBody && (scoped == "all" || scoped == "body") { haystacks.append(prompt.content) }
        if settings.searchInNotes && (scoped == "all") { haystacks.append(prompt.notes) }
        if settings.searchInMetadata && (scoped == "all" || scoped == "metadata") {
            haystacks.append(contentsOf: [prompt.primaryCategory, prompt.subcategory, prompt.whenToUse, prompt.type.displayName])
            haystacks.append(contentsOf: prompt.searchTerms)
            if let folderID = prompt.folderID, let folderName = folders.first(where: { $0.id == folderID })?.name { haystacks.append(folderName) }
        }
        return haystacks.contains { matches($0, query: query, behavior: settings.behavior) }
    }

    private static func matches(_ value: String, query: String, behavior: String) -> Bool {
        let haystack = value.lowercased()
        switch behavior {
        case "exact": return haystack == query
        case "fuzzy":
            var index = haystack.startIndex
            for character in query {
                guard let found = haystack[index...].firstIndex(of: character) else { return false }
                index = haystack.index(after: found)
            }
            return true
        default: return haystack.contains(query)
        }
    }
}
