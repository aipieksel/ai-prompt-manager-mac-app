import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

private enum PendingNavigationAction {
    case selectPrompt(UUID)
    case newEntry
}

struct AppShellView: View {
    @StateObject private var model = AppViewModel()
    @State private var showingDeleteConfirmation = false
    @State private var pendingDeletePrompt: Prompt?
    @State private var showingSettings = false
    @State private var showingExport = false
    @State private var showingAudit = false
    @State private var pendingSelection: PendingNavigationAction?
    @State private var showingUnsavedNavigationConfirmation = false
    @State private var showingUnsavedQuitConfirmation = false
    @State private var expandedVariableKey: String?

    @AppStorage(AppSettingsKeys.appAppearance) private var appAppearanceRaw = AppAppearance.system.rawValue
    @AppStorage(AppSettingsKeys.accentColor) private var accentColorRaw = AppSettingsDefaults.accentColor.rawValue
    @AppStorage(AppSettingsKeys.fontScale) private var fontScaleRaw = AppSettingsDefaults.fontScale.rawValue
    @AppStorage(AppSettingsKeys.buttonVisualStyle) private var buttonStyleRaw = AppSettingsDefaults.buttonStyle.rawValue
    @AppStorage(AppSettingsKeys.buttonTextWeight) private var buttonWeightRaw = AppSettingsDefaults.buttonTextWeight.rawValue
    @AppStorage(AppSettingsKeys.buttonSize) private var buttonSizeRaw = AppSettingsDefaults.buttonSize.rawValue
    @AppStorage(AppSettingsKeys.leftSidebarVisible) private var leftSidebarVisible = AppSettingsDefaults.leftSidebarVisible
    @AppStorage(AppSettingsKeys.rightDetailsSidebarVisible) private var rightDetailsSidebarVisible = AppSettingsDefaults.rightSidebarVisible
    @AppStorage(AppSettingsKeys.promptListWidth) private var promptListWidthStored = AppSettingsDefaults.promptListWidth
    @AppStorage(AppSettingsKeys.detailsSidebarWidth) private var detailsSidebarWidthStored = AppSettingsDefaults.detailsSidebarWidth
    @AppStorage(AppSettingsKeys.resizablePanelsEnabled) private var resizablePanelsEnabled = AppSettingsDefaults.resizablePanelsEnabled
    @AppStorage(AppSettingsKeys.promptListShowIcons) private var promptListShowIcons = AppSettingsDefaults.promptListShowIcons
    @AppStorage(AppSettingsKeys.promptListShowDescription) private var promptListShowDescription = AppSettingsDefaults.promptListShowDescription
    @AppStorage(AppSettingsKeys.promptListShowMetadata) private var promptListShowMetadata = AppSettingsDefaults.promptListShowMetadata
    @AppStorage(AppSettingsKeys.promptListPreviewLines) private var promptListPreviewLines = AppSettingsDefaults.promptListPreviewLines
    @AppStorage(AppSettingsKeys.promptListTruncateLongTitles) private var promptListTruncateLongTitles = AppSettingsDefaults.promptListTruncateLongTitles
    @AppStorage(AppSettingsKeys.promptListRowDensity) private var promptListRowDensityRaw = AppSettingsDefaults.promptListRowDensity.rawValue
    @AppStorage(AppSettingsKeys.rightSidebarShowFolder) private var rightSidebarShowFolder = AppSettingsDefaults.rightSidebarShowFolder
    @AppStorage(AppSettingsKeys.rightSidebarShowPromptMetadata) private var rightSidebarShowPromptMetadata = AppSettingsDefaults.rightSidebarShowPromptMetadata
    @AppStorage(AppSettingsKeys.rightSidebarShowNotes) private var rightSidebarShowNotes = AppSettingsDefaults.rightSidebarShowNotes
    @AppStorage(AppSettingsKeys.rightSidebarShowMetadata) private var rightSidebarShowMetadata = AppSettingsDefaults.rightSidebarShowMetadata

    @AppStorage(AppSettingsKeys.generalOpenLastPrompt) private var generalOpenLastPrompt = true
    @AppStorage(AppSettingsKeys.generalRememberWindowSize) private var generalRememberWindowSize = true
    @AppStorage(AppSettingsKeys.generalRememberSelectedFolder) private var generalRememberSelectedFolder = true
    @AppStorage(AppSettingsKeys.generalConfirmDestructiveActions) private var generalConfirmDestructiveActions = true
    @AppStorage(AppSettingsKeys.generalLaunchSection) private var generalLaunchSection = "last"
    @AppStorage(AppSettingsKeys.sessionLastPromptID) private var sessionLastPromptID = ""
    @AppStorage(AppSettingsKeys.sessionLastSelection) private var sessionLastSelection = "all"
    @AppStorage(AppSettingsKeys.sessionLastSection) private var sessionLastSection = LibrarySection.prompts.rawValue
    @AppStorage(AppSettingsKeys.sessionLastSort) private var sessionLastSort = SortMode.updated.rawValue

    @AppStorage(AppSettingsKeys.editorMarkdownHighlighting) private var editorMarkdownHighlighting = true
    @AppStorage(AppSettingsKeys.editorLineWrap) private var editorLineWrap = true
    @AppStorage(AppSettingsKeys.editorShowWordCount) private var editorShowWordCount = true
    @AppStorage(AppSettingsKeys.editorAutosaveTyping) private var editorAutosaveTyping = false
    @AppStorage(AppSettingsKeys.editorSaveFeedback) private var editorSaveFeedback = true
    @AppStorage(AppSettingsKeys.editorTitleFieldSize) private var editorTitleFieldSize = "compact"
    @AppStorage(AppSettingsKeys.editorActionLabelMode) private var editorActionLabelMode = "responsive"
    @AppStorage(AppSettingsKeys.editorDefaultFormat) private var editorDefaultFormat = "markdown"

