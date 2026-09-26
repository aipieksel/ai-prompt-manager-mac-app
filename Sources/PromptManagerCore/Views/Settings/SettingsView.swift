import SwiftUI
#if os(macOS)
import AppKit
#endif

private let settingsDropdownFixedWidth: CGFloat = 160

struct SettingsView: View {
    @Binding var appearance: AppAppearance
    @Binding var accentColor: AppAccentColor
    @Binding var fontScale: AppFontScale
    @Binding var buttonStyle: AppButtonVisualStyle
    @Binding var buttonWeight: AppButtonTextWeight
    @Binding var buttonSize: AppButtonSize
    @Binding var leftSidebarVisible: Bool
    @Binding var rightSidebarVisible: Bool
    @Binding var promptListWidth: Double
    @Binding var detailsSidebarWidth: Double
    @Binding var resizablePanelsEnabled: Bool
    @Binding var promptListSettings: PromptListDisplaySettings
    @Binding var rightSidebarSections: RightSidebarSectionVisibility
    @Binding var sortMode: SortMode
    let promptCount: Int
    let folderCount: Int
    let onBack: () -> Void
    let onSaveSettings: () -> Void
    let onResetLayout: () -> Void
    let onResetAppearance: () -> Void
    let onResetPromptList: () -> Void
    let onResetSidebarSections: () -> Void

    @AppStorage(AppSettingsKeys.settingsLastSection) private var selectedSectionRaw = SettingsSection.layout.rawValue
    @State private var searchQuery = ""
    @State private var saveStatus = "Settings auto-saved"
    @AppStorage(AppSettingsKeys.generalAutosaveSettings) private var autosaveSettings = true
    @Environment(\.appAccentStyle) private var accent
    @Environment(\.appFontScale) private var scale


    private var selectedSection: SettingsSection {
        SettingsSection(rawValue: selectedSectionRaw) ?? .layout
    }

    private var selectedSectionBinding: Binding<SettingsSection> {
        Binding(
            get: { selectedSection },
            set: { selectedSectionRaw = $0.rawValue }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebarView(selectedSection: selectedSectionBinding, searchQuery: $searchQuery, promptCount: promptCount)
                .frame(width: 240)
            ColumnDivider()
            VStack(spacing: 0) {
                settingsHeader
                Divider().overlay(DT.ColorToken.borderDefault)
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DT.ColorToken.surfaceSecondary)
        }
        .background(DT.ColorToken.surfaceSecondary)
    }

    private var settingsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onBack) { Image(systemName: "arrow.left") }
                .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                .accessibilityLabel("Back")
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedSection.title)
                    .font(.system(size: 18 * scale.scale, weight: .bold))
                    .foregroundStyle(DT.ColorToken.textPrimary)
                Text(selectedSection.description)
                    .font(.system(size: 12 * scale.scale, weight: .regular))
                    .foregroundStyle(DT.ColorToken.textSecondary)
            }
            Spacer()
            Text(saveStatus)
                .font(DT.FontToken.caption)
                .foregroundStyle(DT.ColorToken.textTertiary)
                .padding(.trailing, 2)
            Button {
                onSaveSettings()
                saveStatus = "Saved \(Date().formatted(date: .omitted, time: .shortened))"
            } label: { Label("Save Changes", systemImage: "square.and.arrow.down") }
                .buttonStyle(PrimaryButtonStyle(horizontalPadding: 12))
            Button {
                resetCurrentSection()
            } label: { Label("Reset to Defaults", systemImage: "arrow.counterclockwise") }
                .buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
        .background(DT.ColorToken.surfaceSecondary)
        .onAppear { saveStatus = autosaveSettings ? "Settings auto-saved" : "Manual settings save mode" }
        .onChange(of: autosaveSettings) { _, isEnabled in
            saveStatus = isEnabled ? "Settings auto-saved" : "Manual settings save mode"
        }
    }

    @ViewBuilder private var content: some View {
        switch selectedSection {
        case .layout:
            LayoutSettingsPage(
                leftSidebarVisible: $leftSidebarVisible,
                rightSidebarVisible: $rightSidebarVisible,
                promptListWidth: $promptListWidth,
                detailsSidebarWidth: $detailsSidebarWidth,
                resizablePanelsEnabled: $resizablePanelsEnabled,
                promptListSettings: $promptListSettings,
                rightSidebarSections: $rightSidebarSections,
                sortMode: $sortMode,
                onResetLayout: onResetLayout,
                onResetPromptList: onResetPromptList,
                onResetSidebarSections: onResetSidebarSections
            )
        case .appearance:
            AppearanceSettingsPage(appearance: $appearance, accentColor: $accentColor, fontScale: $fontScale, buttonStyle: $buttonStyle, buttonWeight: $buttonWeight, buttonSize: $buttonSize, onReset: onResetAppearance)
        case .general:
            GeneralSettingsPage()
        case .editor:
            EditorSettingsPage()
        case .variables:
            VariablePromptsSettingsPage()
        case .aiProviders:
            AIProvidersSettingsPage()
        case .aiLogs:
            AIRequestLogSettingsPage()
        case .librarySidebar:
            LibrarySidebarSettingsPage()
        case .searchFilters:
            SearchFiltersSettingsPage()
        case .importExport:
            ImportExportStorageSettingsPage()
        case .clipboard:
            ClipboardCopySettingsPage()
        case .accessibility:
            AccessibilitySettingsPage(fontScale: $fontScale)
        case .advanced:
            AdvancedSettingsPage(onResetAppearance: onResetAppearance, onResetLayout: onResetLayout, onResetPromptList: onResetPromptList, onResetSidebarSections: onResetSidebarSections)
        }
    }

    private var metrics: [(String, String)] {
        [("Prompts", "\(promptCount)"), ("Folders", "\(folderCount)")]
    }

    private func resetCurrentSection() {
        switch selectedSection {
        case .layout:
            onResetLayout(); onResetPromptList(); onResetSidebarSections(); saveStatus = "Layout reset"
        case .appearance:
            onResetAppearance(); saveStatus = "Appearance reset"
        case .advanced:
            onResetAppearance(); onResetLayout(); onResetPromptList(); onResetSidebarSections(); saveStatus = "All settings reset"
        default:
            saveStatus = "No reset needed"
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case layout
    case editor
    case variables
    case aiProviders
    case aiLogs
    case librarySidebar
    case searchFilters
    case importExport
    case clipboard
    case accessibility
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .layout: "Layout Settings"
        case .editor: "Editor"
        case .variables: "Variable Prompts"
        case .aiProviders: "AI Providers"
        case .aiLogs: "AI Logs"
        case .librarySidebar: "Library Sidebar"
        case .searchFilters: "Search & Filters"
        case .importExport: "Import / Export & Storage"
        case .clipboard: "Clipboard & Copy"
        case .accessibility: "Accessibility"
        case .advanced: "Advanced"
        }
    }

    var sidebarTitle: String {
        switch self {
        case .layout: "Layout"
        default: title
        }
    }

    var description: String {
        switch self {
        case .general: "Core app behavior and startup preferences."
        case .appearance: "Customize theme, accent color, font scale, and button treatment."
        case .layout: "Customize how the app is organized and how content is displayed."
        case .editor: "Control text editing behavior."
        case .variables: "Control behavior for prompts with variables."
        case .aiProviders: "Configure provider credentials, model defaults, and run behavior."
        case .aiLogs: "Review AI request and response history."
        case .librarySidebar: "Control library and folder tree display."
        case .searchFilters: "Control search, sort, and filter behavior."
        case .importExport: "Control backups, import behavior, and local storage."
        case .clipboard: "Control copy behavior and clipboard formatting."
        case .accessibility: "Adjust readability and accessibility options."
        case .advanced: "Reset preferences and review diagnostics-oriented actions."
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .layout: "square.grid.2x2"
        case .editor: "pencil"
        case .variables: "curlybraces"
        case .aiProviders: "sparkles"
        case .aiLogs: "doc.text.magnifyingglass"
        case .librarySidebar: "list.bullet.rectangle"
        case .searchFilters: "magnifyingglass"
        case .importExport: "square.and.arrow.down"
        case .clipboard: "doc.on.clipboard"
        case .accessibility: "accessibility"
        case .advanced: "chevron.left.forwardslash.chevron.right"
        }
    }
}

private struct SettingsSidebarView: View {
    @Binding var selectedSection: SettingsSection
    @Binding var searchQuery: String
    let promptCount: Int
    @Environment(\.appAccentStyle) private var accent

    private var visibleSections: [SettingsSection] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return SettingsSection.allCases }
        return SettingsSection.allCases.filter { $0.title.lowercased().contains(query) || $0.description.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SETTINGS")
                .font(DT.FontToken.headingSection)
                .tracking(0.48)
                .foregroundStyle(DT.ColorToken.textTertiary)
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 12)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DT.ColorToken.textTertiary)
                TextField("Search settings...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(DT.FontToken.bodySmall)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.borderDefault))
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(visibleSections) { section in
                        SettingsSidebarRow(section: section, active: selectedSection == section) {
                            selectedSection = section
                        }
                    }
                    if visibleSections.isEmpty {
                        Text("No settings found")
                            .font(DT.FontToken.bodySmall)
                            .foregroundStyle(DT.ColorToken.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                }
                .padding(.horizontal, 14)
            }
            Spacer(minLength: 12)
            Text(AppVersionInfo.current.displayText)
                .font(DT.FontToken.caption)
                .foregroundStyle(DT.ColorToken.textTertiary)
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
        }
        .background(DT.ColorToken.surfaceSecondary)
    }
}

