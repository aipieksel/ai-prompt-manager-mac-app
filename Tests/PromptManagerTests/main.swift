import Foundation
import PromptManagerCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("❌ \(message)\n", stderr)
        exit(1)
    }
}

func testPromptModel() {
    var prompt = Prompt(title: "   ", content: "One two\nthree")
    expect(prompt.title.isEmpty, "empty title should remain empty so editor placeholder text is not persisted")
    expect(prompt.previewSnippet == "One two three", "preview should compact whitespace")
    expect(prompt.wordCount == 3, "word count should be 3")
    prompt.archive()
    expect(prompt.isArchived, "archive should soft-delete")
    prompt.restore()
    expect(!prompt.isArchived, "restore should clear archive")
    let originalUpdatedAt = prompt.updatedAt
    prompt.markOpened(at: originalUpdatedAt.addingTimeInterval(10))
    expect(prompt.lastOpenedAt == originalUpdatedAt.addingTimeInterval(10), "mark opened should update last-opened timestamp")
    expect(prompt.updatedAt == originalUpdatedAt, "mark opened should not change updatedAt or make selected rows jump in Updated sort")
    let copy = prompt.duplicate()
    expect(copy.title == "Untitled Prompt Copy", "duplicate should suffix a display fallback title")
}

func testFiltering() {
    let folder = Folder(name: "Marketing")
    let old = Prompt(title: "Old", content: "Nothing", folderID: folder.id, updatedAt: Date(timeIntervalSince1970: 1))
    let match = Prompt(title: "Product", content: "Launch copy", folderID: folder.id, isFavorite: true, updatedAt: Date(timeIntervalSince1970: 2), copyCount: 9)
    let archived = Prompt(title: "Product archived", content: "Launch", folderID: folder.id, isArchived: true, updatedAt: Date(timeIntervalSince1970: 3))
    let results = LibraryFilterService.visiblePrompts([old, match, archived], folders: [folder], selection: .folder(folder.id), searchQuery: "Product", sortMode: .mostCopied)
    expect(results.map(\.id) == [match.id], "search should use prompt fields and exclude archived prompts after tag removal")

    let now = Date(timeIntervalSince1970: 10_000)
    let child = Folder(name: "Child", parentFolderID: folder.id)
    let childPrompt = Prompt(title: "Nested", content: "Child folder prompt", folderID: child.id, updatedAt: now)
    let oldRecent = Prompt(title: "Too Old", content: "", updatedAt: now.addingTimeInterval(-30 * 86_400))
    let recent = LibraryFilterService.visiblePrompts([oldRecent, childPrompt], folders: [folder, child], selection: .recent, searchQuery: "", sortMode: .updated, now: now)
    expect(recent.map(\.id) == [childPrompt.id], "recent selection should include only prompts updated/opened in the last 14 days")
    let nested = LibraryFilterService.visiblePrompts([old, childPrompt], folders: [folder, child], selection: .folder(folder.id), searchQuery: "child", sortMode: .updated, now: now)
    expect(nested.map(\.id) == [childPrompt.id], "folder selection should include descendant folders and content search")
    let variablePrompt = Prompt(title: "Variable", content: "Use {client_name}", updatedAt: now, variables: [VariableDefinition(key: "client_name")])
    let normalPrompt = Prompt(title: "Normal", content: "No variables", updatedAt: now)
    let variableSelection = LibraryFilterService.visiblePrompts([variablePrompt, normalPrompt], folders: [], selection: .variablePrompts, searchQuery: "", sortMode: .az, now: now)
    expect(variableSelection.map(\.id) == [variablePrompt.id], "variable prompt selection should be computed from detected variables")
    let explicitVariableDraft = Prompt(title: "Draft Variable", content: "Plain draft", updatedAt: now, isVariablePrompt: true)
    let variableTypeFilter = LibraryFilterService.visiblePrompts([variablePrompt, normalPrompt, explicitVariableDraft], folders: [], selection: .all, searchQuery: "", sortMode: .az, metadataFilters: MetadataFilterState(type: .variablePrompt), now: now)
    expect(variableTypeFilter.map(\.id) == [explicitVariableDraft.id, variablePrompt.id], "variable prompt type filter should include explicit variable prompts and detected variable prompts")
    let promptTypeFilter = LibraryFilterService.visiblePrompts([variablePrompt, normalPrompt, explicitVariableDraft], folders: [], selection: .all, searchQuery: "", sortMode: .az, metadataFilters: MetadataFilterState(type: .prompt), now: now)
    expect(promptTypeFilter.map(\.id) == [normalPrompt.id], "plain prompt type filter should exclude explicit and detected variable prompts")

    let a = Prompt(title: "Alpha", content: "", isFavorite: false, createdAt: Date(timeIntervalSince1970: 10), updatedAt: Date(timeIntervalSince1970: 20), lastOpenedAt: Date(timeIntervalSince1970: 30), copyCount: 1)
    let b = Prompt(title: "Bravo", content: "", isFavorite: true, createdAt: Date(timeIntervalSince1970: 30), updatedAt: Date(timeIntervalSince1970: 10), lastOpenedAt: Date(timeIntervalSince1970: 40), copyCount: 5)
    expect(LibraryFilterService.sort([a, b], by: .updated).map(\.title) == ["Alpha", "Bravo"], "updated sort should put newest updated first")
    expect(LibraryFilterService.sort([a, b], by: .created).map(\.title) == ["Bravo", "Alpha"], "created sort should put newest created first")
    expect(LibraryFilterService.sort([a, b], by: .lastOpened).map(\.title) == ["Bravo", "Alpha"], "last opened sort should put newest opened first")
    expect(LibraryFilterService.sort([b, a], by: .az).map(\.title) == ["Alpha", "Bravo"], "A-Z sort should sort ascending")
    expect(LibraryFilterService.sort([a, b], by: .za).map(\.title) == ["Bravo", "Alpha"], "Z-A sort should sort descending")
    expect(LibraryFilterService.sort([a, b], by: .favoritesFirst).first?.title == "Bravo", "favorites first sort should prioritize favorites")
    expect(LibraryFilterService.sort([a, b], by: .mostCopied).first?.title == "Bravo", "most copied sort should prioritize copy count")
}

func testStoreAndImportExport() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("library.json")
    let store = PromptStore(fileURL: url)
    let folder = Folder(name: "Marketing")
    let prompt = Prompt(title: "SEO Brief", content: "Write the page.", folderID: folder.id, notes: "Use keywords.")
    try store.save(PromptLibrary(prompts: [prompt], folders: [folder]))
    let loaded = try store.load()
    expect(loaded.prompts.map(\.title) == ["SEO Brief"], "store should round-trip prompt")
    expect(ImportExportService.markdown(for: prompt).contains("## Notes"), "markdown export should include notes")
    let data = try ImportExportService.exportJSON(prompts: [prompt], folders: [folder])
    expect(String(decoding: data, as: UTF8.self).contains("SEO Brief"), "json export should include prompt")
    let imported = ImportExportService.importTextPrompt(fileName: "Launch Prompt.md", content: "Body")
    expect(imported.title == "Launch Prompt", "import should derive title from filename")
}

@MainActor
func testPromptSelectionDoesNotResortUpdatedList() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let oldUpdatedAt = Date(timeIntervalSince1970: 10)
    let newUpdatedAt = Date(timeIntervalSince1970: 20)
    let older = Prompt(title: "Older", content: "Select me", updatedAt: oldUpdatedAt)
    let newer = Prompt(title: "Newer", content: "Stay first", updatedAt: newUpdatedAt)
    try store.save(PromptLibrary(prompts: [older, newer], folders: []))

    let model = AppViewModel(store: store)
    model.sortMode = .updated
    model.selectPrompt(older)

    expect(model.prompts.first(where: { $0.id == older.id })?.updatedAt == oldUpdatedAt, "selecting/opening a prompt should not mutate updatedAt")
    expect(model.visiblePrompts.map(\.id) == [newer.id, older.id], "selecting an older prompt should not move it to the top of Updated sort")
    expect(model.selectedPromptID == older.id, "the clicked prompt should still become selected")
}

@MainActor
func testBlankPromptCreationDirtySaveAndDiscard() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    try store.save(PromptLibrary(prompts: [], folders: []))

    let model = AppViewModel(store: store)
    model.createPrompt()
    guard let promptID = model.selectedPromptID, let binding = model.bindingForSelectedPrompt() else {
        fputs("❌ created prompt should be selected and bindable\n", stderr)
        exit(1)
    }
    expect(binding.wrappedValue.title.isEmpty, "new prompt title should be blank placeholder state, not real Untitled text")
    expect(binding.wrappedValue.content.isEmpty, "new prompt content should be blank placeholder state, not boilerplate text")
    expect(!model.hasUnsavedPromptChanges, "new blank prompt is explicitly persisted by the create action")

    var edited = binding.wrappedValue
    edited.rename(to: "Draft Title", at: Date(timeIntervalSince1970: 100))
    binding.wrappedValue = edited
    expect(model.hasUnsavedPromptChanges, "editing through selected prompt binding should mark prompt dirty without saving")
    let loadedBeforeSave = try store.load()
    expect(loadedBeforeSave.prompts.first(where: { $0.id == promptID })?.title.isEmpty == true, "dirty edits should not persist before explicit save")
    model.discardUnsavedChanges()
    expect(model.selectedPrompt?.title.isEmpty == true, "discard should restore saved blank prompt")

    guard let bindingAfterDiscard = model.bindingForSelectedPrompt() else {
        fputs("❌ selected prompt should still be bindable after discard\n", stderr)
        exit(1)
    }
    var savedEdit = bindingAfterDiscard.wrappedValue
    savedEdit.rename(to: "Saved Title", at: Date(timeIntervalSince1970: 200))
    bindingAfterDiscard.wrappedValue = savedEdit
    model.save()
    let loadedAfterSave = try store.load()
    expect(loadedAfterSave.prompts.first(where: { $0.id == promptID })?.title == "Saved Title", "explicit save should persist dirty prompt edits")
    expect(!model.hasUnsavedPromptChanges, "explicit save should clear dirty prompt state")
}


@MainActor
func testNewVariablePromptKeepsIdentityWhenContentHasNoVariables() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    try store.save(PromptLibrary(prompts: [], folders: []))

    let model = AppViewModel(store: store)
    model.selection = .variablePrompts
    model.metadataFilters.type = .variablePrompt
    model.createPrompt()

    guard let promptID = model.selectedPromptID, let binding = model.bindingForSelectedPrompt() else {
        fputs("❌ new variable prompt should be selected and bindable\n", stderr)
        exit(1)
    }
    expect(binding.wrappedValue.isVariablePrompt, "new variable prompt should persist explicit variable-prompt identity")
    expect(binding.wrappedValue.hasVariables, "new variable prompt should count as variable prompt before content variables are detected")

    var edited = binding.wrappedValue
    edited.updateContent("Write a launch plan without placeholders.", at: Date(timeIntervalSince1970: 42))
    edited.variables = []
    binding.wrappedValue = edited

    expect(model.selectedPromptID == promptID, "editing plain content should keep the variable prompt selected")
    expect(model.bindingForSelectedPrompt()?.wrappedValue.isVariablePrompt == true, "editing plain content should not clear explicit variable-prompt identity")
    expect(model.visiblePrompts.contains { $0.id == promptID }, "plain-content variable prompt should remain visible in Variable Prompts")

    var tokenEdit = model.bindingForSelectedPrompt()!.wrappedValue
    tokenEdit.updateContent("Write a launch plan for {topic}.", at: Date(timeIntervalSince1970: 43))
    model.bindingForSelectedPrompt()!.wrappedValue = tokenEdit
    expect(model.bindingForSelectedPrompt()?.wrappedValue.variables.map(\.key) == ["topic"], "adding a variable token should populate variable rows")

    var removedTokenEdit = model.bindingForSelectedPrompt()!.wrappedValue
    removedTokenEdit.updateContent("Write a launch plan after removing placeholders.", at: Date(timeIntervalSince1970: 44))
    removedTokenEdit.variables = []
    model.bindingForSelectedPrompt()!.wrappedValue = removedTokenEdit
    expect(model.bindingForSelectedPrompt()?.wrappedValue.isVariablePrompt == true, "removing all variable tokens should keep variable-prompt identity")
    expect(model.bindingForSelectedPrompt()?.wrappedValue.variables.isEmpty == true, "removing all variable tokens should show the no-variables state")
    model.save()

    let reloaded = AppViewModel(store: store)
    let persisted = reloaded.prompts.first { $0.id == promptID }
    expect(persisted?.isVariablePrompt == true, "saved and reloaded plain-content prompt should remain a variable prompt")
    expect(persisted?.variables.isEmpty == true, "plain content should not invent variables")
    reloaded.selection = .variablePrompts
    reloaded.metadataFilters.type = .variablePrompt
    expect(reloaded.visiblePrompts.contains { $0.id == promptID }, "reloaded plain-content variable prompt should remain in Variable Prompts")
}

