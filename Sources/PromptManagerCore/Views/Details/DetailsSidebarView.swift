import SwiftUI

struct DetailsSidebarView: View {
    @Binding var prompt: Prompt
    let folders: [Folder]
    let categories: [String]
    let subcategories: [String]
    let filledCopyMessage: String?
    var sectionVisibility: RightSidebarSectionVisibility = .defaultValue
    var variableSettings: VariablePromptBehaviorSettings = .defaultValue
    var whenToUseDefaultOpen = false
    var notesDefaultOpen = false
    var variablesDefaultOpen = false
    @Binding var expandedVariableKey: String?
    let onSave: () -> Void
    let onCopyFilled: ([String: String]) -> Bool
    let onMoveToFolder: (UUID?) -> Void

    @State private var variableValues: [String: String] = [:]
    @State private var variableFieldHeights: [String: CGFloat] = [:]
    @State private var selectedPresetID: UUID?
    @State private var whenOpen = false
    @State private var notesOpen = false
    @State private var variablesInitialized = false
    @AppStorage(AppSettingsKeys.storageChainCollapsedPreviewLines) private var collapsedPreviewLines = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if prompt.hasVariables && variableSettings.showPanel {
                    VariableInspectorSection(
                        prompt: $prompt,
                        values: $variableValues,
                        fieldHeights: $variableFieldHeights,
                        selectedPresetID: $selectedPresetID,
                        expandedVariableKey: $expandedVariableKey,
                        message: filledCopyMessage,
                        defaultOpen: variablesDefaultOpen,
                        onCopyFilled: { _ = onCopyFilled(variableValues) },
                        onSave: onSave,
                        settings: variableSettings
                    )
                    .padding(.bottom, 22)
                }

                if prompt.hasVariables {
                    InspectorSectionTitle(title: "Variable Runner", icon: "play.rectangle")
                    VStack(spacing: 0) {
                        InspectorRowChrome(label: "Collapsed preview", icon: "text.justify.left") {
                            Stepper(value: collapsedPreviewBinding, in: 0...20, step: 1) {
                                Text("\(collapsedPreviewLines) lines")
                                    .font(DT.FontToken.caption)
                                    .foregroundStyle(DT.ColorToken.textSecondary)
                                    .frame(width: 58, alignment: .trailing)
                            }
                            .frame(width: 110, alignment: .trailing)
                            .help("Output lines shown when the variable prompt runner is collapsed. Use 0 to hide output.")
                        }
                    }
                    .padding(.bottom, 22)
                }

                if sectionVisibility.promptMetadata {
                    InspectorSectionTitle(title: prompt.type == .phrase ? "Phrase Metadata" : "Prompt Metadata", icon: "line.3.horizontal.decrease.circle")
                    VStack(spacing: 0) {
                        FolderMetadataRow(prompt: $prompt, folders: folders, onMoveToFolder: onMoveToFolder)
                        CategoryMetadataRow(prompt: $prompt, categories: categories, onSave: onSave)
                        SubcategoryMetadataRow(prompt: $prompt, subcategories: subcategories, onSave: onSave)
                        InspectorAccordionRow(title: "When to use", icon: "questionmark.circle", isOpen: $whenOpen) {
                            NeutralTextEditor(text: Binding(get: { prompt.whenToUse }, set: { value in
                                guard prompt.whenToUse != value else { return }
                                prompt.whenToUse = value
                                prompt.touch()
                                onSave()
                            }), minHeight: 86, placeholder: "When should this be used?")
                        }
                        if sectionVisibility.notes {
                            InspectorAccordionRow(title: "Notes", icon: "note.text", isOpen: $notesOpen) {
                                NeutralTextEditor(text: Binding(get: { prompt.notes }, set: { value in
                                    guard prompt.notes != value else { return }
                                    prompt.updateNotes(value)
                                    onSave()
                                }), minHeight: 104, placeholder: "Private notes")
                                HStack { Spacer(); Text("\(prompt.notes.count) / 500").font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary) }
                            }
                        }
                    }
                }

                if sectionVisibility.metadata {
                    InspectorSectionTitle(title: "Metadata", icon: "calendar")
                        .padding(.top, 28)
                    MetadataPanelView(prompt: prompt)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(DT.ColorToken.surfacePrimary)
        .onAppear { initializeState() }
        .onChange(of: prompt.id) { _, _ in initializeState() }
        .onChange(of: variablesDefaultOpen) { _, _ in variablesInitialized = false }
    }

    private func initializeState() {
        variableValues = Dictionary(uniqueKeysWithValues: prompt.variables.map { ($0.key, $0.defaultValue) })
        variableFieldHeights = [:]
        selectedPresetID = nil
        whenOpen = whenToUseDefaultOpen
        notesOpen = notesDefaultOpen
        variablesInitialized = false
    }

    private var collapsedPreviewBinding: Binding<Int> {
        Binding(
            get: { collapsedPreviewLines },
            set: { collapsedPreviewLines = max(0, min($0, 20)) }
        )
    }
}