private struct SettingsSidebarRow: View {
    let section: SettingsSection
    let active: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccentStyle) private var accent
    @Environment(\.appFontScale) private var scale

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 15 * scale.scale, weight: .medium))
                    .frame(width: 18)
                Text(section.sidebarTitle)
                    .font(.system(size: 13 * scale.scale, weight: active ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .foregroundStyle(active ? accent.color : DT.ColorToken.textSecondary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: DT.Radius.md))
            .background(active ? accent.softColor : (hovering ? DT.ColorToken.surfaceHover : Color.clear), in: RoundedRectangle(cornerRadius: DT.Radius.md))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct AIProvidersSettingsPage: View {
    @AppStorage(AppSettingsKeys.aiDefaultProvider) private var defaultProvider = AIProviderKind.openAI.rawValue
    @AppStorage(AppSettingsKeys.aiDefaultModel) private var defaultModel = AIProviderKind.openAI.defaultModelID
    @AppStorage(AppSettingsKeys.aiMaxTokens) private var maxTokens = 4096
    @AppStorage(AppSettingsKeys.aiTemperature) private var temperature = 0.7
    @AppStorage(AppSettingsKeys.aiThinkingMode) private var thinkingMode = "Disabled"
    @AppStorage(AppSettingsKeys.aiStreamingResponses) private var streamingResponses = true
    @AppStorage(AppSettingsKeys.aiSaveOutputsByDefault) private var saveOutputs = true
    @AppStorage(AppSettingsKeys.aiConfirmBeforeSending) private var confirmBeforeSending = true
    @AppStorage(AppSettingsKeys.aiLastTestStatus) private var lastTestStatus = "Not tested"
    @State private var apiKeyPreview = ""
    @State private var apiKeyVisible = false
    private let keychain = AIKeychainService()

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "AI Provider", subtitle: "Choose one active provider. The model list below follows the selected provider.") {
                SettingRow(label: "Provider", description: "Provider used by default for new chains and steps.") { providerPicker }
                SettingRow(label: "Model", description: "Default model for the selected provider.") { modelPicker }
                SettingRow(label: "API key", description: "Stored securely in the macOS Keychain for the selected provider.") { apiKeyField }
                SettingRow(label: "Test connection", description: "Verify the selected provider credentials before running live chains.") { Button("Test Connection") { Task { await testConnection() } }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
                SettingRow(label: "Status", description: "Current connection status for \(selectedDefaultProvider.displayName).") { Text(lastTestStatus).font(DT.FontToken.captionStrong).foregroundStyle(connectionStatusColor).frame(width: 220, alignment: .trailing) }
                SettingRow(label: "Refresh models", description: "Refresh the local model catalog for \(selectedDefaultProvider.displayName).") { Button("Refresh Models") { lastTestStatus = "Model catalog refreshed; connection not tested" }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
            }

            SettingsCard(title: "Run Defaults") {
                SettingRow(label: "Max tokens", description: "Maximum number of tokens to generate in a response.") { SettingsIntegerStepper(value: $maxTokens, range: 512...32000, step: 512).frame(width: 220, alignment: .trailing) }
                SettingRow(label: "Temperature", description: "Controls randomness. Lower is more deterministic.") { SettingsDecimalStepper(value: $temperature, range: 0...2, step: 0.1).frame(width: 220, alignment: .trailing) }
                SettingRow(label: "Thinking mode", description: "DeepSeek API thinking mode toggle. Enabled omits temperature per provider rules.") { SettingsOptionPicker(selection: $thinkingMode, options: [("Enabled", "Enabled"), ("Disabled", "Disabled")], width: 220) }
                SettingRow(label: "Streaming responses", description: "Receive tokens in real time when supported by the provider.") { Toggle("", isOn: $streamingResponses).labelsHidden().frame(width: 220, alignment: .trailing) }
                SettingRow(label: "Save outputs by default", description: "Automatically save outputs from completed runs.") { Toggle("", isOn: $saveOutputs).labelsHidden().frame(width: 220, alignment: .trailing) }
                SettingRow(label: "Confirm before sending content", description: "Show a confirmation before sending content to the provider.", showDivider: false) { Toggle("", isOn: $confirmBeforeSending).labelsHidden().frame(width: 220, alignment: .trailing) }
            }
        }
        .onAppear { normalizeThinkingMode(); loadAPIKey(); resetStaleConnectionStatusIfNeeded() }
    }

    private var selectedDefaultProvider: AIProviderKind { AIProviderKind(rawValue: defaultProvider) ?? .openAI }

    private var providerPicker: some View {
        SettingsOptionPicker(
            selection: defaultProviderBinding,
            options: AIProviderKind.allCases.map { ($0.rawValue, $0.displayName) }
        )
    }

    private var modelPicker: some View {
        SettingsOptionPicker(
            selection: defaultModelBinding,
            options: selectedDefaultProvider.models.map { ($0.id, $0.displayName) }
        )
        .onAppear { resetInvalidDefaultModel() }
    }

    private var apiKeyField: some View {
        HStack(spacing: 8) {
            Group {
                if apiKeyVisible {
                    TextField("\(selectedDefaultProvider.displayName) API key", text: apiKeyBinding)
                } else {
                    SecureField("\(selectedDefaultProvider.displayName) API key", text: apiKeyBinding)
                }
            }
            .textFieldStyle(.plain)
            Button {
                apiKeyVisible.toggle()
            } label: {
                Image(systemName: apiKeyVisible ? "eye.slash" : "eye")
                    .foregroundStyle(DT.ColorToken.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(apiKeyVisible ? "Hide API key" : "Show API key")
            .help(apiKeyVisible ? "Hide API key" : "Show API key")
        }
        .padding(.horizontal, 10)
        .frame(width: 220, height: 32)
        .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.borderDefault))
    }


    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { apiKeyPreview },
            set: { newValue in
                apiKeyPreview = newValue
                do { try keychain.saveKey(newValue, for: selectedDefaultProvider) }
                catch { lastTestStatus = "Keychain save failed" }
                if lastTestStatus == "Connected" || lastTestStatus.hasPrefix("Invalid") || lastTestStatus.hasPrefix("Missing") || lastTestStatus.contains("live test") || lastTestStatus.contains("OK") {
                    lastTestStatus = "Not tested"
                }
            }
        )
    }

    private var connectionStatusColor: Color {
        if lastTestStatus == "Connected" { return DT.ColorToken.successGreen }
        if lastTestStatus.hasPrefix("Invalid") || lastTestStatus.hasPrefix("Missing") || lastTestStatus.contains("error") || lastTestStatus.contains("not supported") { return DT.ColorToken.dangerRed }
        if lastTestStatus.contains("OK") || lastTestStatus.contains("refreshed") || lastTestStatus.contains("failed") { return DT.ColorToken.warningYellow }
        return DT.ColorToken.textTertiary
    }

    private func testConnection() async {
        let result = AIConnectionValidator.validate(provider: selectedDefaultProvider, apiKey: apiKeyPreview)
        guard !result.isFailure else {
            lastTestStatus = result.message
            return
        }
        guard selectedDefaultProvider.chatCompletionsEndpoint != nil else {
            lastTestStatus = "Live test not supported"
            return
        }
        lastTestStatus = "Testing…"
        do {
            _ = try await LiveAIProviderClient(keychain: keychain).complete(prompt: "Reply with OK only.", provider: selectedDefaultProvider, modelID: defaultModelBinding.wrappedValue)
            lastTestStatus = "Connected"
        } catch {
            lastTestStatus = error.localizedDescription
        }
    }

    private func normalizeThinkingMode() {
        switch thinkingMode {
        case "Disabled", "Off", "Fast":
            thinkingMode = "Disabled"
        case "Enabled":
            break
        case "High", "Max", "Deep", "Auto":
            thinkingMode = "Enabled"
        default:
            thinkingMode = "Enabled"
        }
    }

    private func loadAPIKey() {
        apiKeyPreview = (try? keychain.readKey(for: selectedDefaultProvider)) ?? ""
    }

    private func resetStaleConnectionStatusIfNeeded() {
        guard lastTestStatus == "Connected" else { return }
        let result = AIConnectionValidator.validate(provider: selectedDefaultProvider, apiKey: apiKeyPreview)
        if result.isFailure { lastTestStatus = result.message }
    }

    private var defaultProviderBinding: Binding<String> {
        Binding(
            get: { defaultProvider },
            set: { newValue in
                defaultProvider = newValue
                resetInvalidDefaultModel()
                loadAPIKey()
                lastTestStatus = "Not tested"
            }
        )
    }

    private var defaultModelBinding: Binding<String> {
        Binding(
            get: {
                selectedDefaultProvider.models.contains { $0.id == defaultModel } ? defaultModel : selectedDefaultProvider.defaultModelID
            },
            set: { newValue in
                defaultModel = selectedDefaultProvider.models.contains { $0.id == newValue } ? newValue : selectedDefaultProvider.defaultModelID
            }
        )
    }

    private func resetInvalidDefaultModel() {
        if !selectedDefaultProvider.models.contains(where: { $0.id == defaultModel }) {
            defaultModel = selectedDefaultProvider.defaultModelID
        }
    }
}

private struct AIRequestLogSettingsPage: View {
    @AppStorage(AppSettingsKeys.aiRequestLogMaxEntries) private var maxEntries = 500
    @AppStorage(AppSettingsKeys.aiRequestLogMaxAgeMinutes) private var maxAgeMinutes = 1440
    @State private var entries: [AIRequestLogEntry] = []
    @State private var status = ""
    private let logService = AIRequestLogService()

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Log Retention", subtitle: "Request and response bodies can contain private prompt content. Keep this log only as long as you need it.") {
                SettingRow(label: "Clear after entries", description: "Keep only the latest number of AI request/response entries.") {
                    SettingsIntegerStepper(value: $maxEntries, range: 1...10000, step: 50)
                        .frame(width: 220, alignment: .trailing)
                }
                SettingRow(label: "Clear after minutes", description: "Remove entries older than this many minutes. Set to 0 to disable age-based clearing.") {
                    SettingsIntegerStepper(value: $maxAgeMinutes, range: 0...10080, step: 60)
                        .frame(width: 220, alignment: .trailing)
                }
                SettingRow(label: "Log actions", description: "Refresh the visible log or clear all stored AI request/response entries.", showDivider: false) {
                    HStack(spacing: 8) {
                        Button("Refresh") { reload() }
                            .buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                        Button("Clear Log") { clearLog() }
                            .buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                    }
                }
                if !status.isEmpty {
                    Text(status)
                        .font(DT.FontToken.caption)
                        .foregroundStyle(DT.ColorToken.textTertiary)
                }
            }

            SettingsCard(title: "AI Request Log", subtitle: "\(entries.count) entries • \(logService.fileURL.path)") {
                if entries.isEmpty {
                    Text("No AI requests have been logged yet.")
                        .font(DT.FontToken.caption)
                        .foregroundStyle(DT.ColorToken.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(entries.reversed()) { entry in
                            AIRequestLogEntryRow(entry: entry)
                        }
                    }
                }
            }
        }
        .onAppear { reload() }
        .onChange(of: maxEntries) { _, _ in reload() }
        .onChange(of: maxAgeMinutes) { _, _ in reload() }
    }

    private func reload() {
        do {
            entries = try logService.load()
            status = "Loaded \(entries.count) log entr\(entries.count == 1 ? "y" : "ies")."
        } catch {
            status = "Unable to load AI log: \(error.localizedDescription)"
        }
    }

    private func clearLog() {
        do {
            try logService.clear()
            entries = []
            status = "AI request log cleared."
        } catch {
            status = "Unable to clear AI log: \(error.localizedDescription)"
        }
    }
}

