import SwiftUI

public enum AppSettingsKeys {
    public static let appAppearance = "appAppearance"
    public static let accentColor = "appearance.accentColor"
    public static let fontScale = "appearance.fontScale"
    public static let headingFontWeight = "appearance.headingFontWeight"
    public static let headingFontSize = "appearance.headingFontSize"
    public static let paragraphFontWeight = "appearance.paragraphFontWeight"
    public static let paragraphFontSize = "appearance.paragraphFontSize"
    public static let labelFontWeight = "appearance.labelFontWeight"
    public static let labelFontSize = "appearance.labelFontSize"
    public static let buttonVisualStyle = "appearance.buttonStyle"
    public static let buttonTextWeight = "appearance.buttonWeight"
    public static let buttonSize = "appearance.buttonSize"
    public static let leftSidebarVisible = "leftSidebarVisible"
    public static let rightDetailsSidebarVisible = "rightDetailsSidebarVisible"
    public static let promptListWidth = "promptListWidth"
    public static let detailsSidebarWidth = "layout.detailsSidebarWidth"
    public static let resizablePanelsEnabled = "layout.resizablePanelsEnabled"
    public static let promptListShowIcons = "promptList.showIcons"
    public static let promptListShowDescription = "promptList.showDescription"
    public static let promptListShowMetadata = "promptList.showMetaRow"
    public static let promptListPreviewLines = "promptList.previewLines"
    public static let promptListTruncateLongTitles = "promptList.truncateLongTitles"
    public static let promptListRowDensity = "promptList.rowDensity"
    public static let rightSidebarShowFolder = "rightSidebar.visibleSections.folder"
    public static let rightSidebarShowPromptMetadata = "rightSidebar.visibleSections.promptMetadata"
    public static let rightSidebarShowNotes = "rightSidebar.visibleSections.notes"
    public static let rightSidebarShowMetadata = "rightSidebar.visibleSections.metadata"
    public static let inspectorWhenToUseDefaultOpen = "inspector.accordions.whenToUseDefaultOpen"
    public static let inspectorNotesDefaultOpen = "inspector.accordions.notesDefaultOpen"
    public static let inspectorVariablesDefaultOpen = "inspector.accordions.variablesDefaultOpen"

