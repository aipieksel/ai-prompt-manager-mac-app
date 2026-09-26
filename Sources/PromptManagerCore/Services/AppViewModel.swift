import Foundation
import SwiftUI

public struct ChainMarkdownExport: Equatable, Sendable {
    public var text: String
    public var suggestedFileName: String

    public init(text: String, suggestedFileName: String) {
        self.text = text
        self.suggestedFileName = suggestedFileName
    }
}

private struct PromptDerivedCache {
    let revision: Int
    let activePrompts: [Prompt]
    let activePhrases: [Prompt]
    let activeVariablePrompts: [Prompt]
    let indexByID: [UUID: Int]
}

private struct ChainDerivedCache {
    let revision: Int
    let activeChains: [PromptChain]
}

private struct VisiblePromptsCacheKey: Equatable {
    let promptRevision: Int
    let folderRevision: Int
    let selection: LibrarySelection
    let searchQuery: String
    let sortMode: SortMode
    let section: LibrarySection
    let filters: MetadataFilterState
    let searchSettings: SearchBehaviorSettings
    let selectedPromptID: UUID?
}

private struct VisiblePromptsCache {
    let key: VisiblePromptsCacheKey
    let prompts: [Prompt]
}

private struct CategoryCacheKey: Equatable {
    let promptRevision: Int
    let section: LibrarySection
    let category: String?
}