func testPromptDecodingBackfillsVariablePromptIdentity() throws {
    let legacy = Prompt(title: "Legacy Variable", content: "Hello {name}", variables: [VariableDefinition(key: "name")])
    let encoder = JSONEncoder()
    let encoded = try encoder.encode(legacy)
    var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] ?? [:]
    object.removeValue(forKey: "isVariablePrompt")
    let legacyData = try JSONSerialization.data(withJSONObject: object)
    let prompt = try JSONDecoder().decode(Prompt.self, from: legacyData)
    expect(prompt.isVariablePrompt, "legacy prompts with variables should decode as explicit variable prompts")
}

@MainActor
func testSelectedPromptStaysBoundWhenItDropsOutOfCurrentFilter() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let variablePrompt = Prompt(title: "Variable", content: "{number}", variables: [VariableDefinition(key: "number")])
    let fallbackPrompt = Prompt(title: "Fallback", content: "{fallback}", variables: [VariableDefinition(key: "fallback")])
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    try store.save(PromptLibrary(prompts: [variablePrompt, fallbackPrompt], folders: []))
    let model = AppViewModel(store: store)
    model.selection = .variablePrompts
    model.selectedPromptID = variablePrompt.id

    guard let binding = model.bindingForSelectedPrompt() else {
        fputs("❌ filtered selected prompt should be bindable\n", stderr)
        exit(1)
    }
    var edited = binding.wrappedValue
    edited.updateContent("abc", at: Date(timeIntervalSince1970: 50))
    edited.variables = []
    binding.wrappedValue = edited

    expect(model.selectedPromptID == variablePrompt.id, "selected prompt id should not jump when edited content removes variables")
    expect(model.selectedPrompt?.id == variablePrompt.id, "selected prompt should remain loaded even when it no longer matches the active filter")
    expect(model.visiblePrompts.contains { $0.id == variablePrompt.id }, "selected prompt should remain visible in the active filtered list while editing")
    expect(model.bindingForSelectedPrompt()?.wrappedValue.content == "abc", "editor binding should keep editing the same prompt after it drops out of the list filter")
    expect(model.prompts.first(where: { $0.id == fallbackPrompt.id })?.content == "{fallback}", "filter fallback prompt should not receive typed editor content")
}

@MainActor
func testSelectedPromptBindingIsIDStableWhenArrayChanges() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let first = Prompt(title: "First", content: "A", updatedAt: Date(timeIntervalSince1970: 1))
    let second = Prompt(title: "Second", content: "B", updatedAt: Date(timeIntervalSince1970: 2))
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    try store.save(PromptLibrary(prompts: [first, second], folders: []))
    let model = AppViewModel(store: store)
    model.selectedPromptID = second.id
    guard let binding = model.bindingForSelectedPrompt() else {
        fputs("❌ selected prompt should be bindable\n", stderr)
        exit(1)
    }
    model.prompts.insert(Prompt(title: "Inserted", content: "C", updatedAt: Date(timeIntervalSince1970: 3)), at: 0)
    var edited = binding.wrappedValue
    edited.updateContent("Updated second", at: Date(timeIntervalSince1970: 4))
    binding.wrappedValue = edited
    expect(model.prompts.first(where: { $0.id == second.id })?.content == "Updated second", "selected prompt binding should update by id, not stale array index")
    expect(model.prompts.first(where: { $0.id == first.id })?.content == "A", "id-stable binding should not overwrite neighboring prompts")
}

@MainActor
func testDerivedPromptCachesInvalidateAfterEdits() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let first = Prompt(title: "Needle", content: "First", updatedAt: Date(timeIntervalSince1970: 1), primaryCategory: "alpha")
    let second = Prompt(title: "Second", content: "Plain", updatedAt: Date(timeIntervalSince1970: 2), primaryCategory: "beta")
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    try store.save(PromptLibrary(prompts: [first, second], folders: []))
    let model = AppViewModel(store: store)
    model.selectedPromptID = nil
    model.sortMode = .az
    model.searchQuery = "Needle"

    expect(model.visiblePrompts.map(\.id) == [first.id], "initial visible prompt cache should reflect the search query")
    expect(!model.availableCategories.contains("gamma"), "initial category cache should not include a future edit")

    guard let binding = model.bindingForPrompt(second.id) else {
        fputs("❌ second prompt should be bindable\n", stderr)
        exit(1)
    }
    var edited = binding.wrappedValue
    edited.rename(to: "Needle Two", at: Date(timeIntervalSince1970: 3))
    edited.primaryCategory = "gamma"
    edited.variables = [VariableDefinition(key: "topic")]
    binding.wrappedValue = edited

    expect(model.visiblePrompts.map(\.id) == [first.id, second.id], "visible prompt cache should invalidate when a prompt edit changes search membership")
    expect(model.availableCategories.contains("gamma"), "category cache should invalidate when prompt metadata changes")
    expect(model.activeVariablePrompts.contains { $0.id == second.id }, "derived variable prompt cache should invalidate when variables change")
}

@MainActor
func testMovingSelectedPromptFollowsDestinationFolder() throws {
    let folderA = Folder(name: "A")
    let folderB = Folder(name: "B")
    let prompt = Prompt(title: "Move Me", content: "Body", folderID: folderA.id)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    try store.save(PromptLibrary(prompts: [prompt], folders: [folderA, folderB]))
    let model = AppViewModel(store: store)
    model.selection = .folder(folderA.id)
    model.selectedPromptID = prompt.id
    model.moveSelectedPrompt(to: folderB.id)
    expect(model.selection == .folder(folderB.id), "moving a prompt from the inspector should switch the list context to the destination folder")
    expect(model.visiblePrompts.contains { $0.id == prompt.id }, "moved prompt should remain visible after folder change")
}

func testVariablePresetUpdateRenameAndVersionInfo() {
    var prompt = Prompt(title: "Preset", content: "{client}", variables: [VariableDefinition(key: "client")])
    prompt.savePreset(name: "Client A", values: ["client": "A"], at: Date(timeIntervalSince1970: 1))
    guard let presetID = prompt.variablePresets.first?.id else {
        fputs("❌ preset should be saved\n", stderr)
        exit(1)
    }
    prompt.updatePreset(presetID, values: ["client": "B"], at: Date(timeIntervalSince1970: 2))
    prompt.renamePreset(presetID, to: "Client B", at: Date(timeIntervalSince1970: 3))
    expect(prompt.variablePresets.first?.values["client"] == "B", "preset update should replace values for selected preset")
    expect(prompt.variablePresets.first?.name == "Client B", "preset rename should persist a user-defined name")
    expect(AppVersionInfo(shortVersion: "0.1.1", build: "12").displayText == "Version 0.1.1", "version info should display the semantic patch version that build packaging increments")
}

@MainActor
func testAppViewModelWorkflows() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("library.json")
    let store = PromptStore(fileURL: url)
    try store.save(PromptLibrary(prompts: [], folders: []))

    let model = AppViewModel(store: store)
    expect(model.prompts.isEmpty, "test model should start with no prompts")

    model.createFolder()
    guard let folderID = model.folders.first?.id else {
        fputs("❌ create folder should append a folder\n", stderr)
        exit(1)
    }
    expect(model.selection == .folder(folderID), "new folder should become selected")
    expect(model.folderRenameRequestID == folderID, "new folder should enter inline rename mode immediately")

    model.renameFolder(folderID, to: "Client Work")
    expect(model.folders.first?.name == "Client Work", "rename folder should update model")

    model.createFolder()
    let sortedRootFolders = model.folders.sorted { $0.sortOrder < $1.sortOrder }
    expect(sortedRootFolders.first?.id == model.folderRenameRequestID, "new root folder should sort directly beneath the FOLDERS add button")

    model.selection = .folder(folderID)
    model.folderRenameRequestID = nil
    model.createPrompt()
    guard let promptID = model.selectedPromptID, let promptIndex = model.prompts.firstIndex(where: { $0.id == promptID }) else {
        fputs("❌ create prompt should select a prompt\n", stderr)
        exit(1)
    }
    expect(model.prompts[promptIndex].folderID == folderID, "new prompt should inherit selected folder")
    model.prompts[promptIndex].rename(to: "Homepage Hero")
    model.prompts[promptIndex].updateContent("Write a concise hero for Prompt Manager.")
    model.save()

    let saved = try store.load()
    expect(saved.folders.first?.name == "Client Work", "renamed folder should persist")
    expect(saved.prompts.first?.title == "Homepage Hero", "renamed prompt should persist")
    expect(saved.prompts.first?.content.contains("Prompt Manager") == true, "prompt content should persist")

    let reloaded = AppViewModel(store: store)
    expect(reloaded.folders.first?.name == "Client Work", "folder rename should survive relaunch")
    expect(reloaded.prompts.first?.title == "Homepage Hero", "prompt rename should survive relaunch")

    reloaded.selection = .templates
    reloaded.searchQuery = "no visible match"
    reloaded.createPrompt()
    expect(reloaded.searchQuery.isEmpty, "creating from a filtered empty state should clear search so the new item is visible")
    expect(reloaded.selectedPrompt?.isTemplate == true, "new prompt from Templates should create a visible template")
    expect(reloaded.visiblePrompts.contains { $0.id == reloaded.selectedPromptID }, "new template should be visible in the Templates filter")

    reloaded.selection = .favorites
    reloaded.createPrompt()
    expect(reloaded.selectedPrompt?.isFavorite == true, "new prompt from Favorites should create a visible favorite")

    reloaded.selection = .all
    reloaded.selectedPromptID = promptID
    if let prompt = reloaded.selectedPrompt {
        reloaded.duplicatePrompt(prompt)
        expect(reloaded.prompts.contains { $0.title == "Homepage Hero Copy" }, "duplicate should create a copy")
        reloaded.copyPrompt(prompt)
        expect(reloaded.prompts.first { $0.id == prompt.id }?.copyCount == 1, "copy should increment copy count")
        reloaded.archivePrompt(prompt)
        expect(reloaded.prompts.first { $0.id == prompt.id }?.isArchived == true, "delete/archive should hide prompt")
    } else {
        fputs("❌ selected prompt should be available for actions\n", stderr)
        exit(1)
    }

    reloaded.deleteFolder(folderID)
    expect(!reloaded.folders.contains { $0.id == folderID }, "delete folder should remove folder")
    expect(reloaded.prompts.allSatisfy { $0.folderID != folderID }, "delete folder should unassign prompts")
    reloaded.moveSelectedPrompt(to: nil)
    expect(reloaded.saveStatus.hasPrefix("Saved"), "explicit save/move action should leave a saved status")
}

func testMetadataModelsAndMigration() throws {
    let legacyJSON = """
    {"prompts":[{"id":"00000000-0000-0000-0000-000000000001","title":"Legacy","content":"Hello","previewSnippet":"Hello","folderID":null,"tagIDs":[],"isFavorite":false,"isTemplate":false,"isArchived":false,"createdAt":"2026-05-28T08:00:00Z","updatedAt":"2026-05-28T08:00:00Z","lastOpenedAt":null,"copyCount":0,"notes":"","sortOrder":null}],"folders":[],"tags":[]}
    """
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    let library = try decoder.decode(PromptLibrary.self, from: Data(legacyJSON.utf8))
    expect(library.prompts.first?.type == .prompt, "legacy prompt should default to prompt type")
    expect(library.prompts.first?.primaryCategory == "uncategorized", "legacy prompt should default metadata category")
    expect(library.importBatches.isEmpty, "legacy library should default import batches")
}

func testMarkdownImportPhrasesAndCategories() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let phraseDir = root.appendingPathComponent("coding/agent-quality", isDirectory: true)
    let contentDir = root.appendingPathComponent("content", isDirectory: true)
    try FileManager.default.createDirectory(at: phraseDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
    try """
    ---
    id: agent-wording-reference
    title: Agent Wording Reference
    type: cheat-sheet
    subcategory: agent-quality
    search_terms:
      - phrases
      - wording
    ---
    # Agent Wording Reference
    Use this phrase with {agent_context}.
    """.write(to: phraseDir.appendingPathComponent("agent-wording-reference.md"), atomically: true, encoding: .utf8)
    try "Audit this content.".write(to: contentDir.appendingPathComponent("content-audit.prompt.md"), atomically: true, encoding: .utf8)

    let preview = PromptFolderImportService.scanFolder(at: root)
    expect(preview.rows.count == 2, "import scan should include two markdown files")
    let phrase = preview.rows.compactMap(\.prompt).first { $0.type == .phrase }
    expect(phrase?.sourceType == "cheat-sheet", "cheat-sheet should normalize to phrase and preserve source type")
    expect(phrase?.primaryCategory == "coding", "phrase category should infer from top-level folder")
    expect(phrase?.subcategory == "agent-quality", "phrase subcategory should preserve folder/front matter")
    expect(phrase?.variables.map(\.key) == ["agent_context"], "variables should be detected in imported phrase")
    let contentPrompt = preview.rows.compactMap(\.prompt).first { $0.primaryCategory == "content" }
    expect(contentPrompt?.type == .prompt, "content prompt without front matter should infer prompt type")
    expect(contentPrompt?.subcategory == "general", "top-level content prompt should infer general subcategory")

    var prompts: [Prompt] = []
    var folders: [Folder] = []
    let batch = PromptFolderImportService.importRows(from: preview, into: &prompts, folders: &folders)
    expect(batch.importedCount == 2, "confirm import should import both rows")
    expect(batch.phraseCount == 1 && batch.promptCount == 1, "batch should count phrases and prompts")
    expect(folders.contains { $0.name == "Coding" && $0.parentFolderID == nil }, "import should create top-level source folder")
    expect(folders.contains { $0.name == "Agent Quality" && $0.parentFolderID != nil }, "import should create nested source folder")
    expect(prompts.first { $0.title == "Agent Wording Reference" }?.folderID != nil, "imported prompt should be assigned to source folder")
}