    @AppStorage(AppSettingsKeys.variablesShowPanel) private var variablesShowPanel = true
    @AppStorage(AppSettingsKeys.variablesPanelWidth) private var variablesPanelWidth = 260.0
    @AppStorage(AppSettingsKeys.variablesFieldDefaultHeight) private var variablesFieldDefaultHeight = 96.0
    @AppStorage(AppSettingsKeys.variablesRememberFieldHeights) private var variablesRememberFieldHeights = true
    @AppStorage(AppSettingsKeys.variablesShowRequiredCount) private var variablesShowRequiredCount = true
    @AppStorage(AppSettingsKeys.variablesActionRowStyle) private var variablesActionRowStyle = "compact"
    @AppStorage(AppSettingsKeys.variablesCopyFilledVisible) private var variablesCopyFilledVisible = true
    @AppStorage(AppSettingsKeys.variablesPresetsEnabled) private var variablesPresetsEnabled = true
    @AppStorage(AppSettingsKeys.variablesDefaultType) private var variablesDefaultType = "textarea"
    @AppStorage(AppSettingsKeys.variablesInsertFormat) private var variablesInsertFormat = "braces"
    @AppStorage(AppSettingsKeys.variablesAutoDetect) private var variablesAutoDetect = true
    @AppStorage(AppSettingsKeys.variablesHighlight) private var variablesHighlight = true
    @AppStorage(AppSettingsKeys.variablesRequireDescriptions) private var variablesRequireDescriptions = false
    @AppStorage(AppSettingsKeys.variablesSortBy) private var variablesSortBy = "source"
    @AppStorage(AppSettingsKeys.inspectorWhenToUseDefaultOpen) private var inspectorWhenToUseDefaultOpen = false
    @AppStorage(AppSettingsKeys.inspectorNotesDefaultOpen) private var inspectorNotesDefaultOpen = false
    @AppStorage(AppSettingsKeys.inspectorVariablesDefaultOpen) private var inspectorVariablesDefaultOpen = false

    @AppStorage(AppSettingsKeys.searchDefaultSort) private var searchDefaultSort = SortMode.updated.rawValue
    @AppStorage(AppSettingsKeys.searchRememberLastSort) private var searchRememberLastSort = true
    @AppStorage(AppSettingsKeys.searchScope) private var searchScope = "all"
    @AppStorage(AppSettingsKeys.searchBehavior) private var searchBehavior = "contains"
    @AppStorage(AppSettingsKeys.searchClearAfterCreate) private var searchClearAfterCreate = true
    @AppStorage(AppSettingsKeys.searchShowFilterChips) private var searchShowFilterChips = true
    @AppStorage(AppSettingsKeys.searchDefaultTypeFilter) private var searchDefaultTypeFilter = "all"
    @AppStorage(AppSettingsKeys.searchInTitle) private var searchInTitle = true
    @AppStorage(AppSettingsKeys.searchInBody) private var searchInBody = true
    @AppStorage(AppSettingsKeys.searchInNotes) private var searchInNotes = true
    @AppStorage(AppSettingsKeys.searchInMetadata) private var searchInMetadata = true

    @AppStorage(AppSettingsKeys.storageImportFolderBehavior) private var storageImportFolderBehavior = "preserve"
    @AppStorage(AppSettingsKeys.storageDuplicateImportBehavior) private var storageDuplicateImportBehavior = "skip"
    @AppStorage(AppSettingsKeys.storagePreserveSourcePath) private var storagePreserveSourcePath = true
    @AppStorage(AppSettingsKeys.storageAutoBackup) private var storageAutoBackup = false
    @AppStorage(AppSettingsKeys.storageBackupFrequency) private var storageBackupFrequency = "weekly"
    @AppStorage(AppSettingsKeys.storageKeepBackupsFor) private var storageKeepBackupsFor = "30"
    @AppStorage(AppSettingsKeys.storageDefaultExportFormat) private var storageDefaultExportFormat = "markdown"
    @AppStorage(AppSettingsKeys.storageAttachmentMode) private var storageAttachmentMode = "local"

    @AppStorage(AppSettingsKeys.clipboardRawShortcut) private var clipboardRawShortcut = true
    @AppStorage(AppSettingsKeys.clipboardFilledShortcut) private var clipboardFilledShortcut = true
    @AppStorage(AppSettingsKeys.clipboardIncludeTitle) private var clipboardIncludeTitle = false
    @AppStorage(AppSettingsKeys.clipboardIncludeMetadata) private var clipboardIncludeMetadata = false
    @AppStorage(AppSettingsKeys.clipboardPreserveMarkdown) private var clipboardPreserveMarkdown = true
    @AppStorage(AppSettingsKeys.clipboardSuccessFeedback) private var clipboardSuccessFeedback = true
    @AppStorage(AppSettingsKeys.clipboardDefaultCopyMode) private var clipboardDefaultCopyMode = "raw"
    @AppStorage(AppSettingsKeys.clipboardRequireVariables) private var clipboardRequireVariables = true

    @AppStorage(AppSettingsKeys.accessibilityReduceMotion) private var accessibilityReduceMotion = false
    @AppStorage(AppSettingsKeys.accessibilityIncreaseContrast) private var accessibilityIncreaseContrast = false
    @AppStorage(AppSettingsKeys.accessibilityFocusRing) private var accessibilityFocusRing = "standard"
    @AppStorage(AppSettingsKeys.accessibilityKeyboardNavigation) private var accessibilityKeyboardNavigation = true
    @AppStorage(AppSettingsKeys.accessibilityLargerTargets) private var accessibilityLargerTargets = false
    @AppStorage(AppSettingsKeys.accessibilityShowTooltips) private var accessibilityShowTooltips = true
    @AppStorage(AppSettingsKeys.accessibilityReduceTransparency) private var accessibilityReduceTransparency = false