    public static let generalOpenLastPrompt = "general.openLastPrompt"
    public static let generalRememberWindowSize = "general.rememberWindowSize"
    public static let generalRememberSelectedFolder = "general.rememberSelectedFolder"
    public static let generalConfirmDestructiveActions = "general.confirmDestructiveActions"
    public static let generalAutosaveSettings = "general.autosaveSettings"
    public static let generalLaunchSection = "general.launchSection"
    public static let editorMarkdownHighlighting = "editor.markdownHighlighting"
    public static let editorLineWrap = "editor.lineWrap"
    public static let editorShowWordCount = "editor.showWordCount"
    public static let editorAutosaveTyping = "editor.autosaveTyping"
    public static let editorSaveFeedback = "editor.saveFeedback"
    public static let editorTitleFieldSize = "editor.titleFieldSize"
    public static let editorActionLabelMode = "editor.actionLabelMode"
    public static let editorDefaultFormat = "editor.defaultFormat"
    public static let variablesShowPanel = "variables.showPanel"
    public static let variablesPanelWidth = "variables.panelWidth"
    public static let variablesFieldDefaultHeight = "variables.fieldDefaultHeight"
    public static let variablesRememberFieldHeights = "variables.rememberFieldHeights"
    public static let variablesShowRequiredCount = "variables.showRequiredCount"
    public static let variablesActionRowStyle = "variables.actionRowStyle"
    public static let variablesCopyFilledVisible = "variables.copyFilledVisible"
    public static let variablesPresetsEnabled = "variables.presetsEnabled"
    public static let variablesDefaultType = "variables.defaultType"
    public static let variablesInsertFormat = "variables.insertFormat"
    public static let variablesAutoDetect = "variables.autoDetect"
    public static let variablesHighlight = "variables.highlight"
    public static let variablesRequireDescriptions = "variables.requireDescriptions"
    public static let variablesSortBy = "variables.sortBy"
    public static let librarySidebarShowCounts = "librarySidebar.showCounts"
    public static let librarySidebarShowFolderCounts = "librarySidebar.showFolderCounts"
    public static let librarySidebarShowIcons = "librarySidebar.showIcons"
    public static let librarySidebarFolderIndentation = "librarySidebar.folderIndentation"
    public static let librarySidebarAutoExpand = "librarySidebar.autoExpand"
    public static let librarySidebarRememberExpanded = "librarySidebar.rememberExpanded"
    public static let librarySidebarFooterShortcuts = "librarySidebar.footerShortcuts"
    public static let searchDefaultSort = "search.defaultSort"
    public static let searchRememberLastSort = "search.rememberLastSort"
    public static let searchScope = "search.scope"
    public static let searchBehavior = "search.behavior"
    public static let searchClearAfterCreate = "search.clearAfterCreate"
    public static let searchShowFilterChips = "search.showFilterChips"
    public static let searchDefaultTypeFilter = "search.defaultTypeFilter"
    public static let searchInTitle = "search.inTitle"
    public static let searchInBody = "search.inBody"
    public static let searchInNotes = "search.inNotes"
    public static let searchInMetadata = "search.inMetadata"
    public static let storageLocation = "storage.location"
    public static let storageImportFolderBehavior = "storage.importFolderBehavior"
    public static let storageDuplicateImportBehavior = "storage.duplicateImportBehavior"
    public static let storagePreserveSourcePath = "storage.preserveSourcePath"
    public static let storageAutoBackup = "storage.autoBackup"
    public static let storageBackupFrequency = "storage.backupFrequency"
    public static let storageKeepBackupsFor = "storage.keepBackupsFor"
    public static let storageDefaultExportFormat = "storage.defaultExportFormat"
    public static let storageAttachmentMode = "storage.attachmentMode"
    public static let storageChainMarkdownOutputFolder = "storage.chainMarkdownOutputFolder"
    public static let storageChainOutputIncludeStepPrefix = "storage.chainOutput.includeStepPrefix"
    public static let storageChainOutputIncludeSuffix = "storage.chainOutput.includeSuffix"
    public static let storageChainOutputSuffix = "storage.chainOutput.suffix"
    public static let storageChainOutputShowTagControls = "storage.chainOutput.showTagControls"
    public static let storageChainCollapsedPreviewLines = "storage.chainOutput.collapsedPreviewLines"
    public static let storageVariablePromptRunnerCollapsed = "storage.variablePrompt.runnerCollapsed"
    public static let storageChainCustomStatuses = "storage.chainOutput.customStatuses"
    public static let clipboardRawShortcut = "clipboard.rawShortcut"
    public static let clipboardFilledShortcut = "clipboard.filledShortcut"
    public static let clipboardIncludeTitle = "clipboard.includeTitle"
    public static let clipboardIncludeMetadata = "clipboard.includeMetadata"
    public static let clipboardPreserveMarkdown = "clipboard.preserveMarkdown"
    public static let clipboardSuccessFeedback = "clipboard.successFeedback"
    public static let clipboardDefaultCopyMode = "clipboard.defaultCopyMode"
    public static let clipboardRequireVariables = "clipboard.requireVariables"
    public static let accessibilityReduceMotion = "accessibility.reduceMotion"
    public static let accessibilityIncreaseContrast = "accessibility.increaseContrast"
    public static let accessibilityFocusRing = "accessibility.focusRing"
    public static let accessibilityKeyboardNavigation = "accessibility.keyboardNavigation"
    public static let accessibilityLargerTargets = "accessibility.largerTargets"
    public static let accessibilityShowTooltips = "accessibility.showTooltips"
    public static let accessibilityReduceTransparency = "accessibility.reduceTransparency"
    public static let advancedDiagnosticsIncludeBodies = "advanced.diagnosticsIncludeBodies"
    public static let advancedExperimentalFeatures = "advanced.experimentalFeatures"
    public static let advancedVerboseLogging = "advanced.verboseLogging"
    public static let advancedConfirmPreferenceReset = "advanced.confirmPreferenceReset"
    public static let aiDefaultProvider = "ai.defaultProvider"
    public static let aiDefaultModel = "ai.defaultModel"
    public static let aiMaxTokens = "ai.maxTokens"
    public static let aiTemperature = "ai.temperature"
    public static let aiThinkingMode = "ai.thinkingMode"
    public static let aiStreamingResponses = "ai.streamingResponses"
    public static let aiSaveOutputsByDefault = "ai.saveOutputsByDefault"
    public static let aiConfirmBeforeSending = "ai.confirmBeforeSending"
    public static let aiLastTestStatus = "ai.lastTestStatus"
    public static let aiShowProviderModelOnChainPage = "ai.showProviderModelOnChainPage"
    public static let aiRequestLogMaxEntries = "ai.requestLog.maxEntries"
    public static let aiRequestLogMaxAgeMinutes = "ai.requestLog.maxAgeMinutes"
    public static let settingsLastSection = "settings.lastSection"
    public static let sessionLastPromptID = "session.lastPromptID"
    public static let sessionLastSelection = "session.lastSelection"
    public static let sessionLastSection = "session.lastSection"
    public static let sessionLastSort = "session.lastSort"
    public static let sessionWindowWidth = "session.windowWidth"
    public static let sessionWindowHeight = "session.windowHeight"
    public static let storageCustomLocation = "storage.customLocation"
    public static let diagnosticsLog = "advanced.diagnosticsLog"
    public static let allKeys: [String] = [
        appAppearance,
        accentColor,
        fontScale,
        headingFontWeight,
        headingFontSize,
        paragraphFontWeight,
        paragraphFontSize,
        labelFontWeight,
        labelFontSize,
        buttonVisualStyle,
        buttonTextWeight,
        buttonSize,
        leftSidebarVisible,
        rightDetailsSidebarVisible,
        promptListWidth,
        detailsSidebarWidth,
        resizablePanelsEnabled,
        promptListShowIcons,
        promptListShowDescription,
        promptListShowMetadata,
        promptListPreviewLines,
        promptListTruncateLongTitles,
        promptListRowDensity,
        rightSidebarShowFolder,
        rightSidebarShowPromptMetadata,
        rightSidebarShowNotes,
        rightSidebarShowMetadata,
        inspectorWhenToUseDefaultOpen,
        inspectorNotesDefaultOpen,
        inspectorVariablesDefaultOpen,
        generalOpenLastPrompt,
        generalRememberWindowSize,
        generalRememberSelectedFolder,
        generalConfirmDestructiveActions,
        generalAutosaveSettings,
        generalLaunchSection,
        editorMarkdownHighlighting,
        editorLineWrap,
        editorShowWordCount,
        editorAutosaveTyping,
        editorSaveFeedback,
        editorTitleFieldSize,
        editorActionLabelMode,
        editorDefaultFormat,
        variablesShowPanel,
        variablesPanelWidth,
        variablesFieldDefaultHeight,
        variablesRememberFieldHeights,
        variablesShowRequiredCount,
        variablesActionRowStyle,
        variablesCopyFilledVisible,
        variablesPresetsEnabled,
        variablesDefaultType,
        variablesInsertFormat,
        variablesAutoDetect,
        variablesHighlight,
        variablesRequireDescriptions,
        variablesSortBy,
        librarySidebarShowCounts,
        librarySidebarShowFolderCounts,
        librarySidebarShowIcons,
        librarySidebarFolderIndentation,
        librarySidebarAutoExpand,
        librarySidebarRememberExpanded,
        librarySidebarFooterShortcuts,
        searchDefaultSort,
        searchRememberLastSort,
        searchScope,
        searchBehavior,
        searchClearAfterCreate,
        searchShowFilterChips,
        searchDefaultTypeFilter,
        searchInTitle,
        searchInBody,
        searchInNotes,
        searchInMetadata,
        storageLocation,
        storageImportFolderBehavior,
        storageDuplicateImportBehavior,
        storagePreserveSourcePath,
        storageAutoBackup,
        storageBackupFrequency,
        storageKeepBackupsFor,
        storageDefaultExportFormat,
        storageAttachmentMode,
        storageChainMarkdownOutputFolder,
        storageChainOutputIncludeStepPrefix,
        storageChainOutputIncludeSuffix,
        storageChainOutputSuffix,
        storageChainOutputShowTagControls,
        storageChainCollapsedPreviewLines,
        storageVariablePromptRunnerCollapsed,
        storageChainCustomStatuses,
        clipboardRawShortcut,
        clipboardFilledShortcut,
        clipboardIncludeTitle,
        clipboardIncludeMetadata,
        clipboardPreserveMarkdown,
        clipboardSuccessFeedback,
        clipboardDefaultCopyMode,
        clipboardRequireVariables,
        accessibilityReduceMotion,
        accessibilityIncreaseContrast,
        accessibilityFocusRing,
        accessibilityKeyboardNavigation,
        accessibilityLargerTargets,
        accessibilityShowTooltips,
        accessibilityReduceTransparency,
        advancedDiagnosticsIncludeBodies,
        advancedExperimentalFeatures,
        advancedVerboseLogging,
        advancedConfirmPreferenceReset,
        aiDefaultProvider,
        aiDefaultModel,
        aiMaxTokens,
        aiTemperature,
        aiThinkingMode,
        aiStreamingResponses,
        aiSaveOutputsByDefault,
        aiConfirmBeforeSending,
        aiLastTestStatus,
        aiShowProviderModelOnChainPage,
        aiRequestLogMaxEntries,
        aiRequestLogMaxAgeMinutes,
        settingsLastSection,
        sessionLastPromptID,
        sessionLastSelection,
        sessionLastSection,
        sessionLastSort,
        sessionWindowWidth,
        sessionWindowHeight,
        storageCustomLocation,
        diagnosticsLog
    ]

}