struct InspectorSectionTitle: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(DT.FontToken.bodySmallStrong)
            .foregroundStyle(DT.ColorToken.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
    }
}

struct InspectorRowChrome<Content: View>: View {
    let label: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Label(label, systemImage: icon)
                .font(DT.FontToken.bodySmall)
                .foregroundStyle(DT.ColorToken.textSecondary)
                .labelStyle(.titleAndIcon)
                .frame(minWidth: 104, alignment: .leading)
            Spacer(minLength: 10)
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 42)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(DT.ColorToken.borderSubtle).frame(height: 1) }
    }
}

struct InspectorActionRow: View {
    @Binding var prompt: Prompt
    let copied: Bool
    let onSave: () -> Void
    let onCopy: () -> Void
    let onArchive: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button("Save", action: onSave)
                .buttonStyle(PrimaryButtonStyle(horizontalPadding: 14))
                .help("Save")

            Button(action: { prompt.toggleFavorite(); onSave() }) {
                Image(systemName: prompt.isFavorite ? "star.fill" : "star").accessibilityLabel("Favorite")
            }
            .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
            .help("Favorite")

            Button(action: onCopy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc").accessibilityLabel(copied ? "Copied" : "Copy")
            }
            .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
            .help(prompt.type == .phrase ? "Copy phrase" : "Copy prompt")

            Button(role: .destructive, action: onArchive) {
                Image(systemName: "trash").accessibilityLabel("Delete")
            }
            .buttonStyle(SecondaryButtonStyle(destructive: true, horizontalPadding: 10))
            .help("Delete")
            Spacer(minLength: 6)
        }
        .padding(.bottom, 6)
    }
}

struct FolderMetadataRow: View {
    @Binding var prompt: Prompt
    let folders: [Folder]
    let onMoveToFolder: (UUID?) -> Void

    var body: some View {
        InspectorRowChrome(label: "Folder", icon: "folder") {
            FolderPickerView(prompt: $prompt, folders: folders, onMoveToFolder: onMoveToFolder)
                .frame(maxWidth: 190)
        }
    }
}

struct CategoryMetadataRow: View {
    @Binding var prompt: Prompt
    let categories: [String]
    let onSave: () -> Void

    var body: some View {
        InspectorRowChrome(label: "Category", icon: "square.grid.2x2") {
            MetadataTokenPickerField(
                placeholder: "Category",
                value: Binding(get: { prompt.primaryCategory }, set: { setCategory($0) }),
                suggestions: categorySuggestions,
                icon: "square.grid.2x2",
                placeholderValue: "uncategorized",
                addLabel: "Add Category",
                onCommitValue: { setCategory($0) }
            )
            .frame(maxWidth: 190)
        }
    }

    private var categorySuggestions: [String] {
        Array(Set((categories + [prompt.primaryCategory]).map(\.slugKey).filter { !$0.isEmpty })).sorted()
    }