private struct AIRequestLogEntryRow: View {
    let entry: AIRequestLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(entry.createdAt.formatted(date: .numeric, time: .shortened))
                    .font(DT.FontToken.captionStrong)
                    .foregroundStyle(DT.ColorToken.textPrimary)
                Text(entry.provider.displayName)
                    .font(DT.FontToken.caption)
                    .foregroundStyle(DT.ColorToken.textSecondary)
                Text(entry.modelID)
                    .font(DT.FontToken.caption)
                    .foregroundStyle(DT.ColorToken.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(entry.status)
                    .font(DT.FontToken.captionStrong)
                    .foregroundStyle(entry.status == "success" ? DT.ColorToken.successGreen : DT.ColorToken.warningYellow)
            }
            logText(title: "Request", value: entry.requestText)
            logText(title: "Response", value: entry.responseText)
        }
        .padding(10)
        .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.borderSubtle))
    }

    private func logText(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DT.FontToken.captionStrong)
                .foregroundStyle(DT.ColorToken.textSecondary)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DT.ColorToken.textPrimary)
                .lineLimit(8)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LayoutSettingsPage: View {
    @Binding var leftSidebarVisible: Bool
    @Binding var rightSidebarVisible: Bool
    @Binding var promptListWidth: Double
    @Binding var detailsSidebarWidth: Double
    @Binding var resizablePanelsEnabled: Bool
    @Binding var promptListSettings: PromptListDisplaySettings
    @Binding var rightSidebarSections: RightSidebarSectionVisibility
    @Binding var sortMode: SortMode
    @AppStorage(AppSettingsKeys.inspectorWhenToUseDefaultOpen) private var whenToUseDefaultOpen = false
    @AppStorage(AppSettingsKeys.inspectorNotesDefaultOpen) private var notesDefaultOpen = false
    @AppStorage(AppSettingsKeys.inspectorVariablesDefaultOpen) private var variablesDefaultOpen = false
    let onResetLayout: () -> Void
    let onResetPromptList: () -> Void
    let onResetSidebarSections: () -> Void

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Application Layout") {
                SettingRow(label: "Left sidebar visible", description: "Show the library sidebar when the app is in prompt mode.") { Toggle("", isOn: $leftSidebarVisible).labelsHidden() }
                SettingRow(label: "Show right inspector by default", description: "Display the inspector panel when selecting a prompt.") { Toggle("", isOn: $rightSidebarVisible).labelsHidden() }
                SettingRow(label: "Prompt list width", description: "Set the default width of the prompt list panel.") { widthPicker(value: $promptListWidth, values: [260, 320, 380, 440, 520]) }
                SettingRow(label: "Inspector default width", description: "Set the default width of the right inspector panel.") { widthPicker(value: $detailsSidebarWidth, values: [280, 300, 340, 360, 400]) }
                SettingRow(label: "Resizable panels", description: "Allow resizing between panels.", showDivider: false) { Toggle("", isOn: $resizablePanelsEnabled).labelsHidden() }
                HStack { Spacer(); Button("Reset layout", action: onResetLayout).buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
            }

            SettingsCard(title: "Prompt List") {
                SettingRow(label: "Default sort order", description: "How prompts are sorted by default in the current library view.") {
                    SettingsEnumMenuPicker(selection: $sortMode, options: SortMode.allCases, label: { $0.rawValue }, width: 170)
                }
                SettingRow(label: "Default view", description: "Choose how dense prompt rows should be.") {
SettingsSegmentedEnumControl(selection: rowDensityBinding, options: PromptListRowDensity.allCases, label: { $0.displayName })
                }
                SettingRow(label: "Show prompt preview", description: "Display a preview snippet under prompt titles.") { Toggle("", isOn: promptListBool(\.showDescription)).labelsHidden() }
                SettingRow(label: "Number of preview lines", description: "How many lines of content to show in previews.") { previewLineControl }
                SettingRow(label: "Show icon tile", description: "Display prompt type icons in the prompt list.") { Toggle("", isOn: promptListBool(\.showIcons)).labelsHidden() }
                SettingRow(label: "Show metadata in list", description: "Display quick metadata such as type, category, and variables.") { Toggle("", isOn: promptListBool(\.showMetadata)).labelsHidden() }
                SettingRow(label: "Truncate long titles", description: "Keep long prompt titles to one line in the list.", showDivider: false) { Toggle("", isOn: promptListBool(\.truncateLongTitles)).labelsHidden() }
                HStack { Spacer(); Button("Reset prompt list", action: onResetPromptList).buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
            }

            SettingsCard(title: "Inspector") {
                SettingRow(label: "Folder section", description: "Show the folder assignment card.") { Toggle("", isOn: rightSectionBool(\.folder)).labelsHidden() }
                SettingRow(label: "Prompt Metadata section", description: "Show type, category, subcategory, and when-to-use fields.") { Toggle("", isOn: rightSectionBool(\.promptMetadata)).labelsHidden() }
                SettingRow(label: "Notes section", description: "Show prompt notes.") { Toggle("", isOn: rightSectionBool(\.notes)).labelsHidden() }
                SettingRow(label: "When to use opens by default", description: "Open the When to use accordion when selecting prompts.") { Toggle("", isOn: $whenToUseDefaultOpen).labelsHidden() }
                SettingRow(label: "Notes opens by default", description: "Open the Notes accordion when selecting prompts.") { Toggle("", isOn: $notesDefaultOpen).labelsHidden() }
                SettingRow(label: "Variables open by default", description: "Open variable accordions by default for variable prompts.") { Toggle("", isOn: $variablesDefaultOpen).labelsHidden() }
                SettingRow(label: "Metadata dates section", description: "Show created, updated, last opened, and copy count.", showDivider: false) { Toggle("", isOn: rightSectionBool(\.metadata)).labelsHidden() }
                HStack { Spacer(); Button("Reset inspector", action: onResetSidebarSections).buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
            }
        }
    }

    private var rowDensityBinding: Binding<PromptListRowDensity> {
        Binding(get: { promptListSettings.rowDensity }, set: { promptListSettings.rowDensity = $0 })
    }

    private func promptListBool(_ keyPath: WritableKeyPath<PromptListDisplaySettings, Bool>) -> Binding<Bool> {
        Binding(get: { promptListSettings[keyPath: keyPath] }, set: { promptListSettings[keyPath: keyPath] = $0 })
    }

    private func rightSectionBool(_ keyPath: WritableKeyPath<RightSidebarSectionVisibility, Bool>) -> Binding<Bool> {
        Binding(get: { rightSidebarSections[keyPath: keyPath] }, set: { rightSidebarSections[keyPath: keyPath] = $0 })
    }

    private var previewLineControl: some View {
        let values = [1, 2, 3]
        return HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.element) { index, value in
                Button("\(value) line\(value == 1 ? "" : "s")") { promptListSettings.previewLineCount = value }
                    .buttonStyle(SettingsSegmentButtonStyle(selected: promptListSettings.previewLineCount == value))
                if index < values.count - 1 {
                    Rectangle()
                        .fill(DT.ColorToken.borderDefault)
                        .frame(width: 1, height: 16)
                }
            }
        }
        .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.sm))
    }

    private func widthPicker(value: Binding<Double>, values: [Int]) -> some View {
        Menu {
            ForEach(values, id: \.self) { width in
                Button {
                    value.wrappedValue = Double(width)
                } label: {
                    let title = "\(width)px"
                    if value.wrappedValue == Double(width) {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            SettingsDropdownLabel(text: "\(Int(value.wrappedValue))px")
        }
        .frame(width: settingsDropdownFixedWidth)
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct AppearanceSettingsPage: View {
    @Binding var appearance: AppAppearance
    @Binding var accentColor: AppAccentColor
    @Binding var fontScale: AppFontScale
    @Binding var buttonStyle: AppButtonVisualStyle
    @Binding var buttonWeight: AppButtonTextWeight
    @Binding var buttonSize: AppButtonSize
    let onReset: () -> Void
    @AppStorage(AppSettingsKeys.headingFontWeight) private var headingFontWeight = "bold"
    @AppStorage(AppSettingsKeys.headingFontSize) private var headingFontSize = "18"
    @AppStorage(AppSettingsKeys.paragraphFontWeight) private var paragraphFontWeight = "regular"
    @AppStorage(AppSettingsKeys.paragraphFontSize) private var paragraphFontSize = "13"
    @AppStorage(AppSettingsKeys.labelFontWeight) private var labelFontWeight = "semibold"
    @AppStorage(AppSettingsKeys.labelFontSize) private var labelFontSize = "12"
    @State private var previewStatus = ""

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Theme") {
                SettingRow(label: "App appearance", description: "Follow macOS or force a light/dark app theme.") {
SettingsSegmentedEnumControl(selection: $appearance, options: AppAppearance.allCases, label: { $0.displayName })
                }
                SettingRow(label: "Accent color", description: "Updates selected states, focus rings, primary buttons, and previews.") {
                    HStack(spacing: 8) {
                        ForEach(AppAccentColor.allCases) { option in
                            Button { accentColor = option } label: {
                                Circle().fill(option.color).frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(accentColor == option ? DT.ColorToken.textPrimary : DT.ColorToken.borderDefault, lineWidth: accentColor == option ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.displayName)
                        }
                    }
                }
                SettingRow(label: "UI font size", description: "Scale compact app controls without changing prompt content.", showDivider: false) {
SettingsSegmentedEnumControl(selection: $fontScale, options: AppFontScale.allCases, label: { $0.displayName })
                }
            }

            SettingsCard(title: "Typography") {
                SettingRow(label: "Heading weight", description: "Font weight for section titles and major labels.") {
                    SettingsOptionPicker(selection: $headingFontWeight, options: fontWeightOptions, width: 160)
                }
                SettingRow(label: "Heading size", description: "Base heading size for compact app headings.") {
                    SettingsOptionPicker(selection: $headingFontSize, options: fontSizeOptions(range: 14...24), width: 120)
                }
                SettingRow(label: "Paragraph weight", description: "Font weight for prompt previews and descriptive text.") {
                    SettingsOptionPicker(selection: $paragraphFontWeight, options: fontWeightOptions, width: 160)
                }
                SettingRow(label: "Paragraph size", description: "Base paragraph size for dense app content.") {
                    SettingsOptionPicker(selection: $paragraphFontSize, options: fontSizeOptions(range: 11...18), width: 120)
                }
                SettingRow(label: "Label weight", description: "Font weight for captions, labels, and metadata.") {
                    SettingsOptionPicker(selection: $labelFontWeight, options: fontWeightOptions, width: 160)
                }
                SettingRow(label: "Label size", description: "Base label size for metadata and form labels.", showDivider: false) {
                    SettingsOptionPicker(selection: $labelFontSize, options: fontSizeOptions(range: 10...16), width: 120)
                }
            }

            SettingsCard(title: "Buttons") {
                SettingRow(label: "Button visual style", description: "Choose the primary action treatment.") {
SettingsSegmentedEnumControl(selection: $buttonStyle, options: AppButtonVisualStyle.allCases, label: { $0.displayName })
                }
                SettingRow(label: "Button text weight", description: "Control action label weight across the app.") {
                    SettingsSegmentedEnumControl(selection: $buttonWeight, options: AppButtonTextWeight.allCases, label: { $0.displayName })
                }
                SettingRow(label: "Button size", description: "Control the height and label size for app action buttons.", showDivider: false) {
                    SettingsSegmentedEnumControl(selection: $buttonSize, options: AppButtonSize.allCases, label: { $0.displayName })
                }
                HStack(spacing: 8) {
                    Button("Primary Button") { previewStatus = "Primary preview clicked" }
                        .buttonStyle(PrimaryButtonStyle(horizontalPadding: 12))
                    Button("Secondary Button") { previewStatus = "Secondary preview clicked" }
                        .buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                    if !previewStatus.isEmpty { Text(previewStatus).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary) }
                    Spacer()
                    Button("Reset appearance", action: onReset).buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                }
            }

            SummaryPreviewCard()
        }
    }

    private var fontWeightOptions: [(String, String)] {
        AppTextWeight.allCases.map { ($0.rawValue, $0.displayName) }
    }

    private func fontSizeOptions(range: ClosedRange<Int>) -> [(String, String)] {
        range.map { ("\($0)", "\($0)px") }
    }
}

private struct AdvancedSettingsPage: View {
    let onResetAppearance: () -> Void
    let onResetLayout: () -> Void
    let onResetPromptList: () -> Void
    let onResetSidebarSections: () -> Void
    @AppStorage(AppSettingsKeys.advancedDiagnosticsIncludeBodies) private var diagnosticsIncludeBodies = false
    @AppStorage(AppSettingsKeys.advancedExperimentalFeatures) private var experimentalFeatures = false
    @AppStorage(AppSettingsKeys.advancedVerboseLogging) private var verboseLogging = false
    @AppStorage(AppSettingsKeys.advancedConfirmPreferenceReset) private var confirmPreferenceReset = true
    @State private var diagnosticsStatus = ""
    @State private var pendingReset: String?

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Reset Settings") {
                SettingRow(label: "Confirm preference resets", description: "Ask before resetting a settings namespace.") { Toggle("", isOn: $confirmPreferenceReset).labelsHidden() }
                SettingRow(label: "Appearance", description: "Reset theme, accent, font scale, and button treatment.") { Button("Reset") { reset("appearance", onResetAppearance) }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
                SettingRow(label: "Layout", description: "Reset panel visibility, widths, and resizable panels.") { Button("Reset") { reset("layout", onResetLayout) }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
                SettingRow(label: "Prompt List", description: "Reset row display, preview, metadata, and icon preferences.") { Button("Reset") { reset("prompt list", onResetPromptList) }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
                SettingRow(label: "Inspector Sections", description: "Reset right inspector card visibility.") { Button("Reset") { reset("inspector", onResetSidebarSections) }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
            }
            SettingsCard(title: "Diagnostics") {
                SettingRow(label: "Verbose logging", description: "Record more detailed local diagnostic events where supported.") { Toggle("", isOn: $verboseLogging).labelsHidden() }
                SettingRow(label: "Include prompt bodies in diagnostics", description: "Allow diagnostic exports to include private prompt content when explicitly exported.") { Toggle("", isOn: $diagnosticsIncludeBodies).labelsHidden() }
                SettingRow(label: "Copy diagnostics summary", description: "Copy a privacy-aware settings summary to the clipboard.", showDivider: false) { Button("Copy Summary", action: copyDiagnosticsSummary).buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
                if !diagnosticsStatus.isEmpty { Text(diagnosticsStatus).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary) }
            }
            SettingsCard(title: "Experimental") {
                SettingRow(label: "Experimental features", description: "Show early settings and app behaviors that may change.", showDivider: false) { Toggle("", isOn: $experimentalFeatures).labelsHidden() }
            }
        }
    }

    private func reset(_ key: String, _ action: () -> Void) {
        if confirmPreferenceReset, pendingReset != key {
            pendingReset = key
            diagnosticsStatus = "Press Reset again to confirm \(key) reset."
            return
        }
        action()
        pendingReset = nil
        diagnosticsStatus = "Reset \(key)."
        if verboseLogging { UserDefaults.standard.set("Reset \(key) at \(Date())", forKey: AppSettingsKeys.diagnosticsLog) }
    }

    private func copyDiagnosticsSummary() {
        let summary = "Prompt Manager diagnostics preferences\nVerbose logging: \(verboseLogging)\nInclude prompt bodies: \(diagnosticsIncludeBodies)\nExperimental features: \(experimentalFeatures)"
        ClipboardService.copy(summary)
        diagnosticsStatus = "Diagnostics summary copied."
    }
}

private struct SettingsFormScroll<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) { content }
                .padding(18)
                .frame(maxWidth: 760, alignment: .leading)
        }
        .background(DT.ColorToken.surfaceSecondary)
    }
}