func testVariableFillingPresetsAndMetadataFilters() {
    var prompt = Prompt(title: "Variable", content: "Hello {{client_name}} and {project_goal}", type: .prompt, primaryCategory: "business", subcategory: "planning")
    prompt.updateContent(VariableDetector.normalizedContent(prompt.content))
    expect(prompt.content.contains("{client_name}"), "double braces should normalize")
    expect(prompt.content.contains("{project_goal}"), "single braces should remain supported")
    let values = ["client_name": "Prompt Manager", "project_goal": "Launch"]
    let filled = VariableDetector.filledPrompt(content: prompt.content, values: values)
    expect(filled.contains("Prompt Manager") && filled.contains("Launch"), "filled prompt should replace configured brace variables")
    prompt.savePreset(name: "Client", values: values)
    expect(prompt.variablePresets.first?.values["client_name"] == "Prompt Manager", "preset should store values per prompt")

    let phrase = Prompt(title: "Phrase", content: "Please preserve wording.", type: .phrase, primaryCategory: "coding", subcategory: "agent-quality")
    let visiblePhrases = LibraryFilterService.visiblePrompts([prompt, phrase], folders: [], selection: .all, searchQuery: "", sortMode: .az, section: .phrases, metadataFilters: MetadataFilterState(category: "coding"))
    expect(visiblePhrases.map(\.id) == [phrase.id], "phrases section should filter by category")
    let visiblePrompts = LibraryFilterService.visiblePrompts([prompt, phrase], folders: [], selection: .all, searchQuery: "business", sortMode: .az, section: .prompts)
    expect(visiblePrompts.map(\.id) == [prompt.id], "prompt search should include metadata")
    let visibleVariables = LibraryFilterService.visiblePrompts([prompt, phrase], folders: [], selection: .variablePrompts, searchQuery: "", sortMode: .az, section: .prompts)
    expect(visibleVariables.map(\.id) == [prompt.id], "variable prompts section should include prompts with detected variables")
}

func testExternalPromptLibraryFixtureIfPresent() {
    guard let fixturePath = ProcessInfo.processInfo.environment["PROMPT_LIBRARY_FIXTURE"],
          !fixturePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        print("SKIP external library fixture: set PROMPT_LIBRARY_FIXTURE to a prompt-library folder")
        return
    }
    let fixture = URL(fileURLWithPath: fixturePath, isDirectory: true)
    guard FileManager.default.fileExists(atPath: fixture.path) else {
        expect(false, "configured external prompt library fixture must exist")
        return
    }
    let preview = PromptFolderImportService.scanFolder(at: fixture)
    let prompts = preview.rows.compactMap(\.prompt)
    let categories = Set(prompts.map(\.primaryCategory))
    expect(categories.isSuperset(of: ["design", "coding", "content", "business"]), "external prompt library should preserve design/coding/content/business top-level categories")
    expect(prompts.contains { $0.type == .phrase && $0.sourceType == "cheat-sheet" }, "external prompt library should import cheat sheets as phrases")
    expect(preview.importableRows.count >= 50, "external prompt library should scan the real prompt files, excluding catalog files")
}


func testAppSettingsDefaultsAndReset() {
    let defaults = AppSettingsSnapshot.defaultValue
    expect(defaults.accentColor == .blue, "default accent should be blue")
    expect(defaults.fontScale == .standard, "default font scale should be standard")
    expect(defaults.buttonStyle == .filled, "default button style should be filled")
    expect(defaults.buttonTextWeight == .semibold, "default button weight should be semibold")
    expect(defaults.promptList == .defaultValue, "default prompt list display settings should match defaults")
    expect(defaults.rightSidebarSections == .defaultValue, "default sidebar section visibility should match defaults")

    var customized = defaults
    customized.accentColor = .purple
    customized.fontScale = .large
    customized.buttonStyle = .outline
    customized.buttonTextWeight = .regular
    customized.promptList = PromptListDisplaySettings(showIcons: false, showDescription: false, showMetadata: false, previewLineCount: 9, truncateLongTitles: false, rowDensity: .compact)
    customized.rightSidebarSections = RightSidebarSectionVisibility(folder: false, promptMetadata: true, notes: true, metadata: false)
    customized.leftSidebarVisible = false
    customized.rightSidebarVisible = false
    customized.promptListWidth = 520
    customized.detailsSidebarWidth = 400
    customized.resizablePanelsEnabled = false

    expect(customized.promptList.previewLineCount == 3, "prompt preview line count should clamp to the supported maximum")
    expect(customized.resettingPromptList().promptList == .defaultValue, "prompt list reset should restore display defaults")
    expect(customized.resettingRightSidebarSections().rightSidebarSections == .defaultValue, "right sidebar reset should restore section defaults")
    let resetLayout = customized.resettingLayout()
    expect(resetLayout.leftSidebarVisible && resetLayout.rightSidebarVisible, "layout reset should restore sidebars")
    expect(resetLayout.promptListWidth == AppSettingsDefaults.promptListWidth, "layout reset should restore prompt list width")
    expect(resetLayout.detailsSidebarWidth == AppSettingsDefaults.detailsSidebarWidth, "layout reset should restore details width")
    expect(resetLayout.resizablePanelsEnabled, "layout reset should restore resizable panels")
    let resetAppearance = customized.resettingAppearance()
    expect(resetAppearance.accentColor == .blue && resetAppearance.fontScale == .standard && resetAppearance.buttonStyle == .filled && resetAppearance.buttonTextWeight == .semibold, "appearance reset should restore appearance defaults")

    let keys = AppSettingsKeys.allKeys
    expect(keys.count > 80, "settings should expose keys for all settings tabs")
    expect(Set(keys).count == keys.count, "settings storage keys should be unique")
}

func testExportAndAudit() throws {
    let prompt = Prompt(title: "Export Me", content: "Body {thing}", type: .prompt, primaryCategory: "design", subcategory: "wireframes", whenToUse: "Use for export tests.", searchTerms: ["export"], variables: [VariableDefinition(key: "thing")])
    let markdown = PromptExportService.markdownDocument(for: prompt)
    expect(markdown.contains("primary_category: design"), "markdown export should include metadata")
    expect(markdown.contains("variables:"), "markdown export should include variables")
    let report = PromptExportService.auditReport(for: [prompt])
    expect(report.contains("Export Me") && report.contains("Complete"), "audit report should include prompt status")
    _ = try PromptExportService.backupData(library: PromptLibrary(prompts: [prompt]))
}


func testChainModelsPersistenceAndExecution() async throws {
    let prompt = Prompt(title: "Audit Prompt", content: "Audit {html_file} for {target_score}", variables: [
        VariableDefinition(key: "html_file", label: "HTML File", type: .textarea, sortOrder: 0),
        VariableDefinition(key: "target_score", label: "Target Score", type: .number, sortOrder: 1)
    ])
    let attachment = ChainFileAttachment(fileName: "landing-page.html", fileExtension: "html", byteCount: 42, snapshotText: "<main>Landing</main>")
    expect(attachment.isSupportedTextAttachment, "HTML attachments should be accepted as validated text input")
    let step = PromptChainStep(promptID: prompt.id, title: prompt.title, variableBindings: [
        ChainVariableBinding(variableKey: "html_file", inputType: .file, fileAttachment: attachment),
        ChainVariableBinding(variableKey: "target_score", inputType: .text, textValue: "9.5")
    ], providerKind: .openAI, modelID: "GPT-4.1")
    let chain = PromptChain(title: "HTML Quality Iteration Chain", steps: [step], defaultProviderKind: .openAI, defaultModelID: "GPT-4.1")
    let library = PromptLibrary(prompts: [prompt], chains: [chain], aiProviders: AIProviderConfiguration.defaults)
    let data = try JSONEncoder.iso8601Pretty.encode(library)
    let json = String(decoding: data, as: UTF8.self)
    expect(json.contains("chains"), "library JSON should include persisted chain definitions")
    expect(!json.lowercased().contains("api_key"), "library JSON should not include raw API key fields")
    let decoded = try JSONDecoder.iso8601.decode(PromptLibrary.self, from: data)
    expect(decoded.chains.first?.title == "HTML Quality Iteration Chain", "chain should round-trip through PromptLibrary")

    let service = ChainExecutionService(client: DeterministicChainProviderClient())
    let run = try await service.run(step: step, prompt: prompt, previousOutputs: [:])
    expect(run.status == .complete, "deterministic chain runner should complete")
    expect(run.resolvedPrompt == "Audit <main>Landing</main> for 9.5", "chain runner should inject file and text values exactly at their variable token positions")

    let suffixPrompt = Prompt(title: "Suffix", content: "Instructions first.\n\nHere is the file:\n{markdown}", variables: [VariableDefinition(key: "markdown", sortOrder: 0)])
    let suffixAttachment = ChainFileAttachment(fileName: "markdown1.md", fileExtension: "md", byteCount: 12, snapshotText: "# Markdown One")
    let suffixStep = PromptChainStep(promptID: suffixPrompt.id, title: suffixPrompt.title, variableBindings: [ChainVariableBinding(variableKey: "markdown", inputType: .file, fileAttachment: suffixAttachment)])
    let resolved = try service.resolve(step: suffixStep, prompt: suffixPrompt, previousOutputs: [:]).0
    expect(resolved == "Instructions first.\n\nHere is the file:\n# Markdown One", "file variables at the bottom should append the file exactly where the token appears")
    expect(ChainOutputStore.responseFileName(for: suffixAttachment, step: suffixStep) == "step-01-markdown1_response.md", "response output file should be based on the step number and attached file name")
}

@MainActor
func testAppViewModelChainWorkflow() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let prompt = Prompt(title: "Rewrite", content: "Rewrite {input}", variables: [VariableDefinition(key: "input")])
    try store.save(PromptLibrary(prompts: [prompt], folders: []))
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: DeterministicChainProviderClient()))
    model.createChainDraft()
    expect(model.librarySection == .chains, "new chain action should switch to chained prompts mode")
    guard let chain = model.selectedChain, let step = chain.steps.first else { fputs("❌ chain draft should have an initial step\n", stderr); exit(1) }
    expect(chain.isDraft, "new chain should start as an in-memory draft")
    model.updateStepPrompt(chainID: chain.id, stepID: step.id, promptID: prompt.id)
    guard let chainBinding = model.bindingForSelectedChain() else {
        fputs("❌ selected chain should be bindable for rename\n", stderr)
        exit(1)
    }
    var renamedChain = chainBinding.wrappedValue
    renamedChain.title = "Homepage Rewrite Chain"
    chainBinding.wrappedValue = renamedChain
    guard var updatedStep = model.selectedChain?.steps.first else { fputs("❌ updated chain step missing\n", stderr); exit(1) }
    updatedStep.variableBindings = [ChainVariableBinding(variableKey: "input", inputType: .text, textValue: "homepage copy")]
    model.updateBinding(chainID: chain.id, stepID: updatedStep.id, binding: updatedStep.variableBindings[0])
    model.saveSelectedChain()
    expect(!(model.selectedChain?.isDraft ?? true), "saving a selected chain should persist it")
    let saved = try store.load()
    expect(saved.chains.count == 1, "saved chain should be written to library JSON")
    expect(saved.chains.first?.title == "Homepage Rewrite Chain", "saved chain should persist the edited chain name")
    await model.runStep(updatedStep.id)
    expect(model.chainRuns.first?.status == .complete, "running a step should create a completed run")
    expect(model.selectedChain?.steps.first?.status == .complete, "running a step should update step status")
}

@MainActor
func testChainFileRunSavesDeterministicResponsePromptAndFile() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let prompt = Prompt(title: "Variable Prompt", content: "Improve this file in one shot.\n\n{markdown}", variables: [VariableDefinition(key: "markdown")])
    let chainID = UUID()
    let stepID = UUID()
    let attachment = ChainFileAttachment(fileName: "markdown1.md", fileExtension: "md", byteCount: 13, snapshotText: "# Old content")
    let step = PromptChainStep(id: stepID, promptID: prompt.id, title: prompt.title, variableBindings: [ChainVariableBinding(variableKey: "markdown", inputType: .file, fileAttachment: attachment)], outputPolicy: .saveMarkdown, providerKind: .openAI, modelID: "gpt-4o", finalOutputTag: "final-file")
    let chain = PromptChain(id: chainID, title: "Quality Chain", steps: [step])
    try store.save(PromptLibrary(prompts: [prompt], folders: [], chains: [chain]))
    let outputRoot = directory.appendingPathComponent("outputs", isDirectory: true)
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: TaggedMarkdownProviderClient()))
    model.chainOutputStore = ChainOutputStore(rootURL: outputRoot)
    model.load()
    model.selectedChainID = chainID
    await model.runStep(stepID)
    let expectedURL = outputRoot.appendingPathComponent("chain_1", isDirectory: true).appendingPathComponent("final-file.md")
    expect(FileManager.default.fileExists(atPath: expectedURL.path), "chain file run should save tagged final markdown as the tag-name file")
    let savedText = try String(contentsOf: expectedURL, encoding: .utf8)
    expect(savedText == "# Final Markdown\n\nOnly this section should be downloadable.", "response file should contain only the tagged final markdown, not assessment text")
    expect(model.prompts.contains { $0.title == "final-file.md" && $0.sourceFilePath == expectedURL.path && $0.sourceType == "chain-output" && !$0.content.contains("Assessment") }, "chain response should be upserted as final markdown only for history/discovery")
    let loaded = try store.load()
    expect(loaded.prompts.contains { $0.title == "final-file.md" && $0.sourceFilePath == expectedURL.path }, "chain response prompt should be automatically persisted")
}