    private func setCategory(_ value: String) {
        let previous = prompt.primaryCategory.slugKey
        let slug = value.slugKey.isEmpty ? "uncategorized" : value.slugKey
        guard prompt.primaryCategory.slugKey != slug else { return }
        prompt.primaryCategory = slug
        var categorySet = Set(prompt.categories.map(\.slugKey).filter { !$0.isEmpty })
        categorySet.remove(previous)
        if slug != "uncategorized" { categorySet.insert(slug) }
        prompt.categories = categorySet.sorted()
        prompt.touch()
        onSave()
    }
}

struct SubcategoryMetadataRow: View {
    @Binding var prompt: Prompt
    let subcategories: [String]
    let onSave: () -> Void

    var body: some View {
        InspectorRowChrome(label: "Subcategory", icon: "rectangle.stack") {
            MetadataTokenPickerField(
                placeholder: "Subcategory",
                value: Binding(get: { prompt.subcategory }, set: { setSubcategory($0) }),
                suggestions: subcategorySuggestions,
                icon: "rectangle.stack",
                placeholderValue: "general",
                addLabel: "Add Subcategory",
                onCommitValue: { setSubcategory($0) }
            )
            .frame(maxWidth: 190)
        }
    }

    private var subcategorySuggestions: [String] {
        Array(Set((subcategories + [prompt.subcategory]).map(\.slugKey).filter { !$0.isEmpty })).sorted()
    }

    private func setSubcategory(_ value: String) {
        let slug = value.slugKey.isEmpty ? "general" : value.slugKey
        guard prompt.subcategory.slugKey != slug else { return }
        prompt.subcategory = slug
        prompt.touch()
        onSave()
    }
}

struct InspectorAccordionRow<Content: View>: View {
    let title: String
    let icon: String?
    @Binding var isOpen: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                isOpen.toggle()
            } label: {
                HStack(spacing: 10) {
                    if let icon {
                        Label(title, systemImage: icon)
                            .font(DT.FontToken.bodySmall)
                            .foregroundStyle(DT.ColorToken.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(title)
                            .font(DT.FontToken.bodySmall)
                            .foregroundStyle(DT.ColorToken.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DT.ColorToken.textTertiary)
                }
                .frame(height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            if isOpen {
                VStack(alignment: .leading, spacing: 8) { content }
                    .padding(.bottom, 10)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(DT.ColorToken.borderSubtle).frame(height: 1) }
    }
}

struct NeutralTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat
    var placeholder: String
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(DT.FontToken.bodySmall)
                    .foregroundStyle(DT.ColorToken.textMuted)
                    .padding(.top, 9)
                    .padding(.leading, 10)
            }
            TextEditor(text: $text)
                .font(DT.FontToken.bodySmall)
                .foregroundStyle(DT.ColorToken.textSecondary)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: minHeight)
                .focusEffectDisabled()
                .focused($focused)
        }
        .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(DT.ColorToken.borderStrong, lineWidth: 1))
    }
}

struct FolderPickerView: View {
    @Binding var prompt: Prompt
    let folders: [Folder]
    let onMoveToFolder: (UUID?) -> Void
    @State private var showingFolderPicker = false

    var body: some View {
        Button { showingFolderPicker.toggle() } label: {
            HStack(spacing: 8) {
                Text(selectedFolderName)
                    .font(DT.FontToken.bodySmall)
                    .foregroundStyle(Color(light: "#374151", dark: "#CBD5E1"))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DT.ColorToken.textTertiary)
            }
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .popover(isPresented: $showingFolderPicker, arrowEdge: .bottom) {
            FolderPickerPopover(folders: folders, selectedFolderID: prompt.folderID) { folderID in
                onMoveToFolder(folderID)
                showingFolderPicker = false
            }
        }
        .onDisappear { showingFolderPicker = false }
    }

    private var selectedFolderName: String {
        guard let folderID = prompt.folderID, let folder = folders.first(where: { $0.id == folderID }) else { return "No Folder" }
        return folderPath(folder)
    }

    private func folderPath(_ folder: Folder) -> String {
        if let parentID = folder.parentFolderID, let parent = folders.first(where: { $0.id == parentID }) { return "\(parent.name) > \(folder.name)" }
        return folder.name
    }
}