public enum AppSettingEffect: String, Codable, Sendable {
    case appSurface
    case persistence
    case importExport
    case clipboard
    case diagnostics
    case accessibility
}

public struct AppSettingConsumer: Codable, Equatable, Sendable {
    public var key: String
    public var effect: AppSettingEffect
    public var evidence: String

    public init(key: String, effect: AppSettingEffect, evidence: String) {
        self.key = key
        self.effect = effect
        self.evidence = evidence
    }
}

public enum AppSettingsAuditRegistry {
    public static let visibleConsumerKeys: Set<String> = Set(AppSettingsKeys.allKeys).subtracting([
        AppSettingsKeys.sessionLastPromptID,
        AppSettingsKeys.sessionLastSelection,
        AppSettingsKeys.sessionLastSection,
        AppSettingsKeys.sessionLastSort,
        AppSettingsKeys.sessionWindowWidth,
        AppSettingsKeys.sessionWindowHeight,
        AppSettingsKeys.storageCustomLocation,
        AppSettingsKeys.diagnosticsLog
    ])

    public static let consumers: [AppSettingConsumer] = visibleConsumerKeys.map { key in
        let effect: AppSettingEffect
        if key.hasPrefix("clipboard") { effect = .clipboard }
        else if key.hasPrefix("storage") { effect = .importExport }
        else if key.hasPrefix("advanced") { effect = .diagnostics }
        else if key.hasPrefix("accessibility") { effect = .accessibility }
        else if key.hasPrefix("general") || key.hasPrefix("search") { effect = .persistence }
        else { effect = .appSurface }
        return AppSettingConsumer(key: key, effect: effect, evidence: "Wired through Settings functional activation sprint")
    }