    private var errorPresented: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }

    private var importPreviewPresented: Binding<Bool> {
        Binding(get: { model.importPreview != nil }, set: { if !$0 { model.importPreview = nil } })
    }

    private var appAppearance: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance(rawValue: appAppearanceRaw) ?? .system },
            set: { appAppearanceRaw = $0.rawValue }
        )
    }

    private var accentColor: Binding<AppAccentColor> {
        Binding(
            get: { AppAccentColor(rawValue: accentColorRaw) ?? AppSettingsDefaults.accentColor },
            set: { accentColorRaw = $0.rawValue }
        )
    }

    private var fontScale: Binding<AppFontScale> {
        Binding(
            get: { AppFontScale(rawValue: fontScaleRaw) ?? AppSettingsDefaults.fontScale },
            set: { fontScaleRaw = $0.rawValue }
        )
    }

    private var buttonStyle: Binding<AppButtonVisualStyle> {
        Binding(
            get: { AppButtonVisualStyle(rawValue: buttonStyleRaw) ?? AppSettingsDefaults.buttonStyle },
            set: { buttonStyleRaw = $0.rawValue }
        )
    }

    private var buttonWeight: Binding<AppButtonTextWeight> {
        Binding(
            get: { AppButtonTextWeight(rawValue: buttonWeightRaw) ?? AppSettingsDefaults.buttonTextWeight },
            set: { buttonWeightRaw = $0.rawValue }
        )
    }

    private var buttonSize: Binding<AppButtonSize> {
        Binding(
            get: { AppButtonSize(rawValue: buttonSizeRaw) ?? AppSettingsDefaults.buttonSize },
            set: { buttonSizeRaw = $0.rawValue }
        )
    }

    private var promptListSettings: PromptListDisplaySettings {
        PromptListDisplaySettings(
            showIcons: promptListShowIcons,
            showDescription: promptListShowDescription,
            showMetadata: promptListShowMetadata,
            previewLineCount: promptListPreviewLines,
            truncateLongTitles: promptListTruncateLongTitles,
            rowDensity: PromptListRowDensity(rawValue: promptListRowDensityRaw) ?? AppSettingsDefaults.promptListRowDensity
        )
    }

    private var promptListSettingsBinding: Binding<PromptListDisplaySettings> {
        Binding(
            get: { promptListSettings },
            set: { newValue in
                promptListShowIcons = newValue.showIcons
                promptListShowDescription = newValue.showDescription
                promptListShowMetadata = newValue.showMetadata
                promptListPreviewLines = newValue.previewLineCount
                promptListTruncateLongTitles = newValue.truncateLongTitles
                promptListRowDensityRaw = newValue.rowDensity.rawValue
            }
        )
    }

    private var rightSidebarSections: RightSidebarSectionVisibility {
        RightSidebarSectionVisibility(
            folder: rightSidebarShowFolder,
            promptMetadata: rightSidebarShowPromptMetadata,
            notes: rightSidebarShowNotes,
            metadata: rightSidebarShowMetadata
        )
    }

    private var rightSidebarSectionsBinding: Binding<RightSidebarSectionVisibility> {
        Binding(
            get: { rightSidebarSections },
            set: { newValue in
                rightSidebarShowFolder = newValue.folder
                rightSidebarShowPromptMetadata = newValue.promptMetadata
                rightSidebarShowNotes = newValue.notes
                rightSidebarShowMetadata = newValue.metadata
            }
        )
    }

    private var settingsSnapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(
            accentColor: accentColor.wrappedValue,
            fontScale: fontScale.wrappedValue,
            buttonStyle: buttonStyle.wrappedValue,
            buttonTextWeight: buttonWeight.wrappedValue,
            buttonSize: buttonSize.wrappedValue,
            promptList: promptListSettings,
            rightSidebarSections: rightSidebarSections,
            leftSidebarVisible: leftSidebarVisible,
            rightSidebarVisible: rightDetailsSidebarVisible,
            promptListWidth: promptListWidthStored,
            detailsSidebarWidth: detailsSidebarWidthStored,
            resizablePanelsEnabled: resizablePanelsEnabled
        )
    }


    private var editorBehaviorSettings: EditorBehaviorSettings {
        EditorBehaviorSettings(markdownHighlighting: editorMarkdownHighlighting, lineWrap: editorLineWrap, showWordCount: editorShowWordCount, autosaveTyping: editorAutosaveTyping, saveFeedback: editorSaveFeedback, titleFieldSize: editorTitleFieldSize, actionLabelMode: editorActionLabelMode, defaultFormat: editorDefaultFormat)
    }

    private var variableBehaviorSettings: VariablePromptBehaviorSettings {
        VariablePromptBehaviorSettings(showPanel: variablesShowPanel, panelWidth: variablesPanelWidth, fieldDefaultHeight: variablesFieldDefaultHeight, rememberFieldHeights: variablesRememberFieldHeights, showRequiredCount: variablesShowRequiredCount, actionRowStyle: variablesActionRowStyle, copyFilledVisible: variablesCopyFilledVisible, presetsEnabled: variablesPresetsEnabled, defaultType: variablesDefaultType, insertFormat: variablesInsertFormat, autoDetect: variablesAutoDetect, highlight: variablesHighlight, requireDescriptions: variablesRequireDescriptions, sortBy: variablesSortBy)
    }

    private var searchBehaviorSettings: SearchBehaviorSettings {
        SearchBehaviorSettings(scope: searchScope, behavior: searchBehavior, searchInTitle: searchInTitle, searchInBody: searchInBody, searchInNotes: searchInNotes, searchInMetadata: searchInMetadata)
    }

    private var clipboardBehaviorSettings: ClipboardBehaviorSettings {
        ClipboardBehaviorSettings(rawShortcut: clipboardRawShortcut, filledShortcut: clipboardFilledShortcut, includeTitle: clipboardIncludeTitle, includeMetadata: clipboardIncludeMetadata, preserveMarkdown: clipboardPreserveMarkdown, successFeedback: clipboardSuccessFeedback, defaultCopyMode: clipboardDefaultCopyMode, requireVariables: clipboardRequireVariables)
    }

    private var importExportBehaviorSettings: ImportExportBehaviorSettings {
        ImportExportBehaviorSettings(importFolderBehavior: storageImportFolderBehavior, duplicateImportBehavior: storageDuplicateImportBehavior, preserveSourcePath: storagePreserveSourcePath, defaultExportFormat: storageDefaultExportFormat, autoBackup: storageAutoBackup, backupFrequency: storageBackupFrequency, keepBackupsFor: storageKeepBackupsFor, attachmentMode: storageAttachmentMode)
    }

    private var runtimeSettings: AppRuntimeSettings {
        AppRuntimeSettings(increaseContrast: accessibilityIncreaseContrast, reduceTransparency: accessibilityReduceTransparency, largerTargets: accessibilityLargerTargets, reduceMotion: accessibilityReduceMotion, focusRing: accessibilityFocusRing, showTooltips: accessibilityShowTooltips)
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = AppLayoutMetrics(
                containerWidth: proxy.size.width,
                leftSidebarVisible: leftSidebarVisible,
                rightDetailsSidebarVisible: rightDetailsSidebarVisible,
                detailsWidth: CGFloat(detailsSidebarWidthStored),
                resizablePanelsEnabled: resizablePanelsEnabled
            )
            let promptListWidth = metrics.clampedPromptListWidth(CGFloat(promptListWidthStored))
            VStack(spacing: 0) {
                ToolbarView(
                    searchQuery: $model.searchQuery,
                    sortMode: $model.sortMode,
                    appearance: appAppearance,
                    metrics: metrics,
                    newPromptTitle: newEntryTitle,
                    saveStatus: model.saveStatus,
                    leftSidebarVisible: $leftSidebarVisible,
                    rightDetailsSidebarVisible: $rightDetailsSidebarVisible,
                    onNewPrompt: requestNewEntry,
                    onNewChain: requestNewChain,
                    onNewFolder: { model.createFolder() },
                    onImport: { applyRuntimeSettings(); openImportPanel() },
                    onExport: { applyRuntimeSettings(); showingExport = true },
                    onAudit: { model.runMetadataAudit(); showingAudit = true },
                    onSettings: { showingSettings = true }
                )
                Divider().overlay(DT.ColorToken.borderDefault)
                if showingSettings {
                    SettingsView(
                        appearance: appAppearance,
                        accentColor: accentColor,
                        fontScale: fontScale,
                        buttonStyle: buttonStyle,
                        buttonWeight: buttonWeight,
                        buttonSize: buttonSize,
                        leftSidebarVisible: $leftSidebarVisible,
                        rightSidebarVisible: $rightDetailsSidebarVisible,
                        promptListWidth: $promptListWidthStored,
                        detailsSidebarWidth: $detailsSidebarWidthStored,
                        resizablePanelsEnabled: $resizablePanelsEnabled,
                        promptListSettings: promptListSettingsBinding,
                        rightSidebarSections: rightSidebarSectionsBinding,
                        sortMode: $model.sortMode,
                        promptCount: model.activePrompts.count + model.activePhrases.count,
                        folderCount: model.folders.count,
                        onBack: { applyRuntimeSettings(); persistSession(); showingSettings = false },
                        onSaveSettings: { model.saveStatus = "Settings saved \(Date().formatted(date: .omitted, time: .shortened))" },
                        onResetLayout: resetLayoutSettings,
                        onResetAppearance: resetAppearanceSettings,
                        onResetPromptList: resetPromptListSettings,
                        onResetSidebarSections: resetRightSidebarSections
                    )
                } else {
                    HStack(spacing: 0) {
                        if leftSidebarVisible {
                            LibrarySidebarView(model: model, onSettings: { showingSettings = true })
                                .frame(width: metrics.sidebarWidth)
                            ColumnDivider()
                        }
                        contentColumns(metrics: metrics, promptListWidth: promptListWidth)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(AppSurface.background)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowConfigurator(
            rememberSize: generalRememberWindowSize,
            shouldClose: { !model.hasUnsavedPromptChanges || editorAutosaveTyping },
            onCloseBlocked: { showingUnsavedQuitConfirmation = true }
        ).frame(width: 0, height: 0))
        .appSettingsEnvironment(settingsSnapshot, runtime: runtimeSettings)
        .alert("Delete Prompt?", isPresented: $showingDeleteConfirmation, presenting: pendingDeletePrompt) { prompt in
            Button("Archive", role: .destructive) { model.archivePrompt(prompt); pendingDeletePrompt = nil }
            Button("Cancel", role: .cancel) { pendingDeletePrompt = nil }
        } message: { prompt in
            Text("\"\(prompt.title)\" will be hidden from normal library views.")
        }
        .alert("Prompt Manager Error", isPresented: errorPresented) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .alert("Unsaved Prompt Changes", isPresented: $showingUnsavedNavigationConfirmation) {
            Button("Save") { continuePendingNavigation(saveFirst: true) }
            Button("Discard", role: .destructive) { continuePendingNavigation(saveFirst: false) }
            Button("Cancel", role: .cancel) { pendingSelection = nil }
        } message: {
            Text("Save your current prompt changes before switching?")
        }
        .alert("Unsaved Prompt Changes", isPresented: $showingUnsavedQuitConfirmation) {
            Button("Save and Quit") {
                model.save()
                NSApplication.shared.terminate(nil)
            }
            Button("Discard and Quit", role: .destructive) {
                model.discardUnsavedChanges()
                NSApplication.shared.terminate(nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save your current prompt changes before quitting?")
        }
        .sheet(isPresented: importPreviewPresented) {
            if let preview = model.importPreview {
                ImportReviewSheet(preview: preview, onCancel: { model.importPreview = nil }, onConfirm: model.confirmImportPreview)
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportSheet(selectedTitle: model.selectedPrompt?.title, onExport: export, onCancel: { showingExport = false })
        }
        .sheet(isPresented: $showingAudit) {
            AuditReportSheet(report: model.auditReport, onCopy: { ClipboardService.copy(model.auditReport) }, onExport: exportAudit, onClose: { showingAudit = false })
        }
        .onAppear { applyRuntimeSettings(); restoreSessionIfNeeded() }
        .preferredColorScheme((AppAppearance(rawValue: appAppearanceRaw) ?? .system).colorScheme)
        .focusedValue(\.promptCommandActions, AppCommandActions(
            newPrompt: requestNewEntry,
            newFolder: { model.createFolder() },
            save: model.save,
            duplicate: { if let prompt = model.selectedPrompt { model.duplicatePrompt(prompt) } },
            delete: { if let prompt = model.selectedPrompt { requestArchive(prompt) } },
            copyPrompt: { if let prompt = model.selectedPrompt { applyRuntimeSettings(); model.copyPrompt(prompt) } },
            hasSelectedPrompt: model.selectedPrompt != nil
        ))
    }


    @ViewBuilder
    private func contentColumns(metrics: AppLayoutMetrics, promptListWidth: CGFloat) -> some View {
        if model.librarySection == .chains {
            chainColumns(metrics: metrics, promptListWidth: promptListWidth)
        } else {
            promptColumns(metrics: metrics, promptListWidth: promptListWidth)
        }
    }

    @ViewBuilder
    private func divider(metrics: AppLayoutMetrics, promptListWidth: CGFloat) -> some View {
        if resizablePanelsEnabled {
            ResizableColumnDivider(
                currentWidth: promptListWidth,
                minWidth: metrics.promptListMinWidth,
                maxWidth: metrics.promptListMaxWidth,
                onResize: { promptListWidthStored = Double(metrics.clampedPromptListWidth($0)) }
            )
            .frame(width: metrics.promptListDividerWidth)
        } else {
            ColumnDivider()
        }
    }

    @ViewBuilder
    private func chainColumns(metrics: AppLayoutMetrics, promptListWidth: CGFloat) -> some View {
        ChainListView(chains: model.visibleChains, selectedChainID: model.selectedChain?.id, onSelect: model.selectChain, onNew: requestNewChain)
            .frame(width: promptListWidth)
        divider(metrics: metrics, promptListWidth: promptListWidth)
        if let chain = model.bindingForSelectedChain() {
            ChainBuilderView(
                chain: chain,
                prompts: model.prompts,
                previousOutputs: { step in
                    step.variableBindings.contains { $0.inputType == .loopFeedbackFile }
                        ? model.latestOutputs(for: chain.wrappedValue)
                        : model.previousOutputs(for: chain.wrappedValue, before: step)
                },
                onSave: model.saveSelectedChain,
                onRunChain: model.startRunSelectedChain,
                onRunLoop: model.startRunSelectedLoop,
                onStopChain: model.cancelSelectedChainRun,
                onOpenOutputFolder: openSelectedChainOutputFolder,
                onAddStep: { model.addStepToSelectedChain() },
                onRunStep: model.startRunStep,
                onStopStep: model.cancelStepRun,
                onSaveStepMarkdown: saveChainStepMarkdown,
                onRemoveStep: model.removeStep,
                onDelete: model.archiveSelectedChain,
                onPromptChange: { stepID, promptID in model.updateStepPrompt(chainID: chain.wrappedValue.id, stepID: stepID, promptID: promptID) },
                onBindingChange: { stepID, binding in model.updateBinding(chainID: chain.wrappedValue.id, stepID: stepID, binding: binding) },
                onProviderModelChange: { stepID, provider, modelID in model.updateStepProvider(chainID: chain.wrappedValue.id, stepID: stepID, providerKind: provider, modelID: modelID) },
                onOutputPolicyChange: { stepID, policy in model.updateStepOutputPolicy(chainID: chain.wrappedValue.id, stepID: stepID, outputPolicy: policy) },
                onFinalOutputTagChange: { stepID, tagName in model.updateStepFinalOutputTag(chainID: chain.wrappedValue.id, stepID: stepID, tagName: tagName) },
                onOutputFileOptionsChange: { stepID, fileName, outputFilePath, overwrite in model.updateStepOutputFileOptions(chainID: chain.wrappedValue.id, stepID: stepID, fileName: fileName, outputFilePath: outputFilePath, overwrite: overwrite) },
                onChooseOutputFile: chooseChainStepOutputFile,
                onLoopChange: { startID, endID, loopCount, monitorRules in
                    model.updateChainLoop(chainID: chain.wrappedValue.id, startStepID: startID, endStepID: endID, loopCount: loopCount)
                    model.updateChainMonitorRules(chainID: chain.wrappedValue.id, rules: monitorRules)
                },
                onToggleStepCollapsed: { stepID in model.toggleChainStepCollapsed(chainID: chain.wrappedValue.id, stepID: stepID) },
                chainOutputFolderURL: { model.chainOutputFolderURL(for: $0) },
                latestStepRun: model.latestStepRun,
                latestCompletedStepRun: model.latestCompletedStepRun,
                latestOutput: model.latestStepOutput,
                latestError: model.latestStepError,
                stepRunCount: { model.stepRunCount(for: $0) }
            )
            .frame(minWidth: metrics.editorMinWidth(forPromptListWidth: promptListWidth), maxWidth: .infinity)
            if rightDetailsSidebarVisible {
                ColumnDivider()
                ChainRunInspectorView(
                    chain: model.selectedChain,
                    selectedStep: model.selectedChainStep,
                    providers: model.aiProviders,
                    chainRuns: model.chainRuns,
                    onCollapsedPreviewLineChange: { lineCount in
                        guard let id = model.selectedChainID else { return }
                        model.updateChainCollapsedPreviewLines(chainID: id, lineCount: lineCount)
                    },
                    onChooseOutputFolder: chooseSelectedChainOutputFolder
                )
                    .frame(width: metrics.detailsWidth)
            }
        } else {
            EmptyChainBuilderView(onNewChain: requestNewChain)
                .frame(minWidth: metrics.editorMinWidth(forPromptListWidth: promptListWidth), maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func promptColumns(metrics: AppLayoutMetrics, promptListWidth: CGFloat) -> some View {
        PromptListView(
            prompts: model.visiblePrompts,
            selectedPromptID: model.selectedPrompt?.id,
            filters: $model.metadataFilters,
            section: model.librarySection,
            categories: model.availableCategories,
            subcategories: model.availableSubcategories,
            displaySettings: promptListSettings,
            showFilterChips: searchShowFilterChips,
            onSelect: requestSelectPrompt,
            onCopy: model.copyPrompt,
            onDuplicate: model.duplicatePrompt,
            onArchive: requestArchive
        )
        .frame(width: promptListWidth)
        divider(metrics: metrics, promptListWidth: promptListWidth)
        if let prompt = model.bindingForSelectedPrompt() {
            PromptEditorView(
                prompt: prompt,
                copied: model.copiedPromptID == prompt.wrappedValue.id,
                onSave: model.save,
                onCopy: { applyRuntimeSettings(); model.copyPrompt(prompt.wrappedValue) },
                onArchive: { requestArchive(prompt.wrappedValue) },
                editorSettings: editorBehaviorSettings,
                variableSettings: variableBehaviorSettings,
                variableRunner: AnyView(
                    VariablePromptRunnerView(
                        prompt: prompt,
                        onRun: { model.startRunVariablePrompt(prompt.wrappedValue.id) },
                        onStop: { model.cancelVariablePromptRun(prompt.wrappedValue.id) },
                        onSaveMarkdown: { model.saveVariablePromptMarkdown(prompt.wrappedValue.id) },
                        latestRun: { stepID in model.latestVariablePromptRun(promptID: prompt.wrappedValue.id, stepID: stepID) },
                        latestOutput: { stepID in model.latestVariablePromptRun(promptID: prompt.wrappedValue.id, stepID: stepID)?.outputText },
                        latestError: { stepID in model.latestVariablePromptRun(promptID: prompt.wrappedValue.id, stepID: stepID)?.errorMessage },
                        stepRunCount: { stepID in model.chainRuns.reduce(0) { $0 + $1.stepRuns.filter { $0.stepID == stepID }.count } }
                    )
                ),
                onVariableTokenClick: { key in
                    expandedVariableKey = key
                    rightDetailsSidebarVisible = true
                }
            )
            .frame(minWidth: metrics.editorMinWidth(forPromptListWidth: promptListWidth), maxWidth: .infinity)
            if rightDetailsSidebarVisible {
                ColumnDivider()
                DetailsSidebarView(
                    prompt: prompt,
                    folders: model.folders,
                    categories: model.availableCategories,
                    subcategories: model.availableSubcategories,
                    filledCopyMessage: model.filledCopyMessage,
                    sectionVisibility: rightSidebarSections,
                    variableSettings: variableBehaviorSettings,
                    whenToUseDefaultOpen: inspectorWhenToUseDefaultOpen,
                    notesDefaultOpen: inspectorNotesDefaultOpen,
                    variablesDefaultOpen: inspectorVariablesDefaultOpen,
                    expandedVariableKey: $expandedVariableKey,
                    onSave: model.save,
                    onCopyFilled: { values in applyRuntimeSettings(); return model.copyFilledPrompt(prompt.wrappedValue, values: values) },
                    onMoveToFolder: { model.moveSelectedPrompt(to: $0) }
                )
                .frame(width: metrics.detailsWidth)
            }
        } else {
            EmptyEditorView(onNewPrompt: requestNewEntry, mode: model.librarySection, variableMode: model.selection == .variablePrompts)
                .frame(minWidth: metrics.editorMinWidth(forPromptListWidth: promptListWidth), maxWidth: .infinity)
        }
    }

    private func requestArchive(_ prompt: Prompt) {
        if generalConfirmDestructiveActions {
            pendingDeletePrompt = prompt
            showingDeleteConfirmation = true
        } else {
            model.archivePrompt(prompt)
        }
    }

    private func requestNewChain() {
        guard model.hasUnsavedPromptChanges && !editorAutosaveTyping else {
            model.createChainDraft()
            return
        }
        pendingSelection = .newEntry
        showingUnsavedNavigationConfirmation = true
    }

    private func requestNewEntry() {
        guard model.hasUnsavedPromptChanges && !editorAutosaveTyping else {
            createEntryForCurrentMode()
            return
        }
        pendingSelection = .newEntry
        showingUnsavedNavigationConfirmation = true
    }

    private func requestSelectPrompt(_ prompt: Prompt) {
        guard model.selectedPromptID != prompt.id else {
            model.selectPrompt(prompt)
            return
        }
        guard model.hasUnsavedPromptChanges && !editorAutosaveTyping else {
            model.selectPrompt(prompt)
            return
        }
        pendingSelection = .selectPrompt(prompt.id)
        showingUnsavedNavigationConfirmation = true
    }

    private func continuePendingNavigation(saveFirst: Bool) {
        let action = pendingSelection
        pendingSelection = nil
        if saveFirst { model.save() } else { model.discardUnsavedChanges() }
        switch action {
        case .selectPrompt(let id):
            if let prompt = model.prompts.first(where: { $0.id == id }) { model.selectPrompt(prompt) }
        case .newEntry:
            createEntryForCurrentMode()
        case nil:
            break
        }
    }

    private func createEntryForCurrentMode() {
        if model.librarySection == .chains {
            model.librarySection = .prompts
            model.selection = .all
            model.createPrompt()
        } else {
            model.librarySection == .phrases ? model.createPhrase() : model.createPrompt()
        }
    }


    private func applyRuntimeSettings() {
        model.searchSettings = searchBehaviorSettings
        model.clipboardSettings = clipboardBehaviorSettings
        model.importExportSettings = importExportBehaviorSettings
        model.clearSearchAfterCreate = searchClearAfterCreate
        model.defaultVariableType = VariableInputType(rawValue: variablesDefaultType) ?? .textarea
        model.autoDetectVariables = variablesAutoDetect
        if searchRememberLastSort, let sort = SortMode(rawValue: sessionLastSort) { model.sortMode = sort }
    }

    private func restoreSessionIfNeeded() {
        applyRuntimeSettings()
        if searchRememberLastSort, let sort = SortMode(rawValue: sessionLastSort) { model.sortMode = sort }
        else if let sort = SortMode(rawValue: searchDefaultSort) { model.sortMode = sort }
        if generalRememberSelectedFolder || generalLaunchSection == "last" { restoreSelection(sessionLastSelection) }
        else { restoreSelection(generalLaunchSection) }
        if generalOpenLastPrompt, let id = UUID(uuidString: sessionLastPromptID), model.prompts.contains(where: { $0.id == id && !$0.isArchived }) { model.selectedPromptID = id }
        if let type = PromptTypeFilter(rawValue: searchDefaultTypeFilter), searchDefaultTypeFilter != "all" { model.metadataFilters.type = type }
    }

    private func persistSession() {
        sessionLastPromptID = model.selectedPromptID?.uuidString ?? ""
        sessionLastSelection = selectionKey(model.selection)
        sessionLastSection = model.librarySection.rawValue
        sessionLastSort = model.sortMode.rawValue
    }

    private func selectionKey(_ selection: LibrarySelection) -> String {
        switch selection {
        case .all: return "all"
        case .favorites: return "favorites"
        case .recent: return "recent"
        case .templates: return "templates"
        case .variablePrompts: return model.librarySection == .chains ? "chains" : "variables"
        case .folder(let id): return "folder:\(id.uuidString)"
        }
    }

    private func restoreSelection(_ key: String) {
        switch key {
        case "favorites": model.selection = .favorites; model.librarySection = .prompts
        case "recent": model.selection = .recent; model.librarySection = .prompts
        case "templates": model.selection = .templates; model.librarySection = .prompts
        case "variables": model.selection = .variablePrompts; model.librarySection = .prompts
        case "chains": model.selection = .all; model.librarySection = .chains
        case let folder where folder.hasPrefix("folder:"):
            if let id = UUID(uuidString: String(folder.dropFirst(7))), model.folders.contains(where: { $0.id == id }) { model.selection = .folder(id) }
        default: model.selection = .all; model.librarySection = .prompts
        }
    }

    private var newEntryTitle: String {
        if model.librarySection == .phrases { return "New Phrase" }
        if model.selection == .variablePrompts || model.metadataFilters.type == .variablePrompt { return "New Variable Prompt" }
        return "New Prompt"
    }

    private func resetLayoutSettings() {
        leftSidebarVisible = AppSettingsDefaults.leftSidebarVisible
        rightDetailsSidebarVisible = AppSettingsDefaults.rightSidebarVisible
        promptListWidthStored = AppSettingsDefaults.promptListWidth
        detailsSidebarWidthStored = AppSettingsDefaults.detailsSidebarWidth
        resizablePanelsEnabled = AppSettingsDefaults.resizablePanelsEnabled
        model.saveStatus = "Layout reset"
    }

    private func resetAppearanceSettings() {
        appAppearanceRaw = AppAppearance.system.rawValue
        accentColorRaw = AppSettingsDefaults.accentColor.rawValue
        fontScaleRaw = AppSettingsDefaults.fontScale.rawValue
        buttonStyleRaw = AppSettingsDefaults.buttonStyle.rawValue
        buttonWeightRaw = AppSettingsDefaults.buttonTextWeight.rawValue
        buttonSizeRaw = AppSettingsDefaults.buttonSize.rawValue
        model.saveStatus = "Appearance reset"
    }

    private func resetPromptListSettings() {
        promptListShowIcons = AppSettingsDefaults.promptListShowIcons
        promptListShowDescription = AppSettingsDefaults.promptListShowDescription
        promptListShowMetadata = AppSettingsDefaults.promptListShowMetadata
        promptListPreviewLines = AppSettingsDefaults.promptListPreviewLines
        promptListTruncateLongTitles = AppSettingsDefaults.promptListTruncateLongTitles
        promptListRowDensityRaw = AppSettingsDefaults.promptListRowDensity.rawValue
        model.saveStatus = "Prompt list settings reset"
    }

    private func resetRightSidebarSections() {
        rightSidebarShowFolder = AppSettingsDefaults.rightSidebarShowFolder
        rightSidebarShowPromptMetadata = AppSettingsDefaults.rightSidebarShowPromptMetadata
        rightSidebarShowNotes = AppSettingsDefaults.rightSidebarShowNotes
        rightSidebarShowMetadata = AppSettingsDefaults.rightSidebarShowMetadata
        model.saveStatus = "Inspector sections reset"
    }

    private func openImportPanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        if panel.runModal() == .OK, let url = panel.url { model.prepareImport(from: url) }
        #endif
    }

    private func export(_ scope: PromptExportScope) {
        let prompts = exportPrompts(for: scope)
        do {
            let data: Data
            let name: String
            if scope == .backup || storageDefaultExportFormat == "json" {
                data = try PromptExportService.backupData(library: PromptLibrary(prompts: prompts, folders: model.folders, importBatches: model.importBatches))
                name = "saved-pixel-\(scope.rawValue.slugKey)-export.json"
            } else if storageDefaultExportFormat == "txt" {
                data = prompts.map { $0.content }.joined(separator: "\n\n---\n\n").data(using: .utf8) ?? Data()
                name = "saved-pixel-\(scope.rawValue.slugKey).txt"
            } else {
                data = PromptExportService.markdownCollection(for: prompts).data(using: .utf8) ?? Data()
                name = "saved-pixel-\(scope.rawValue.slugKey).md"
            }
            saveData(data, suggestedName: name)
            showingExport = false
        } catch { model.errorMessage = error.localizedDescription }
    }

    private func exportAudit() {
        saveData(model.auditReport.data(using: .utf8) ?? Data(), suggestedName: "saved-pixel-metadata-audit.md")
    }

    private func exportPrompts(for scope: PromptExportScope) -> [Prompt] {
        switch scope {
        case .selected:
            return model.selectedPrompt.map { [$0] } ?? []
        case .currentFolder:
            return model.visiblePrompts
        case .currentCategory:
            guard model.metadataFilters.category != nil else { return model.visiblePrompts }
            return model.visiblePrompts
        case .all, .backup:
            return model.prompts.filter { !$0.isArchived }
        }
    }

    private func saveData(_ data: Data, suggestedName: String) {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        if panel.runModal() == .OK, let url = panel.url {
            do { try data.write(to: url, options: [.atomic]); model.saveStatus = "Exported \(url.lastPathComponent)" }
            catch { model.errorMessage = error.localizedDescription }
        }
        #endif
    }

    private func saveChainStepMarkdown(_ stepID: UUID) {
        do {
            let export = try model.markdownExportForStep(stepID)
            #if os(macOS)
            let panel = NSSavePanel()
            panel.nameFieldStringValue = export.suggestedFileName
            panel.title = "Save Markdown"
            panel.message = "Choose where to save this chained prompt/output Markdown file."
            if panel.runModal() == .OK, let url = panel.url {
                if let chainID = model.selectedChainID {
                    model.updateStepOutputFileOptions(chainID: chainID, stepID: stepID, fileName: url.lastPathComponent, outputFilePath: url.path)
                }
                model.saveStepMarkdown(stepID)
                model.saveStatus = "Exported \(url.lastPathComponent)"
            }
            #else
            model.saveStepMarkdown(stepID)
            #endif
        } catch {
            model.errorMessage = error.localizedDescription
            model.saveStatus = "Save failed"
        }
    }

    private func chooseChainStepOutputFile(_ stepID: UUID) {
        guard let chain = model.selectedChain,
              let step = chain.steps.first(where: { $0.id == stepID }) else { return }
        #if os(macOS)
        let attachment = step.variableBindings.compactMap(\.fileAttachment).first
        let suggestedName = ChainOutputStore.configuredOutputFileName(for: step, attachment: attachment)
        let panel = NSSavePanel()
        panel.title = "Choose Output Markdown File"
        panel.message = "Choose the exact folder and filename this step should save to every time it runs."
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        let existingPath = step.customOutputFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existingPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: existingPath).deletingLastPathComponent()
            panel.nameFieldStringValue = URL(fileURLWithPath: existingPath).lastPathComponent
        } else {
            panel.directoryURL = model.chainOutputFolderURL(for: chain)
        }
        if panel.runModal() == .OK, let url = panel.url {
            model.updateStepOutputFileOptions(chainID: chain.id, stepID: stepID, fileName: url.lastPathComponent, outputFilePath: url.path)
            model.saveStatus = "Output file selected"
        }
        #endif
    }

    private func openSelectedChainOutputFolder() {
        guard let chain = model.selectedChain else { return }
        let url = model.chainOutputFolderURL(for: chain)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            #if os(macOS)
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
            #endif
            model.saveStatus = "Opened outputs"
        } catch {
            model.errorMessage = error.localizedDescription
            model.saveStatus = "Open failed"
        }
    }

    private func chooseSelectedChainOutputFolder() {
        guard let chainID = model.selectedChainID else { return }
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Choose Chain Output Folder"
        panel.message = "Select the folder where this chain should save Markdown outputs."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            model.updateChainOutputFolder(chainID: chainID, path: url.path)
            model.saveStatus = "Unsaved chain changes"
        }
        #endif
    }
}

struct AppLayoutMetrics {
    let containerWidth: CGFloat
    let leftSidebarVisible: Bool
    let rightDetailsSidebarVisible: Bool
    let detailsWidthSetting: CGFloat
    let resizablePanelsEnabled: Bool

    init(containerWidth: CGFloat, leftSidebarVisible: Bool = true, rightDetailsSidebarVisible: Bool = true, detailsWidth: CGFloat = DT.Size.detailsWidth, resizablePanelsEnabled: Bool = true) {
        self.containerWidth = containerWidth
        self.leftSidebarVisible = leftSidebarVisible
        self.rightDetailsSidebarVisible = rightDetailsSidebarVisible
        self.detailsWidthSetting = detailsWidth
        self.resizablePanelsEnabled = resizablePanelsEnabled
    }

    var scale: CGFloat { min(1, max(0.84, containerWidth / 1440)) }
    var sidebarWidth: CGFloat { round(DT.Size.sidebarWidth * scale) }
    var promptListWidth: CGFloat { round(DT.Size.promptListWidth * scale) }
    var promptListMinWidth: CGFloat { round(DT.Size.promptListMinWidth * scale) }
    var promptListMaxWidth: CGFloat {
        let absoluteMax = round(DT.Size.promptListMaxWidth * scale)
        let availableMax = containerWidth - visibleSidebarWidth - visibleDetailsWidth - DT.Size.editorMinWidth - visibleDividerWidth
        return max(promptListMinWidth, min(absoluteMax, availableMax))
    }
    var detailsWidth: CGFloat { round(min(max(detailsWidthSetting, 260), 420) * scale) }
    var visibleSidebarWidth: CGFloat { leftSidebarVisible ? sidebarWidth : 0 }
    var visibleDetailsWidth: CGFloat { rightDetailsSidebarVisible ? detailsWidth : 0 }
    var promptListDividerWidth: CGFloat { 1 }
    var visibleDividerWidth: CGFloat { promptListDividerWidth + (leftSidebarVisible ? 1 : 0) + (rightDetailsSidebarVisible ? 1 : 0) }
    var compactToolbar: Bool { containerWidth < 1320 }

    func clampedPromptListWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, promptListMinWidth), promptListMaxWidth)
    }

    func editorMinWidth(forPromptListWidth promptListWidth: CGFloat) -> CGFloat {
        let available = containerWidth - visibleSidebarWidth - promptListWidth - visibleDetailsWidth - visibleDividerWidth
        return max(320, min(DT.Size.editorMinWidth, available))
    }
}