struct TaggedMarkdownProviderClient: ChainProviderClient {
    func complete(prompt: String, provider: AIProviderKind, modelID: String) async throws -> String {
        expect(!prompt.contains("<final-file>") && !prompt.contains("</final-file>"), "chain provider prompt should not inject wrapper instructions; tags come from the saved prompt text only")
        return """
        Assessment: this page needs changes.

        <final-file>
        # Final Markdown

        Only this section should be downloadable.
        </final-file>

        Final score: 9.8/10
        """
    }
}

struct CustomTaggedMarkdownProviderClient: ChainProviderClient {
    func complete(prompt: String, provider: AIProviderKind, modelID: String) async throws -> String {
        expect(!prompt.contains("<final-file>") && !prompt.contains("</final-file>"), "custom tags should come from user prompt instructions, not code-injected provider contracts")
        return "notes\n<final-file>\n# Custom Final\n</final-file>\nscore"
    }
}

actor FreshLoopCallRecorder {
    private var activeCallCount = 0
    private var maxConcurrentCallCount = 0
    private var recordedPrompts: [String] = []

    func begin(prompt: String) -> Int {
        activeCallCount += 1
        maxConcurrentCallCount = max(maxConcurrentCallCount, activeCallCount)
        recordedPrompts.append(prompt)
        return recordedPrompts.count
    }

    func end() {
        activeCallCount = max(0, activeCallCount - 1)
    }

    func snapshot() -> (prompts: [String], maxConcurrent: Int) {
        (recordedPrompts, maxConcurrentCallCount)
    }
}

struct RecordingFreshLoopProviderClient: ChainProviderClient {
    let recorder: FreshLoopCallRecorder

    func complete(prompt: String, provider: AIProviderKind, modelID: String) async throws -> String {
        let callNumber = await recorder.begin(prompt: prompt)
        do {
            try await Task.sleep(nanoseconds: 5_000_000)
            await recorder.end()
            return "fresh-call-\(callNumber)\n\(prompt)"
        } catch {
            await recorder.end()
            throw error
        }
    }
}

struct RecordingLoopFeedbackProviderClient: ChainProviderClient {
    let recorder: FreshLoopCallRecorder

    func complete(prompt: String, provider: AIProviderKind, modelID: String) async throws -> String {
        let callNumber = await recorder.begin(prompt: prompt)
        await recorder.end()
        if prompt.hasPrefix("REVIEW") {
            return "STEP2_FEEDBACK_\(callNumber)\n\(prompt)"
        }
        return "STEP1_OUTPUT_\(callNumber)\n\(prompt)"
    }
}

actor SequenceProviderRecorder {
    private var outputs: [String]
    private var prompts: [String] = []

    init(outputs: [String]) {
        self.outputs = outputs
    }

    func next(prompt: String) -> String {
        prompts.append(prompt)
        if outputs.isEmpty { return "fallback-output" }
        return outputs.removeFirst()
    }

    func snapshot() -> [String] { prompts }
}

struct SequenceProviderClient: ChainProviderClient {
    let recorder: SequenceProviderRecorder

    func complete(prompt: String, provider: AIProviderKind, modelID: String) async throws -> String {
        await recorder.next(prompt: prompt)
    }
}

@MainActor
func testCustomFinalTagSavesTagNamedMarkdownAndFeedsNextStep() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let firstPrompt = Prompt(title: "Make File", content: "Make final file")
    let secondPrompt = Prompt(title: "Use File", content: "Use this:\n{markdown}", variables: [VariableDefinition(key: "markdown")])
    let firstStepID = UUID()
    let secondStepID = UUID()
    let firstStep = PromptChainStep(id: firstStepID, promptID: firstPrompt.id, title: firstPrompt.title, sortOrder: 0, outputPolicy: .saveMarkdown, providerKind: .openAI, modelID: "gpt-4o", finalOutputTag: "final-file")
    let secondStep = PromptChainStep(id: secondStepID, promptID: secondPrompt.id, title: secondPrompt.title, sortOrder: 1, variableBindings: [ChainVariableBinding(variableKey: "markdown", inputType: .previousStepOutput, sourceStepID: firstStepID, sourceOutputTag: "final-file")], outputPolicy: .viewOnly)
    let chain = PromptChain(title: "Custom Tag Chain", steps: [firstStep, secondStep])
    try store.save(PromptLibrary(prompts: [firstPrompt, secondPrompt], folders: [], chains: [chain]))
    let outputRoot = directory.appendingPathComponent("outputs", isDirectory: true)
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: CustomTaggedMarkdownProviderClient()))
    model.chainOutputStore = ChainOutputStore(rootURL: outputRoot)
    model.load()
    model.selectedChainID = model.chains.first?.id
    await model.runStep(firstStepID)

    let expectedURL = outputRoot.appendingPathComponent("chain_1", isDirectory: true).appendingPathComponent("final-file.md")
    expect(FileManager.default.fileExists(atPath: expectedURL.path), "custom tagged output should save as final-file.md")
    let savedCustomText = try String(contentsOf: expectedURL, encoding: .utf8)
    expect(savedCustomText == "# Custom Final", "custom tagged output file should contain only the tag contents")
    let resolvedSecond = try model.chainExecutionService.resolve(step: model.chains[0].steps[1], prompt: secondPrompt, previousOutputs: model.previousOutputs(for: model.chains[0], before: model.chains[0].steps[1])).0
    expect(resolvedSecond == "Use this:\n# Custom Final", "next step should inject the selected custom tag content from the previous step")
}

@MainActor
func testChainCustomStatusesAndMonitorStopBeforeNextStep() async throws {
    expect(ChainCustomStatusSettings.decode("").contains("Success"), "custom status defaults should include Success")
    expect(ChainCustomStatusSettings.decode("").contains("Stopped"), "custom status defaults should include Stopped")
    expect(ChainOutputMonitorRule(phrase: "9.7", statusLabel: "Success").matches(output: "Score: 9.7", stepID: UUID()), "exact matching should find the configured phrase")
    expect(!ChainOutputMonitorRule(phrase: "Score", statusLabel: "Success").matches(output: "score", stepID: UUID()), "matching should be exact and case-sensitive")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let firstPrompt = Prompt(title: "Rate", content: "Rate")
    let secondPrompt = Prompt(title: "Fix", content: "Fix")
    let firstStepID = UUID()
    let secondStepID = UUID()
    let rule = ChainOutputMonitorRule(phrase: "9.7", statusLabel: "Success")
    let firstStep = PromptChainStep(id: firstStepID, promptID: firstPrompt.id, title: firstPrompt.title, sortOrder: 0)
    let secondStep = PromptChainStep(id: secondStepID, promptID: secondPrompt.id, title: secondPrompt.title, sortOrder: 1)
    let chain = PromptChain(title: "Monitor Chain", steps: [firstStep, secondStep], monitorRules: [rule])
    try store.save(PromptLibrary(prompts: [firstPrompt, secondPrompt], folders: [], chains: [chain]))

    let recorder = SequenceProviderRecorder(outputs: ["Overall rating: 9.7/10", "should-not-run"])
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: SequenceProviderClient(recorder: recorder)))
    model.load()
    model.selectedChainID = model.chains.first?.id
    await model.runSelectedChain()

    let prompts = await recorder.snapshot()
    expect(prompts.count == 1, "matching monitor rule should stop before the next chain step")
    expect(model.selectedChain?.lastMonitorStatusLabel == "Success", "chain should persist the selected custom status when the rule matches")
    expect(model.selectedChain?.steps.first?.monitorStatusLabel == "Success", "matched step should display the custom monitor status")
    expect(model.selectedChain?.steps.dropFirst().first?.status == .notRun, "next step should remain not run after monitor stop")
    expect(model.chainRuns.first?.monitorStatusLabel == "Success", "run history should store monitor custom status")

    let reloaded = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: SequenceProviderClient(recorder: recorder)))
    reloaded.load()
    expect(reloaded.chains.first?.monitorRules.first?.phrase == "9.7", "monitor rule phrase should persist after reload")
    expect(reloaded.chains.first?.lastMonitorStatusLabel == "Success", "matched custom status should persist after reload")
}

@MainActor
func testLoopMonitorStopStopsBeforeNextIteration() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let firstPrompt = Prompt(title: "Fix", content: "Fix")
    let secondPrompt = Prompt(title: "Rate", content: "Rate")
    let firstStepID = UUID()
    let secondStepID = UUID()
    let firstStep = PromptChainStep(id: firstStepID, promptID: firstPrompt.id, title: firstPrompt.title, sortOrder: 0)
    let secondStep = PromptChainStep(id: secondStepID, promptID: secondPrompt.id, title: secondPrompt.title, sortOrder: 1)
    let rule = ChainOutputMonitorRule(phrase: "9.7", statusLabel: "Stopped", stepScope: .specificStep, stepID: secondStepID)
    let chain = PromptChain(title: "Loop Monitor Chain", steps: [firstStep, secondStep], loopStartStepID: firstStepID, loopEndStepID: secondStepID, loopCount: 3, monitorRules: [rule])
    try store.save(PromptLibrary(prompts: [firstPrompt, secondPrompt], folders: [], chains: [chain]))

    let recorder = SequenceProviderRecorder(outputs: ["fixed page", "Overall rating: 9.7/10", "should-not-loop"])
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: SequenceProviderClient(recorder: recorder)))
    model.load()
    model.selectedChainID = model.chains.first?.id
    await model.runSelectedLoop()

    let prompts = await recorder.snapshot()
    expect(prompts.count == 2, "matching loop monitor rule should stop before the next loop iteration starts")
    expect(model.selectedChain?.lastLoopRunCount == 1, "monitor stop should record the loop iteration that stopped")
    expect(model.selectedChain?.totalLoopRunCount == 1, "monitor stop should count as one loop run for metrics")
    expect(model.selectedChain?.lastMonitorStatusLabel == "Stopped", "loop monitor should persist the selected custom status")
    expect(model.selectedChain?.steps.dropFirst().first?.monitorStatusLabel == "Stopped", "matching loop step should show the custom status")
}

@MainActor
func testRunLoopUsesFreshSequentialProviderCallForEveryStep() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let firstPrompt = Prompt(title: "Generate Number", content: "Generate a new number")
    let secondPrompt = Prompt(title: "Use Number", content: "Use latest output:\n{prior}", variables: [VariableDefinition(key: "prior")])
    let firstStepID = UUID()
    let secondStepID = UUID()
    let firstStep = PromptChainStep(id: firstStepID, promptID: firstPrompt.id, title: firstPrompt.title, sortOrder: 0)
    let secondStep = PromptChainStep(id: secondStepID, promptID: secondPrompt.id, title: secondPrompt.title, sortOrder: 1, variableBindings: [ChainVariableBinding(variableKey: "prior", inputType: .previousStepOutput, sourceStepID: firstStepID)])
    let chain = PromptChain(title: "Fresh Loop Chain", steps: [firstStep, secondStep], loopStartStepID: firstStepID, loopEndStepID: secondStepID, loopCount: 3)
    try store.save(PromptLibrary(prompts: [firstPrompt, secondPrompt], folders: [], chains: [chain]))

    let recorder = FreshLoopCallRecorder()
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: RecordingFreshLoopProviderClient(recorder: recorder)))
    model.load()
    model.selectedChainID = model.chains.first?.id
    await model.runSelectedLoop()

    let snapshot = await recorder.snapshot()
    expect(snapshot.prompts.count == 6, "three two-step loop iterations should create six separate provider calls")
    expect(snapshot.maxConcurrent == 1, "loop step provider calls must be awaited sequentially, not overlapped or linked")
    expect(snapshot.prompts[0] == "Generate a new number", "first loop call should start from step 1")
    expect(snapshot.prompts[1].contains("fresh-call-1"), "step 2 in iteration 1 should receive the fresh output from step 1")
    expect(snapshot.prompts[2] == "Generate a new number", "iteration 2 should start a fresh step 1 provider call")
    expect(snapshot.prompts[3].contains("fresh-call-3") && !snapshot.prompts[3].contains("fresh-call-1"), "iteration 2 step 2 should use the latest step 1 output, not a stale previous iteration output")
    expect(snapshot.prompts[5].contains("fresh-call-5") && !snapshot.prompts[5].contains("fresh-call-3"), "iteration 3 step 2 should use the newest step 1 output")
    expect(model.selectedChain?.lastLoopRunCount == 3, "loop should record the completed loop count")
}