    public static var missingVisibleConsumers: [String] {
        let consumerKeys = Set(consumers.map(\.key))
        return visibleConsumerKeys.subtracting(consumerKeys).sorted()
    }
}

public enum AppAccentColor: String, CaseIterable, Identifiable, Sendable {
    case blue
    case purple
    case green
    case orange
    case pink
    case graphite

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .blue: "Blue"
        case .purple: "Purple"
        case .green: "Green"
        case .orange: "Orange"
        case .pink: "Pink"
        case .graphite: "Graphite"
        }
    }

    public var color: Color {
        switch self {
        case .blue: Color(hex: "#0A66E8")
        case .purple: Color(hex: "#7C3AED")
        case .green: Color(hex: "#16A34A")
        case .orange: Color(hex: "#F97316")
        case .pink: Color(hex: "#DB2777")
        case .graphite: Color(hex: "#475467")
        }
    }

    public var hoverColor: Color {
        switch self {
        case .blue: Color(hex: "#075BD1")
        case .purple: Color(hex: "#6D28D9")
        case .green: Color(hex: "#15803D")
        case .orange: Color(hex: "#EA580C")
        case .pink: Color(hex: "#BE185D")
        case .graphite: Color(hex: "#344054")
        }
    }

    public var softColor: Color {
        switch self {
        case .blue: Color(light: "#EAF3FF", dark: "#0B2543")
        case .purple: Color(light: "#F3E8FF", dark: "#2B174F")
        case .green: Color(light: "#DCFCE7", dark: "#10331F")
        case .orange: Color(light: "#FFEDD5", dark: "#3B220D")
        case .pink: Color(light: "#FCE7F3", dark: "#3B1230")
        case .graphite: Color(light: "#F2F4F7", dark: "#202832")
        }
    }

    public var borderColor: Color {
        switch self {
        case .blue: Color(light: "#BFD7FF", dark: "#1E4E86")
        case .purple: Color(light: "#DDD6FE", dark: "#5B21B6")
        case .green: Color(light: "#BBF7D0", dark: "#166534")
        case .orange: Color(light: "#FED7AA", dark: "#9A3412")
        case .pink: Color(light: "#FBCFE8", dark: "#9D174D")
        case .graphite: Color(light: "#D0D5DD", dark: "#475467")
        }
    }
}