struct ColumnDivider: View { var body: some View { Rectangle().fill(DT.ColorToken.borderDefault).frame(width: 1) } }

#if os(macOS)
struct ResizableColumnDivider: NSViewRepresentable {
    let currentWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let onResize: (CGFloat) -> Void

    func makeNSView(context: Context) -> PromptListResizeHandleView {
        let view = PromptListResizeHandleView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: PromptListResizeHandleView, context: Context) {
        nsView.currentWidth = currentWidth
        nsView.minWidth = minWidth
        nsView.maxWidth = maxWidth
        nsView.onResize = onResize
        nsView.needsDisplay = true
    }
}

final class PromptListResizeHandleView: NSView {
    var currentWidth: CGFloat = DT.Size.promptListWidth
    var minWidth: CGFloat = DT.Size.promptListMinWidth
    var maxWidth: CGFloat = DT.Size.promptListMaxWidth
    var onResize: (CGFloat) -> Void = { _ in }

    private var startWidth: CGFloat = DT.Size.promptListWidth
    private var startX: CGFloat = 0
    private var hovering = false

    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
        setAccessibilityRole(.splitter)
        setAccessibilityLabel("Resize prompt list")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setAccessibilityRole(.splitter)
        setAccessibilityLabel("Resize prompt list")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        startWidth = currentWidth
        startX = event.locationInWindow.x
    }

    override func mouseDragged(with event: NSEvent) {
        let x = event.locationInWindow.x
        let proposedWidth = startWidth + (x - startX)
        onResize(Swift.min(Swift.max(proposedWidth, minWidth), maxWidth))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        NSBezierPath(rect: dirtyRect).fill()
        let lineWidth: CGFloat = 1
        let lineRect = NSRect(x: (bounds.width - lineWidth) / 2, y: 0, width: lineWidth, height: bounds.height)
        NSColor.separatorColor.setFill()
        NSBezierPath(rect: lineRect).fill()
    }
}
#else
struct ResizableColumnDivider: View {
    let currentWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let onResize: (CGFloat) -> Void
    @State private var startWidth: CGFloat?