private struct SettingsIntegerStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        Stepper(value: stepperBinding, in: range, step: step) {
            TextField("", value: textBinding, format: .number.grouping(.automatic))
                .textFieldStyle(.plain)
                .font(DT.FontToken.captionStrong)
                .foregroundStyle(DT.ColorToken.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(width: 82)
                .accessibilityLabel("Numeric value")
        }
    }

    private var stepperBinding: Binding<Int> {
        Binding(
            get: { value },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    private var textBinding: Binding<Int> { stepperBinding }
}

private struct SettingsDecimalStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        Stepper(value: stepperBinding, in: range, step: step) {
            TextField("", value: textBinding, format: .number.precision(.fractionLength(1)))
                .textFieldStyle(.plain)
                .font(DT.FontToken.captionStrong)
                .foregroundStyle(DT.ColorToken.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(width: 82)
                .accessibilityLabel("Numeric value")
        }
    }

    private var stepperBinding: Binding<Double> {
        Binding(
            get: { value },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    private var textBinding: Binding<Double> { stepperBinding }
}

private struct SettingsOptionPicker: View {
    @Binding var selection: String
    let options: [(String, String)]
    var width: CGFloat = 180

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { value, label in
                Button {
                    selection = value
                } label: {
                    if selection == value {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
        } label: {
            SettingsDropdownLabel(text: options.first(where: { $0.0 == selection })?.1 ?? "Select")
        }
        .frame(width: settingsDropdownFixedWidth)
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct SettingsDoublePicker: View {
    @Binding var value: Double
    let values: [Int]
    let suffix: String
    var width: CGFloat = 150

    var body: some View {
        Menu {
            ForEach(values, id: \.self) { option in
                Button {
                    value = Double(option)
                } label: {
                    let title = "\(option)\(suffix)"
                    if value == Double(option) {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            SettingsDropdownLabel(text: "\(Int(value))\(suffix)")
        }
        .frame(width: settingsDropdownFixedWidth)
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct SettingsDropdownLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(DT.FontToken.captionStrong)
                .foregroundStyle(DT.ColorToken.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(DT.ColorToken.textTertiary)
        }
        .frame(width: settingsDropdownFixedWidth, alignment: .leading)
        .frame(minHeight: 28, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct SettingsEnumMenuPicker<Option: Identifiable & Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String
    var width: CGFloat = 170

    var body: some View {
        Menu {
            ForEach(options, id: \.id) { option in
                Button {
                    selection = option
                } label: {
                    if selection == option {
                        Label(label(option), systemImage: "checkmark")
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            SettingsDropdownLabel(text: label(selection))
        }
        .frame(width: settingsDropdownFixedWidth)
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct GeneralSettingsPage: View {
    @AppStorage(AppSettingsKeys.generalOpenLastPrompt) private var openLastPrompt = true
    @AppStorage(AppSettingsKeys.generalRememberWindowSize) private var rememberWindowSize = true
    @AppStorage(AppSettingsKeys.generalRememberSelectedFolder) private var rememberSelectedFolder = true
    @AppStorage(AppSettingsKeys.generalConfirmDestructiveActions) private var confirmDestructive = true
    @AppStorage(AppSettingsKeys.generalAutosaveSettings) private var autosaveSettings = true
    @AppStorage(AppSettingsKeys.generalLaunchSection) private var launchSection = "last"

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Startup") {
                SettingRow(label: "Open last selected prompt", description: "Restore the prompt you were editing when the app launches.") { Toggle("", isOn: $openLastPrompt).labelsHidden() }
                SettingRow(label: "Remember window size", description: "Use the last app window size instead of the design default.") { Toggle("", isOn: $rememberWindowSize).labelsHidden() }
                SettingRow(label: "Remember selected folder", description: "Restore the selected folder or library section on launch.") { Toggle("", isOn: $rememberSelectedFolder).labelsHidden() }
                SettingRow(label: "Launch section", description: "Choose the default landing section when no previous state is available.") { SettingsOptionPicker(selection: $launchSection, options: [("last", "Last Used"), ("all", "All Prompts"), ("favorites", "Favorites"), ("variables", "Variable Prompts")], width: 180) }
            }
            SettingsCard(title: "Safety and Saving") {
                SettingRow(label: "Confirm destructive actions", description: "Ask before archive, delete, reset, or clear actions.") { Toggle("", isOn: $confirmDestructive).labelsHidden() }
                SettingRow(label: "Autosave settings changes", description: "Persist preference changes immediately as you adjust controls.", showDivider: false) { Toggle("", isOn: $autosaveSettings).labelsHidden() }
            }
        }
    }
}

private struct EditorSettingsPage: View {
    @AppStorage(AppSettingsKeys.editorMarkdownHighlighting) private var markdownHighlighting = true
    @AppStorage(AppSettingsKeys.editorLineWrap) private var lineWrap = true
    @AppStorage(AppSettingsKeys.editorShowWordCount) private var showWordCount = true
    @AppStorage(AppSettingsKeys.editorAutosaveTyping) private var autosaveTyping = false
    @AppStorage(AppSettingsKeys.editorSaveFeedback) private var saveFeedback = true
    @AppStorage(AppSettingsKeys.editorTitleFieldSize) private var titleFieldSize = "compact"
    @AppStorage(AppSettingsKeys.editorActionLabelMode) private var actionLabelMode = "responsive"
    @AppStorage(AppSettingsKeys.editorDefaultFormat) private var defaultFormat = "markdown"

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Editing") {
                SettingRow(label: "Markdown syntax highlighting", description: "Color markdown tokens inside the editable prompt body.") { Toggle("", isOn: $markdownHighlighting).labelsHidden() }
                SettingRow(label: "Line wrap", description: "Wrap long prompt lines inside the editor.") { Toggle("", isOn: $lineWrap).labelsHidden() }
                SettingRow(label: "Autosave while typing", description: "Persist prompt edits automatically as you type.") { Toggle("", isOn: $autosaveTyping).labelsHidden() }
                SettingRow(label: "Default prompt format", description: "Choose the default content mode shown in the editor footer.") { SettingsOptionPicker(selection: $defaultFormat, options: [("markdown", "Markdown"), ("plain", "Plain Text")], width: 160) }
            }
            SettingsCard(title: "Editor Chrome") {
                SettingRow(label: "Show word / character count", description: "Display the footer count bar for the selected prompt.") { Toggle("", isOn: $showWordCount).labelsHidden() }
                SettingRow(label: "Save feedback visibility", description: "Show Ready/Saved status near editor actions.") { Toggle("", isOn: $saveFeedback).labelsHidden() }
                SettingRow(label: "Title field size", description: "Control the prompt title input density.") { SettingsOptionPicker(selection: $titleFieldSize, options: [("compact", "Compact"), ("default", "Default"), ("large", "Large")], width: 160) }
                SettingRow(label: "Action bar label mode", description: "Choose how editor actions adapt at narrow widths.", showDivider: false) { SettingsOptionPicker(selection: $actionLabelMode, options: [("responsive", "Responsive"), ("labels", "Labels"), ("icons", "Icons")], width: 170) }
            }
        }
    }
}

private struct VariablePromptsSettingsPage: View {
    @AppStorage(AppSettingsKeys.variablesShowPanel) private var showPanel = true
    @AppStorage(AppSettingsKeys.variablesPanelWidth) private var panelWidth = 260.0
    @AppStorage(AppSettingsKeys.variablesFieldDefaultHeight) private var fieldHeight = 96.0
    @AppStorage(AppSettingsKeys.variablesRememberFieldHeights) private var rememberFieldHeights = true
    @AppStorage(AppSettingsKeys.variablesShowRequiredCount) private var showRequiredCount = true
    @AppStorage(AppSettingsKeys.variablesActionRowStyle) private var actionRowStyle = "compact"
    @AppStorage(AppSettingsKeys.variablesCopyFilledVisible) private var copyFilledVisible = true
    @AppStorage(AppSettingsKeys.variablesPresetsEnabled) private var presetsEnabled = true
    @AppStorage(AppSettingsKeys.variablesDefaultType) private var defaultType = "textarea"
    @AppStorage(AppSettingsKeys.variablesInsertFormat) private var insertFormat = "braces"
    @AppStorage(AppSettingsKeys.variablesAutoDetect) private var autoDetect = true
    @AppStorage(AppSettingsKeys.variablesHighlight) private var highlight = true
    @AppStorage(AppSettingsKeys.variablesRequireDescriptions) private var requireDescriptions = false
    @AppStorage(AppSettingsKeys.variablesSortBy) private var sortBy = "source"

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Variable Panel") {
                SettingRow(label: "Show variable panel", description: "Open the dedicated variable panel for prompts with variables.") { Toggle("", isOn: $showPanel).labelsHidden() }
                SettingRow(label: "Variable panel width", description: "Preferred width for the variable input panel.") { SettingsDoublePicker(value: $panelWidth, values: [220, 260, 300, 340], suffix: "px") }
                SettingRow(label: "Variable field default height", description: "Initial height for textarea-style variable fields.") { SettingsDoublePicker(value: $fieldHeight, values: [72, 96, 120, 160], suffix: "px") }
                SettingRow(label: "Remember variable field heights", description: "Keep manually resized variable fields per prompt.") { Toggle("", isOn: $rememberFieldHeights).labelsHidden() }
                SettingRow(label: "Show required count", description: "Display required variable counts in the panel header.") { Toggle("", isOn: $showRequiredCount).labelsHidden() }
                SettingRow(label: "Variable action row style", description: "Control how preset/copy actions are grouped.", showDivider: false) { SettingsOptionPicker(selection: $actionRowStyle, options: [("compact", "Compact"), ("full", "Full Labels"), ("icons", "Icons")], width: 170) }
            }
            SettingsCard(title: "Variable Behavior") {
                SettingRow(label: "Copy filled prompt button", description: "Show the primary filled-copy action for variable prompts.") { Toggle("", isOn: $copyFilledVisible).labelsHidden() }
                SettingRow(label: "Presets enabled", description: "Allow saving and loading reusable variable value presets.") { Toggle("", isOn: $presetsEnabled).labelsHidden() }
                SettingRow(label: "Default variable type", description: "Choose the default input type for newly detected variables.") { SettingsOptionPicker(selection: $defaultType, options: [("text", "Text"), ("textarea", "Textarea"), ("url", "URL"), ("select", "Select")], width: 170) }
                SettingRow(label: "Insert variable format", description: "Preferred syntax when inserting a variable token.") { SettingsOptionPicker(selection: $insertFormat, options: [("braces", "{variable}"), ("double", "{{variable}}"), ("brackets", "[Variable]")], width: 170) }
                SettingRow(label: "Auto-detect variables", description: "Detect variables from braces and supported placeholder syntax.") { Toggle("", isOn: $autoDetect).labelsHidden() }
                SettingRow(label: "Highlight variables", description: "Highlight variable tokens inside prompt content where supported.") { Toggle("", isOn: $highlight).labelsHidden() }
                SettingRow(label: "Require variable descriptions", description: "Flag variables that are missing descriptions during review.") { Toggle("", isOn: $requireDescriptions).labelsHidden() }
                SettingRow(label: "Sort variables by", description: "Choose the default variable order in the panel.", showDivider: false) { SettingsOptionPicker(selection: $sortBy, options: [("source", "Source Order"), ("az", "A-Z"), ("required", "Required First")], width: 170) }
            }
        }
    }
}

private struct LibrarySidebarSettingsPage: View {
    @AppStorage(AppSettingsKeys.librarySidebarShowCounts) private var showCounts = true
    @AppStorage(AppSettingsKeys.librarySidebarShowFolderCounts) private var showFolderCounts = true
    @AppStorage(AppSettingsKeys.librarySidebarShowIcons) private var showIcons = true
    @AppStorage(AppSettingsKeys.librarySidebarFolderIndentation) private var folderIndentation = "compact"
    @AppStorage(AppSettingsKeys.librarySidebarAutoExpand) private var autoExpand = false
    @AppStorage(AppSettingsKeys.librarySidebarRememberExpanded) private var rememberExpanded = true
    @AppStorage(AppSettingsKeys.librarySidebarFooterShortcuts) private var footerShortcuts = true

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Library Rows") {
                SettingRow(label: "Show library counts", description: "Display counts next to All, Favorites, Recent, Templates, Variables, and Phrases.") { Toggle("", isOn: $showCounts).labelsHidden() }
                SettingRow(label: "Show sidebar icons", description: "Display SF Symbol icons beside library navigation rows.") { Toggle("", isOn: $showIcons).labelsHidden() }
                SettingRow(label: "Show footer shortcuts", description: "Keep bottom utility shortcuts such as Settings visible in the sidebar footer.") { Toggle("", isOn: $footerShortcuts).labelsHidden() }
            }
            SettingsCard(title: "Folder Tree") {
                SettingRow(label: "Show folder counts", description: "Display prompt counts next to folder names.") { Toggle("", isOn: $showFolderCounts).labelsHidden() }
                SettingRow(label: "Folder indentation", description: "Choose compact or standard nested-folder indentation.") { SettingsOptionPicker(selection: $folderIndentation, options: [("compact", "Compact"), ("standard", "Standard")], width: 160) }
                SettingRow(label: "Auto-expand folders", description: "Expand folders automatically when matching search/filter state.") { Toggle("", isOn: $autoExpand).labelsHidden() }
                SettingRow(label: "Remember expanded folders", description: "Restore folder disclosure state after relaunch.", showDivider: false) { Toggle("", isOn: $rememberExpanded).labelsHidden() }
            }
        }
    }
}

private struct SearchFiltersSettingsPage: View {
    @AppStorage(AppSettingsKeys.searchDefaultSort) private var defaultSort = SortMode.updated.rawValue
    @AppStorage(AppSettingsKeys.searchRememberLastSort) private var rememberLastSort = true
    @AppStorage(AppSettingsKeys.searchScope) private var searchScope = "all"
    @AppStorage(AppSettingsKeys.searchBehavior) private var searchBehavior = "contains"
    @AppStorage(AppSettingsKeys.searchClearAfterCreate) private var clearAfterCreate = true
    @AppStorage(AppSettingsKeys.searchShowFilterChips) private var showFilterChips = true
    @AppStorage(AppSettingsKeys.searchDefaultTypeFilter) private var defaultTypeFilter = "all"
    @AppStorage(AppSettingsKeys.searchInTitle) private var searchInTitle = true
    @AppStorage(AppSettingsKeys.searchInBody) private var searchInBody = true
    @AppStorage(AppSettingsKeys.searchInNotes) private var searchInNotes = true
    @AppStorage(AppSettingsKeys.searchInMetadata) private var searchInMetadata = true

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Sort and Filters") {
                SettingRow(label: "Default sort", description: "Sort mode used for new sessions when last sort is not restored.") { SettingsOptionPicker(selection: $defaultSort, options: SortMode.allCases.map { ($0.rawValue, $0.rawValue) }, width: 190) }
                SettingRow(label: "Remember last sort", description: "Restore the last sort choice between launches.") { Toggle("", isOn: $rememberLastSort).labelsHidden() }
                SettingRow(label: "Show filter chips", description: "Display type, category, and subcategory filter chips above the list.") { Toggle("", isOn: $showFilterChips).labelsHidden() }
                SettingRow(label: "Default type filter", description: "Choose a default entry type when opening the library.") { SettingsOptionPicker(selection: $defaultTypeFilter, options: [("all", "All"), ("prompt", "Prompt"), ("phrase", "Phrase"), ("variable", "Variable Prompt")], width: 180) }
            }
            SettingsCard(title: "Search Behavior") {
                SettingRow(label: "Search scope", description: "Choose where search should look by default.") { SettingsOptionPicker(selection: $searchScope, options: [("all", "All Fields"), ("titles", "Titles"), ("body", "Body"), ("metadata", "Metadata")], width: 170) }
                SettingRow(label: "Search behavior", description: "Choose matching behavior for typed queries.") { SettingsOptionPicker(selection: $searchBehavior, options: [("contains", "Contains"), ("fuzzy", "Fuzzy"), ("exact", "Exact")], width: 160) }
                SettingRow(label: "Clear search after creating item", description: "Clear stale search text when creating a prompt so the new item is visible.") { Toggle("", isOn: $clearAfterCreate).labelsHidden() }
                SettingRow(label: "Search in title", description: "Include prompt titles in search.") { Toggle("", isOn: $searchInTitle).labelsHidden() }
                SettingRow(label: "Search in body", description: "Include prompt body text in search.") { Toggle("", isOn: $searchInBody).labelsHidden() }
                SettingRow(label: "Search in notes", description: "Include right-sidebar notes in search.") { Toggle("", isOn: $searchInNotes).labelsHidden() }
                SettingRow(label: "Search in metadata", description: "Include category, subcategory, type, and usage metadata.", showDivider: false) { Toggle("", isOn: $searchInMetadata).labelsHidden() }
            }
        }
    }
}