struct FolderPickerPopover: View {
    let folders: [Folder]
    let selectedFolderID: UUID?
    let select: (UUID?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                DropdownOptionRow(title: "No Folder", selected: selectedFolderID == nil, action: { select(nil) })
                Divider().overlay(DT.ColorToken.borderDefault)
                ForEach(sortedFolders) { folder in
                    DropdownOptionRow(title: folderPath(folder), selected: selectedFolderID == folder.id, action: { select(folder.id) })
                }
            }
            .padding(8)
        }
        .frame(width: 260, height: min(280, CGFloat(max(2, folders.count + 1)) * 36 + 18))
        .background(DT.ColorToken.surfacePrimary)
    }

    private var sortedFolders: [Folder] { folders.sorted { folderPath($0).localizedCaseInsensitiveCompare(folderPath($1)) == .orderedAscending } }
    private func folderPath(_ folder: Folder) -> String {
        if let parentID = folder.parentFolderID, let parent = folders.first(where: { $0.id == parentID }) { return "\(parent.name) > \(folder.name)" }
        return folder.name
    }
}

struct DropdownOptionRow: View {
    let title: String
    var selected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(DT.FontToken.bodySmall)
                    .foregroundStyle(DT.ColorToken.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 12)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DT.ColorToken.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

struct MetadataTokenPickerField: View {
    let placeholder: String
    @Binding var value: String
    let suggestions: [String]
    let icon: String
    var placeholderValue: String? = nil
    var addLabel: String = "Add"
    let onCommitValue: (String) -> Void
    @State private var showingPicker = false
    @State private var addingNew = false
    @State private var newValue = ""

    var body: some View {
        Button { showingPicker.toggle() } label: {
            HStack(spacing: 8) {
                Text(displayValue)
                    .font(DT.FontToken.bodySmall)
                    .foregroundStyle(isPlaceholder ? DT.ColorToken.textTertiary : Color(light: "#374151", dark: "#CBD5E1"))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DT.ColorToken.textTertiary)
            }
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            MetadataTokenPickerPopover(
                title: placeholder,
                suggestions: normalizedSuggestions,
                selectedValue: isPlaceholder ? nil : value.slugKey,
                addingNew: $addingNew,
                newValue: $newValue,
                addLabel: addLabel,
                onSelect: { option in commit(option); showingPicker = false },
                onCreate: { commitNewValue() }
            )
        }
        .onDisappear { showingPicker = false; addingNew = false; newValue = "" }
    }

    private var normalizedSuggestions: [String] {
        Array(Set(suggestions.map(\.slugKey).filter { !$0.isEmpty })).sorted { $0.humanizedTitle.localizedCaseInsensitiveCompare($1.humanizedTitle) == .orderedAscending }
    }

    private var isPlaceholder: Bool {
        guard let placeholderValue else { return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || value.slugKey == placeholderValue.slugKey
    }

    private var displayValue: String { isPlaceholder ? placeholder : value.humanizedTitle }

    private func commit(_ rawValue: String) {
        let slug = rawValue.slugKey
        if !isPlaceholder, slug == value.slugKey {
            let cleared = placeholderValue?.slugKey ?? ""
            value = cleared
            onCommitValue(cleared)
            return
        }
        value = slug
        onCommitValue(slug)
    }

    private func commitNewValue() {
        let slug = newValue.slugKey
        guard !slug.isEmpty else { return }
        commit(slug)
        showingPicker = false
        addingNew = false
        newValue = ""
    }
}

struct MetadataTokenPickerPopover: View {
    let title: String
    let suggestions: [String]
    let selectedValue: String?
    @Binding var addingNew: Bool
    @Binding var newValue: String
    let addLabel: String
    let onSelect: (String) -> Void
    let onCreate: () -> Void
    @FocusState private var newFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                if suggestions.isEmpty {
                    Text("No reusable \(title.lowercased()) yet.")
                        .font(DT.FontToken.bodySmall)
                        .foregroundStyle(DT.ColorToken.textTertiary)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(suggestions, id: \.self) { option in
                        DropdownOptionRow(title: option.humanizedTitle, selected: selectedValue == option.slugKey, action: { onSelect(option) })
                    }
                }
                Divider().overlay(DT.ColorToken.borderDefault)
                if addingNew {
                    HStack(spacing: 8) {
                        TextField(title, text: $newValue)
                            .textFieldStyle(.plain)
                            .font(DT.FontToken.bodySmall)
                            .focused($newFocused)
                            .onSubmit(onCreate)
                        Button("Save", action: onCreate)
                            .buttonStyle(PrimaryButtonStyle(horizontalPadding: 10))
                            .disabled(newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(DT.ColorToken.borderStrong))
                    .onAppear { newFocused = true }
                } else {
                    DropdownOptionRow(title: addLabel, action: { addingNew = true; newValue = "" })
                }
            }
            .padding(8)
        }
        .frame(width: 260, height: min(320, CGFloat(max(3, suggestions.count + 2)) * 36 + 18))
        .background(DT.ColorToken.surfacePrimary)
    }
}