public enum AppFontScale: String, CaseIterable, Identifiable, Sendable {
    case compact
    case standard
    case large
    case extraLarge

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .compact: "Compact"
        case .standard: "Default"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    public var scale: CGFloat {
        switch self {
        case .compact: 0.94
        case .standard: 1
        case .large: 1.08
        case .extraLarge: 1.16
        }
    }
}

public enum AppButtonVisualStyle: String, CaseIterable, Identifiable, Sendable {
    case filled
    case soft
    case outline
    case minimal

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .filled: "Filled"
        case .soft: "Soft"
        case .outline: "Outline"
        case .minimal: "Minimal"
        }
    }
}

public enum AppButtonTextWeight: String, CaseIterable, Identifiable, Sendable {
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .light: "Light"
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        case .heavy: "Heavy"
        }
    }

    public var fontWeight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
}

public enum AppTextWeight: String, CaseIterable, Identifiable, Sendable {
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .light: "Light"
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        case .heavy: "Heavy"
        }
    }
    public var fontWeight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
}

public extension String {
    var appTextWeight: Font.Weight {
        (AppTextWeight(rawValue: self) ?? .regular).fontWeight
    }
}


public enum AppButtonSize: String, CaseIterable, Identifiable, Sendable {
    case small
    case medium
    case large

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    public var height: CGFloat {
        switch self {
        case .small: 32
        case .medium: 38
        case .large: 44
        }
    }

    public var fontSize: CGFloat {
        switch self {
        case .small: 12
        case .medium: 13
        case .large: 14
        }
    }
}

public enum PromptListRowDensity: String, CaseIterable, Identifiable, Sendable {
    case compact
    case comfortable
    case spacious

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .compact: "Compact"
        case .comfortable: "Comfortable"
        case .spacious: "Spacious"
        }
    }

    public var rowHeight: CGFloat {
        switch self {
        case .compact: 88
        case .comfortable: 116
        case .spacious: 132
        }
    }
}

public struct PromptListDisplaySettings: Equatable, Sendable {
    public var showIcons: Bool
    public var showDescription: Bool
    public var showMetadata: Bool
    public var previewLineCount: Int
    public var truncateLongTitles: Bool
    public var rowDensity: PromptListRowDensity

    public init(
        showIcons: Bool = AppSettingsDefaults.promptListShowIcons,
        showDescription: Bool = AppSettingsDefaults.promptListShowDescription,
        showMetadata: Bool = AppSettingsDefaults.promptListShowMetadata,
        previewLineCount: Int = AppSettingsDefaults.promptListPreviewLines,
        truncateLongTitles: Bool = AppSettingsDefaults.promptListTruncateLongTitles,
        rowDensity: PromptListRowDensity = AppSettingsDefaults.promptListRowDensity
    ) {
        self.showIcons = showIcons
        self.showDescription = showDescription
        self.showMetadata = showMetadata
        self.previewLineCount = max(1, min(3, previewLineCount))
        self.truncateLongTitles = truncateLongTitles
        self.rowDensity = rowDensity
    }

    public static let defaultValue = PromptListDisplaySettings()
}

public struct RightSidebarSectionVisibility: Equatable, Sendable {
    public var folder: Bool
    public var promptMetadata: Bool
    public var notes: Bool
    public var metadata: Bool

    public init(
        folder: Bool = AppSettingsDefaults.rightSidebarShowFolder,
        promptMetadata: Bool = AppSettingsDefaults.rightSidebarShowPromptMetadata,
        notes: Bool = AppSettingsDefaults.rightSidebarShowNotes,
        metadata: Bool = AppSettingsDefaults.rightSidebarShowMetadata
    ) {
        self.folder = folder
        self.promptMetadata = promptMetadata
        self.notes = notes
        self.metadata = metadata
    }

    public static let defaultValue = RightSidebarSectionVisibility()
}

public struct EditorBehaviorSettings: Equatable, Sendable {
    public var markdownHighlighting: Bool = true
    public var lineWrap: Bool = true
    public var showWordCount: Bool = true
    public var autosaveTyping: Bool = false
    public var saveFeedback: Bool = true
    public var titleFieldSize: String = "compact"
    public var actionLabelMode: String = "responsive"
    public var defaultFormat: String = "markdown"