private struct ImportExportStorageSettingsPage: View {
    @AppStorage(AppSettingsKeys.storageLocation) private var storageLocation = "Application Support"
    @AppStorage(AppSettingsKeys.storageImportFolderBehavior) private var importFolderBehavior = "preserve"
    @AppStorage(AppSettingsKeys.storageDuplicateImportBehavior) private var duplicateImportBehavior = "skip"
    @AppStorage(AppSettingsKeys.storagePreserveSourcePath) private var preserveSourcePath = true
    @AppStorage(AppSettingsKeys.storageAutoBackup) private var autoBackup = false
    @AppStorage(AppSettingsKeys.storageBackupFrequency) private var backupFrequency = "weekly"
    @AppStorage(AppSettingsKeys.storageKeepBackupsFor) private var keepBackupsFor = "30"
    @AppStorage(AppSettingsKeys.storageDefaultExportFormat) private var defaultExportFormat = "markdown"
    @AppStorage(AppSettingsKeys.storageAttachmentMode) private var attachmentMode = "local"
    @AppStorage(AppSettingsKeys.storageCustomLocation) private var customLocation = ""
    @AppStorage(AppSettingsKeys.storageChainMarkdownOutputFolder) private var chainMarkdownOutputFolder = ""
    @AppStorage(AppSettingsKeys.storageChainOutputIncludeStepPrefix) private var chainIncludeStepPrefix = true
    @AppStorage(AppSettingsKeys.storageChainOutputIncludeSuffix) private var chainIncludeSuffix = true
    @AppStorage(AppSettingsKeys.storageChainOutputSuffix) private var chainOutputSuffix = "response"
    @AppStorage(AppSettingsKeys.storageChainOutputShowTagControls) private var chainShowTagControls = true
    @AppStorage(AppSettingsKeys.storageChainCollapsedPreviewLines) private var chainCollapsedPreviewLines = 0
    @AppStorage(AppSettingsKeys.storageChainCustomStatuses) private var chainCustomStatusesRaw = ChainCustomStatusSettings.encode(ChainCustomStatusSettings.defaults)
    @State private var actionStatus = ""
    @State private var newChainStatus = ""