@MainActor
func testLoopFeedbackFileUsesInitialFileThenSavedOutputAndFeedback() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let firstPrompt = Prompt(title: "Fix Page", content: "FIX\n{markdown}", variables: [VariableDefinition(key: "markdown")])
    let secondPrompt = Prompt(title: "Review Page", content: "REVIEW\n{work}", variables: [VariableDefinition(key: "work")])
    let firstStepID = UUID()
    let secondStepID = UUID()
    let outputURL = directory.appendingPathComponent("fixed.md")
    let originalURL = directory.appendingPathComponent("page.md")
    try "# Original from disk\n".write(to: originalURL, atomically: true, encoding: .utf8)
    let attachment = ChainFileAttachment(fileName: "page.md", fileExtension: "md", byteCount: 10, originalPath: originalURL.path, snapshotText: "# Stale Snapshot\n")
    let updatedAttachment = ChainFileAttachment(fileName: "fixed.md", fileExtension: "md", byteCount: 0, originalPath: outputURL.path, snapshotText: "")
    let firstBinding = ChainVariableBinding(variableKey: "markdown", inputType: .loopFeedbackFile, fileAttachment: attachment, sourceStepID: secondStepID)
    let secondBinding = ChainVariableBinding(variableKey: "work", inputType: .file, fileAttachment: updatedAttachment)
    let firstStep = PromptChainStep(id: firstStepID, promptID: firstPrompt.id, title: firstPrompt.title, sortOrder: 0, variableBindings: [firstBinding], outputPolicy: .saveMarkdown, customOutputFilePath: outputURL.path, overwriteOutputFile: true)
    let secondStep = PromptChainStep(id: secondStepID, promptID: secondPrompt.id, title: secondPrompt.title, sortOrder: 1, variableBindings: [secondBinding], outputPolicy: .viewOnly)
    let chain = PromptChain(title: "Feedback Loop Chain", steps: [firstStep, secondStep], loopStartStepID: firstStepID, loopEndStepID: secondStepID, loopCount: 2)
    try store.save(PromptLibrary(prompts: [firstPrompt, secondPrompt], folders: [], chains: [chain]))

    let recorder = FreshLoopCallRecorder()
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: RecordingLoopFeedbackProviderClient(recorder: recorder)))
    model.load()
    model.selectedChainID = model.chains.first?.id
    await model.runSelectedLoop()

    let snapshot = await recorder.snapshot()
    expect(snapshot.prompts.count == 4, "two two-step loop iterations should create four fresh provider calls")
    expect(snapshot.maxConcurrent == 1, "loop feedback calls must stay sequential")
    expect(snapshot.prompts[0] == "FIX\n# Original from disk", "first loop pass should read only the original attached file from disk")
    expect(!snapshot.prompts[0].contains("Stale Snapshot"), "file variables should refresh from their original path instead of using stale stored snapshots")
    expect(!snapshot.prompts[0].contains("STEP2_FEEDBACK"), "first loop pass should not use stale feedback from old runs")
    expect(snapshot.prompts[1].contains("STEP1_OUTPUT_1"), "review step should receive the first step output")
    expect(snapshot.prompts[1].hasPrefix("REVIEW\nSTEP1_OUTPUT_1"), "review step should read the saved step 1 Markdown file path as its file input")
    expect(!snapshot.prompts[1].contains("## Current saved output"), "review step file input should be the saved file contents, not a loop feedback wrapper")
    expect(snapshot.prompts[2].contains("## Original input file"), "later first-step passes should include the original input file section again")
    expect(snapshot.prompts[2].contains("# Original from disk"), "later first-step passes should reread the original input file")
    expect(snapshot.prompts[2].contains("## Current saved output"), "later first-step passes should include the latest saved output section")
    expect(snapshot.prompts[2].contains("STEP1_OUTPUT_1"), "later first-step passes should read the saved output from the previous first-step run")
    expect(snapshot.prompts[2].contains("## Feedback from loop step"), "later first-step passes should include a feedback section")
    expect(snapshot.prompts[2].contains("STEP2_FEEDBACK_2"), "later first-step passes should include the selected later step feedback")
    expect(snapshot.prompts[3].contains("STEP1_OUTPUT_3"), "final review should use the newest fixed output from the current loop pass")
    let savedText = try String(contentsOf: outputURL, encoding: .utf8)
    expect(savedText.contains("STEP1_OUTPUT_3"), "step 1 output file should be overwritten with the newest fixed output")
    expect(!savedText.hasPrefix("STEP1_OUTPUT_1"), "overwritten output file should not be the stale first-pass output")
}

@MainActor
func testChainOutputFilenameSettingsAndCustomOverwrite() async throws {
    let oldPrefix = UserDefaults.standard.object(forKey: AppSettingsKeys.storageChainOutputIncludeStepPrefix)
    let oldSuffixEnabled = UserDefaults.standard.object(forKey: AppSettingsKeys.storageChainOutputIncludeSuffix)
    let oldSuffix = UserDefaults.standard.object(forKey: AppSettingsKeys.storageChainOutputSuffix)
    defer {
        restoreUserDefault(oldPrefix, forKey: AppSettingsKeys.storageChainOutputIncludeStepPrefix)
        restoreUserDefault(oldSuffixEnabled, forKey: AppSettingsKeys.storageChainOutputIncludeSuffix)
        restoreUserDefault(oldSuffix, forKey: AppSettingsKeys.storageChainOutputSuffix)
    }
    let attachment = ChainFileAttachment(fileName: "brief.md", fileExtension: "md", byteCount: 1, snapshotText: "x")
    let step = PromptChainStep(title: "File Step", sortOrder: 1)
    UserDefaults.standard.set(false, forKey: AppSettingsKeys.storageChainOutputIncludeStepPrefix)
    UserDefaults.standard.set(true, forKey: AppSettingsKeys.storageChainOutputIncludeSuffix)
    UserDefaults.standard.set("fixed", forKey: AppSettingsKeys.storageChainOutputSuffix)
    expect(ChainOutputStore.responseFileName(for: attachment, step: step) == "brief_fixed.md", "filename settings should allow removing step prefix and customizing suffix")
    UserDefaults.standard.set(false, forKey: AppSettingsKeys.storageChainOutputIncludeSuffix)
    expect(ChainOutputStore.responseFileName(for: attachment, step: step) == "brief.md", "filename settings should allow removing suffix entirely")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ChainOutputStore(rootURL: directory)
    let chain = PromptChain(sequenceID: 1, title: "Overwrite")
    var customStep = PromptChainStep(title: "Custom", customOutputFileName: "chosen.md", overwriteOutputFile: false)
    let first = try store.saveStepMarkdown("one", chain: chain, step: customStep, sourceAttachment: nil)
    let second = try store.saveStepMarkdown("two", chain: chain, step: customStep, sourceAttachment: nil)
    expect(first.lastPathComponent == "chosen.md" && second.lastPathComponent == "chosen-2.md", "custom file names should avoid overwriting when overwrite is off")
    customStep.overwriteOutputFile = true
    let third = try store.saveStepMarkdown("three", chain: chain, step: customStep, sourceAttachment: nil)
    expect(third.lastPathComponent == "chosen.md", "custom file names should overwrite when overwrite is on")
    let overwritten = try String(contentsOf: third, encoding: .utf8)
    expect(overwritten == "three", "overwrite should replace matching custom filename contents")

    let externalFolder = directory.appendingPathComponent("external-drive", isDirectory: true)
    let externalURL = externalFolder.appendingPathComponent("picked-output.md")
    let pathStep = PromptChainStep(title: "Picked", customOutputFileName: "picked-output.md", customOutputFilePath: externalURL.path, overwriteOutputFile: true)
    let savedExternal = try store.saveStepMarkdown("external", chain: chain, step: pathStep, sourceAttachment: nil)
    expect(savedExternal.path == externalURL.path, "explicit per-step output file path should override the chain/default output folder")
    let externalText = try String(contentsOf: externalURL, encoding: .utf8)
    expect(externalText == "external", "explicit per-step output file should be written at the selected path")
}

struct SlowCancellableChainProviderClient: ChainProviderClient {
    func complete(prompt: String, provider: AIProviderKind, modelID: String) async throws -> String {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        return "Should not complete after cancellation"
    }
}

@MainActor
func testRunningChainStepCanBeStopped() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let prompt = Prompt(title: "Slow Prompt", content: "Wait and answer")
    let stepID = UUID()
    let chainID = UUID()
    let step = PromptChainStep(id: stepID, promptID: prompt.id, title: prompt.title, sortOrder: 0)
    let chain = PromptChain(id: chainID, title: "Stop Test", steps: [step])
    try store.save(PromptLibrary(prompts: [prompt], folders: [], chains: [chain]))

    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: SlowCancellableChainProviderClient()))
    model.load()
    model.selectedChainID = chainID
    model.startRunStep(stepID)
    try await Task.sleep(nanoseconds: 80_000_000)
    expect(model.chains.first?.steps.first?.status == .running, "step should enter running status before it is stopped")
    model.cancelStepRun(stepID)
    try await Task.sleep(nanoseconds: 80_000_000)
    expect(model.chains.first?.steps.first?.status == .cancelled, "stopping a running step should mark it cancelled")
    expect(model.latestStepRun(for: stepID)?.status == .cancelled, "stopping a running step should create a cancelled run record")
    expect(model.saveStatus == "Step stopped", "stopping a running step should show stopped feedback")
}

@MainActor
func testSaveSelectedChainPersistsLatestTaggedOutput() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let prompt = Prompt(title: "Variable Prompt", content: "Fix {markdown}", variables: [VariableDefinition(key: "markdown")])
    let chainID = UUID()
    let stepID = UUID()
    let attachment = ChainFileAttachment(fileName: "manual.md", fileExtension: "md", byteCount: 10, snapshotText: "# Input")
    let step = PromptChainStep(id: stepID, promptID: prompt.id, title: prompt.title, variableBindings: [ChainVariableBinding(variableKey: "markdown", inputType: .file, fileAttachment: attachment)], outputPolicy: .saveMarkdown, finalOutputTag: "final-file")
    let chain = PromptChain(id: chainID, title: "Manual Save Chain", steps: [step])
    try store.save(PromptLibrary(prompts: [prompt], folders: [], chains: [chain]))
    let outputRoot = directory.appendingPathComponent("outputs", isDirectory: true)
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: DeterministicChainProviderClient()))
    model.chainOutputStore = ChainOutputStore(rootURL: outputRoot)
    model.load()
    model.selectedChainID = chainID
    model.selectedChainStepID = stepID
    var run = ChainRun(chainID: chainID, status: .complete)
    run.stepRuns = [ChainStepRun(stepID: stepID, resolvedPrompt: "Fix # Input", providerKind: .openAI, modelID: "gpt-4o", inputSnapshot: [:], fileSnapshots: [attachment], outputText: "Notes before\n<final-file>\n# Manual Final\n</final-file>\nNotes after", status: .complete)]
    model.chainRuns = [run]
    let export = try model.markdownExportForStep(stepID)
    expect(export.text == "# Manual Final", "Markdown export should expose only the tagged final output text")
    expect(export.suggestedFileName == "final-file.md", "Markdown export should suggest the tagged final markdown filename")
    model.saveSelectedChain()

    let expectedURL = outputRoot.appendingPathComponent("chain_1", isDirectory: true).appendingPathComponent("final-file.md")
    let savedText = try String(contentsOf: expectedURL, encoding: .utf8)
    expect(savedText == "# Manual Final", "Save Chain should persist the latest selected step final tagged markdown")
    expect(model.saveStatus.hasPrefix("Saved"), "manual chain save should show saved feedback")
}

@MainActor
func testSaveStepMarkdownButtonSavesResolvedPromptWithoutOutput() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let prompt = Prompt(title: "Prompt Save", content: "Please fix {markdown}", variables: [VariableDefinition(key: "markdown")])
    let chainID = UUID()
    let stepID = UUID()
    let attachment = ChainFileAttachment(fileName: "source.md", fileExtension: "md", byteCount: 7, snapshotText: "# Input")
    let step = PromptChainStep(id: stepID, promptID: prompt.id, title: prompt.title, variableBindings: [ChainVariableBinding(variableKey: "markdown", inputType: .file, fileAttachment: attachment)], outputPolicy: .saveMarkdown, finalOutputTag: "final-file")
    let chain = PromptChain(id: chainID, title: "Save Prompt Chain", steps: [step])
    try store.save(PromptLibrary(prompts: [prompt], folders: [], chains: [chain]))
    let outputRoot = directory.appendingPathComponent("outputs", isDirectory: true)
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: DeterministicChainProviderClient()))
    model.chainOutputStore = ChainOutputStore(rootURL: outputRoot)
    model.load()
    model.selectedChainID = chainID

    model.saveStepMarkdown(stepID)

    let export = try model.markdownExportForStep(stepID)
    expect(export.text.contains("Please fix # Input"), "Markdown export should expose the resolved chained prompt when no output exists yet")
    expect(export.suggestedFileName == "step-01-source_response.md", "Markdown export should suggest a step-prefixed markdown filename")
    let expectedURL = outputRoot.appendingPathComponent("chain_1", isDirectory: true).appendingPathComponent("step-01-source_response.md")
    let saved = try String(contentsOf: expectedURL, encoding: .utf8)
    expect(saved.contains("Please fix # Input"), "Save Markdown button should save the resolved chained prompt when no output exists yet")
    expect(model.saveStatus.hasPrefix("Saved"), "Save Markdown button should show saved feedback")
}