    private var editorBehaviorSettings: EditorBehaviorSettings {
        EditorBehaviorSettings(markdownHighlighting: editorMarkdownHighlighting, lineWrap: editorLineWrap, showWordCount: editorShowWordCount, autosaveTyping: editorAutosaveTyping, saveFeedback: editorSaveFeedback, titleFieldSize: editorTitleFieldSize, actionLabelMode: editorActionLabelMode, defaultFormat: editorDefaultFormat)
    }

    private var variableBehaviorSettings: VariablePromptBehaviorSettings {
        VariablePromptBehaviorSettings(showPanel: variablesShowPanel, panelWidth: variablesPanelWidth, fieldDefaultHeight: variablesFieldDefaultHeight, rememberFieldHeights: variablesRememberFieldHeights, showRequiredCount: variablesShowRequiredCount, actionRowStyle: variablesActionRowStyle, copyFilledVisible: variablesCopyFilledVisible, presetsEnabled: variablesPresetsEnabled, defaultType: variablesDefaultType, insertFormat: variablesInsertFormat, autoDetect: variablesAutoDetect, highlight: variablesHighlight, requireDescriptions: variablesRequireDescriptions, sortBy: variablesSortBy)
    }

    private var searchBehaviorSettings: SearchBehaviorSettings {
        SearchBehaviorSettings(scope: searchScope, behavior: searchBehavior, searchInTitle: searchInTitle, searchInBody: searchInBody, searchInNotes: searchInNotes, searchInMetadata: searchInMetadata)
    }