    private var chainCustomStatuses: [String] {
        ChainCustomStatusSettings.decode(chainCustomStatusesRaw)
    }

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Storage") {
                SettingRow(label: "Library storage location", description: "Where the local prompt library is stored.") { SettingsOptionPicker(selection: $storageLocation, options: [("Application Support", "Application Support"), ("Documents", "Documents"), ("Custom", "Custom")], width: 210) }
                SettingRow(label: "Migrate selected storage", description: "Copy the current library into the selected storage location for the next launch.") { Button("Migrate", action: migrateStorage).buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
                SettingRow(label: "Attachment storage", description: "Choose how future prompt attachments should be stored.") { SettingsOptionPicker(selection: $attachmentMode, options: [("local", "Local"), ("linked", "Linked Files"), ("none", "Disabled")], width: 170) }
                SettingRow(label: "Attachment policy", description: "Current attachment mode evidence for new attachment workflows.") { Text(attachmentPolicyText).font(DT.FontToken.captionStrong).foregroundStyle(DT.ColorToken.textSecondary) }
                SettingRow(label: "Chain markdown output folder", description: chainMarkdownOutputFolder.isEmpty ? "Default app support Chain Outputs folder." : chainMarkdownOutputFolder) {
                    HStack(spacing: 8) {
                        Button("Choose", action: chooseChainMarkdownFolder).buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                        Button("Default") { chainMarkdownOutputFolder = "" }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                    }
                }
                SettingRow(label: "Chain filename step prefix", description: "Include step-01, step-02 before automatic chain output filenames.") { Toggle("", isOn: $chainIncludeStepPrefix).labelsHidden() }
                SettingRow(label: "Chain filename suffix", description: "Append a suffix to automatic chain output filenames.") { Toggle("", isOn: $chainIncludeSuffix).labelsHidden() }
                if chainIncludeSuffix {
                    SettingRow(label: "Suffix text", description: "Custom suffix appended to automatic chain output filenames.") {
                        TextField("response", text: $chainOutputSuffix)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .frame(width: 170, height: 30)
                            .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                    }
                }
                SettingRow(label: "Show chain tag controls", description: "Show optional tag fields in chain steps and previous-output variables.") { Toggle("", isOn: $chainShowTagControls).labelsHidden() }
                SettingRow(label: "Collapsed step preview lines", description: "Default output lines shown when newly created chain steps are collapsed. Use 0 to hide output.") {
                    SettingsIntegerStepper(value: $chainCollapsedPreviewLines, range: 0...20, step: 1)
                        .frame(width: 150, alignment: .trailing)
                }
                SettingRow(label: "Reveal storage folder", description: "Open the local app support folder in Finder.", showDivider: false) { Button("Reveal", action: revealStorageFolder).buttonStyle(SecondaryButtonStyle(horizontalPadding: 12)) }
                if !actionStatus.isEmpty { Text(actionStatus).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary) }
            }
            SettingsCard(title: "Chain Custom Statuses") {
                Text("Statuses defined here are available in each chain loop popover for stop/status rules.")
                    .font(DT.FontToken.caption)
                    .foregroundStyle(DT.ColorToken.textTertiary)
                VStack(spacing: 0) {
                    ForEach(Array(chainCustomStatuses.enumerated()), id: \.offset) { index, status in
                        SettingRow(label: "Status \(index + 1)", description: index < 2 ? "Default chain status." : "Custom chain status.") {
                            HStack(spacing: 8) {
                                TextField("Status", text: Binding(
                                    get: { status },
                                    set: { updateChainStatus(at: index, value: $0) }
                                ))
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .frame(width: 170, height: 30)
                                .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                                Button {
                                    removeChainStatus(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(IconToolbarButtonStyle())
                                .disabled(chainCustomStatuses.count <= 1)
                                .accessibilityLabel("Delete custom chain status")
                            }
                        }
                    }
                }
                SettingRow(label: "Add status", description: "Add another status option for chain monitor rules.", showDivider: false) {
                    HStack(spacing: 8) {
                        TextField("Target reached", text: $newChainStatus)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .frame(width: 170, height: 30)
                            .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                        Button("Add", action: addChainStatus)
                            .buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                            .disabled(newChainStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            SettingsCard(title: "Import") {
                SettingRow(label: "Import folder behavior", description: "How source folders should map into the library.") { SettingsOptionPicker(selection: $importFolderBehavior, options: [("preserve", "Preserve"), ("flatten", "Flatten"), ("ask", "Ask Each Time")], width: 180) }
                SettingRow(label: "Duplicate import behavior", description: "What to do when an imported prompt already exists.") { SettingsOptionPicker(selection: $duplicateImportBehavior, options: [("skip", "Skip"), ("update", "Update"), ("copy", "Create Copy"), ("ask", "Ask")], width: 180) }
                SettingRow(label: "Preserve source path metadata", description: "Keep original source-path metadata on imported prompts.") { Toggle("", isOn: $preserveSourcePath).labelsHidden() }
            }
            SettingsCard(title: "Export and Backups") {
                SettingRow(label: "Default export format", description: "Preferred format when exporting prompt collections.") { SettingsOptionPicker(selection: $defaultExportFormat, options: [("markdown", "Markdown"), ("json", "JSON Backup"), ("txt", "Plain Text")], width: 180) }
                SettingRow(label: "Automatic backups", description: "Create periodic local library backups.") { Toggle("", isOn: $autoBackup).labelsHidden() }
                SettingRow(label: "Backup frequency", description: "How often automatic backups should run when enabled.") { SettingsOptionPicker(selection: $backupFrequency, options: [("daily", "Daily"), ("weekly", "Weekly"), ("monthly", "Monthly")], width: 160) }
                SettingRow(label: "Keep backups for", description: "Retention period for automatic backups.", showDivider: false) { SettingsOptionPicker(selection: $keepBackupsFor, options: [("7", "7 days"), ("30", "30 days"), ("90", "90 days"), ("365", "1 year")], width: 160) }
            }
        }
    }

    private func updateChainStatus(at index: Int, value: String) {
        var statuses = chainCustomStatuses
        guard statuses.indices.contains(index) else { return }
        statuses[index] = value
        chainCustomStatusesRaw = ChainCustomStatusSettings.encode(statuses)
    }

    private func removeChainStatus(at index: Int) {
        var statuses = chainCustomStatuses
        guard statuses.indices.contains(index), statuses.count > 1 else { return }
        statuses.remove(at: index)
        chainCustomStatusesRaw = ChainCustomStatusSettings.encode(statuses)
    }

    private func addChainStatus() {
        let clean = newChainStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var statuses = chainCustomStatuses
        if !statuses.contains(clean) { statuses.append(clean) }
        chainCustomStatusesRaw = ChainCustomStatusSettings.encode(statuses)
        newChainStatus = ""
    }

    private var attachmentPolicyText: String {
        switch attachmentMode { case "linked": "Linked file references"; case "none": "Attachments disabled"; default: "Local attachment copies" }
    }

    private func migrateStorage() {
        do {
            let url = try PromptStore.migrateCurrentStore(to: storageLocation, customPath: customLocation.isEmpty ? nil : customLocation)
            actionStatus = "Migrated storage to \(url.deletingLastPathComponent().path). Restart to use it."
        } catch { actionStatus = "Storage migration failed: \(error.localizedDescription)" }
    }

    private func revealStorageFolder() {
        #if os(macOS)
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
        NSWorkspace.shared.activateFileViewerSelecting([url])
        actionStatus = "Opened storage location in Finder."
        #else
        actionStatus = "Storage location reveal is unavailable on this platform."
        #endif
    }

    private func chooseChainMarkdownFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose the folder where chained prompt Markdown outputs should be saved."
        if panel.runModal() == .OK, let url = panel.url {
            chainMarkdownOutputFolder = url.path
            actionStatus = "Chain Markdown outputs will save to \(url.path)."
        }
        #else
        actionStatus = "Folder selection is unavailable on this platform."
        #endif
    }
}

private struct ClipboardCopySettingsPage: View {
    @AppStorage(AppSettingsKeys.clipboardRawShortcut) private var rawShortcut = true
    @AppStorage(AppSettingsKeys.clipboardFilledShortcut) private var filledShortcut = true
    @AppStorage(AppSettingsKeys.clipboardIncludeTitle) private var includeTitle = false
    @AppStorage(AppSettingsKeys.clipboardIncludeMetadata) private var includeMetadata = false
    @AppStorage(AppSettingsKeys.clipboardPreserveMarkdown) private var preserveMarkdown = true
    @AppStorage(AppSettingsKeys.clipboardSuccessFeedback) private var successFeedback = true
    @AppStorage(AppSettingsKeys.clipboardDefaultCopyMode) private var defaultCopyMode = "raw"
    @AppStorage(AppSettingsKeys.clipboardRequireVariables) private var requireVariables = true

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Copy Actions") {
                SettingRow(label: "Raw prompt copy shortcut", description: "Enable quick copy for the selected prompt body.") { Toggle("", isOn: $rawShortcut).labelsHidden() }
                SettingRow(label: "Filled prompt copy shortcut", description: "Enable quick copy for variable prompts after values are filled.") { Toggle("", isOn: $filledShortcut).labelsHidden() }
                SettingRow(label: "Default copy mode", description: "Choose the preferred copy behavior when both modes are available.") { SettingsOptionPicker(selection: $defaultCopyMode, options: [("raw", "Raw Prompt"), ("filled", "Filled Prompt"), ("ask", "Ask")], width: 170) }
                SettingRow(label: "Require variables before filled copy", description: "Block filled-copy until all required variables have values.") { Toggle("", isOn: $requireVariables).labelsHidden() }
            }
            SettingsCard(title: "Clipboard Format") {
                SettingRow(label: "Include title on copy", description: "Prefix copied prompts with the prompt title.") { Toggle("", isOn: $includeTitle).labelsHidden() }
                SettingRow(label: "Include metadata on copy", description: "Include category and when-to-use metadata when copying.") { Toggle("", isOn: $includeMetadata).labelsHidden() }
                SettingRow(label: "Preserve Markdown", description: "Keep Markdown formatting in copied prompt text.") { Toggle("", isOn: $preserveMarkdown).labelsHidden() }
                SettingRow(label: "Copy success feedback", description: "Show a visible copied/saved message after copy actions.", showDivider: false) { Toggle("", isOn: $successFeedback).labelsHidden() }
            }
        }
    }
}