@MainActor
func testAutomaticChainMarkdownOutputsUseChainIDStepPrefixesAndOverwriteAcrossMultipleChains() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let answerPrompt = Prompt(title: "Answer", content: "Return answer for {topic}", variables: [VariableDefinition(key: "topic")])
    let nextPrompt = Prompt(title: "Use Previous", content: "Use prior output: {prior}", variables: [VariableDefinition(key: "prior")])
    let filePrompt = Prompt(title: "File Output", content: "Summarize file:\n{markdown}", variables: [VariableDefinition(key: "markdown")])
    let chainAID = UUID()
    let chainBID = UUID()
    let stepA1ID = UUID()
    let stepA2ID = UUID()
    let stepB1ID = UUID()
    let stepA1 = PromptChainStep(id: stepA1ID, promptID: answerPrompt.id, title: answerPrompt.title, sortOrder: 0, variableBindings: [ChainVariableBinding(variableKey: "topic", inputType: .text, textValue: "first run")], outputPolicy: .saveMarkdown)
    let stepA2 = PromptChainStep(id: stepA2ID, promptID: nextPrompt.id, title: nextPrompt.title, sortOrder: 1, variableBindings: [ChainVariableBinding(variableKey: "prior", inputType: .previousStepOutput, sourceStepID: stepA1ID)], outputPolicy: .saveMarkdown)
    let attachment = ChainFileAttachment(fileName: "brief.md", fileExtension: "md", byteCount: 12, snapshotText: "# Brief")
    let stepB1 = PromptChainStep(id: stepB1ID, promptID: filePrompt.id, title: filePrompt.title, sortOrder: 0, variableBindings: [ChainVariableBinding(variableKey: "markdown", inputType: .file, fileAttachment: attachment)], outputPolicy: .saveMarkdown)
    let chainA = PromptChain(id: chainAID, title: "Answer Chain", steps: [stepA1, stepA2])
    let chainB = PromptChain(id: chainBID, title: "File Chain", steps: [stepB1])
    try store.save(PromptLibrary(prompts: [answerPrompt, nextPrompt, filePrompt], folders: [], chains: [chainA, chainB]))

    let outputRoot = directory.appendingPathComponent("outputs", isDirectory: true)
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: DeterministicChainProviderClient()))
    model.chainOutputStore = ChainOutputStore(rootURL: outputRoot)
    model.load()

    model.selectedChainID = chainAID
    await model.runSelectedChain()
    let chainAFolder = outputRoot.appendingPathComponent("chain_1", isDirectory: true)
    let stepA1URL = chainAFolder.appendingPathComponent("step-01-answer_response.md")
    let stepA2URL = chainAFolder.appendingPathComponent("step-02-use-previous_response.md")
    expect(FileManager.default.fileExists(atPath: stepA1URL.path), "chain A step 1 should auto-save into the chain_1 folder")
    expect(FileManager.default.fileExists(atPath: stepA2URL.path), "chain A step 2 should auto-save with a step-02 prefix")
    let initialCount = try FileManager.default.contentsOfDirectory(at: chainAFolder, includingPropertiesForKeys: nil).count
    let initialStepA1Text = try String(contentsOf: stepA1URL, encoding: .utf8)
    expect(initialStepA1Text.contains("first run"), "auto-saved step output should include the first run input")

    model.updateBinding(chainID: chainAID, stepID: stepA1ID, binding: ChainVariableBinding(variableKey: "topic", inputType: .text, textValue: "second run"))
    await model.runSelectedChain()
    let rerunCount = try FileManager.default.contentsOfDirectory(at: chainAFolder, includingPropertiesForKeys: nil).count
    let overwrittenStepA1Text = try String(contentsOf: stepA1URL, encoding: .utf8)
    expect(rerunCount == initialCount, "rerunning the same chain should overwrite step files instead of creating duplicates")
    expect(overwrittenStepA1Text.contains("second run") && !overwrittenStepA1Text.contains("first run"), "rerun should overwrite the step file with the latest output")

    model.selectedChainID = chainBID
    await model.runSelectedChain()
    let chainBFolder = outputRoot.appendingPathComponent("chain_2", isDirectory: true)
    let stepBURL = chainBFolder.appendingPathComponent("step-01-brief_response.md")
    expect(FileManager.default.fileExists(atPath: stepBURL.path), "chain B file-input step should auto-save into its own chain_N folder")
    expect(chainAFolder.path != chainBFolder.path, "different chains should use different chain_N output folders")
    expect(model.chains.first(where: { $0.id == chainAID })?.stableStorageID == "chain_1", "loaded chain A should migrate to chain_1")
    expect(model.chainOutputFolderURL(for: model.chains.first(where: { $0.id == chainAID })!).lastPathComponent == "chain_1", "open-output-folder URL should target the stable chain_N folder")
}

@MainActor
func testMonotonicPromptAndChainSequenceIDsDoNotReuseDeletedNumbers() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let existingPrompts = (1...80).map { Prompt(title: "Prompt \($0)", content: "Body \($0)") }
    let existingChain = PromptChain(title: "Existing Chain")
    try store.save(PromptLibrary(prompts: existingPrompts, folders: [], chains: [existingChain]))

    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: DeterministicChainProviderClient()))
    model.load()
    expect(model.prompts.compactMap(\.sequenceID).min() == 1, "legacy prompts should migrate starting at prompt_1")
    expect(model.prompts.compactMap(\.sequenceID).max() == 80, "legacy prompts should migrate through prompt_80")
    expect(model.chains.first?.stableStorageID == "chain_1", "legacy first chain should migrate to chain_1")

    model.createPrompt()
    let prompt81 = model.selectedPrompt
    expect(prompt81?.stableStorageID == "prompt_81", "new prompt after 80 existing prompts should be prompt_81")
    if let prompt81 {
        model.prompts.removeAll { $0.id == prompt81.id }
    }
    model.createPrompt()
    expect(model.selectedPrompt?.stableStorageID == "prompt_82", "deleted prompt numbers must not be reused")

    model.createChainDraft()
    expect(model.selectedChain?.stableStorageID == "chain_2", "second created chain should be chain_2")
    if let chain2ID = model.selectedChainID {
        model.chains.removeAll { $0.id == chain2ID }
    }
    model.createChainDraft()
    expect(model.selectedChain?.stableStorageID == "chain_3", "deleted chain folder numbers must not be reused")
}

@MainActor
func testChainPreviousOutputsUseLatestExtractedStepOutputAndDeleteStep() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let first = Prompt(title: "Number", content: "Return 10")
    let second = Prompt(title: "Add", content: "Take {previous} and add 15", variables: [VariableDefinition(key: "previous")])
    let firstStepID = UUID()
    let secondStepID = UUID()
    let firstStep = PromptChainStep(id: firstStepID, promptID: first.id, title: first.title, sortOrder: 0, finalOutputTag: "final-file")
    let secondStep = PromptChainStep(id: secondStepID, promptID: second.id, title: second.title, sortOrder: 1, variableBindings: [ChainVariableBinding(variableKey: "previous", inputType: .previousStepOutput, sourceStepID: firstStepID, sourceOutputTag: "final-file")])
    let chain = PromptChain(title: "Math Chain", steps: [firstStep, secondStep])
    try store.save(PromptLibrary(prompts: [first, second], folders: [], chains: [chain]))
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: DeterministicChainProviderClient()))
    model.load()
    guard let loadedChain = model.selectedChain else { fputs("❌ chain should load\n", stderr); exit(1) }
    let oldRun = ChainRun(chainID: loadedChain.id, startedAt: Date(timeIntervalSince1970: 1), status: .complete, stepRuns: [
        ChainStepRun(stepID: firstStepID, resolvedPrompt: "", providerKind: .openAI, modelID: "gpt-4o", inputSnapshot: [:], outputText: "5", status: .complete, startedAt: Date(timeIntervalSince1970: 1))
    ])
    let newRun = ChainRun(chainID: loadedChain.id, startedAt: Date(timeIntervalSince1970: 2), status: .complete, stepRuns: [
        ChainStepRun(stepID: firstStepID, resolvedPrompt: "", providerKind: .openAI, modelID: "gpt-4o", inputSnapshot: [:], outputText: "notes\n<final-file>\n10\n</final-file>", status: .complete, startedAt: Date(timeIntervalSince1970: 2))
    ])
    model.chainRuns = [oldRun, newRun]
    let outputs = model.previousOutputs(for: loadedChain, before: secondStep)
    let resolvedPrevious = try model.chainExecutionService.resolve(step: secondStep, prompt: second, previousOutputs: outputs).0
    expect(resolvedPrevious == "Take 10 and add 15", "previous step values should use the latest completed run and extract final tagged output")
    model.save()
    let reloaded = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: DeterministicChainProviderClient()))
    expect(reloaded.chainRuns.count == 2, "chain runs should persist so previous step outputs survive leaving and returning to the chain")
    model.removeStep(secondStepID)
    expect(model.selectedChain?.steps.count == 1, "delete step should remove the selected chain step")
    expect(model.selectedChain?.steps.first?.sortOrder == 0, "remaining steps should be re-ordered after delete")
}


func testNoVariableChainRunsAndEmptyPromptFails() async throws {
    let prompt = Prompt(title: "Plain Prompt", content: "Summarize this without variables.", variables: [])
    let step = PromptChainStep(promptID: prompt.id, title: prompt.title, providerKind: .deepSeek, modelID: "deepseek-v4-flash")
    let service = ChainExecutionService(client: DeterministicChainProviderClient())
    let run = try await service.run(step: step, prompt: prompt, previousOutputs: [:])
    expect(run.status == .complete, "chain steps should run when the prompt has no variables")
    expect(run.inputSnapshot.isEmpty, "no-variable prompt should not require variable bindings")
    expect(run.outputText.contains("DeepSeek"), "no-variable run should still produce visible output")

    let empty = Prompt(title: "Empty", content: "", variables: [])
    do {
        _ = try await service.run(step: PromptChainStep(promptID: empty.id, title: empty.title), prompt: empty, previousOutputs: [:])
        fputs("❌ empty chain prompt should fail instead of completing silently\n", stderr)
        exit(1)
    } catch {
        expect(error.localizedDescription.contains("no prompt content"), "empty prompt failure should explain why the chain did not run")
    }
}

@MainActor
func testAppViewModelChainFailureRecordsVisibleError() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    try store.save(PromptLibrary(prompts: [], folders: []))
    let model = AppViewModel(store: store)
    model.createChainDraft()
    guard let stepID = model.selectedChain?.steps.first?.id else { fputs("❌ chain draft should have a step\n", stderr); exit(1) }
    await model.runStep(stepID)
    expect(model.selectedChain?.steps.first?.status == .failed, "running a chain step without a prompt should mark the step failed")
    expect(model.latestStepError(for: stepID)?.contains("Choose a saved prompt") == true, "failed chain step should expose a visible error message")
    expect(model.saveStatus == "Chain run failed", "failed chain step should not report completion")
}

extension JSONEncoder {
    static var iso8601Pretty: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return encoder }
}

extension JSONDecoder {
    static var iso8601: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }
}


@MainActor
func testVariablePromptBatchFolderRunsSequentiallyAndSkipsExistingOutputs() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let input = directory.appendingPathComponent("input", isDirectory: true)
    let output = directory.appendingPathComponent("output", isDirectory: true)
    try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    try "# A".write(to: input.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
    try "# B".write(to: input.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)
    try "# C".write(to: input.appendingPathComponent("c.markdown"), atomically: true, encoding: .utf8)
    try "keep existing".write(to: output.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)

    var prompt = Prompt(title: "Batch Variable", content: "Fix file:\n{markdown}", variables: [VariableDefinition(key: "markdown")], variableRunOutputFolderPath: output.path)
    let folder = ChainFolderAttachment(folderName: "input", originalPath: input.path, markdownFileCount: 3)
    prompt.variableRunStep = PromptChainStep(promptID: prompt.id, title: prompt.title, variableBindings: [ChainVariableBinding(variableKey: "markdown", inputType: .folder, folderAttachment: folder)], outputPolicy: .saveMarkdown, overwriteOutputFile: false)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    try store.save(PromptLibrary(prompts: [prompt]))
    let recorder = FreshLoopCallRecorder()
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: RecordingFreshLoopProviderClient(recorder: recorder)))

    await model.runVariablePrompt(prompt.id)

    let snapshot = await recorder.snapshot()
    expect(snapshot.maxConcurrent == 1, "variable prompt folder batch should run one fresh provider call at a time")
    expect(snapshot.prompts.count == 2, "overwrite off should skip existing output files before provider calls")
    expect(snapshot.prompts[0].contains("# A") && snapshot.prompts[1].contains("# C"), "batch should process top-level Markdown files A-Z and skip b.md")
    let skippedText = try String(contentsOf: output.appendingPathComponent("b.md"), encoding: .utf8)
    expect(skippedText == "keep existing", "skipped output should not be overwritten")
    expect(FileManager.default.fileExists(atPath: output.appendingPathComponent("a.md").path), "batch should save output using input Markdown filename")
    expect(FileManager.default.fileExists(atPath: output.appendingPathComponent("c.markdown").path), "batch should preserve markdown extension in output filename")
    expect(model.prompts.count == 1 && !model.prompts.contains { $0.sourceType == "chain-output" }, "variable prompt folder batch should not add generated output files to the prompt catalog")
    let persisted = try store.load()
    expect(persisted.prompts.count == 1 && persisted.prompts.first?.id == prompt.id, "persisted variable folder batch library should contain only the original prompt")
    expect(model.saveStatus.contains("skipped 1"), "batch summary should report skipped files")
}