    public init(
        markdownHighlighting: Bool = true,
        lineWrap: Bool = true,
        showWordCount: Bool = true,
        autosaveTyping: Bool = false,
        saveFeedback: Bool = true,
        titleFieldSize: String = "compact",
        actionLabelMode: String = "responsive",
        defaultFormat: String = "markdown"
    ) {
        self.markdownHighlighting = markdownHighlighting
        self.lineWrap = lineWrap
        self.showWordCount = showWordCount
        self.autosaveTyping = autosaveTyping
        self.saveFeedback = saveFeedback
        self.titleFieldSize = titleFieldSize
        self.actionLabelMode = actionLabelMode
        self.defaultFormat = defaultFormat
    }

    public static let defaultValue = EditorBehaviorSettings()
}

public struct VariablePromptBehaviorSettings: Equatable, Sendable {
    public var showPanel: Bool = true
    public var panelWidth: Double = 260
    public var fieldDefaultHeight: Double = 96
    public var rememberFieldHeights: Bool = true
    public var showRequiredCount: Bool = true
    public var actionRowStyle: String = "compact"
    public var copyFilledVisible: Bool = true
    public var presetsEnabled: Bool = true
    public var defaultType: String = "textarea"
    public var insertFormat: String = "braces"
    public var autoDetect: Bool = true
    public var highlight: Bool = true
    public var requireDescriptions: Bool = false
    public var sortBy: String = "source"

    public init(
        showPanel: Bool = true,
        panelWidth: Double = 260,
        fieldDefaultHeight: Double = 96,
        rememberFieldHeights: Bool = true,
        showRequiredCount: Bool = true,
        actionRowStyle: String = "compact",
        copyFilledVisible: Bool = true,
        presetsEnabled: Bool = true,
        defaultType: String = "textarea",
        insertFormat: String = "braces",
        autoDetect: Bool = true,
        highlight: Bool = true,
        requireDescriptions: Bool = false,
        sortBy: String = "source"
    ) {
        self.showPanel = showPanel
        self.panelWidth = panelWidth
        self.fieldDefaultHeight = fieldDefaultHeight
        self.rememberFieldHeights = rememberFieldHeights
        self.showRequiredCount = showRequiredCount
        self.actionRowStyle = actionRowStyle
        self.copyFilledVisible = copyFilledVisible
        self.presetsEnabled = presetsEnabled
        self.defaultType = defaultType
        self.insertFormat = insertFormat
        self.autoDetect = autoDetect
        self.highlight = highlight
        self.requireDescriptions = requireDescriptions
        self.sortBy = sortBy
    }

    public static let defaultValue = VariablePromptBehaviorSettings()
}

public struct SearchBehaviorSettings: Equatable, Sendable {
    public var scope: String = "all"
    public var behavior: String = "contains"
    public var searchInTitle: Bool = true
    public var searchInBody: Bool = true
    public var searchInNotes: Bool = true
    public var searchInMetadata: Bool = true

    public init(
        scope: String = "all",
        behavior: String = "contains",
        searchInTitle: Bool = true,
        searchInBody: Bool = true,
        searchInNotes: Bool = true,
        searchInMetadata: Bool = true
    ) {
        self.scope = scope
        self.behavior = behavior
        self.searchInTitle = searchInTitle
        self.searchInBody = searchInBody
        self.searchInNotes = searchInNotes
        self.searchInMetadata = searchInMetadata
    }

    public static let defaultValue = SearchBehaviorSettings()
}

public struct ClipboardBehaviorSettings: Equatable, Sendable {
    public var rawShortcut: Bool = true
    public var filledShortcut: Bool = true
    public var includeTitle: Bool = false
    public var includeMetadata: Bool = false
    public var preserveMarkdown: Bool = true
    public var successFeedback: Bool = true
    public var defaultCopyMode: String = "raw"
    public var requireVariables: Bool = true

    public init(
        rawShortcut: Bool = true,
        filledShortcut: Bool = true,
        includeTitle: Bool = false,
        includeMetadata: Bool = false,
        preserveMarkdown: Bool = true,
        successFeedback: Bool = true,
        defaultCopyMode: String = "raw",
        requireVariables: Bool = true
    ) {
        self.rawShortcut = rawShortcut
        self.filledShortcut = filledShortcut
        self.includeTitle = includeTitle
        self.includeMetadata = includeMetadata
        self.preserveMarkdown = preserveMarkdown
        self.successFeedback = successFeedback
        self.defaultCopyMode = defaultCopyMode
        self.requireVariables = requireVariables
    }

    public static let defaultValue = ClipboardBehaviorSettings()
}

public struct ImportExportBehaviorSettings: Equatable, Sendable {
    public var importFolderBehavior: String = "preserve"
    public var duplicateImportBehavior: String = "skip"
    public var preserveSourcePath: Bool = true
    public var defaultExportFormat: String = "markdown"
    public var autoBackup: Bool = false
    public var backupFrequency: String = "weekly"
    public var keepBackupsFor: String = "30"
    public var attachmentMode: String = "local"