struct VariableInspectorSection: View {
    @Binding var prompt: Prompt
    @Binding var values: [String: String]
    @Binding var fieldHeights: [String: CGFloat]
    @Binding var selectedPresetID: UUID?
    @Binding var expandedVariableKey: String?
    let message: String?
    let defaultOpen: Bool
    let onCopyFilled: () -> Void
    let onSave: () -> Void
    var settings: VariablePromptBehaviorSettings = .defaultValue
    @State private var presetName = ""
    @State private var showingPresetNameSheet = false
    @State private var showingManagePresets = false
    @State private var localOpenKeys: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            variableHeaderRow
            if let message {
                Text(message)
                    .font(DT.FontToken.captionStrong)
                    .foregroundStyle(message.contains("Please") ? DT.ColorToken.dangerRed : DT.ColorToken.successGreen)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
            }
            ForEach(sortedVariables) { variable in
                InspectorAccordionRow(title: variable.label, icon: nil, isOpen: openBinding(for: variable.key)) {
                    VariableInputFieldView(variable: variable, value: valueBinding(for: variable), height: heightBinding(for: variable), highlightVariables: settings.highlight, showLabel: false, showRequiredMarker: false)
                }
            }
        }
        .onAppear { initializeOpenKeys() }
        .onChange(of: prompt.id) { _, _ in initializeOpenKeys() }
        .onChange(of: expandedVariableKey) { _, key in
            guard let key, prompt.variables.contains(where: { $0.key == key }) else { return }
            localOpenKeys.insert(key)
        }
        .sheet(isPresented: $showingPresetNameSheet) {
            PresetNameSheet(name: $presetName, title: "Save Preset As", onCancel: { showingPresetNameSheet = false }, onSave: savePreset)
        }
        .sheet(isPresented: $showingManagePresets) {
            ManagePresetsSheet(prompt: $prompt, selectedPresetID: $selectedPresetID, onSave: onSave)
        }
    }

    private var variableHeaderRow: some View {
        HStack(spacing: 8) {
            Text("Variables")
                .font(DT.FontToken.bodySmallStrong)
                .foregroundStyle(DT.ColorToken.textSecondary)
            Spacer(minLength: 8)
            if settings.presetsEnabled {
                Menu {
                    Button("Save As…", systemImage: "square.and.pencil") { presetName = ""; showingPresetNameSheet = true }
                    Button("Save", systemImage: "square.and.arrow.down") { updateSelectedPreset() }.disabled(selectedPresetID == nil)
                    Button("Manage Presets…", systemImage: "slider.horizontal.3") { showingManagePresets = true }.disabled(prompt.variablePresets.isEmpty)
                    Divider()
                    Button("Defaults") { values = Dictionary(uniqueKeysWithValues: prompt.variables.map { ($0.key, $0.defaultValue) }) }
                    if !prompt.variablePresets.isEmpty {
                        Divider()
                        ForEach(prompt.variablePresets) { preset in
                            Button(preset.name) { selectedPresetID = preset.id; values = preset.values }
                        }
                    }
                } label: {
                    Label(selectedPresetName, systemImage: "slider.horizontal.3").lineLimit(1)
                }
                .buttonStyle(SecondaryMenuButtonStyle(horizontalPadding: 10))
            }
            if settings.copyFilledVisible {
                Button(action: onCopyFilled) { Label("Copy", systemImage: "doc.on.clipboard").lineLimit(1) }
                    .buttonStyle(PrimaryButtonStyle(horizontalPadding: 10))
            }
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(DT.ColorToken.borderSubtle).frame(height: 1).offset(y: 3) }
    }

    private var selectedPresetName: String { prompt.variablePresets.first(where: { $0.id == selectedPresetID })?.name ?? "Preset" }

    private func initializeOpenKeys() {
        localOpenKeys = defaultOpen ? Set(prompt.variables.map(\.key)) : []
        if let expandedVariableKey { localOpenKeys.insert(expandedVariableKey) }
    }

    private func openBinding(for key: String) -> Binding<Bool> {
        Binding(get: { localOpenKeys.contains(key) }, set: { isOpen in
            if isOpen { localOpenKeys.insert(key) } else { localOpenKeys.remove(key) }
        })
    }

    private func valueBinding(for variable: VariableDefinition) -> Binding<String> {
        Binding(get: { values[variable.key] ?? variable.defaultValue }, set: { values[variable.key] = $0 })
    }

    private func heightBinding(for variable: VariableDefinition) -> Binding<CGFloat> {
        Binding(get: { settings.rememberFieldHeights ? (fieldHeights[variable.key] ?? CGFloat(settings.fieldDefaultHeight)) : CGFloat(settings.fieldDefaultHeight) }, set: { if settings.rememberFieldHeights { fieldHeights[variable.key] = min(max($0, DT.Size.variableFieldMinHeight), DT.Size.variableFieldMaxHeight) } })
    }

    private var sortedVariables: [VariableDefinition] {
        switch settings.sortBy {
        case "az": return prompt.variables.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        case "required": return prompt.variables.sorted { $0.required != $1.required ? $0.required && !$1.required : $0.sortOrder < $1.sortOrder }
        default: return prompt.variables.sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    private func savePreset() {
        let name = presetName.trimmedNonEmpty(defaultValue: "Preset \(prompt.variablePresets.count + 1)")
        prompt.savePreset(name: name, values: values)
        selectedPresetID = prompt.variablePresets.last?.id
        presetName = ""
        showingPresetNameSheet = false
        onSave()
    }

    private func updateSelectedPreset() {
        guard let selectedPresetID else { return }
        prompt.updatePreset(selectedPresetID, values: values)
        onSave()
    }
}

struct MetadataPanelView: View {
    let prompt: Prompt
    var body: some View {
        VStack(spacing: 0) {
            MetadataRowView(icon: "calendar", label: "Created", value: SidebarDateFormatter.timestamp(prompt.createdAt))
            MetadataRowView(icon: "clock", label: "Updated", value: SidebarDateFormatter.timestamp(prompt.updatedAt))
            MetadataRowView(icon: "eye", label: "Last Opened", value: prompt.lastOpenedAt.map(SidebarDateFormatter.timestamp) ?? "Never")
            MetadataRowView(icon: "doc.on.clipboard", label: "Copy Count", value: "\(prompt.copyCount)")
        }
    }
}

public enum SidebarDateFormatter {
    public static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yy HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct MetadataRowView: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(DT.ColorToken.textTertiary).frame(width: 16)
            Text(label).font(DT.FontToken.bodySmall).foregroundStyle(DT.ColorToken.textSecondary)
            Spacer()
            Text(value).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary).multilineTextAlignment(.trailing)
        }
        .frame(height: 30)
        .overlay(alignment: .bottom) { Rectangle().fill(DT.ColorToken.borderSubtle).frame(height: 1) }
    }
}