@MainActor
func testVariablePromptSingleRunSavesFileWithoutCatalogUpsert() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let output = directory.appendingPathComponent("output", isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    var prompt = Prompt(title: "Single Variable", content: "Write for {topic}", variables: [VariableDefinition(key: "topic")], variableRunOutputFolderPath: output.path)
    prompt.variableRunStep = PromptChainStep(promptID: prompt.id, title: prompt.title, variableBindings: [ChainVariableBinding(variableKey: "topic", inputType: .text, textValue: "catalog safety")], outputPolicy: .saveMarkdown)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    try store.save(PromptLibrary(prompts: [prompt]))
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: DeterministicChainProviderClient()))

    await model.runVariablePrompt(prompt.id)

    let outputFiles = try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil).filter { $0.pathExtension.lowercased() == "md" }
    expect(outputFiles.count == 1, "single variable run should save exactly one Markdown output file")
    expect(model.prompts.count == 1 && !model.prompts.contains { $0.sourceType == "chain-output" }, "single variable run should not upsert output as a prompt catalog entry")
    let persisted = try store.load()
    expect(persisted.prompts.count == 1 && persisted.prompts.first?.id == prompt.id, "single variable run should persist only the original prompt")
}

@MainActor
func testGeneratedVariableOutputCatalogEntriesAreRemovedOnLoad() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let normal = Prompt(title: "Normal", content: "Keep me")
    let generated = Prompt(title: "generated.md", content: "Remove me", sourceType: "chain-output", primaryCategory: "chained-prompts", categories: ["chained-prompts"], subcategory: "chain-output", whenToUse: "Saved response from chained prompt Variable Prompts / Social Media Images.", searchTerms: ["chain-output", "variable-prompts-social-media-images"], sourceFilePath: outputPath(in: directory, name: "generated.md"))
    let realChainOutput = Prompt(title: "chain.md", content: "Keep chain output", sourceType: "chain-output", primaryCategory: "chained-prompts", categories: ["chained-prompts"], subcategory: "chain-output", whenToUse: "Saved response from chained prompt Real Chain.", searchTerms: ["chain-output", "real-chain"], sourceFilePath: outputPath(in: directory, name: "chain.md"))
    try store.save(PromptLibrary(prompts: [normal, generated, realChainOutput]))

    let model = AppViewModel(store: store)

    expect(!model.prompts.contains { $0.id == generated.id }, "generated variable output catalog entries should be removed from memory on load")
    expect(model.prompts.contains { $0.id == normal.id } && model.prompts.contains { $0.id == realChainOutput.id }, "cleanup should preserve normal prompts and real chain output prompts")
    let persisted = try store.load()
    expect(!persisted.prompts.contains { $0.id == generated.id }, "generated variable output catalog cleanup should be persisted")
}

private func outputPath(in directory: URL, name: String) -> String {
    directory.appendingPathComponent("outputs", isDirectory: true).appendingPathComponent(name).path
}

@MainActor
func testVariableRunnerCollapseSettingIsGlobalAndNonDirty() throws {
    let key = AppSettingsKeys.storageVariablePromptRunnerCollapsed
    let oldValue = UserDefaults.standard.object(forKey: key)
    defer { restoreUserDefault(oldValue, forKey: key) }
    UserDefaults.standard.removeObject(forKey: key)

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let updatedAt = Date(timeIntervalSince1970: 100)
    let prompt = Prompt(title: "Collapse", content: "Use {thing}", updatedAt: updatedAt, variables: [VariableDefinition(key: "thing")])
    try store.save(PromptLibrary(prompts: [prompt]))
    let model = AppViewModel(store: store)

    expect((UserDefaults.standard.object(forKey: key) as? Bool) ?? AppSettingsDefaults.variablePromptRunnerCollapsed, "variable runner should default collapsed")
    model.toggleVariableRunCollapsed(promptID: prompt.id)
    expect(UserDefaults.standard.bool(forKey: key) == false, "variable runner collapse toggle should update the shared setting")
    expect(!model.hasUnsavedPromptChanges, "variable runner collapse toggle should not dirty the prompt")
    expect(model.prompts.first(where: { $0.id == prompt.id })?.updatedAt == updatedAt, "variable runner collapse toggle should not mutate prompt updatedAt")
}

@MainActor
func testTypeOwnedFolderMigrationAndScopedFiltering() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let root = Folder(name: "Work")
    let child = Folder(name: "Pages", parentFolderID: root.id)
    let variable = Prompt(title: "Variable", content: "Use {markdown}", folderID: child.id, variables: [VariableDefinition(key: "markdown")])
    let phrase = Prompt(title: "Phrase", content: "Reusable", folderID: root.id, type: .phrase)
    let chain = PromptChain(title: "Chain", folderID: child.id)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    try store.save(PromptLibrary(prompts: [variable, phrase], folders: [root, child], chains: [chain]))

    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: DeterministicChainProviderClient()))
    let variableFolder = model.folders.first { $0.scope == .variablePrompts && $0.name == "Pages" }
    let phraseFolder = model.folders.first { $0.scope == .phrases && $0.name == "Work" }
    let chainFolder = model.folders.first { $0.scope == .chains && $0.name == "Pages" }
    expect(variableFolder != nil && phraseFolder != nil && chainFolder != nil, "load should migrate shared folders into type-owned folder namespaces")
    expect(model.prompts.first { $0.id == variable.id }?.folderID == variableFolder?.id, "variable prompts should move to variable prompt folder namespace")
    expect(model.prompts.first { $0.id == phrase.id }?.folderID == phraseFolder?.id, "phrases should move to phrase folder namespace")
    expect(model.chains.first { $0.id == chain.id }?.folderID == chainFolder?.id, "chains should move to chain folder namespace")

    model.librarySection = .prompts
    model.metadataFilters.type = .variablePrompt
    model.selection = .folder(variableFolder!.id)
    expect(model.visiblePrompts.map(\.id) == [variable.id], "variable folder selection should filter to variable prompts in that namespace")
    model.librarySection = .chains
    model.selection = .folder(chainFolder!.id)
    expect(model.visibleChains.map(\.id) == [chain.id], "chain folder selection should filter chains in that namespace")
}

func testProviderModelCatalogAndSwitching() {
    expect(AIProviderKind.openAI.models.map(\.id).contains("gpt-4o-mini"), "OpenAI model picker should use the Mac Voice OpenAI model list")
    expect(AIProviderKind.deepSeek.models.map(\.id) == ["deepseek-v4-flash", "deepseek-v4-pro"], "DeepSeek model picker should show only DeepSeek V4 models")
    expect(AIProviderKind.openRouter.models.contains { $0.id == "anthropic/claude-sonnet-4-6" }, "OpenRouter models from Mac Voice should be available")
    expect(AIProviderConfiguration.defaults.count == AIProviderKind.allCases.count, "provider defaults should exist for every Mac Voice provider")
}

func testAIRequestLogServiceRetentionAndPersistence() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("ai-log.json")
    let defaults = UserDefaults(suiteName: "ai-log-test-\(UUID().uuidString)")!
    defaults.set(2, forKey: AppSettingsKeys.aiRequestLogMaxEntries)
    defaults.set(10, forKey: AppSettingsKeys.aiRequestLogMaxAgeMinutes)
    let service = AIRequestLogService(fileURL: url, userDefaults: defaults)
    let now = Date(timeIntervalSince1970: 10_000)

    service.append(provider: .openAI, modelID: "gpt-4o", requestText: "old", responseText: "old response", status: "success", date: now.addingTimeInterval(-20 * 60))
    service.append(provider: .deepSeek, modelID: "deepseek-v4-flash", requestText: "first", responseText: "first response", status: "success", date: now.addingTimeInterval(-60))
    service.append(provider: .deepSeek, modelID: "deepseek-v4-pro", requestText: "second", responseText: "second response", status: "success", date: now)

    let entries = try service.load(now: now)
    expect(entries.map(\.requestText) == ["first", "second"], "AI request log should trim by max age and max entry count")
    try service.clear()
    let clearedEntries = try service.load()
    expect(clearedEntries.isEmpty, "AI request log should support clearing all entries")
}

actor ProviderCallRecorder {
    private var calls: [(provider: AIProviderKind, modelID: String)] = []
    func record(provider: AIProviderKind, modelID: String) {
        calls.append((provider, modelID))
    }
    func snapshot() -> [(provider: AIProviderKind, modelID: String)] { calls }
}

struct RecordingProviderClient: ChainProviderClient {
    let recorder: ProviderCallRecorder
    func complete(prompt: String, provider: AIProviderKind, modelID: String) async throws -> String {
        await recorder.record(provider: provider, modelID: modelID)
        return "Recorded \(provider.displayName) \(modelID): \(prompt)"
    }
}

@MainActor
func testGlobalAISettingsProviderModelIsRuntimeSource() async throws {
    let providerKey = AppSettingsKeys.aiDefaultProvider
    let modelKey = AppSettingsKeys.aiDefaultModel
    let oldProvider = UserDefaults.standard.object(forKey: providerKey)
    let oldModel = UserDefaults.standard.object(forKey: modelKey)
    defer {
        restoreUserDefault(oldProvider, forKey: providerKey)
        restoreUserDefault(oldModel, forKey: modelKey)
    }
    UserDefaults.standard.set(AIProviderKind.deepSeek.rawValue, forKey: providerKey)
    UserDefaults.standard.set("deepseek-v4-pro", forKey: modelKey)

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let prompt = Prompt(title: "Settings Runtime", content: "Run this.", variables: [])
    let staleStep = PromptChainStep(promptID: prompt.id, title: prompt.title, outputPolicy: .viewOnly, providerKind: .openAI, modelID: "gpt-4o")
    let staleChain = PromptChain(title: "Stale Chain", steps: [staleStep], defaultProviderKind: .openAI, defaultModelID: "gpt-4o")
    var variablePrompt = Prompt(title: "Variable", content: "Hello {name}", variables: [VariableDefinition(key: "name")])
    variablePrompt.variableRunStep = PromptChainStep(promptID: variablePrompt.id, title: variablePrompt.title, variableBindings: [ChainVariableBinding(variableKey: "name", inputType: .text, textValue: "World")], outputPolicy: .viewOnly, providerKind: .openAI, modelID: "gpt-4o")
    try store.save(PromptLibrary(prompts: [prompt, variablePrompt], folders: [], chains: [staleChain]))

    let recorder = ProviderCallRecorder()
    let model = AppViewModel(store: store, chainExecutionService: ChainExecutionService(client: RecordingProviderClient(recorder: recorder)))
    model.createChainDraft()
    expect(model.selectedChain?.defaultProviderKind == .deepSeek, "new chains should initialize from Settings provider")
    expect(model.selectedChain?.defaultModelID == "deepseek-v4-pro", "new chains should initialize from Settings model")

    model.selectedChainID = staleChain.id
    await model.runStep(staleStep.id)
    model.selectedPromptID = variablePrompt.id
    await model.runVariablePrompt(variablePrompt.id)

    let calls = await recorder.snapshot()
    expect(calls.count == 2, "chain and variable prompt runs should both call the provider")
    expect(calls.allSatisfy { $0.provider == .deepSeek && $0.modelID == "deepseek-v4-pro" }, "runtime should ignore stale per-step OpenAI values and use Settings provider/model")
    expect(model.chainRuns.prefix(2).allSatisfy { $0.stepRuns.first?.providerKind == .deepSeek && $0.stepRuns.first?.modelID == "deepseek-v4-pro" }, "recorded run metadata should show the Settings provider/model")

    guard let chain = model.chains.first(where: { $0.id == staleChain.id }) else {
        fputs("❌ stale chain should still exist\n", stderr)
        exit(1)
    }
    model.updateStepProvider(chainID: chain.id, stepID: staleStep.id, providerKind: .openAI)
    expect(UserDefaults.standard.string(forKey: providerKey) == AIProviderKind.openAI.rawValue, "legacy provider update path should update global Settings provider only")
    expect(model.chains.first(where: { $0.id == chain.id })?.steps.first?.providerKind == .deepSeek, "legacy provider update path should not create per-step provider overrides")
}