    public init(
        importFolderBehavior: String = "preserve",
        duplicateImportBehavior: String = "skip",
        preserveSourcePath: Bool = true,
        defaultExportFormat: String = "markdown",
        autoBackup: Bool = false,
        backupFrequency: String = "weekly",
        keepBackupsFor: String = "30",
        attachmentMode: String = "local"
    ) {
        self.importFolderBehavior = importFolderBehavior
        self.duplicateImportBehavior = duplicateImportBehavior
        self.preserveSourcePath = preserveSourcePath
        self.defaultExportFormat = defaultExportFormat
        self.autoBackup = autoBackup
        self.backupFrequency = backupFrequency
        self.keepBackupsFor = keepBackupsFor
        self.attachmentMode = attachmentMode
    }

    public static let defaultValue = ImportExportBehaviorSettings()
}

public struct AppSettingsSnapshot: Equatable, Sendable {
    public var accentColor: AppAccentColor
    public var fontScale: AppFontScale
    public var buttonStyle: AppButtonVisualStyle
    public var buttonTextWeight: AppButtonTextWeight
    public var buttonSize: AppButtonSize
    public var promptList: PromptListDisplaySettings
    public var rightSidebarSections: RightSidebarSectionVisibility
    public var leftSidebarVisible: Bool
    public var rightSidebarVisible: Bool
    public var promptListWidth: Double
    public var detailsSidebarWidth: Double
    public var resizablePanelsEnabled: Bool

    public init(
        accentColor: AppAccentColor = AppSettingsDefaults.accentColor,
        fontScale: AppFontScale = AppSettingsDefaults.fontScale,
        buttonStyle: AppButtonVisualStyle = AppSettingsDefaults.buttonStyle,
        buttonTextWeight: AppButtonTextWeight = AppSettingsDefaults.buttonTextWeight,
        buttonSize: AppButtonSize = AppSettingsDefaults.buttonSize,
        promptList: PromptListDisplaySettings = .defaultValue,
        rightSidebarSections: RightSidebarSectionVisibility = .defaultValue,
        leftSidebarVisible: Bool = AppSettingsDefaults.leftSidebarVisible,
        rightSidebarVisible: Bool = AppSettingsDefaults.rightSidebarVisible,
        promptListWidth: Double = AppSettingsDefaults.promptListWidth,
        detailsSidebarWidth: Double = AppSettingsDefaults.detailsSidebarWidth,
        resizablePanelsEnabled: Bool = AppSettingsDefaults.resizablePanelsEnabled
    ) {
        self.accentColor = accentColor
        self.fontScale = fontScale
        self.buttonStyle = buttonStyle
        self.buttonTextWeight = buttonTextWeight
        self.buttonSize = buttonSize
        self.promptList = promptList
        self.rightSidebarSections = rightSidebarSections
        self.leftSidebarVisible = leftSidebarVisible
        self.rightSidebarVisible = rightSidebarVisible
        self.promptListWidth = promptListWidth
        self.detailsSidebarWidth = detailsSidebarWidth
        self.resizablePanelsEnabled = resizablePanelsEnabled
    }

    public static let defaultValue = AppSettingsSnapshot()

    public func resettingPromptList() -> AppSettingsSnapshot {
        var copy = self
        copy.promptList = .defaultValue
        return copy
    }

    public func resettingRightSidebarSections() -> AppSettingsSnapshot {
        var copy = self
        copy.rightSidebarSections = .defaultValue
        return copy
    }

    public func resettingLayout() -> AppSettingsSnapshot {
        var copy = self
        copy.leftSidebarVisible = AppSettingsDefaults.leftSidebarVisible
        copy.rightSidebarVisible = AppSettingsDefaults.rightSidebarVisible
        copy.promptListWidth = AppSettingsDefaults.promptListWidth
        copy.detailsSidebarWidth = AppSettingsDefaults.detailsSidebarWidth
        copy.resizablePanelsEnabled = AppSettingsDefaults.resizablePanelsEnabled
        return copy
    }

    public func resettingAppearance() -> AppSettingsSnapshot {
        var copy = self
        copy.accentColor = AppSettingsDefaults.accentColor
        copy.fontScale = AppSettingsDefaults.fontScale
        copy.buttonStyle = AppSettingsDefaults.buttonStyle
        copy.buttonTextWeight = AppSettingsDefaults.buttonTextWeight
        copy.buttonSize = AppSettingsDefaults.buttonSize
        return copy
    }
}