private struct CategoryCache {
    let key: CategoryCacheKey
    let values: [String]
}

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var prompts: [Prompt] = [] { didSet { promptRevision &+= 1 } }
    @Published public var folders: [Folder] = [] { didSet { folderRevision &+= 1 } }
    @Published public var importBatches: [ImportBatch] = []
    @Published public var chains: [PromptChain] = [] { didSet { chainRevision &+= 1 } }
    @Published public var aiProviders: [AIProviderConfiguration] = AIProviderConfiguration.defaults
    @Published public var selectedChainID: UUID?
    @Published public var selectedChainStepID: UUID?
    @Published public var chainRuns: [ChainRun] = []
    @Published public var selection: LibrarySelection = .all
    @Published public var librarySection: LibrarySection = .prompts
    @Published public var metadataFilters = MetadataFilterState()
    @Published public var selectedPromptID: UUID?
    @Published public var searchQuery = ""
    @Published public var sortMode: SortMode = .updated
    @Published public var copiedPromptID: UUID?
    @Published public var filledCopyMessage: String?
    @Published public var errorMessage: String?
    @Published public var saveStatus: String = "Ready"
    @Published public var folderRenameRequestID: UUID?
    @Published public var importPreview: ImportPreview?
    @Published public var auditReport: String = ""

    public var searchSettings: SearchBehaviorSettings = .defaultValue
    public var clipboardSettings: ClipboardBehaviorSettings = .defaultValue
    public var importExportSettings: ImportExportBehaviorSettings = .defaultValue
    public var clearSearchAfterCreate: Bool = true
    public var defaultVariableType: VariableInputType = .textarea
    public var autoDetectVariables: Bool = true
    public var chainExecutionService: ChainExecutionService
    public var chainOutputStore = ChainOutputStore()
    public private(set) var nextPromptNumber: Int = 1
    public private(set) var nextChainNumber: Int = 1

    private let store: PromptStore
    private var savedPromptSnapshots: [UUID: Prompt] = [:]
    private var dirtyPromptIDs = Set<UUID>()
    private var runningStepTasks: [UUID: Task<Void, Never>] = [:]
    private var runningChainTask: Task<Void, Never>?
    private var activeLoopInitialFileOnlyStepIDs = Set<UUID>()
    private var promptRevision = 0
    private var folderRevision = 0
    private var chainRevision = 0
    private var promptDerivedCache: PromptDerivedCache?
    private var chainDerivedCache: ChainDerivedCache?
    private var visiblePromptsCache: VisiblePromptsCache?
    private var categoriesCache: CategoryCache?
    private var subcategoriesCache: CategoryCache?

    public var hasUnsavedPromptChanges: Bool { !dirtyPromptIDs.isEmpty }
    public var activeChains: [PromptChain] { chainDerivedData().activeChains }
    public var visibleChains: [PromptChain] {
        guard case .folder = selection else { return activeChains }
        let ids = LibraryFilterService.folderScopeIDs(for: selection, folders: folders)
        return activeChains.filter { $0.folderID.map(ids.contains) == true }
    }
    public var selectedChain: PromptChain? {
        get {
            if let selectedChainID, let chain = chains.first(where: { $0.id == selectedChainID && !$0.isArchived }) { return chain }
            return activeChains.first
        }
        set { selectedChainID = newValue?.id }
    }
    public var selectedChainStep: PromptChainStep? {
        guard let chain = selectedChain else { return nil }
        if let selectedChainStepID, let step = chain.steps.first(where: { $0.id == selectedChainStepID }) { return step }
        return chain.steps.sorted { $0.sortOrder < $1.sortOrder }.first
    }

    public init(store: PromptStore = PromptStore(), chainExecutionService: ChainExecutionService = ChainExecutionService(client: LiveAIProviderClient())) {
        self.store = store
        self.chainExecutionService = chainExecutionService
        load()
    }

    public var visiblePrompts: [Prompt] {
        let key = VisiblePromptsCacheKey(
            promptRevision: promptRevision,
            folderRevision: folderRevision,
            selection: selection,
            searchQuery: searchQuery,
            sortMode: sortMode,
            section: librarySection,
            filters: metadataFilters,
            searchSettings: searchSettings,
            selectedPromptID: selectedPromptID
        )
        if let cache = visiblePromptsCache, cache.key == key { return cache.prompts }
        let filtered = LibraryFilterService.visiblePrompts(prompts, folders: folders, selection: selection, searchQuery: searchQuery, sortMode: sortMode, section: librarySection, metadataFilters: metadataFilters, searchSettings: searchSettings)
        let result: [Prompt]
        if librarySection != .chains,
           let selectedPromptID,
           !filtered.contains(where: { $0.id == selectedPromptID }),
           let selectedIndex = promptIndex(for: selectedPromptID),
           !prompts[selectedIndex].isArchived {
            result = [prompts[selectedIndex]] + filtered
        } else {
            result = filtered
        }
        visiblePromptsCache = VisiblePromptsCache(key: key, prompts: result)
        return result
    }

    public var selectedPrompt: Prompt? {
        get {
            if let selectedPromptID,
               let index = promptIndex(for: selectedPromptID),
               !prompts[index].isArchived {
                return prompts[index]
            }
            return visiblePrompts.first
        }
        set { selectedPromptID = newValue?.id }
    }

    public var activePrompts: [Prompt] { promptDerivedData().activePrompts }
    public var activePhrases: [Prompt] { promptDerivedData().activePhrases }
    public var activeVariablePrompts: [Prompt] { promptDerivedData().activeVariablePrompts }
    public var availableCategories: [String] {
        let key = CategoryCacheKey(promptRevision: promptRevision, section: librarySection, category: nil)
        if let cache = categoriesCache, cache.key == key { return cache.values }
        let values = LibraryFilterService.availableCategories(in: prompts.filter { !$0.isArchived }, section: librarySection)
        categoriesCache = CategoryCache(key: key, values: values)
        return values
    }
    public var availableSubcategories: [String] {
        let key = CategoryCacheKey(promptRevision: promptRevision, section: librarySection, category: metadataFilters.category)
        if let cache = subcategoriesCache, cache.key == key { return cache.values }
        let values = LibraryFilterService.availableSubcategories(in: prompts.filter { !$0.isArchived }, category: metadataFilters.category, section: librarySection)
        subcategoriesCache = CategoryCache(key: key, values: values)
        return values
    }


    private func promptDerivedData() -> PromptDerivedCache {
        if let cache = promptDerivedCache, cache.revision == promptRevision { return cache }
        var activePrompts: [Prompt] = []
        var activePhrases: [Prompt] = []
        var activeVariablePrompts: [Prompt] = []
        var indexByID: [UUID: Int] = [:]
        indexByID.reserveCapacity(prompts.count)
        activePrompts.reserveCapacity(prompts.count)
        for (index, prompt) in prompts.enumerated() {
            indexByID[prompt.id] = index
            guard !prompt.isArchived else { continue }
            if prompt.type == .phrase {
                activePhrases.append(prompt)
            } else {
                activePrompts.append(prompt)
                if prompt.hasVariables { activeVariablePrompts.append(prompt) }
            }
        }
        let cache = PromptDerivedCache(revision: promptRevision, activePrompts: activePrompts, activePhrases: activePhrases, activeVariablePrompts: activeVariablePrompts, indexByID: indexByID)
        promptDerivedCache = cache
        return cache
    }

    private func promptIndex(for id: UUID) -> Int? {
        promptDerivedData().indexByID[id]
    }

    private func chainDerivedData() -> ChainDerivedCache {
        if let cache = chainDerivedCache, cache.revision == chainRevision { return cache }
        let activeChains = chains
            .filter { !$0.isArchived }
            .sorted { ($0.lastRunAt ?? $0.updatedAt) > ($1.lastRunAt ?? $1.updatedAt) }
        let cache = ChainDerivedCache(revision: chainRevision, activeChains: activeChains)
        chainDerivedCache = cache
        return cache
    }

    public static func settingsDefaultProviderModel(userDefaults: UserDefaults = .standard) -> (provider: AIProviderKind, modelID: String) {
        let provider = userDefaults.string(forKey: AppSettingsKeys.aiDefaultProvider).flatMap(AIProviderKind.init(rawValue:)) ?? .openAI
        let storedModel = userDefaults.string(forKey: AppSettingsKeys.aiDefaultModel) ?? provider.defaultModelID
        let modelID = provider.models.contains(where: { $0.id == storedModel }) ? storedModel : provider.defaultModelID
        return (provider, modelID)
    }

    private var settingsProviderModel: (provider: AIProviderKind, modelID: String) {
        Self.settingsDefaultProviderModel()
    }

    private func stepUsingSettingsProvider(_ step: PromptChainStep) -> PromptChainStep {
        let defaults = settingsProviderModel
        var updated = step
        updated.providerKind = defaults.provider
        updated.modelID = defaults.modelID
        return updated
    }

    public func bindingForSelectedPrompt() -> Binding<Prompt>? {
        guard let id = selectedPrompt?.id else { return nil }
        return bindingForPrompt(id)
    }

    public func bindingForPrompt(_ id: UUID) -> Binding<Prompt>? {
        guard promptIndex(for: id) != nil else { return nil }
        return Binding(
            get: {
                guard let idx = self.promptIndex(for: id) else { return Prompt(title: "", content: "") }
                return self.prompts[idx]
            },
            set: { updated in
                guard let idx = self.promptIndex(for: id) else { return }
                self.prompts[idx] = updated
                self.markPromptDirty(id)
            }
        )
    }

    public func load() {
        do {
            let library = try store.load()
            prompts = library.prompts.map(Self.reconciledPromptVariables)
            folders = library.folders
            importBatches = library.importBatches
            chains = library.chains.map(Self.reconciledChainModels)
            chainRuns = library.chainRuns
            aiProviders = library.aiProviders.mergedWithProviderDefaults()
            nextPromptNumber = library.nextPromptNumber
            nextChainNumber = library.nextChainNumber
            assignMissingSequenceIDs()
            migrateFoldersToTypeOwnedNamespacesIfNeeded()
            let removedGeneratedVariableOutputs = removeGeneratedVariableOutputCatalogEntries()
            if removedGeneratedVariableOutputs > 0 {
                try? store.save(currentLibrary())
                saveStatus = "Removed \(removedGeneratedVariableOutputs) generated variable output entries"
            }
            selectedChainID = activeChains.first?.id
            selectedPromptID = visiblePrompts.first(where: { $0.title == "Product Description Generator" })?.id ?? visiblePrompts.first?.id
            markAllPromptsSaved()
        } catch { errorMessage = error.localizedDescription }
    }

    public func save() {
        do {
            assignMissingSequenceIDs()
            try store.save(currentLibrary())
            try PromptBackupService.runIfNeeded(library: currentLibrary(), settings: importExportSettings, storeURL: store.fileURL)
            markAllPromptsSaved()
            saveStatus = "Saved \(Date().formatted(date: .omitted, time: .shortened))"
        } catch {
            saveStatus = "Save failed"
            errorMessage = error.localizedDescription
        }
    }

    public func currentLibrary() -> PromptLibrary {
        assignMissingSequenceIDs()
        return PromptLibrary(prompts: prompts.map(Self.reconciledPromptVariables), folders: folders, importBatches: importBatches, chains: chains.filter { !$0.isDraft }.map(Self.reconciledChainModels), chainRuns: chainRuns, aiProviders: aiProviders.redactedForPersistence(), nextPromptNumber: nextPromptNumber, nextChainNumber: nextChainNumber)
    }

    private func allocatePromptSequenceID() -> Int {
        var candidate = max(nextPromptNumber, 1)
        let used = Set(prompts.compactMap(\.sequenceID).filter { $0 > 0 })
        while used.contains(candidate) { candidate += 1 }
        nextPromptNumber = candidate + 1
        return candidate
    }

    private func allocateChainSequenceID() -> Int {
        var candidate = max(nextChainNumber, 1)
        let used = Set(chains.compactMap(\.sequenceID).filter { $0 > 0 })
        while used.contains(candidate) { candidate += 1 }
        nextChainNumber = candidate + 1
        return candidate
    }

    private func assignMissingSequenceIDs() {
        for index in prompts.indices where (prompts[index].sequenceID ?? 0) <= 0 {
            prompts[index].sequenceID = allocatePromptSequenceID()
        }
        if let maxPrompt = prompts.compactMap(\.sequenceID).max() {
            nextPromptNumber = max(nextPromptNumber, maxPrompt + 1)
        }
        for index in chains.indices where (chains[index].sequenceID ?? 0) <= 0 {
            chains[index].sequenceID = allocateChainSequenceID()
        }
        if let maxChain = chains.compactMap(\.sequenceID).max() {
            nextChainNumber = max(nextChainNumber, maxChain + 1)
        }
    }

    private static func reconciledChainModels(_ chain: PromptChain) -> PromptChain {
        var copy = chain
        copy.steps = chain.steps.map { step in
            var updated = step
            if !updated.providerKind.models.contains(where: { $0.id == updated.modelID }) {
                updated.modelID = updated.providerKind.defaultModelID
            }
            return updated
        }
        return copy
    }

    private static func reconciledPromptVariables(_ prompt: Prompt) -> Prompt {
        if prompt.sourceType == "chain-output" {
            var output = prompt
            output.variables = []
            output.isVariablePrompt = false
            return output
        }
        var copy = prompt
        let detected = VariableDetector.definitions(in: prompt.content)
        let existingByKey = Dictionary(uniqueKeysWithValues: prompt.variables.map { ($0.key, $0) })
        copy.variables = detected.map { detectedVariable in
            guard var existing = existingByKey[detectedVariable.key] else { return detectedVariable }
            existing.sortOrder = detectedVariable.sortOrder
            if existing.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { existing.label = detectedVariable.label }
            return existing
        }
        if var step = copy.variableRunStep {
            step.promptID = copy.id
            step.title = copy.displayTitle
            step.variableBindings = Prompt.reconciledVariableBindings(step.variableBindings, variables: copy.variables)
            copy.variableRunStep = step
        }
        return copy
    }

    private func migrateFoldersToTypeOwnedNamespacesIfNeeded() {
        guard !folders.isEmpty else { return }
        let existingScopes = Set(folders.map(\.scope))
        guard existingScopes == [.prompts] else { return }

        func path(for folderID: UUID?) -> [String] {
            guard let folderID else { return [] }
            var names: [String] = []
            var current = folders.first { $0.id == folderID }
            var seen = Set<UUID>()
            while let folder = current, !seen.contains(folder.id) {
                seen.insert(folder.id)
                names.insert(folder.name, at: 0)
                current = folder.parentFolderID.flatMap { parentID in folders.first { $0.id == parentID } }
            }
            return names
        }

        func ensurePath(_ names: [String], scope: FolderScope) -> UUID? {
            guard !names.isEmpty else { return nil }
            var parent: UUID?
            for name in names {
                if let existing = folders.first(where: { $0.scope == scope && $0.parentFolderID == parent && $0.name == name }) {
                    parent = existing.id
                } else {
                    let sortOrder = ((folders.filter { $0.scope == scope && $0.parentFolderID == parent }.map(\.sortOrder).max()) ?? -1) + 1
                    let folder = Folder(name: name, parentFolderID: parent, sortOrder: sortOrder, scope: scope)
                    folders.append(folder)
                    parent = folder.id
                }
            }
            return parent
        }

        for index in prompts.indices {
            let scope: FolderScope? = if prompts[index].type == .phrase {
                .phrases
            } else if prompts[index].hasVariables {
                .variablePrompts
            } else {
                nil
            }
            guard let scope, let currentFolderID = prompts[index].folderID else { continue }
            prompts[index].folderID = ensurePath(path(for: currentFolderID), scope: scope)
        }
        for index in chains.indices where chains[index].folderID != nil {
            chains[index].folderID = ensurePath(path(for: chains[index].folderID), scope: .chains)
        }
    }

    public func markPromptDirty(_ id: UUID) {
        dirtyPromptIDs.insert(id)
        saveStatus = "Unsaved changes"
    }

    public func markAllPromptsSaved() {
        savedPromptSnapshots = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, $0) })
        dirtyPromptIDs.removeAll()
    }

    public func discardUnsavedChanges() {
        for id in dirtyPromptIDs {
            if let snapshot = savedPromptSnapshots[id], let idx = prompts.firstIndex(where: { $0.id == id }) {
                prompts[idx] = snapshot
            } else if savedPromptSnapshots[id] == nil {
                prompts.removeAll { $0.id == id }
            }
        }
        dirtyPromptIDs.removeAll()
        if selectedPromptID.map({ id in !prompts.contains { $0.id == id } }) == true {
            selectedPromptID = visiblePrompts.first?.id
        }
        saveStatus = "Discarded changes"
    }

    public func saveIfAutosaveEnabled(_ enabled: Bool) {
        if enabled { save() }
    }

    public func createPrompt() {
        let folderID: UUID? = if case let .folder(id) = selection { id } else { nil }
        let variableMode = selection == .variablePrompts || metadataFilters.type == .variablePrompt
        let p = Prompt(
            sequenceID: allocatePromptSequenceID(),
            title: "",
            content: "",
            folderID: folderID,
            isFavorite: selection == .favorites,
            isTemplate: selection == .templates,
            type: selection == .templates ? .template : .prompt,
            primaryCategory: metadataFilters.category ?? "uncategorized",
            subcategory: metadataFilters.subcategory ?? "general",
            variables: variableMode ? [VariableDefinition(key: "client_name", type: defaultVariableType)] : [],
            isVariablePrompt: variableMode
        )
        librarySection = .prompts
        if clearSearchAfterCreate { searchQuery = "" }
        if metadataFilters.type == .phrase { metadataFilters.type = nil }
        prompts.insert(p, at: 0)
        selectedPromptID = p.id
        save()
    }

    public func createChainDraft() {
        librarySection = .chains
        selection = .all
        metadataFilters.clear()
        if clearSearchAfterCreate { searchQuery = "" }
        let provider = settingsProviderModel
        let defaultCollapsedLines = UserDefaults.standard.object(forKey: AppSettingsKeys.storageChainCollapsedPreviewLines) as? Int ?? 0
        let folderID: UUID? = if case let .folder(id) = selection { id } else { nil }
        let chain = PromptChain(sequenceID: allocateChainSequenceID(), title: "Untitled Chain", steps: [PromptChainStep(sortOrder: 0, providerKind: provider.provider, modelID: provider.modelID)], defaultProviderKind: provider.provider, defaultModelID: provider.modelID, folderID: folderID, isDraft: true, collapsedOutputPreviewLineCount: defaultCollapsedLines)
        chains.insert(chain, at: 0)
        selectedChainID = chain.id
        selectedChainStepID = chain.steps.first?.id
        saveStatus = "Draft chain"
    }

    public func saveSelectedChain() {
        guard let id = selectedChain?.id, let idx = chains.firstIndex(where: { $0.id == id }) else { return }
        if let stepID = selectedChainStepID,
           let stepIndex = chains[idx].steps.firstIndex(where: { $0.id == stepID }),
           let runIndex = chainRuns.firstIndex(where: { $0.chainID == id && $0.stepRuns.contains(where: { $0.stepID == stepID && $0.status == .complete }) }),
           let runStepIndex = chainRuns[runIndex].stepRuns.firstIndex(where: { $0.stepID == stepID && $0.status == .complete }) {
            do {
                let savedStepRun = try persistChainStepOutput(chainIndex: idx, stepIndex: stepIndex, stepRun: chainRuns[runIndex].stepRuns[runStepIndex])
                chainRuns[runIndex].stepRuns[runStepIndex] = savedStepRun
                saveStatus = "Saved markdown"
            } catch {
                errorMessage = error.localizedDescription
                saveStatus = "Save failed"
                return
            }
        }
        chains[idx].touch()
        save()
    }

    public func saveStepMarkdown(_ stepID: UUID) {
        guard let chainIndex = chains.firstIndex(where: { $0.id == selectedChainID }),
              let stepIndex = chains[chainIndex].steps.firstIndex(where: { $0.id == stepID }) else { return }
        selectedChainStepID = stepID
        let chain = chains[chainIndex]
        let step = chains[chainIndex].steps[stepIndex]
        do {
            if let runIndex = chainRuns.firstIndex(where: { $0.chainID == chain.id && $0.stepRuns.contains(where: { $0.stepID == stepID && $0.status == .complete }) }),
               let runStepIndex = chainRuns[runIndex].stepRuns.firstIndex(where: { $0.stepID == stepID && $0.status == .complete }) {
                let savedStepRun = try persistChainStepOutput(chainIndex: chainIndex, stepIndex: stepIndex, stepRun: chainRuns[runIndex].stepRuns[runStepIndex])
                chainRuns[runIndex].stepRuns[runStepIndex] = savedStepRun
            } else {
                guard let promptID = step.promptID, let prompt = prompts.first(where: { $0.id == promptID }) else {
                    throw ChainExecutionError.missingPrompt(step.title)
                }
                let resolved = try chainExecutionService.resolve(step: step, prompt: prompt, previousOutputs: previousOutputs(for: chain, before: step)).0
                _ = try effectiveChainOutputStore().saveStepMarkdown(resolved, chain: chain, step: step, sourceAttachment: step.variableBindings.compactMap(\.fileAttachment).first)
            }
            chains[chainIndex].touch()
            save()
            errorMessage = nil
            saveStatus = "Saved markdown"
        } catch {
            errorMessage = error.localizedDescription
            saveStatus = "Save failed"
        }
    }

    public func markdownExportForStep(_ stepID: UUID) throws -> ChainMarkdownExport {
        guard let chain = selectedChain,
              let step = chain.steps.first(where: { $0.id == stepID }) else {
            throw ChainExecutionError.missingPrompt("Selected chain step")
        }
        if let latestRun = latestStepRun(for: stepID), latestRun.status == .complete {
            let text = ChainFinalMarkdownExtractor.downloadableMarkdown(from: latestRun.outputText, tagName: step.finalOutputTag)
            let suggestedName = latestRun.outputFilePath.map { URL(fileURLWithPath: $0).lastPathComponent }
                ?? ChainOutputStore.outputFileName(for: latestRun.outputText, attachment: latestRun.fileSnapshots.first, step: step)
            return ChainMarkdownExport(text: text, suggestedFileName: suggestedName)
        }
        guard let promptID = step.promptID, let prompt = prompts.first(where: { $0.id == promptID }) else {
            throw ChainExecutionError.missingPrompt(step.title)
        }
        let resolved = try chainExecutionService.resolve(step: step, prompt: prompt, previousOutputs: previousOutputs(for: chain, before: step)).0
        let suggestedName = ChainOutputStore.responseFileName(for: step.variableBindings.compactMap(\.fileAttachment).first, step: step)
        return ChainMarkdownExport(text: resolved, suggestedFileName: suggestedName)
    }

    public func bindingForSelectedChain() -> Binding<PromptChain>? {
        guard let id = selectedChain?.id else { return nil }
        return bindingForChain(id)
    }

    public func bindingForChain(_ id: UUID) -> Binding<PromptChain>? {
        guard chains.contains(where: { $0.id == id }) else { return nil }
        return Binding(get: { self.chains.first(where: { $0.id == id }) ?? PromptChain() }, set: { updated in
            guard let idx = self.chains.firstIndex(where: { $0.id == id }) else { return }
            self.chains[idx] = updated
            self.chains[idx].updatedAt = .now
            self.saveStatus = "Unsaved chain changes"
        })
    }

    public func selectChain(_ chain: PromptChain) {
        librarySection = .chains
        selectedChainID = chain.id
        selectedChainStepID = chain.steps.sorted { $0.sortOrder < $1.sortOrder }.first?.id
    }

    public func addStepToSelectedChain(promptID: UUID? = nil) {
        guard let id = selectedChain?.id, let idx = chains.firstIndex(where: { $0.id == id }) else { return }
        let order = ((chains[idx].steps.map(\.sortOrder).max() ?? -1) + 1)
        let prompt = promptID.flatMap { pid in prompts.first { $0.id == pid } }
        var bindings: [ChainVariableBinding] = []
        if let prompt { bindings = prompt.variables.map { ChainVariableBinding(variableKey: $0.key) } }
        let provider = settingsProviderModel
        let step = PromptChainStep(promptID: promptID, title: prompt?.displayTitle ?? "Choose a prompt", sortOrder: order, variableBindings: bindings, providerKind: provider.provider, modelID: provider.modelID, status: .notRun)
        chains[idx].steps.append(step)
        selectedChainStepID = step.id
        saveStatus = "Unsaved chain changes"
    }

    public func removeStep(_ stepID: UUID) {
        guard let id = selectedChain?.id, let idx = chains.firstIndex(where: { $0.id == id }) else { return }
        chains[idx].steps.removeAll { $0.id == stepID }
        for index in chains[idx].steps.indices { chains[idx].steps[index].sortOrder = index }
        selectedChainStepID = chains[idx].steps.first?.id
        chains[idx].updatedAt = .now
        if chains[idx].isDraft {
            saveStatus = "Unsaved chain changes"
        } else {
            save()
            saveStatus = "Deleted step"
        }
    }

    public func archiveSelectedChain() {
        guard let id = selectedChain?.id, let idx = chains.firstIndex(where: { $0.id == id }) else { return }
        chains[idx].isArchived = true
        chains[idx].updatedAt = .now
        selectedChainID = activeChains.first { $0.id != id }?.id
        save()
    }

    public func updateStepPrompt(chainID: UUID, stepID: UUID, promptID: UUID?) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }), let sidx = chains[cidx].steps.firstIndex(where: { $0.id == stepID }) else { return }
        let prompt = promptID.flatMap { pid in prompts.first { $0.id == pid } }
        chains[cidx].steps[sidx].promptID = promptID
        chains[cidx].steps[sidx].title = prompt?.displayTitle ?? "Choose a prompt"
        if let prompt { chains[cidx].steps[sidx].variableBindings = prompt.variables.map { ChainVariableBinding(variableKey: $0.key) } }
        chains[cidx].updatedAt = .now
        saveStatus = "Unsaved chain changes"
    }


    public func updateStepProvider(chainID: UUID, stepID: UUID, providerKind: AIProviderKind, modelID: String? = nil) {
        let proposedModel = modelID ?? providerKind.defaultModelID
        let resolvedModelID = providerKind.models.contains(where: { $0.id == proposedModel }) ? proposedModel : providerKind.defaultModelID
        UserDefaults.standard.set(providerKind.rawValue, forKey: AppSettingsKeys.aiDefaultProvider)
        UserDefaults.standard.set(resolvedModelID, forKey: AppSettingsKeys.aiDefaultModel)
        saveStatus = "Updated AI settings"
    }

    public func updateStepOutputPolicy(chainID: UUID, stepID: UUID, outputPolicy: ChainOutputPolicy) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }),
              let sidx = chains[cidx].steps.firstIndex(where: { $0.id == stepID }) else { return }
        chains[cidx].steps[sidx].outputPolicy = outputPolicy
        chains[cidx].updatedAt = .now
        saveStatus = "Unsaved chain changes"
    }

    public func updateStepFinalOutputTag(chainID: UUID, stepID: UUID, tagName: String) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }),
              let sidx = chains[cidx].steps.firstIndex(where: { $0.id == stepID }) else { return }
        chains[cidx].steps[sidx].finalOutputTag = tagName.sanitizedXMLTagName(defaultValue: "")
        chains[cidx].updatedAt = .now
        saveStatus = "Unsaved chain changes"
    }

    public func updateStepOutputFileOptions(chainID: UUID, stepID: UUID, fileName: String? = nil, outputFilePath: String? = nil, overwrite: Bool? = nil) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }),
              let sidx = chains[cidx].steps.firstIndex(where: { $0.id == stepID }) else { return }
        if let outputFilePath {
            let url = URL(fileURLWithPath: outputFilePath)
            chains[cidx].steps[sidx].customOutputFilePath = url.pathExtension.isEmpty ? url.appendingPathExtension("md").path : url.path
            chains[cidx].steps[sidx].customOutputFileName = url.lastPathComponent
        }
        if let fileName {
            chains[cidx].steps[sidx].customOutputFileName = fileName
            let existingPath = chains[cidx].steps[sidx].customOutputFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !existingPath.isEmpty {
                let existingURL = URL(fileURLWithPath: existingPath)
                let typedURL = URL(fileURLWithPath: fileName)
                let outputName = typedURL.pathExtension.isEmpty ? typedURL.lastPathComponent + ".md" : typedURL.lastPathComponent
                chains[cidx].steps[sidx].customOutputFilePath = existingURL.deletingLastPathComponent().appendingPathComponent(outputName).path
            }
        }
        if let overwrite { chains[cidx].steps[sidx].overwriteOutputFile = overwrite }
        chains[cidx].updatedAt = .now
        saveStatus = "Unsaved chain changes"
    }

    public func updateChainLoop(chainID: UUID, startStepID: UUID?, endStepID: UUID?, loopCount: Int) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }) else { return }
        let sortedSteps = chains[cidx].steps.sorted { $0.sortOrder < $1.sortOrder }
        var start = startStepID
        var end = endStepID
        if let startID = start, let endID = end,
           let startIndex = sortedSteps.firstIndex(where: { $0.id == startID }),
           let endIndex = sortedSteps.firstIndex(where: { $0.id == endID }),
           startIndex > endIndex {
            start = endID
            end = startID
        }
        chains[cidx].loopStartStepID = start
        chains[cidx].loopEndStepID = end
        chains[cidx].loopCount = max(1, min(loopCount, 100))
        chains[cidx].updatedAt = .now
        saveStatus = "Unsaved chain changes"
    }

    public func updateChainMonitorRules(chainID: UUID, rules: [ChainOutputMonitorRule]) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }) else { return }
        chains[cidx].monitorRules = sanitizedMonitorRules(rules, for: chains[cidx])
        chains[cidx].updatedAt = .now
        saveStatus = "Unsaved chain changes"
    }

    private func sanitizedMonitorRules(_ rules: [ChainOutputMonitorRule], for chain: PromptChain) -> [ChainOutputMonitorRule] {
        let stepIDs = Set(chain.steps.map(\.id))
        return rules.map { rule in
            var copy = rule
            copy.phrase = copy.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.statusLabel = copy.statusLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Stopped" : copy.statusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            if copy.stepScope == .specificStep, let stepID = copy.stepID, !stepIDs.contains(stepID) {
                copy.stepScope = .anyLoopStep
                copy.stepID = nil
            }
            if copy.stepScope == .anyLoopStep { copy.stepID = nil }
            return copy
        }
    }

    public func toggleChainStepCollapsed(chainID: UUID, stepID: UUID) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }) else { return }
        if chains[cidx].collapsedStepIDs.contains(stepID) {
            chains[cidx].collapsedStepIDs.removeAll { $0 == stepID }
        } else {
            chains[cidx].collapsedStepIDs.append(stepID)
        }
        chains[cidx].updatedAt = .now
        saveStatus = "Unsaved chain changes"
        persistChainPresentationPreferences()
    }

    public func updateChainCollapsedPreviewLines(chainID: UUID, lineCount: Int) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }) else { return }
        chains[cidx].collapsedOutputPreviewLineCount = max(0, min(lineCount, 20))
        chains[cidx].updatedAt = .now
        saveStatus = "Unsaved chain changes"
        persistChainPresentationPreferences()
    }

    public func updateChainOutputFolder(chainID: UUID, path: String) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }) else { return }
        chains[cidx].customOutputFolderPath = path
        chains[cidx].updatedAt = .now
        saveStatus = "Unsaved chain changes"
        persistChainPresentationPreferences()
    }

    private func persistChainPresentationPreferences() {
        do {
            assignMissingSequenceIDs()
            try store.save(currentLibrary())
            saveStatus = "Saved layout"
        } catch {
            errorMessage = error.localizedDescription
            saveStatus = "Save failed"
        }
    }

    public func chainOutputFolderURL(for chain: PromptChain) -> URL {
        effectiveChainOutputStore().folderURL(for: chain)
    }

    public func updateBinding(chainID: UUID, stepID: UUID, binding: ChainVariableBinding) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }), let sidx = chains[cidx].steps.firstIndex(where: { $0.id == stepID }) else { return }
        if let bidx = chains[cidx].steps[sidx].variableBindings.firstIndex(where: { $0.variableKey == binding.variableKey }) {
            chains[cidx].steps[sidx].variableBindings[bidx] = binding
        } else {
            chains[cidx].steps[sidx].variableBindings.append(binding)
        }
        chains[cidx].updatedAt = .now
        saveStatus = "Unsaved chain changes"
    }

    public func previousOutputs(for chain: PromptChain, before step: PromptChainStep) -> [UUID: String] {
        var outputs: [UUID: String] = [:]
        let priorIDs = Set(chain.steps.filter { $0.sortOrder < step.sortOrder }.map(\.id))
        for run in chainRuns.filter({ $0.chainID == chain.id }).sorted(by: { $0.startedAt > $1.startedAt }) {
            for stepRun in run.stepRuns where priorIDs.contains(stepRun.stepID) && stepRun.status == .complete && outputs[stepRun.stepID] == nil {
                outputs[stepRun.stepID] = stepRun.outputText
            }
        }
        return outputs
    }

    public func latestOutputs(for chain: PromptChain) -> [UUID: String] {
        var outputs: [UUID: String] = [:]
        let stepIDs = Set(chain.steps.map(\.id))
        for run in chainRuns.filter({ $0.chainID == chain.id }).sorted(by: { $0.startedAt > $1.startedAt }) {
            for stepRun in run.stepRuns where stepIDs.contains(stepRun.stepID) && stepRun.status == .complete && outputs[stepRun.stepID] == nil {
                outputs[stepRun.stepID] = stepRun.outputText
            }
        }
        return outputs
    }

    private func latestPreviousOutputsForFreshStepRun(chainID: UUID, before step: PromptChainStep) -> [UUID: String] {
        guard let currentChain = chains.first(where: { $0.id == chainID }) else { return [:] }
        let needsLoopFeedback = step.variableBindings.contains { $0.inputType == .loopFeedbackFile }
        let needsAnyStepOutput = step.variableBindings.contains { binding in
            guard binding.inputType == .previousStepOutput,
                  let sourceStepID = binding.sourceStepID,
                  let sourceStep = currentChain.steps.first(where: { $0.id == sourceStepID })
            else { return false }
            return sourceStep.sortOrder >= step.sortOrder
        }
        return (needsLoopFeedback || needsAnyStepOutput) ? latestOutputs(for: currentChain) : previousOutputs(for: currentChain, before: step)
    }


    public func latestStepRun(for stepID: UUID) -> ChainStepRun? {
        chainRuns.compactMap { run in run.stepRuns.first { $0.stepID == stepID } }.sorted { $0.startedAt > $1.startedAt }.first
    }

    public func latestCompletedStepRun(for stepID: UUID) -> ChainStepRun? {
        chainRuns
            .compactMap { run in run.stepRuns.first { $0.stepID == stepID && $0.status == .complete } }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    public func latestStepOutput(for stepID: UUID) -> String? {
        guard let run = latestStepRun(for: stepID), run.status == .complete, !run.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return run.outputText
    }

    private func latestSavedStepOutputText(for step: PromptChainStep) -> String? {
        guard let run = latestCompletedStepRun(for: step.id) else { return nil }
        if let path = run.outputFilePath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            if let text = try? String(contentsOf: url, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }
        let output = ChainFinalMarkdownExtractor.downloadableMarkdown(from: run.outputText, tagName: step.finalOutputTag)
        return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : output
    }

    public func latestStepError(for stepID: UUID) -> String? {
        guard let run = latestStepRun(for: stepID), run.status == .failed || run.status == .cancelled else { return nil }
        return run.errorMessage
    }

    public func startRunStep(_ stepID: UUID) {
        guard runningStepTasks[stepID] == nil else { return }
        let task = Task { [weak self] in
            await self?.runStep(stepID)
            await MainActor.run { self?.runningStepTasks[stepID] = nil }
        }
        runningStepTasks[stepID] = task
    }

    public func cancelStepRun(_ stepID: UUID) {
        runningStepTasks[stepID]?.cancel()
        runningStepTasks[stepID] = nil
        markStepCancelled(stepID)
    }

    public func startRunSelectedChain() {
        guard runningChainTask == nil else { return }
        let task = Task { [weak self] in
            await self?.runSelectedChain()
            await MainActor.run { self?.runningChainTask = nil }
        }
        runningChainTask = task
    }

    public func startRunSelectedLoop() {
        guard runningChainTask == nil else { return }
        let task = Task { [weak self] in
            await self?.runSelectedLoop()
            await MainActor.run { self?.runningChainTask = nil }
        }
        runningChainTask = task
    }

    public func cancelSelectedChainRun() {
        runningChainTask?.cancel()
        runningChainTask = nil
        guard let selectedChainID, let chain = chains.first(where: { $0.id == selectedChainID }) else { return }
        for step in chain.steps where step.status == .running {
            markStepCancelled(step.id)
        }
        saveStatus = "Chain stopped"
    }


    public func updateVariableRunStep(promptID: UUID, step: PromptChainStep) {
        guard let idx = prompts.firstIndex(where: { $0.id == promptID }) else { return }
        var updated = step
        updated.promptID = promptID
        updated.title = prompts[idx].displayTitle
        updated.sortOrder = 0
        updated.variableBindings = Prompt.reconciledVariableBindings(updated.variableBindings, variables: prompts[idx].variables)
        prompts[idx].variableRunStep = updated
        prompts[idx].touch()
        markPromptDirty(promptID)
    }

    public func updateVariableRunOutputFolder(promptID: UUID, folderPath: String) {
        guard let idx = prompts.firstIndex(where: { $0.id == promptID }) else { return }
        prompts[idx].variableRunOutputFolderPath = folderPath
        prompts[idx].touch()
        markPromptDirty(promptID)
    }

    public func toggleVariableRunCollapsed(promptID: UUID) {
        let current = UserDefaults.standard.object(forKey: AppSettingsKeys.storageVariablePromptRunnerCollapsed) as? Bool ?? AppSettingsDefaults.variablePromptRunnerCollapsed
        UserDefaults.standard.set(!current, forKey: AppSettingsKeys.storageVariablePromptRunnerCollapsed)
    }

    public func startRunVariablePrompt(_ promptID: UUID) {
        guard runningStepTasks[promptID] == nil else { return }
        let task = Task { [weak self] in
            await self?.runVariablePrompt(promptID)
            await MainActor.run { self?.runningStepTasks[promptID] = nil }
        }
        runningStepTasks[promptID] = task
    }

    public func cancelVariablePromptRun(_ promptID: UUID) {
        runningStepTasks[promptID]?.cancel()
        runningStepTasks[promptID] = nil
        if let idx = prompts.firstIndex(where: { $0.id == promptID }) {
            var step = prompts[idx].variableRunnerStep
            step.status = .cancelled
            prompts[idx].variableRunStep = step
        }
        saveStatus = "Variable prompt stopped"
    }

    public func runVariablePrompt(_ promptID: UUID) async {
        guard let promptIndex = prompts.firstIndex(where: { $0.id == promptID }) else { return }
        var prompt = Self.reconciledPromptVariables(prompts[promptIndex])
        var step = stepUsingSettingsProvider(prompt.variableRunnerStep)
        step.status = .running
        prompt.variableRunStep = step
        prompts[promptIndex] = prompt
        saveStatus = "Running variable prompt…"

        func recordFailure(_ message: String) {
            var failedStep = step
            failedStep.status = .failed
            var failedRun = ChainRun(chainID: promptID, status: .failed)
            failedRun.finishedAt = .now
            failedRun.stepRuns = [ChainStepRun(stepID: step.id, resolvedPrompt: "", providerKind: step.providerKind, modelID: step.modelID, inputSnapshot: [:], outputText: "", status: .failed, errorMessage: message, startedAt: failedRun.startedAt, finishedAt: .now)]
            chainRuns.insert(failedRun, at: 0)
            if let idx = prompts.firstIndex(where: { $0.id == promptID }) {
                prompts[idx].variableRunStep = failedStep
            }
            errorMessage = message
            saveStatus = "Variable prompt failed"
        }

        do {
            if let folderBinding = step.variableBindings.first(where: { $0.inputType == .folder && $0.folderAttachment != nil }), let folder = folderBinding.folderAttachment {
                let attachments = try ChainExecutionService.markdownAttachments(in: folder)
                guard !attachments.isEmpty else { throw ChainExecutionError.missingRequiredVariable("No Markdown files found in \(folder.folderName)") }
                var completed = 0
                var skipped: [String] = []
                for attachment in attachments {
                    try Task.checkCancellation()
                    let outputURL = variablePromptOutputFolderURL(for: prompt).appendingPathComponent(attachment.fileName)
                    if !step.overwriteOutputFile && FileManager.default.fileExists(atPath: outputURL.path) {
                        skipped.append(attachment.fileName)
                        continue
                    }
                    var iterationStep = step
                    iterationStep.customOutputFileName = attachment.fileName
                    iterationStep.customOutputFilePath = outputURL.path
                    iterationStep.variableBindings = step.variableBindings.map { binding in
                        guard binding.inputType == .folder else { return binding }
                        var copy = binding
                        copy.inputType = .file
                        copy.fileAttachment = attachment
                        return copy
                    }
                    let stepRun = try await chainExecutionService.run(step: iterationStep, prompt: prompt, previousOutputs: [:])
                    let savedRun = try persistVariablePromptOutput(prompt: prompt, step: iterationStep, stepRun: stepRun, forcedFileName: attachment.fileName)
                    var run = ChainRun(chainID: promptID, status: .complete)
                    run.stepRuns = [savedRun]
                    run.finishedAt = .now
                    chainRuns.insert(run, at: 0)
                    completed += 1
                }
                step.status = .complete
                prompt.variableRunStep = step
                if let idx = prompts.firstIndex(where: { $0.id == promptID }) {
                    prompts[idx] = prompt
                    prompts[idx].updatedAt = .now
                }
                saveStatus = skipped.isEmpty ? "Batch complete • \(completed) files" : "Batch complete • \(completed) files • skipped \(skipped.count)"
            } else {
                let stepRun = try await chainExecutionService.run(step: step, prompt: prompt, previousOutputs: [:])
                let savedRun = try persistVariablePromptOutput(prompt: prompt, step: step, stepRun: stepRun, forcedFileName: nil)
                var run = ChainRun(chainID: promptID, status: .complete)
                run.stepRuns = [savedRun]
                run.finishedAt = .now
                chainRuns.insert(run, at: 0)
                step.status = .complete
                step.lastOutputID = savedRun.id
                prompt.variableRunStep = step
                if let idx = prompts.firstIndex(where: { $0.id == promptID }) {
                    prompts[idx] = prompt
                    prompts[idx].updatedAt = .now
                }
                saveStatus = "Variable prompt complete • saved"
            }
            try store.save(currentLibrary())
            markAllPromptsSaved()
            errorMessage = nil
        } catch {
            if Task.isCancelled || Self.isCancellationError(error) {
                cancelVariablePromptRun(promptID)
                return
            }
            recordFailure(error.localizedDescription)
        }
    }

    private func variablePromptOutputFolderURL(for prompt: Prompt) -> URL {
        let selected = prompt.variableRunOutputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selected.isEmpty { return URL(fileURLWithPath: selected, isDirectory: true) }
        return ChainOutputStore.defaultRootURL()
            .appendingPathComponent("Variable Prompt Outputs", isDirectory: true)
            .appendingPathComponent(prompt.stableStorageID, isDirectory: true)
    }

    private func persistVariablePromptOutput(prompt: Prompt, step: PromptChainStep, stepRun: ChainStepRun, forcedFileName: String?) throws -> ChainStepRun {
        guard step.outputPolicy == .saveMarkdown || step.outputPolicy == .saveAndUseNext else { return stepRun }
        let folderURL = variablePromptOutputFolderURL(for: prompt)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        var saveStep = step
        if let forcedFileName {
            saveStep.customOutputFileName = forcedFileName
            saveStep.customOutputFilePath = folderURL.appendingPathComponent(forcedFileName).path
        }
        let chain = PromptChain(sequenceID: prompt.sequenceID, title: prompt.displayTitle, steps: [saveStep], customOutputFolderPath: folderURL.path)
        let sourceAttachment = stepRun.fileSnapshots.first
        let url = try ChainOutputStore(rootURL: ChainOutputStore.defaultRootURL()).saveStepMarkdown(stepRun.outputText, chain: chain, step: saveStep, sourceAttachment: sourceAttachment)
        var saved = stepRun
        saved.outputFilePath = url.path
        return saved
    }

    public func latestVariablePromptRun(promptID: UUID, stepID: UUID) -> ChainStepRun? {
        chainRuns.first { $0.chainID == promptID && $0.stepRuns.contains { $0.stepID == stepID } }?.stepRuns.first { $0.stepID == stepID }
    }

    public func saveVariablePromptMarkdown(_ promptID: UUID) {
        guard let prompt = prompts.first(where: { $0.id == promptID }) else { return }
        let step = prompt.variableRunnerStep
        do {
            if let latest = latestVariablePromptRun(promptID: promptID, stepID: step.id), latest.status == .complete {
                _ = try persistVariablePromptOutput(prompt: prompt, step: step, stepRun: latest, forcedFileName: latest.outputFilePath.map { URL(fileURLWithPath: $0).lastPathComponent })
            } else {
                let resolved = try chainExecutionService.resolve(step: step, prompt: prompt, previousOutputs: [:]).0
                let chain = PromptChain(sequenceID: prompt.sequenceID, title: prompt.displayTitle, steps: [step], customOutputFolderPath: variablePromptOutputFolderURL(for: prompt).path)
                _ = try ChainOutputStore(rootURL: ChainOutputStore.defaultRootURL()).saveStepMarkdown(resolved, chain: chain, step: step, sourceAttachment: step.variableBindings.compactMap(\.fileAttachment).first)
            }
            saveStatus = "Saved markdown"
        } catch {
            errorMessage = error.localizedDescription
            saveStatus = "Save failed"
        }
    }

    public func runStep(_ stepID: UUID) async {
        guard let chainIndex = chains.firstIndex(where: { $0.id == selectedChainID }), let stepIndex = chains[chainIndex].steps.firstIndex(where: { $0.id == stepID }) else { return }
        var chain = chains[chainIndex]
        let step = stepUsingSettingsProvider(chain.steps[stepIndex])
        chain.defaultProviderKind = step.providerKind
        chain.defaultModelID = step.modelID
        chain.steps[stepIndex] = step
        chains[chainIndex].defaultProviderKind = step.providerKind
        chains[chainIndex].defaultModelID = step.modelID
        chains[chainIndex].steps[stepIndex] = step
        chains[chainIndex].steps[stepIndex].status = .running
        chains[chainIndex].steps[stepIndex].monitorStatusLabel = ""
        chains[chainIndex].lastMonitorStatusLabel = ""
        chains[chainIndex].lastMonitorMatchedPhrase = ""
        chain.steps[stepIndex].status = .running
        chain.steps[stepIndex].monitorStatusLabel = ""
        chain.lastMonitorStatusLabel = ""
        chain.lastMonitorMatchedPhrase = ""
        saveStatus = "Running step \(step.sortOrder + 1)…"

        func recordFailure(_ message: String, resolvedPrompt: String = "") {
            var failedRun = ChainRun(chainID: chain.id, status: .failed)
            failedRun.finishedAt = .now
            failedRun.stepRuns = [ChainStepRun(stepID: step.id, resolvedPrompt: resolvedPrompt, providerKind: step.providerKind, modelID: step.modelID, inputSnapshot: [:], outputText: "", status: .failed, errorMessage: message, startedAt: failedRun.startedAt, finishedAt: .now)]
            chainRuns.insert(failedRun, at: 0)
            chains[chainIndex].steps[stepIndex].status = .failed
            chains[chainIndex].updatedAt = .now
            errorMessage = message
            saveStatus = "Chain run failed"
        }

        guard let promptID = step.promptID, let prompt = prompts.first(where: { $0.id == promptID }) else {
            recordFailure("Choose a saved prompt before running step \(step.sortOrder + 1).")
            return
        }

        do {
            var run = ChainRun(chainID: chain.id, status: .running)
            let loopFeedbackUsesInitialFileOnly = activeLoopInitialFileOnlyStepIDs.remove(step.id) != nil
            let currentStepSavedOutput = loopFeedbackUsesInitialFileOnly ? nil : latestSavedStepOutputText(for: step)
            let stepRun = try await chainExecutionService.run(
                step: step,
                prompt: prompt,
                previousOutputs: latestPreviousOutputsForFreshStepRun(chainID: chain.id, before: step),
                currentStepSavedOutput: currentStepSavedOutput,
                loopFeedbackUsesInitialFileOnly: loopFeedbackUsesInitialFileOnly
            )
            if Task.isCancelled {
                markStepCancelled(stepID)
                return
            }
            run.stepRuns = [stepRun]
            run.status = .complete
            run.finishedAt = .now
            if step.outputPolicy == .saveMarkdown || step.outputPolicy == .saveAndUseNext {
                let savedStepRun = try persistChainStepOutput(chainIndex: chainIndex, stepIndex: stepIndex, stepRun: stepRun)
                run.stepRuns = [savedStepRun]
            }
            if let monitorMatch = monitorMatch(for: chain, step: step, output: run.stepRuns.first?.outputText ?? stepRun.outputText) {
                var monitoredStepRun = run.stepRuns.first ?? stepRun
                monitoredStepRun.monitorStatusLabel = monitorMatch.statusLabel
                monitoredStepRun.monitorMatchedPhrase = monitorMatch.phrase
                run.stepRuns = [monitoredStepRun]
                run.monitorStatusLabel = monitorMatch.statusLabel
                run.monitorMatchedPhrase = monitorMatch.phrase
            }
            chainRuns.insert(run, at: 0)
            chain.steps[stepIndex].status = .complete
            chain.steps[stepIndex].lastOutputID = run.stepRuns.first?.id
            let monitorStatus = run.monitorStatusLabel.trimmedNonEmpty(defaultValue: "")
            if !monitorStatus.isEmpty {
                chain.steps[stepIndex].monitorStatusLabel = monitorStatus
                chain.lastMonitorStatusLabel = monitorStatus
                chain.lastMonitorMatchedPhrase = run.monitorMatchedPhrase
            }
            chain.lastRunAt = .now
            chain.updatedAt = .now
            mergeCurrentChainPresentationPreferences(into: &chain, at: chainIndex)
            chains[chainIndex] = chain
            try store.save(currentLibrary())
            try PromptBackupService.runIfNeeded(library: currentLibrary(), settings: importExportSettings, storeURL: store.fileURL)
            markAllPromptsSaved()
            errorMessage = nil
            saveStatus = run.monitorStatusLabel.isEmpty ? "Step complete • saved" : "Stopped: \(run.monitorStatusLabel)"
        } catch {
            if Task.isCancelled || Self.isCancellationError(error) {
                markStepCancelled(stepID)
                return
            }
            recordFailure(error.localizedDescription)
        }
    }

    private static func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    private func monitorMatch(for chain: PromptChain, step: PromptChainStep, output: String) -> (statusLabel: String, phrase: String)? {
        for rule in chain.monitorRules where rule.matches(output: output, stepID: step.id) {
            return (rule.statusLabel, rule.phrase.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private func clearMonitorState(chainID: UUID) {
        guard let cidx = chains.firstIndex(where: { $0.id == chainID }) else { return }
        chains[cidx].lastMonitorStatusLabel = ""
        chains[cidx].lastMonitorMatchedPhrase = ""
        for sidx in chains[cidx].steps.indices {
            chains[cidx].steps[sidx].monitorStatusLabel = ""
        }
    }

    private func markStepCancelled(_ stepID: UUID) {
        guard let chainIndex = chains.firstIndex(where: { $0.steps.contains(where: { $0.id == stepID }) }),
              let stepIndex = chains[chainIndex].steps.firstIndex(where: { $0.id == stepID }) else { return }
        let step = chains[chainIndex].steps[stepIndex]
        let message = "Step stopped by user."
        if step.status == .cancelled,
           chainRuns.contains(where: { $0.chainID == chains[chainIndex].id && $0.stepRuns.contains(where: { $0.stepID == stepID && $0.status == .cancelled }) }) {
            return
        }
        var cancelledRun = ChainRun(chainID: chains[chainIndex].id, status: .cancelled)
        cancelledRun.finishedAt = .now
        cancelledRun.stepRuns = [ChainStepRun(stepID: step.id, resolvedPrompt: "", providerKind: step.providerKind, modelID: step.modelID, inputSnapshot: [:], outputText: "", status: .cancelled, errorMessage: message, startedAt: cancelledRun.startedAt, finishedAt: .now)]
        chainRuns.insert(cancelledRun, at: 0)
        chains[chainIndex].steps[stepIndex].status = .cancelled
        chains[chainIndex].updatedAt = .now
        errorMessage = nil
        saveStatus = "Step stopped"
        try? store.save(currentLibrary())
        markAllPromptsSaved()
    }


    private func persistChainStepOutput(chainIndex: Int, stepIndex: Int, stepRun: ChainStepRun) throws -> ChainStepRun {
        let chain = chains[chainIndex]
        let step = chains[chainIndex].steps[stepIndex]
        guard step.outputPolicy == .saveMarkdown || step.outputPolicy == .saveAndUseNext else { return stepRun }
        let sourceAttachment = stepRun.fileSnapshots.first
        let downloadableText = ChainFinalMarkdownExtractor.downloadableMarkdown(from: stepRun.outputText, tagName: step.finalOutputTag)
        let url = try effectiveChainOutputStore().saveStepMarkdown(stepRun.outputText, chain: chain, step: step, sourceAttachment: sourceAttachment)
        var savedStepRun = stepRun
        savedStepRun.outputFilePath = url.path
        upsertChainOutputPrompt(outputText: downloadableText, outputURL: url, chainTitle: chain.title, sourceAttachment: sourceAttachment)
        return savedStepRun
    }

    private func effectiveChainOutputStore() -> ChainOutputStore {
        let builtInDefault = ChainOutputStore.builtInDefaultRootURL().standardizedFileURL.path
        if chainOutputStore.rootURL.standardizedFileURL.path == builtInDefault {
            return ChainOutputStore(rootURL: ChainOutputStore.defaultRootURL())
        }
        return chainOutputStore
    }

    private func upsertChainOutputPrompt(outputText: String, outputURL: URL, chainTitle: String, sourceAttachment: ChainFileAttachment?) {
        let rootFolderID = ensureFolder(named: "Chain Outputs", parentFolderID: nil)
        let chainFolderID = ensureFolder(named: chainTitle.trimmedNonEmpty(defaultValue: "Untitled Chain"), parentFolderID: rootFolderID)
        let responseFileName = outputURL.lastPathComponent
        let now = Date.now
        if let idx = prompts.firstIndex(where: { $0.sourceFilePath == outputURL.path || ($0.folderID == chainFolderID && $0.title == responseFileName) }) {
            prompts[idx].title = responseFileName
            prompts[idx].content = outputText
            prompts[idx].previewSnippet = Prompt.makePreview(from: outputText)
            prompts[idx].folderID = chainFolderID
            prompts[idx].sourceFilePath = outputURL.path
            prompts[idx].sourceType = "chain-output"
            prompts[idx].primaryCategory = "chained-prompts"
            prompts[idx].categories = Array(Set(prompts[idx].categories + ["chained-prompts"])).sorted()
            prompts[idx].subcategory = "chain-output"
            prompts[idx].searchTerms = Array(Set(prompts[idx].searchTerms + ["chain-output", chainTitle.slugKey, sourceAttachment?.fileName.slugKey ?? "response"])).sorted()
            prompts[idx].variables = []
            prompts[idx].isVariablePrompt = false
            prompts[idx].updatedAt = now
        } else {
            let prompt = Prompt(
                sequenceID: allocatePromptSequenceID(),
                title: responseFileName,
                content: outputText,
                folderID: chainFolderID,
                createdAt: now,
                updatedAt: now,
                type: .prompt,
                sourceType: "chain-output",
                primaryCategory: "chained-prompts",
                categories: ["chained-prompts"],
                subcategory: "chain-output",
                whenToUse: "Saved response from chained prompt \(chainTitle).",
                searchTerms: ["chain-output", chainTitle.slugKey, sourceAttachment?.fileName.slugKey ?? "response"],
                variables: [],
                sourceFilePath: outputURL.path,
                lastImportedAt: now
            )
            prompts.insert(prompt, at: 0)
        }
    }

    @discardableResult
    private func removeGeneratedVariableOutputCatalogEntries() -> Int {
        let generatedIDs = Set(prompts.filter(isGeneratedVariableOutputCatalogPrompt).map(\.id))
        guard !generatedIDs.isEmpty else { return 0 }
        prompts.removeAll { generatedIDs.contains($0.id) }
        removeEmptyGeneratedVariableOutputFolders()
        return generatedIDs.count
    }

    private func isGeneratedVariableOutputCatalogPrompt(_ prompt: Prompt) -> Bool {
        guard prompt.sourceType == "chain-output" else { return false }
        if prompt.whenToUse.localizedCaseInsensitiveContains("Variable Prompts /") { return true }
        guard let folderID = prompt.folderID,
              let folder = folders.first(where: { $0.id == folderID })
        else { return false }
        return folder.name.localizedCaseInsensitiveContains("Variable Prompts /")
    }

    private func removeEmptyGeneratedVariableOutputFolders() {
        let usedFolderIDs = Set(prompts.compactMap(\.folderID))
        let generatedFolderIDs = Set(folders.filter { folder in
            folder.name.localizedCaseInsensitiveContains("Variable Prompts /") && !usedFolderIDs.contains(folder.id)
        }.map(\.id))
        guard !generatedFolderIDs.isEmpty else { return }
        folders.removeAll { generatedFolderIDs.contains($0.id) }
    }

    private func mergeCurrentChainPresentationPreferences(into chain: inout PromptChain, at chainIndex: Int) {
        guard chains.indices.contains(chainIndex), chains[chainIndex].id == chain.id else { return }
        let current = chains[chainIndex]
        chain.collapsedStepIDs = current.collapsedStepIDs
        chain.collapsedOutputPreviewLineCount = current.collapsedOutputPreviewLineCount
        chain.customOutputFolderPath = current.customOutputFolderPath
    }

    private func ensureFolder(named name: String, parentFolderID: UUID?) -> UUID {
        let normalized = name.trimmedNonEmpty(defaultValue: "Chain Outputs")
        if let existing = folders.first(where: { $0.parentFolderID == parentFolderID && $0.name == normalized }) { return existing.id }
        let sortOrder = ((folders.filter { $0.parentFolderID == parentFolderID }.map(\.sortOrder).max()) ?? -1) + 1
        let folder = Folder(name: normalized, parentFolderID: parentFolderID, sortOrder: sortOrder)
        folders.append(folder)
        return folder.id
    }

    public func runSelectedChain() async {
        guard let selectedChainID else { return }
        guard let chainIndex = chains.firstIndex(where: { $0.id == selectedChainID }) else { return }
        clearMonitorState(chainID: selectedChainID)
        let stepIDs = chains[chainIndex].steps.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.id)
        guard !stepIDs.isEmpty else {
            errorMessage = "Add at least one step before running this chain."
            saveStatus = "Chain run failed"
            return
        }
        for stepID in stepIDs {
            if Task.isCancelled {
                markStepCancelled(stepID)
                saveStatus = "Chain stopped"
                break
            }
            await runStep(stepID)
            if Task.isCancelled {
                saveStatus = "Chain stopped"
                break
            }
            if shouldStopChainRun(selectedChainID: selectedChainID, stepID: stepID) { break }
        }
        if let currentChain = chains.first(where: { $0.id == selectedChainID }), currentChain.steps.allSatisfy({ $0.status == .complete }) {
            saveStatus = "Chain complete"
        }
    }

    public func runSelectedLoop() async {
        guard let selectedChainID else { return }
        guard let chainIndex = chains.firstIndex(where: { $0.id == selectedChainID }) else { return }
        clearMonitorState(chainID: selectedChainID)
        let sortedSteps = chains[chainIndex].steps.sorted(by: { $0.sortOrder < $1.sortOrder })
        guard !sortedSteps.isEmpty else {
            errorMessage = "Add at least one step before running this loop."
            saveStatus = "Loop run failed"
            return
        }
        guard let startID = chains[chainIndex].loopStartStepID,
              let endID = chains[chainIndex].loopEndStepID,
              let startIndex = sortedSteps.firstIndex(where: { $0.id == startID }),
              let endIndex = sortedSteps.firstIndex(where: { $0.id == endID }),
              startIndex <= endIndex else {
            errorMessage = "Choose a contiguous loop range before running the loop."
            saveStatus = "Loop run failed"
            return
        }
        let loopStepIDs = sortedSteps[startIndex...endIndex].map(\.id)
        let loopCount = max(1, min(chains[chainIndex].loopCount, 100))
        activeLoopInitialFileOnlyStepIDs = Set(loopStepIDs)
        defer { activeLoopInitialFileOnlyStepIDs.removeAll() }

        for iteration in 1...loopCount {
            saveStatus = "Running loop \(iteration) of \(loopCount)…"
            for stepID in loopStepIDs {
                if Task.isCancelled { markStepCancelled(stepID); saveStatus = "Loop stopped"; return }
                await runStep(stepID)
                if shouldStopChainRun(selectedChainID: selectedChainID, stepID: stepID) {
                    if let currentIndex = chains.firstIndex(where: { $0.id == selectedChainID }),
                       !chains[currentIndex].lastMonitorStatusLabel.isEmpty {
                        chains[currentIndex].lastLoopRunCount = iteration
                        chains[currentIndex].totalLoopRunCount += 1
                        chains[currentIndex].lastRunAt = .now
                        chains[currentIndex].updatedAt = .now
                        try? store.save(currentLibrary())
                    }
                    return
                }
            }
            if let currentIndex = chains.firstIndex(where: { $0.id == selectedChainID }) {
                chains[currentIndex].lastLoopRunCount = iteration
                chains[currentIndex].totalLoopRunCount += 1
                chains[currentIndex].updatedAt = .now
            }
        }
        if let currentIndex = chains.firstIndex(where: { $0.id == selectedChainID }) {
            chains[currentIndex].lastLoopRunCount = loopCount
            chains[currentIndex].lastRunAt = .now
            chains[currentIndex].updatedAt = .now
            try? store.save(currentLibrary())
        }
        saveStatus = "Loop complete"
    }

    public func stepRunCount(for stepID: UUID) -> Int {
        chainRuns.reduce(0) { total, run in
            total + run.stepRuns.filter { $0.stepID == stepID }.count
        }
    }

    private func shouldStopChainRun(selectedChainID: UUID, stepID: UUID) -> Bool {
        if Task.isCancelled {
            saveStatus = "Chain stopped"
            return true
        }
        guard let currentChain = chains.first(where: { $0.id == selectedChainID }),
              let status = currentChain.steps.first(where: { $0.id == stepID })?.status else { return true }
        if status == .failed {
            saveStatus = "Chain run failed"
            return true
        }
        if status == .cancelled {
            saveStatus = "Chain stopped"
            return true
        }
        let monitorStatus = currentChain.lastMonitorStatusLabel.trimmedNonEmpty(defaultValue: "")
        if !monitorStatus.isEmpty {
            saveStatus = "Stopped: \(monitorStatus)"
            return true
        }
        return false
    }

    public func testProvider(_ kind: AIProviderKind) {
        guard let idx = aiProviders.firstIndex(where: { $0.kind == kind }) else { return }
        aiProviders[idx].isConfigured = true
        aiProviders[idx].lastTestedAt = .now
        aiProviders[idx].lastTestStatus = .complete
        saveStatus = "\(kind.displayName) connected"
        save()
    }

    public func createPhrase() {
        let folderID: UUID? = if case let .folder(id) = selection { id } else { nil }
        let p = Prompt(sequenceID: allocatePromptSequenceID(), title: "Untitled Phrase", content: "Reusable wording for your agent...", folderID: folderID, isFavorite: selection == .favorites, type: .phrase, primaryCategory: metadataFilters.category ?? "uncategorized", subcategory: metadataFilters.subcategory ?? "general", whenToUse: "Use as reusable wording when speaking to an agent.", searchTerms: ["phrase", "wording", "agent"])
        librarySection = .phrases
        if clearSearchAfterCreate { searchQuery = "" }
        metadataFilters.type = nil
        prompts.insert(p, at: 0)
        selectedPromptID = p.id
        save()
    }

    public func createFolder(parentFolderID: UUID? = nil, scope: FolderScope? = nil) {
        let resolvedScope = scope ?? parentFolderID.flatMap { parentID in folders.first { $0.id == parentID }?.scope } ?? folderScopeForCurrentContext()
        let siblingSortOrders = folders
            .filter { $0.parentFolderID == parentFolderID && $0.scope == resolvedScope }
            .map(\.sortOrder)
        let topSortOrder = (siblingSortOrders.min() ?? 0) - 1
        let f = Folder(name: "New Folder", parentFolderID: parentFolderID, sortOrder: topSortOrder, scope: resolvedScope)
        folders.append(f)
        selection = .folder(f.id)
        if resolvedScope == .chains { librarySection = .chains }
        if resolvedScope == .phrases { librarySection = .phrases }
        if resolvedScope == .variablePrompts { librarySection = .prompts; metadataFilters.type = .variablePrompt }
        folderRenameRequestID = f.id
        save()
    }

    private func folderScopeForCurrentContext() -> FolderScope {
        if librarySection == .chains { return .chains }
        if librarySection == .phrases { return .phrases }
        if selection == .variablePrompts || metadataFilters.type == .variablePrompt { return .variablePrompts }
        return .prompts
    }

    public func selectPrompt(_ prompt: Prompt) {
        mutate(prompt.id) { $0.markOpened() }
        selectedPromptID = prompt.id
    }
    public func copyPrompt(_ prompt: Prompt) {
        guard clipboardSettings.rawShortcut else { filledCopyMessage = "Raw copy disabled in Settings"; return }
        ClipboardService.copy(ClipboardService.formattedPrompt(prompt, settings: clipboardSettings))
        mutate(prompt.id) { $0.recordCopy() }
        copiedPromptID = prompt.id
        if clipboardSettings.successFeedback { filledCopyMessage = prompt.type == .phrase ? "Phrase copied" : "Prompt copied" }
        save()
    }
    public func copyFilledPrompt(_ prompt: Prompt, values: [String: String]) -> Bool {
        guard clipboardSettings.filledShortcut else { filledCopyMessage = "Filled copy disabled in Settings"; return false }
        let missing = VariableDetector.missingRequiredVariables(definitions: prompt.variables, values: values)
        if clipboardSettings.requireVariables {
            guard missing.isEmpty else { filledCopyMessage = "Please fill required variables before copying."; return false }
        }
        ClipboardService.copy(ClipboardService.formattedPrompt(prompt, settings: clipboardSettings, bodyOverride: VariableDetector.filledPrompt(content: prompt.content, values: values)))
        mutate(prompt.id) { $0.recordCopy() }
        copiedPromptID = prompt.id
        if clipboardSettings.successFeedback { filledCopyMessage = "Filled prompt copied" }
        save()
        return true
    }
    public func duplicatePrompt(_ prompt: Prompt) {
        var copy = prompt.duplicate()
        copy.sequenceID = allocatePromptSequenceID()
        prompts.insert(copy, at: 0)
        selectedPromptID = copy.id
        librarySection = copy.type == .phrase ? .phrases : .prompts
        save()
    }
    public func archivePrompt(_ prompt: Prompt) { mutate(prompt.id) { $0.archive() }; selectedPromptID = visiblePrompts.first { $0.id != prompt.id }?.id; save() }

    public func bindingForFolder(_ id: UUID) -> Binding<Folder>? {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(get: { self.folders[idx] }, set: { self.folders[idx] = $0; self.save() })
    }

    public func renameFolder(_ id: UUID, to name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].rename(to: name)
        folderRenameRequestID = nil
        save()
    }

    public func requestFolderRename(_ id: UUID) {
        selection = .folder(id)
        folderRenameRequestID = id
    }

    public func deleteFolder(_ id: UUID) {
        let childIDs = LibraryFilterService.folderScopeIDs(for: .folder(id), folders: folders)
        folders.removeAll { childIDs.contains($0.id) }
        for idx in prompts.indices where prompts[idx].folderID.map(childIDs.contains) == true {
            prompts[idx].folderID = nil
            prompts[idx].touch()
        }
        for idx in chains.indices where chains[idx].folderID.map(childIDs.contains) == true {
            chains[idx].folderID = nil
            chains[idx].updatedAt = .now
        }
        if case let .folder(selectedID) = selection, childIDs.contains(selectedID) { selection = .all }
        save()
    }

    public func moveSelectedPrompt(to folderID: UUID?) {
        guard let selectedPromptID, let current = prompts.first(where: { $0.id == selectedPromptID }) else { return }
        mutate(selectedPromptID) { $0.move(to: folderID) }
        selection = folderID.map(LibrarySelection.folder) ?? .all
        librarySection = current.type == .phrase ? .phrases : .prompts
        if current.type != .phrase && current.hasVariables { metadataFilters.type = .variablePrompt }
        save()
    }

    public func prepareImport(from folderURL: URL) {
        importPreview = PromptFolderImportService.scanFolder(at: folderURL, existingPrompts: prompts, duplicateBehavior: importExportSettings.duplicateImportBehavior, preserveSourcePath: importExportSettings.preserveSourcePath, defaultVariableType: defaultVariableType, autoDetectVariables: autoDetectVariables)
    }

    public func confirmImportPreview() {
        guard let importPreview else { return }
        let batch = PromptFolderImportService.importRows(from: importPreview, into: &prompts, folders: &folders, folderBehavior: importExportSettings.importFolderBehavior, duplicateBehavior: importExportSettings.duplicateImportBehavior)
        assignMissingSequenceIDs()
        importBatches.insert(batch, at: 0)
        if let first = prompts.first { selectedPromptID = first.id; librarySection = first.type == .phrase ? .phrases : .prompts }
        self.importPreview = nil
        saveStatus = "Imported \(batch.importedCount) entries"
        save()
    }

    public func runMetadataAudit() {
        auditReport = PromptExportService.auditReport(for: prompts.filter { !$0.isArchived })
    }

    public func clearMetadataFilters() { metadataFilters.clear() }

    public func mutate(_ id: UUID, change: (inout Prompt) -> Void) { guard let idx = prompts.firstIndex(where: { $0.id == id }) else { return }; change(&prompts[idx]) }
}