func testSidebarTimestampIncludesSeconds() {
    let timestamp = SidebarDateFormatter.timestamp(Date(timeIntervalSince1970: 1_717_500_908))
    expect(timestamp.range(of: #"^\d{2}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}$"#, options: .regularExpression) != nil, "metadata timestamps should use compact dd/MM/yy HH:mm:ss format")
}

@MainActor
func testVariablePromptOutputBehaviorAndFolderPersistence() throws {
    expect(ChainOutputPolicy.variablePromptOptions == [.viewOnly, .saveMarkdown], "variable prompt output behavior should only expose view-only and auto-save Markdown")
    expect(!ChainOutputPolicy.variablePromptOptions.contains(.saveAndUseNext), "variable prompt output behavior should not expose next-step output policy")
    expect(!ChainOutputPolicy.variablePromptOptions.map(\.displayName).contains { $0.localizedCaseInsensitiveContains("next step") }, "variable prompt output behavior labels should not mention next steps")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PromptStore(fileURL: directory.appendingPathComponent("library.json"))
    let prompt = Prompt(title: "Folder Output", content: "Use {item}", variables: [VariableDefinition(key: "item")])
    try store.save(PromptLibrary(prompts: [prompt], folders: []))

    let outputFolder = directory.appendingPathComponent("variable-output", isDirectory: true).path
    let model = AppViewModel(store: store)
    model.updateVariableRunOutputFolder(promptID: prompt.id, folderPath: outputFolder)
    model.save()

    let reloaded = try store.load()
    expect(reloaded.prompts.first(where: { $0.id == prompt.id })?.variableRunOutputFolderPath == outputFolder, "variable prompt output folder should persist with the prompt")
}

func restoreUserDefault(_ value: Any?, forKey key: String) {
    if let value {
        UserDefaults.standard.set(value, forKey: key)
    } else {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

do {
    testPromptModel()
    testFiltering()
    try testStoreAndImportExport()
    try testMetadataModelsAndMigration()
    try testMarkdownImportPhrasesAndCategories()
    testVariableFillingPresetsAndMetadataFilters()
    testAppSettingsDefaultsAndReset()
    try testExportAndAudit()
    testSettingsAuditRegistry()
    testSearchBehaviorSettings()
    testClipboardSettingsFormatting()
    try testBackupServiceAndStorageSettings()
    testExternalPromptLibraryFixtureIfPresent()
    try await MainActor.run { try testPromptSelectionDoesNotResortUpdatedList() }
    try await MainActor.run { try testBlankPromptCreationDirtySaveAndDiscard() }
    try await MainActor.run { try testNewVariablePromptKeepsIdentityWhenContentHasNoVariables() }
    try testPromptDecodingBackfillsVariablePromptIdentity()
    try await MainActor.run { try testSelectedPromptStaysBoundWhenItDropsOutOfCurrentFilter() }
    try await MainActor.run { try testSelectedPromptBindingIsIDStableWhenArrayChanges() }
    try await MainActor.run { try testDerivedPromptCachesInvalidateAfterEdits() }
    try await MainActor.run { try testMovingSelectedPromptFollowsDestinationFolder() }
    testVariablePresetUpdateRenameAndVersionInfo()
    testVariableDetectorOnlyDetectsConfiguredBraceTokens()
    try await MainActor.run { try testAppViewModelWorkflows() }
    try await testChainModelsPersistenceAndExecution()
    try await testAppViewModelChainWorkflow()
    try await testChainFileRunSavesDeterministicResponsePromptAndFile()
    try await testCustomFinalTagSavesTagNamedMarkdownAndFeedsNextStep()
    try await testChainCustomStatusesAndMonitorStopBeforeNextStep()
    try await testLoopMonitorStopStopsBeforeNextIteration()
    try await testRunLoopUsesFreshSequentialProviderCallForEveryStep()
    try await testLoopFeedbackFileUsesInitialFileThenSavedOutputAndFeedback()
    try await testChainOutputFilenameSettingsAndCustomOverwrite()
    try await testRunningChainStepCanBeStopped()
    try await MainActor.run { try testSaveSelectedChainPersistsLatestTaggedOutput() }
    try await MainActor.run { try testSaveStepMarkdownButtonSavesResolvedPromptWithoutOutput() }
    try await testAutomaticChainMarkdownOutputsUseChainIDStepPrefixesAndOverwriteAcrossMultipleChains()
    try await MainActor.run { try testMonotonicPromptAndChainSequenceIDsDoNotReuseDeletedNumbers() }
    try await MainActor.run { try testChainPreviousOutputsUseLatestExtractedStepOutputAndDeleteStep() }
    try await testNoVariableChainRunsAndEmptyPromptFails()
    try await testAppViewModelChainFailureRecordsVisibleError()
    try await testVariablePromptBatchFolderRunsSequentiallyAndSkipsExistingOutputs()
    try await testVariablePromptSingleRunSavesFileWithoutCatalogUpsert()
    try await MainActor.run { try testGeneratedVariableOutputCatalogEntriesAreRemovedOnLoad() }
    try await MainActor.run { try testVariableRunnerCollapseSettingIsGlobalAndNonDirty() }
    try await MainActor.run { try testTypeOwnedFolderMigrationAndScopedFiltering() }
    testProviderModelCatalogAndSwitching()
    try testAIRequestLogServiceRetentionAndPersistence()
    try await testGlobalAISettingsProviderModelIsRuntimeSource()
    testSidebarTimestampIncludesSeconds()
    try await MainActor.run { try testVariablePromptOutputBehaviorAndFolderPersistence() }
    testAIConnectionValidationDoesNotReportStaticConnected()
    try testLiveAIProviderClientRequestConstruction()
    print("✅ PromptManagerChecks passed")
} catch {
    fputs("❌ \(error)\n", stderr)
    exit(1)
}

func testVariableDetectorOnlyDetectsConfiguredBraceTokens() {
    let plain = "No configured variables in this long body, despite normal punctuation and markdown [links]."
    expect(VariableDetector.definitions(in: plain).isEmpty, "plain content without brace tokens should skip variable detection")
    expect(VariableDetector.normalizedContent(plain) == plain, "plain content should return unchanged during normalization")

    let content = "Use {markdown} only. Ignore [Number] and [None Or List Only Blockers That Could Not Be Safely Fixed]. Also ignore <HTML>."
    let keys = VariableDetector.definitions(in: content).map(\.key)
    expect(keys == ["markdown"], "variable detection should only detect configured brace tokens and ignore bracket/angle text")
    let normalized = VariableDetector.normalizedContent(content)
    expect(normalized.contains("[Number]") && normalized.contains("<HTML>"), "normalization should not convert unsupported variable formats when braces are configured")
}

func testSettingsAuditRegistry() {
    expect(AppSettingsAuditRegistry.missingVisibleConsumers.isEmpty, "every visible setting key should have a declared consumer/effect")
    expect(AppSettingsAuditRegistry.consumers.count >= 75, "settings registry should cover the expanded settings surface")
}

func testSearchBehaviorSettings() {
    let prompt = Prompt(title: "Needle", content: "Body match", notes: "Private note", primaryCategory: "business", subcategory: "planning")
    let noTitle = SearchBehaviorSettings(scope: "all", behavior: "contains", searchInTitle: false, searchInBody: true, searchInNotes: true, searchInMetadata: true)
    expect(LibraryFilterService.visiblePrompts([prompt], folders: [], selection: .all, searchQuery: "Needle", sortMode: .az, searchSettings: noTitle).isEmpty, "search title toggle should exclude titles")
    let exact = SearchBehaviorSettings(scope: "all", behavior: "exact", searchInTitle: true, searchInBody: true, searchInNotes: true, searchInMetadata: true)
    expect(LibraryFilterService.visiblePrompts([prompt], folders: [], selection: .all, searchQuery: "Needle", sortMode: .az, searchSettings: exact).count == 1, "exact search should match exact field")
    expect(LibraryFilterService.visiblePrompts([prompt], folders: [], selection: .all, searchQuery: "Need", sortMode: .az, searchSettings: exact).isEmpty, "exact search should not do contains")
    let fuzzy = SearchBehaviorSettings(scope: "all", behavior: "fuzzy", searchInTitle: true, searchInBody: false, searchInNotes: false, searchInMetadata: false)
    expect(LibraryFilterService.visiblePrompts([prompt], folders: [], selection: .all, searchQuery: "Ndl", sortMode: .az, searchSettings: fuzzy).count == 1, "fuzzy search should match ordered characters")
}

func testClipboardSettingsFormatting() {
    let prompt = Prompt(title: "Copy Me", content: "**Bold** `{thing}`", primaryCategory: "coding", subcategory: "agent-quality", whenToUse: "When testing")
    let rich = ClipboardBehaviorSettings(includeTitle: true, includeMetadata: true, preserveMarkdown: true)
    let richText = ClipboardService.formattedPrompt(prompt, settings: rich)
    expect(richText.contains("# Copy Me"), "clipboard title setting should include title")
    expect(richText.contains("Category: Coding"), "clipboard metadata setting should include category")
    expect(richText.contains("**Bold**"), "preserve markdown should keep markdown tokens")
    let plain = ClipboardBehaviorSettings(preserveMarkdown: false)
    expect(!ClipboardService.formattedPrompt(prompt, settings: plain).contains("**"), "plain clipboard setting should strip simple markdown markers")
}

func testBackupServiceAndStorageSettings() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storeURL = dir.appendingPathComponent("library.json")
    let library = PromptLibrary(prompts: [Prompt(title: "Backup", content: "Body")])
    try PromptBackupService.runIfNeeded(library: library, settings: ImportExportBehaviorSettings(autoBackup: true, backupFrequency: "daily", keepBackupsFor: "7"), storeURL: storeURL, now: Date(timeIntervalSince1970: 1000))
    let backups = try FileManager.default.contentsOfDirectory(at: PromptBackupService.backupDirectory(for: storeURL), includingPropertiesForKeys: nil)
    expect(backups.contains { $0.lastPathComponent.hasPrefix("library-backup-") }, "auto backup setting should create backup file")
}

func testAIConnectionValidationDoesNotReportStaticConnected() {
    expect(AIConnectionValidator.validate(provider: .deepSeek, apiKey: "dfdf").message == "Invalid key format", "invalid DeepSeek key should not validate as connected")
    expect(AIConnectionValidator.validate(provider: .deepSeek, apiKey: "sk-valid-looking-deepseek-key").message == "Key format OK; live test not run", "valid-looking DeepSeek key should remain explicitly unverified without a live API check")
    expect(AIConnectionValidator.validate(provider: .openAI, apiKey: "").message == "Missing API key", "empty API key should show missing status")
}


func testLiveAIProviderClientRequestConstruction() throws {
    let defaults = UserDefaults(suiteName: "live-client-test-\(UUID().uuidString)")!
    defaults.set(1234, forKey: AppSettingsKeys.aiMaxTokens)
    defaults.set(0.2, forKey: AppSettingsKeys.aiTemperature)
    let client = LiveAIProviderClient(keychain: AIKeychainService(service: "test"), userDefaults: defaults)
    let openAI = try client.makeChatCompletionsRequest(prompt: "Hello", provider: .openAI, modelID: "gpt-4o", apiKey: "sk-test")
    expect(openAI.url?.absoluteString == "https://api.openai.com/v1/chat/completions", "OpenAI should use chat completions endpoint")
    expect(openAI.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test", "OpenAI request should include bearer token")
    let body = String(data: openAI.httpBody ?? Data(), encoding: .utf8) ?? ""
    expect(body.contains("\"model\":\"gpt-4o\"") && body.contains("Hello"), "OpenAI request body should include model and prompt")
    defaults.set("Enabled", forKey: AppSettingsKeys.aiThinkingMode)
    let deepSeek = try client.makeChatCompletionsRequest(prompt: "Hi", provider: .deepSeek, modelID: "deepseek-v4-flash", apiKey: "sk-test")
    expect(deepSeek.url?.absoluteString == "https://api.deepseek.com/chat/completions", "DeepSeek should use chat completions endpoint")
    let deepSeekBody = String(data: deepSeek.httpBody ?? Data(), encoding: .utf8) ?? ""
    expect(deepSeekBody.contains("\"thinking\":{\"type\":\"enabled\"}"), "DeepSeek thinking mode should use an enabled/disabled toggle payload")
    expect(!deepSeekBody.contains("reasoning_effort"), "DeepSeek settings UI should not send hidden high/max effort when the visible mode is only enabled/disabled")
    defaults.set("Disabled", forKey: AppSettingsKeys.aiThinkingMode)
    let deepSeekDisabled = try client.makeChatCompletionsRequest(prompt: "Hi", provider: .deepSeek, modelID: "deepseek-v4-pro", apiKey: "sk-test")
    let disabledBody = String(data: deepSeekDisabled.httpBody ?? Data(), encoding: .utf8) ?? ""
    expect(disabledBody.contains("\"thinking\":{\"type\":\"disabled\"}"), "DeepSeek disabled thinking mode should send disabled toggle")
    do {
        _ = try client.makeChatCompletionsRequest(prompt: "Hi", provider: .anthropic, modelID: "claude", apiKey: "sk-test")
        expect(false, "unsupported providers should throw")
    } catch {
        expect(error.localizedDescription.contains("not implemented"), "unsupported provider error should explain live support scope")
    }
}