    private var clipboardBehaviorSettings: ClipboardBehaviorSettings {
        ClipboardBehaviorSettings(rawShortcut: clipboardRawShortcut, filledShortcut: clipboardFilledShortcut, includeTitle: clipboardIncludeTitle, includeMetadata: clipboardIncludeMetadata, preserveMarkdown: clipboardPreserveMarkdown, successFeedback: clipboardSuccessFeedback, defaultCopyMode: clipboardDefaultCopyMode, requireVariables: clipboardRequireVariables)
    }

    private var importExportBehaviorSettings: ImportExportBehaviorSettings {
        ImportExportBehaviorSettings(importFolderBehavior: storageImportFolderBehavior, duplicateImportBehavior: storageDuplicateImportBehavior, preserveSourcePath: storagePreserveSourcePath, defaultExportFormat: storageDefaultExportFormat, autoBackup: storageAutoBackup, backupFrequency: storageBackupFrequency, keepBackupsFor: storageKeepBackupsFor, attachmentMode: storageAttachmentMode)
    }

    private var runtimeSettings: AppRuntimeSettings {
        AppRuntimeSettings(increaseContrast: accessibilityIncreaseContrast, reduceTransparency: accessibilityReduceTransparency, largerTargets: accessibilityLargerTargets, reduceMotion: accessibilityReduceMotion, focusRing: accessibilityFocusRing, showTooltips: accessibilityShowTooltips)
    }

    var body: some View {
        Rectangle()
            .fill(DT.ColorToken.borderDefault)
            .frame(width: 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let base = startWidth ?? currentWidth
                        if startWidth == nil { startWidth = currentWidth }
                        onResize(Swift.min(Swift.max(base + value.translation.width, minWidth), maxWidth))
                    }
                    .onEnded { _ in startWidth = nil }
            )
    }
}
#endif

enum AppSurface {
    static let background = DT.ColorToken.appBackground
    static let primary = DT.ColorToken.surfacePrimary
    static let secondary = DT.ColorToken.surfaceSecondary
    static let tertiary = DT.ColorToken.surfaceTertiary
}