public enum AppSettingsDefaults {
    public static let accentColor: AppAccentColor = .blue
    public static let fontScale: AppFontScale = .standard
    public static let buttonStyle: AppButtonVisualStyle = .filled
    public static let buttonTextWeight: AppButtonTextWeight = .semibold
    public static let buttonSize: AppButtonSize = .medium
    public static let leftSidebarVisible = true
    public static let rightSidebarVisible = true
    public static let promptListWidth = Double(DesignTokens.Size.promptListWidth)
    public static let detailsSidebarWidth = Double(DesignTokens.Size.detailsWidth)
    public static let resizablePanelsEnabled = true
    public static let promptListShowIcons = true
    public static let promptListShowDescription = true
    public static let promptListShowMetadata = true
    public static let promptListPreviewLines = 2
    public static let promptListTruncateLongTitles = true
    public static let promptListRowDensity: PromptListRowDensity = .comfortable
    public static let rightSidebarShowFolder = true
    public static let rightSidebarShowPromptMetadata = true
    public static let rightSidebarShowNotes = true
    public static let rightSidebarShowMetadata = true
    public static let inspectorWhenToUseDefaultOpen = false
    public static let inspectorNotesDefaultOpen = false
    public static let inspectorVariablesDefaultOpen = false
    public static let variablePromptRunnerCollapsed = true
}

struct AppAccentStyle: Equatable {
    var color: Color
    var hoverColor: Color
    var softColor: Color
    var borderColor: Color

    static let blue = AppAccentStyle(accent: .blue)

    init(accent: AppAccentColor) {
        color = accent.color
        hoverColor = accent.hoverColor
        softColor = accent.softColor
        borderColor = accent.borderColor
    }
}



public struct AppRuntimeSettings: Equatable, Sendable {
    public var increaseContrast = false
    public var reduceTransparency = false
    public var largerTargets = false
    public var reduceMotion = false
    public var focusRing = "standard"
    public var showTooltips = true

    public static let defaultValue = AppRuntimeSettings()
}

private struct AppRuntimeSettingsKey: EnvironmentKey { static let defaultValue = AppRuntimeSettings.defaultValue }
private struct AppAccentStyleKey: EnvironmentKey { static let defaultValue = AppAccentStyle.blue }
private struct AppFontScaleKey: EnvironmentKey { static let defaultValue = AppFontScale.standard }
private struct AppButtonVisualStyleKey: EnvironmentKey { static let defaultValue = AppButtonVisualStyle.filled }
private struct AppButtonTextWeightKey: EnvironmentKey { static let defaultValue = AppButtonTextWeight.semibold }
private struct AppButtonSizeKey: EnvironmentKey { static let defaultValue = AppButtonSize.medium }

extension EnvironmentValues {
    var appAccentStyle: AppAccentStyle {
        get { self[AppAccentStyleKey.self] }
        set { self[AppAccentStyleKey.self] = newValue }
    }

    var appFontScale: AppFontScale {
        get { self[AppFontScaleKey.self] }
        set { self[AppFontScaleKey.self] = newValue }
    }

    var appButtonVisualStyle: AppButtonVisualStyle {
        get { self[AppButtonVisualStyleKey.self] }
        set { self[AppButtonVisualStyleKey.self] = newValue }
    }

    var appButtonTextWeight: AppButtonTextWeight {
        get { self[AppButtonTextWeightKey.self] }
        set { self[AppButtonTextWeightKey.self] = newValue }
    }

    var appButtonSize: AppButtonSize {
        get { self[AppButtonSizeKey.self] }
        set { self[AppButtonSizeKey.self] = newValue }
    }

    var appRuntimeSettings: AppRuntimeSettings {
        get { self[AppRuntimeSettingsKey.self] }
        set { self[AppRuntimeSettingsKey.self] = newValue }
    }
}

extension View {
    func appSettingsEnvironment(_ settings: AppSettingsSnapshot, runtime: AppRuntimeSettings = .defaultValue) -> some View {
        self
            .environment(\.appRuntimeSettings, runtime)
            .environment(\.appAccentStyle, AppAccentStyle(accent: settings.accentColor))
            .environment(\.appFontScale, settings.fontScale)
            .environment(\.appButtonVisualStyle, settings.buttonStyle)
            .environment(\.appButtonTextWeight, settings.buttonTextWeight)
            .environment(\.appButtonSize, settings.buttonSize)
            .tint(settings.accentColor.color)
    }
}