private struct AccessibilitySettingsPage: View {
    @Binding var fontScale: AppFontScale
    @AppStorage(AppSettingsKeys.accessibilityReduceMotion) private var reduceMotion = false
    @AppStorage(AppSettingsKeys.accessibilityIncreaseContrast) private var increaseContrast = false
    @AppStorage(AppSettingsKeys.accessibilityFocusRing) private var focusRing = "standard"
    @AppStorage(AppSettingsKeys.accessibilityKeyboardNavigation) private var keyboardNavigation = true
    @AppStorage(AppSettingsKeys.accessibilityLargerTargets) private var largerTargets = false
    @AppStorage(AppSettingsKeys.accessibilityShowTooltips) private var showTooltips = true
    @AppStorage(AppSettingsKeys.accessibilityReduceTransparency) private var reduceTransparency = false

    var body: some View {
        SettingsFormScroll {
            SettingsCard(title: "Readability") {
                SettingRow(label: "UI font size", description: "Increase or decrease app-wide control text.", showDivider: false) { SettingsSegmentedEnumControl(selection: $fontScale, options: AppFontScale.allCases, label: { $0.displayName }) }
                SettingRow(label: "Increase contrast", description: "Prefer stronger borders and text contrast where supported.") { Toggle("", isOn: $increaseContrast).labelsHidden() }
                SettingRow(label: "Reduce transparency", description: "Prefer solid surfaces for panels and cards.") { Toggle("", isOn: $reduceTransparency).labelsHidden() }
                SettingRow(label: "Larger click targets", description: "Use roomier targets for small utility controls.") { Toggle("", isOn: $largerTargets).labelsHidden() }
            }
            SettingsCard(title: "Interaction") {
                SettingRow(label: "Reduce motion", description: "Avoid decorative animation and motion where possible.") { Toggle("", isOn: $reduceMotion).labelsHidden() }
                SettingRow(label: "Keyboard navigation", description: "Keep keyboard navigation active for primary controls.") { Toggle("", isOn: $keyboardNavigation).labelsHidden() }
                SettingRow(label: "Focus ring strength", description: "Choose how visible focused fields should be.") { SettingsOptionPicker(selection: $focusRing, options: [("subtle", "Subtle"), ("standard", "Standard"), ("strong", "Strong")], width: 160) }
                SettingRow(label: "Show tooltips", description: "Display help text for toolbar and compact controls.") { Toggle("", isOn: $showTooltips).labelsHidden() }
                SettingRow(label: "Accessibility evidence", description: "Visible confirmation of active accessibility preferences.", showDivider: false) { Text(evidenceText).font(DT.FontToken.captionStrong).foregroundStyle(DT.ColorToken.textSecondary).frame(width: 220, alignment: .trailing) }
            }
        }
    }

    private var evidenceText: String {
        var items: [String] = []
        if increaseContrast { items.append("Higher contrast") }
        if reduceTransparency { items.append("Solid surfaces") }
        if largerTargets { items.append("Larger targets") }
        if reduceMotion { items.append("Reduced motion") }
        items.append("Focus: \(focusRing.humanizedTitle)")
        items.append(showTooltips ? "Tooltips on" : "Tooltips off")
        return items.joined(separator: " • ")
    }
}

private struct SummarySettingsPage: View {
    let title: String
    let icon: String
    let message: String
    let metrics: [(String, String)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SettingsCard(title: title) {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(DT.ColorToken.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                        Text(message)
                            .font(DT.FontToken.bodySmall)
                            .foregroundStyle(DT.ColorToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !metrics.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(metrics, id: \.0) { metric in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(metric.1).font(.system(size: 20, weight: .bold)).foregroundStyle(DT.ColorToken.textPrimary)
                                    Text(metric.0).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                            }
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

private struct SettingsLivePreview: View {
    let promptListSettings: PromptListDisplaySettings
    let rightSidebarSections: RightSidebarSectionVisibility
    @State private var selectedPreviewTitle = "Alternative Infrastructure Visual Metaphor"

    private var previewPrompts: [Prompt] {
        [
            Prompt(title: "Alternative Infrastructure Visual Metaphor", content: "Current visual / section: hero visual section for the technical architecture narrative.", isFavorite: true, updatedAt: .now.addingTimeInterval(-1_260), type: .prompt, primaryCategory: "design", subcategory: "component-design", whenToUse: "Use when you want the same message communicated through a different technical visual component.", variables: [VariableDefinition(key: "current_hero_visual_section_or_html"), VariableDefinition(key: "preferred_metaphor")]),
            Prompt(title: "Balsamiq Redesign Before After", content: "Current interface: redesign this before and after mockup with clear annotations.", updatedAt: .now.addingTimeInterval(-10_800), primaryCategory: "design", variables: [VariableDefinition(key: "screen")]),
            Prompt(title: "Business Plan", content: "You will receive a markdown file with a short description and target market.", updatedAt: .now.addingTimeInterval(-25_200), primaryCategory: "business")
        ]
    }

    var body: some View {
        SettingsCard(title: "Live Preview", subtitle: "This preview shows how your layout settings affect the app.") {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(DT.ColorToken.textTertiary)
                        Text("Search prompts...").font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.borderDefault))
                    .padding(8)
                    Divider().overlay(DT.ColorToken.borderSubtle)
                    ForEach(previewPrompts) { prompt in
                        PromptListRowView(prompt: prompt, selected: prompt.title == selectedPreviewTitle, displaySettings: promptListSettings) { selectedPreviewTitle = prompt.title }
                        Divider().overlay(DT.ColorToken.borderSubtle)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 220)
                .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: DT.Radius.lg).stroke(DT.ColorToken.borderDefault))

                EditorPreviewCard(prompt: previewPrompts[0])
                    .frame(minWidth: 240, maxWidth: .infinity)
                InspectorPreviewCard(prompt: previewPrompts[0], visibility: rightSidebarSections)
                    .frame(width: 260)
            }
            .frame(minHeight: 520)
        }
    }
}

private struct EditorPreviewCard: View {
    let prompt: Prompt
    @State private var actionStatus = "Ready"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DT.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Favorite") { actionStatus = "Favorite toggled in preview" }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                Button("Copy") { actionStatus = "Prompt copied in preview" }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                Button("Save") { actionStatus = "Preview saved" }.buttonStyle(PrimaryButtonStyle(horizontalPadding: 10))
            }
            Text(actionStatus).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary)
            SettingsPreviewVariablesCard(prompt: prompt)
            Spacer()
            HStack {
                Text("Markdown")
                    .font(DT.FontToken.captionStrong)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DT.Radius.sm).stroke(DT.ColorToken.borderDefault))
                Spacer()
                Text("101 words • 782 characters")
                    .font(DT.FontToken.caption)
                    .foregroundStyle(DT.ColorToken.textTertiary)
            }
        }
        .padding(14)
        .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.lg).stroke(DT.ColorToken.borderDefault))
    }
}

private struct SettingsPreviewVariablesCard: View {
    let prompt: Prompt
    @AppStorage(AppSettingsKeys.storageCustomLocation) private var customLocation = ""
    @State private var actionStatus = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Variables", systemImage: "curlybraces")
                    .font(DT.FontToken.bodySmallStrong)
                    .foregroundStyle(DT.ColorToken.textSecondary)
                Spacer()
                Text("2 required")
                    .font(DT.FontToken.caption)
                    .foregroundStyle(DT.ColorToken.textTertiary)
            }
            HStack {
                Button("Preset") { actionStatus = "Preset menu opened in preview" }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                Spacer()
                Button("Copy Fill…") { actionStatus = "Filled prompt copied in preview" }.buttonStyle(PrimaryButtonStyle(horizontalPadding: 10))
            }
            if !actionStatus.isEmpty { Text(actionStatus).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary) }
            ForEach(prompt.variables.prefix(2)) { variable in
                VStack(alignment: .leading, spacing: 5) {
                    Text(variable.label).font(DT.FontToken.captionStrong).foregroundStyle(DT.ColorToken.textSecondary)
                    RoundedRectangle(cornerRadius: DT.Radius.md)
                        .fill(DT.ColorToken.surfacePrimary)
                        .frame(height: 56)
                        .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.borderDefault))
                }
            }
        }
        .padding(12)
        .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.lg).stroke(DT.ColorToken.borderDefault))
    }
}

private struct InspectorPreviewCard: View {
    let prompt: Prompt
    let visibility: RightSidebarSectionVisibility

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if visibility.folder { PreviewDetailsCard(title: "Folder", icon: "folder") { PreviewField("Design > Component Design") } }
                if visibility.promptMetadata { PreviewMetadataCard(prompt: prompt) }
                if visibility.notes { PreviewDetailsCard(title: "Notes", icon: "note.text") { RoundedRectangle(cornerRadius: DT.Radius.md).fill(DT.ColorToken.surfacePrimary).frame(height: 82).overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.borderDefault)) } }
                if visibility.metadata { PreviewDetailsCard(title: "Metadata", icon: "calendar") { VStack(spacing: 8) { PreviewMetaRow("Created", "28/05/26"); PreviewMetaRow("Updated", "28/05/26"); PreviewMetaRow("Last Opened", "28/05/26"); PreviewMetaRow("Copy Count", "0") } } }
            }
            .padding(10)
        }
        .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.lg).stroke(DT.ColorToken.borderDefault))
    }
}

private struct PreviewMetadataCard: View {
    let prompt: Prompt
    var body: some View {
        PreviewDetailsCard(title: "Prompt Metadata", icon: "line.3.horizontal.decrease.circle") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Type").font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary)
                    Spacer()
                    Text("Variable Prompt")
                        .font(DT.FontToken.captionStrong)
                        .foregroundStyle(DT.ColorToken.accentBlue)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(DT.ColorToken.accentBlueSoft, in: Capsule())
                }
                PreviewField(prompt.primaryCategory)
                PreviewField(prompt.subcategory)
                Text(prompt.whenToUse).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary).fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DT.Radius.sm).stroke(DT.ColorToken.borderDefault))
            }
        }
    }
}

private struct PreviewDetailsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(DT.FontToken.captionStrong).foregroundStyle(DT.ColorToken.textSecondary)
            content
        }
        .padding(12)
        .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.lg).stroke(DT.ColorToken.borderDefault))
    }
}

private struct PreviewField: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack { Text(text).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary).lineLimit(1); Spacer(); Image(systemName: "chevron.down").font(.system(size: 10)).foregroundStyle(DT.ColorToken.textTertiary) }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.sm).stroke(DT.ColorToken.borderDefault))
    }
}

private struct PreviewMetaRow: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View { HStack { Text(label); Spacer(); Text(value) }.font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary) }
}

private struct SummaryPreviewCard: View {
    @AppStorage(AppSettingsKeys.storageCustomLocation) private var customLocation = ""
    @State private var actionStatus = ""
    var body: some View {
        SettingsCard(title: "Preview") {
            Text("Appearance changes update this workspace and shared app controls immediately.")
                .font(DT.FontToken.bodySmall)
                .foregroundStyle(DT.ColorToken.textSecondary)
            HStack(spacing: 8) {
                Button("Create") { actionStatus = "Create preview clicked" }.buttonStyle(PrimaryButtonStyle(horizontalPadding: 12))
                Button("Cancel") { actionStatus = "Cancel preview clicked" }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
            }
            if !actionStatus.isEmpty { Text(actionStatus).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary) }
            PromptListRowView(prompt: Prompt(title: "Accent preview prompt", content: "Selected states, buttons, and focus rings use the chosen accent color.", isFavorite: true, primaryCategory: "design"), selected: true, displaySettings: .defaultValue) { actionStatus = "Preview row selected" }
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.lg))
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(DT.FontToken.bodySmallStrong).foregroundStyle(DT.ColorToken.textPrimary)
                if let subtitle { Text(subtitle).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary) }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.lg).stroke(DT.ColorToken.borderDefault))
    }
}

private struct SettingRow<Control: View>: View {
    let label: String
    let description: String
    var showDivider = true
    @ViewBuilder let control: Control
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(DT.FontToken.captionStrong).foregroundStyle(DT.ColorToken.textPrimary)
                Text(description).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if showDivider {
                Rectangle().fill(DT.ColorToken.borderSubtle).frame(height: 1).offset(y: 8)
            }
        }
    }
}

private struct SettingsSegmentedEnumControl<Option: Identifiable & Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String
    @Environment(\.appAccentStyle) private var accent

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(DT.FontToken.captionStrong)
                        .foregroundStyle(selection == option ? DT.ColorToken.textInverse : DT.ColorToken.textPrimary)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .frame(minWidth: 58)
                        .background {
                            if selection == option {
                                Rectangle().fill(accent.color)
                            }
                        }
                }
                .buttonStyle(.plain)

                if index < options.count - 1 {
                    Rectangle()
                        .fill(DT.ColorToken.borderDefault)
                        .frame(width: 1, height: 16)
                }
            }
        }
        .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.sm))
    }
}

private struct SettingsSegmentButtonStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.appAccentStyle) private var accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DT.FontToken.captionStrong)
            .foregroundStyle(selected ? DT.ColorToken.textInverse : DT.ColorToken.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background {
                if selected {
                    Rectangle().fill(accent.color)
                }
            }
    }
}
