import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PromptEditorView: View {
    @Binding var prompt: Prompt
    let copied: Bool
    let onSave: () -> Void
    let onCopy: () -> Void
    let onArchive: () -> Void
    var editorSettings: EditorBehaviorSettings = .defaultValue
    var variableSettings: VariablePromptBehaviorSettings = .defaultValue
    var variableRunner: AnyView? = nil
    var onVariableTokenClick: (String) -> Void = { _ in }
    @FocusState private var titleFocused: Bool
    @AppStorage(AppSettingsKeys.headingFontWeight) private var headingFontWeight = "semibold"

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                TextField(prompt.type == .phrase ? "Phrase title" : "Prompt title", text: titleBinding)
                    .font(.system(size: titleFontSize, weight: headingFontWeight.appTextWeight))
                    .foregroundStyle(DT.ColorToken.textPrimary)
                    .textFieldStyle(.plain)
                    .focusEffectDisabled()
                    .focused($titleFocused)
                    .padding(.horizontal, 14)
                    .frame(height: titleFieldHeight)
                    .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.borderDefault, lineWidth: 1))
                EditorTitleActionRow(prompt: $prompt, copied: copied, onSave: onSave, onCopy: onCopy, onArchive: onArchive)
            }
            if let variableRunner, prompt.hasVariables {
                variableRunner
            }
            editorWorkspace
        }
        .padding(24)
        .frame(maxHeight: .infinity)
        .background(DT.ColorToken.surfacePrimary)
    }

    @ViewBuilder
    private var editorWorkspace: some View {
        PromptTextEditorView(prompt: $prompt, settings: editorSettings, variableSettings: variableSettings, onSave: onSave, onVariableTokenClick: onVariableTokenClick)
    }

    private var titleFontSize: CGFloat {
        switch editorSettings.titleFieldSize { case "large": 20; case "default": 18; default: 16 }
    }

    private var titleFieldHeight: CGFloat {
        switch editorSettings.titleFieldSize { case "large": 42; case "default": 38; default: 34 }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { prompt.title },
            set: { newValue in
                guard prompt.title != newValue else { return }
                prompt.title = newValue
                prompt.touch()
                if editorSettings.autosaveTyping { onSave() }
            }
        )
    }
}

struct EditorTitleActionRow: View {
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
        }
        .frame(height: 34)
    }
}

struct VariableSidePanelView: View {
    @Binding var prompt: Prompt
    @Binding var values: [String: String]
    @Binding var fieldHeights: [String: CGFloat]
    @Binding var selectedPresetID: UUID?
    let message: String?
    let onCopyFilled: () -> Void
    let onSave: () -> Void
    var settings: VariablePromptBehaviorSettings = .defaultValue
    @State private var presetName = ""
    @State private var showingPresetNameSheet = false
    @State private var showingManagePresets = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("Variables", systemImage: "curlybraces")
                    .font(DT.FontToken.bodySmallStrong)
                    .foregroundStyle(DT.ColorToken.textPrimary)
                Spacer()
                if settings.showRequiredCount {
                    Text("\(prompt.variables.filter(\.required).count) required")
                        .font(DT.FontToken.caption)
                        .foregroundStyle(DT.ColorToken.textTertiary)
                }
            }

            HStack(spacing: 8) {
                if settings.presetsEnabled {
                Menu {
                    Button("Save As…", systemImage: "square.and.pencil") {
                        presetName = ""
                        showingPresetNameSheet = true
                    }
                    Button("Save", systemImage: "square.and.arrow.down") { updateSelectedPreset() }
                        .disabled(selectedPresetID == nil)
                    Button("Manage Presets…", systemImage: "slider.horizontal.3") {
                        showingManagePresets = true
                    }
                    .disabled(prompt.variablePresets.isEmpty)
                    Divider()
                    Button("Defaults") { values = Dictionary(uniqueKeysWithValues: prompt.variables.map { ($0.key, $0.defaultValue) }) }
                    if settings.presetsEnabled && !prompt.variablePresets.isEmpty {
                        Divider()
                        ForEach(prompt.variablePresets) { preset in
                            Button(preset.name) {
                                selectedPresetID = preset.id
                                values = preset.values
                            }
                        }
                    }
                } label: {
                    Label("Preset", systemImage: "slider.horizontal.3")
                        .lineLimit(1)
                }
                .buttonStyle(SecondaryMenuButtonStyle(horizontalPadding: 12))

                Button(action: { presetName = ""; showingPresetNameSheet = true }) {
                    Image(systemName: "square.and.pencil")
                        .accessibilityLabel("Save Preset")
                }
                .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                .help("Save current variable values as a preset")
                .disabled(values.isEmpty)
                }

                if settings.copyFilledVisible {
                Button(action: onCopyFilled) {
                    Label("Copy", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                        .accessibilityLabel("Copy filled prompt")
                }
                .buttonStyle(PrimaryButtonStyle(horizontalPadding: 12))
                .help("Copy the prompt with variable values inserted")
                }
            }

            if let message {
                Text(message)
                    .font(DT.FontToken.captionStrong)
                    .foregroundStyle(message.contains("Please") ? DT.ColorToken.dangerRed : DT.ColorToken.successGreen)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedVariables) { variable in
                        VariableInputFieldView(variable: variable, value: valueBinding(for: variable), height: heightBinding(for: variable), highlightVariables: settings.highlight)
                    }

                }
                .padding(.vertical, 2)
                .padding(.trailing, 2)
            }
            .frame(maxHeight: .infinity)
            if settings.presetsEnabled && !prompt.variablePresets.isEmpty {
                Text("Choose a preset from the menu or delete it below.")
                    .font(DT.FontToken.caption)
                    .foregroundStyle(DT.ColorToken.textTertiary)
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.lg).strokeBorder(DT.ColorToken.borderDefault, lineWidth: 1))
        .sheet(isPresented: $showingPresetNameSheet) {
            PresetNameSheet(
                name: $presetName,
                title: "Save Preset As",
                onCancel: { showingPresetNameSheet = false },
                onSave: savePreset
            )
        }
        .sheet(isPresented: $showingManagePresets) {
            ManagePresetsSheet(prompt: $prompt, selectedPresetID: $selectedPresetID, onSave: onSave)
        }
    }

    private func valueBinding(for variable: VariableDefinition) -> Binding<String> {
        Binding(get: { values[variable.key] ?? variable.defaultValue }, set: { values[variable.key] = $0 })
    }

    private func heightBinding(for variable: VariableDefinition) -> Binding<CGFloat> {
        Binding(
            get: { settings.rememberFieldHeights ? (fieldHeights[variable.key] ?? CGFloat(settings.fieldDefaultHeight)) : CGFloat(settings.fieldDefaultHeight) },
            set: { if settings.rememberFieldHeights { fieldHeights[variable.key] = min(max($0, DT.Size.variableFieldMinHeight), DT.Size.variableFieldMaxHeight) } }
        )
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

struct PresetNameSheet: View {
    @Binding var name: String
    let title: String
    let onCancel: () -> Void
    let onSave: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(DT.FontToken.bodyStrong)
                .foregroundStyle(DT.ColorToken.textPrimary)
            TextField("Preset name", text: $name)
                .textFieldStyle(.plain)
                .focused($focused)
                .fieldChrome(focused: focused, radius: 7)
                .frame(height: 36)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                Button("Save", action: onSave).buttonStyle(PrimaryButtonStyle(horizontalPadding: 12))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { focused = true }
    }
}

struct ManagePresetsSheet: View {
    @Binding var prompt: Prompt
    @Binding var selectedPresetID: UUID?
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var names: [UUID: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manage Presets")
                .font(DT.FontToken.bodyStrong)
                .foregroundStyle(DT.ColorToken.textPrimary)
            if prompt.variablePresets.isEmpty {
                Text("No presets saved yet.")
                    .font(DT.FontToken.bodySmall)
                    .foregroundStyle(DT.ColorToken.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(prompt.variablePresets) { preset in
                        HStack(spacing: 8) {
                            TextField("Preset name", text: Binding(get: { names[preset.id] ?? preset.name }, set: { names[preset.id] = $0 }))
                                .textFieldStyle(.roundedBorder)
                            Button(role: .destructive) {
                                prompt.deletePreset(preset.id)
                                if selectedPresetID == preset.id { selectedPresetID = nil }
                                onSave()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(SecondaryButtonStyle(destructive: true, horizontalPadding: 10))
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Done") {
                    for preset in prompt.variablePresets {
                        if let name = names[preset.id], name.trimmingCharacters(in: .whitespacesAndNewlines) != preset.name {
                            prompt.renamePreset(preset.id, to: name)
                        }
                    }
                    onSave()
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(horizontalPadding: 12))
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            names = Dictionary(uniqueKeysWithValues: prompt.variablePresets.map { ($0.id, $0.name) })
        }
    }
}

struct VariableInputFieldView: View {
    let variable: VariableDefinition
    @Binding var value: String
    @Binding var height: CGFloat
    var highlightVariables: Bool = true
    var showLabel: Bool = true
    var showRequiredMarker: Bool = true
    @FocusState private var focused: Bool
    @State private var resizeStartHeight: CGFloat?
    @State private var resizing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showLabel {
                HStack(spacing: 4) {
                    Text(variable.label)
                        .font(DT.FontToken.caption)
                        .foregroundStyle(DT.ColorToken.textSecondary)
                    if showRequiredMarker && variable.required {
                        Text("*")
                            .font(DT.FontToken.captionStrong)
                            .foregroundStyle(DT.ColorToken.dangerRed)
                    }
                }
            }
            TextEditor(text: $value)
                .font(DT.FontToken.bodySmall)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: height)
                .focusEffectDisabled()
                .focused($focused)
                .fieldChrome(focused: focused || resizing, radius: 7)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(resizing ? DT.ColorToken.accentBlue : DT.ColorToken.borderStrong)
                        .frame(width: 34, height: 3)
                        .padding(.bottom, 5)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let base = resizeStartHeight ?? height
                                    if resizeStartHeight == nil { resizeStartHeight = height }
                                    resizing = true
                                    height = min(max(base + value.translation.height, DT.Size.variableFieldMinHeight), DT.Size.variableFieldMaxHeight)
                                }
                                .onEnded { _ in
                                    resizeStartHeight = nil
                                    resizing = false
                                }
                        )
                        .help("Drag to resize this variable field")
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PromptActionBarView: View {
    @Binding var prompt: Prompt
    let copied: Bool
    let saveStatus: String
    var showStatus: Bool = true
    var actionLabelMode: String = "responsive"
    var rawCopyEnabled: Bool = true
    let onSave: () -> Void
    let onCopy: () -> Void
    let onDuplicate: () -> Void
    let onArchive: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            actionButtons(labelStyle: .full, includeStatus: true)
            actionButtons(labelStyle: .short, includeStatus: false)
            actionButtons(labelStyle: .icon, includeStatus: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 38)
    }

    @ViewBuilder
    private func actionButtons(labelStyle: ActionBarLabelStyle, includeStatus: Bool) -> some View {
        HStack(spacing: labelStyle.spacing) {
            Button(action: { prompt.toggleFavorite(); onSave() }) { actionLabel(full: "Favorite", short: "Fav", icon: prompt.isFavorite ? "star.fill" : "star", style: labelStyle) }.buttonStyle(SecondaryButtonStyle(horizontalPadding: labelStyle.horizontalPadding)).help("Favorite")
            Button(action: onCopy) { actionLabel(full: copied ? "Copied" : (prompt.type == .phrase ? "Copy Phrase" : "Copy"), short: copied ? "Copied" : "Copy", icon: copied ? "checkmark" : "doc.on.doc", style: copied ? .icon : labelStyle) }.buttonStyle(SecondaryButtonStyle(horizontalPadding: labelStyle.horizontalPadding)).help(prompt.type == .phrase ? "Copy phrase" : "Copy raw prompt")
            Button(action: onSave) { actionLabel(full: "Save", short: "Save", icon: "square.and.arrow.down", style: labelStyle) }.buttonStyle(PrimaryButtonStyle(horizontalPadding: labelStyle.horizontalPadding)).help("Save")
            Button(action: onDuplicate) { actionLabel(full: "Duplicate", short: "Dup", icon: "doc.on.doc", style: labelStyle) }.buttonStyle(SecondaryButtonStyle(horizontalPadding: labelStyle.horizontalPadding)).help("Duplicate")
            Button(role: .destructive, action: onArchive) { actionLabel(full: "Delete", short: "Del", icon: "trash", style: labelStyle) }.buttonStyle(SecondaryButtonStyle(destructive: true, horizontalPadding: labelStyle.horizontalPadding)).help("Delete")
            if includeStatus && showStatus { Text(saveStatus).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary).lineLimit(1).padding(.leading, 6) }
        }
    }

    @ViewBuilder private func actionLabel(full: String, short: String, icon: String, style: ActionBarLabelStyle) -> some View {
        switch style { case .full: Label(full, systemImage: icon); case .short: Label(short, systemImage: icon); case .icon: Image(systemName: icon).accessibilityLabel(full) }
    }
}

private enum ActionBarLabelStyle { case full, short, icon; var spacing: CGFloat { self == .full ? 10 : 8 }; var horizontalPadding: CGFloat { self == .full ? 14 : 12 } }

struct PromptTextEditorView: View {
    @Binding var prompt: Prompt
    var settings: EditorBehaviorSettings = .defaultValue
    var variableSettings: VariablePromptBehaviorSettings = .defaultValue
    let onSave: () -> Void
    var onVariableTokenClick: (String) -> Void = { _ in }
    @State private var formatMode = "Markdown"
    @State private var showingFormatPicker = false
    @FocusState private var contentFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            editorBody
                .padding(20)
            Divider().overlay(DT.ColorToken.borderSubtle)
            HStack(spacing: 8) {
                formatMenu
                Spacer()
                if settings.showWordCount {
                    Text("\(prompt.wordCount) words").font(DT.FontToken.caption)
                    Text("•").font(DT.FontToken.caption)
                    Text("\(prompt.characterCount) characters").font(DT.FontToken.caption)
                }
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 15))
            }.foregroundStyle(DT.ColorToken.textSecondary).padding(.horizontal, 16).frame(height: 42)
        }.frame(maxHeight: .infinity).frame(minHeight: 260)
            .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.lg).stroke(DT.ColorToken.borderDefault, lineWidth: 1))
        .onAppear { formatMode = settings.defaultFormat == "plain" ? "Plain Text" : "Markdown" }
    }

    private var formatMenu: some View {
        Button {
            showingFormatPicker.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(formatMode)
                    .font(DT.FontToken.caption)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(DT.ColorToken.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.sm).strokeBorder(DT.ColorToken.borderDefault, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .popover(isPresented: $showingFormatPicker, arrowEdge: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    DropdownOptionRow(title: "Markdown", selected: formatMode == "Markdown") {
                        formatMode = "Markdown"
                        showingFormatPicker = false
                    }
                    DropdownOptionRow(title: "Plain Text", selected: formatMode == "Plain Text") {
                        formatMode = "Plain Text"
                        showingFormatPicker = false
                    }
                }
                .padding(8)
            }
            .frame(width: 180, height: 90)
            .background(DT.ColorToken.surfacePrimary)
        }
        .onDisappear { showingFormatPicker = false }
    }

    @ViewBuilder private var editorBody: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: contentBinding)
                .font(DT.FontToken.bodySmall)
                .scrollContentBackground(.hidden)
                .focusEffectDisabled()
                .focused($contentFocused)
                .padding(0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if prompt.content.isEmpty && !contentFocused {
                Text("Prompt content")
                    .font(DT.FontToken.bodySmall)
                    .foregroundStyle(DT.ColorToken.textMuted)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var contentBinding: Binding<String> {
        Binding(get: { prompt.content }, set: { newValue in
            guard prompt.content != newValue else { return }
            prompt.content = newValue
            prompt.previewSnippet = Prompt.makePreview(from: newValue)
            if variableSettings.autoDetect {
                prompt.variables = VariableDetector.definitions(in: newValue).map { variable in
                    var copy = variable
                    copy.type = VariableInputType(rawValue: variableSettings.defaultType) ?? .textarea
                    return copy
                }
            }
            prompt.touch()
            if settings.autosaveTyping { onSave() }
        })
    }
}

struct EmptyEditorView: View {
    let onNewPrompt: () -> Void
    var mode: LibrarySection = .prompts
    var variableMode: Bool = false
    var body: some View { ContentUnavailableView { Label(title, systemImage: mode == .phrases ? "text.quote" : variableMode ? "curlybraces" : "doc.text") } description: { Text(description) } actions: { Button(buttonTitle, action: onNewPrompt).buttonStyle(PrimaryButtonStyle()) } }
    private var title: String { mode == .phrases ? "No phrase selected" : variableMode ? "No variable prompt selected" : "No prompt selected" }
    private var description: String { mode == .phrases ? "Select a phrase from the library or create a new one." : variableMode ? "Select a variable prompt from the library or create one with placeholders." : "Select a prompt from the library or create a new one." }
    private var buttonTitle: String { mode == .phrases ? "New Phrase" : variableMode ? "New Variable Prompt" : "New Prompt" }
}

#if os(macOS)
final class VariableAwareTextView: NSTextView {
    var onVariableClick: (String) -> Void = { _ in }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let key = variableKey(at: point) {
            onVariableClick(key)
        }
        super.mouseDown(with: event)
    }

    private func variableKey(at point: NSPoint) -> String? {
        guard let layoutManager, let textContainer else { return nil }
        var containerPoint = point
        containerPoint.x -= textContainerOrigin.x
        containerPoint.y -= textContainerOrigin.y
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let nsText = string as NSString
        guard charIndex < nsText.length else { return nil }
        let fullRange = NSRange(location: 0, length: nsText.length)
        guard let regex = try? NSRegularExpression(pattern: #"\{([A-Za-z0-9_\- ]+)\}"#) else { return nil }
        for match in regex.matches(in: string, range: fullRange) where NSLocationInRange(charIndex, match.range) {
            return nsText.substring(with: match.range(at: 1)).variableKey
        }
        return nil
    }
}

struct MarkdownHighlightedTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var lineWrap: Bool = true
    var onVariableTokenClick: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, isFocused: $isFocused, onVariableTokenClick: onVariableTokenClick) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = VariableAwareTextView()
        textView.onVariableClick = context.coordinator.handleVariableClick
        textView.isEditable = true
        textView.isSelectable = true
        textView.importsGraphics = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !lineWrap
        textView.autoresizingMask = [.width]
        textView.font = MarkdownSyntaxHighlighter.baseFont
        textView.delegate = context.coordinator
        scrollView.documentView = textView
        context.coordinator.textView = textView
        textView.string = text
        context.coordinator.applyHighlighting(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textContainer?.containerSize = NSSize(width: lineWrap ? scrollView.contentSize.width : .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = lineWrap
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            context.coordinator.applyHighlighting(to: textView, preserving: selectedRange)
        } else {
            context.coordinator.refreshVisibleAttributesIfNeeded(in: textView)
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool
        let onVariableTokenClick: (String) -> Void
        weak var textView: NSTextView?
        private var isApplying = false

        init(text: Binding<String>, isFocused: Binding<Bool>, onVariableTokenClick: @escaping (String) -> Void) {
            _text = text
            _isFocused = isFocused
            self.onVariableTokenClick = onVariableTokenClick
        }

        func handleVariableClick(_ key: String) {
            onVariableTokenClick(key)
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplying, let textView = notification.object as? NSTextView else { return }
            text = textView.string
            applyHighlighting(to: textView)
        }

        func textDidBeginEditing(_ notification: Notification) { isFocused = true }
        func textDidEndEditing(_ notification: Notification) { isFocused = false }

        func applyHighlighting(to textView: NSTextView, preserving requestedRange: NSRange? = nil) {
            guard let storage = textView.textStorage else { return }
            let selectedRange = requestedRange ?? textView.selectedRange()
            isApplying = true
            let highlighted = MarkdownSyntaxHighlighter.highlight(textView.string)
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            if fullRange.length > 0 {
                storage.setAttributes(MarkdownSyntaxHighlighter.baseAttributes, range: fullRange)
                highlighted.enumerateAttributes(in: fullRange) { attrs, range, _ in
                    storage.addAttributes(attrs, range: range)
                }
            }
            storage.endEditing()
            restoreSelection(selectedRange, in: textView)
            isApplying = false
        }

        private func restoreSelection(_ selectedRange: NSRange, in textView: NSTextView) {
            let length = (textView.string as NSString).length
            if selectedRange.location <= length {
                let safeLength = max(0, min(selectedRange.length, length - selectedRange.location))
                textView.setSelectedRange(NSRange(location: selectedRange.location, length: safeLength))
            } else {
                textView.setSelectedRange(NSRange(location: length, length: 0))
            }
        }

        func refreshVisibleAttributesIfNeeded(in textView: NSTextView) {
            guard textView.textStorage?.length ?? 0 > 0 else { return }
            applyHighlighting(to: textView)
        }
    }
}

@MainActor enum MarkdownSyntaxHighlighter {
    static let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static var baseAttributes: [NSAttributedString.Key: Any] { [
        .font: baseFont,
        .foregroundColor: textColor,
        .paragraphStyle: paragraphStyle
    ] }
    private static let boldFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
    private static let headingFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)

    static func highlight(_ text: String) -> NSAttributedString {
        let ns = text as NSString
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: baseAttributes
        )
        let fullRange = NSRange(location: 0, length: ns.length)
        applyLinePatterns(in: attributed, text: ns)
        applyRegex(#"`([^`]+)`"#, color: tokenBlue, font: baseFont, in: attributed, range: fullRange)
        applyRegex(#"\*\*([^*]+)\*\*"#, color: strongTextColor, font: boldFont, in: attributed, range: fullRange)
        applyRegex(#"\{[A-Za-z0-9_\\- ]+\}"#, color: tokenPurple, font: boldFont, in: attributed, range: fullRange)
        return attributed
    }

    private static func applyLinePatterns(in attributed: NSMutableAttributedString, text ns: NSString) {
        let text = ns as String
        var location = 0
        for rawLine in text.components(separatedBy: "\n") {
            let lineRange = NSRange(location: location, length: (rawLine as NSString).length)
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            let leadingSpaces = rawLine.prefix { $0 == " " || $0 == "\t" }.count
            let markerLocation = location + leadingSpaces
            if trimmed.hasPrefix("#") {
                attributed.addAttributes([.foregroundColor: tokenBlue, .font: headingFont], range: lineRange)
            } else if trimmed == "---" {
                attributed.addAttributes([.foregroundColor: tokenMuted], range: lineRange)
            } else if let colon = rawLine.firstIndex(of: ":"), !rawLine.hasPrefix(" ") {
                let keyLength = rawLine.distance(from: rawLine.startIndex, to: colon)
                attributed.addAttributes([.foregroundColor: tokenGreen, .font: boldFont], range: NSRange(location: location, length: keyLength + 1))
                if keyLength + 1 < lineRange.length {
                    attributed.addAttributes([.foregroundColor: tokenBlue], range: NSRange(location: location + keyLength + 1, length: lineRange.length - keyLength - 1))
                }
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
                attributed.addAttributes([.foregroundColor: tokenOrange, .font: boldFont], range: NSRange(location: markerLocation, length: 1))
            } else if let marker = trimmed.range(of: #"^\d+\."#, options: .regularExpression) {
                let len = trimmed.distance(from: marker.lowerBound, to: marker.upperBound)
                attributed.addAttributes([.foregroundColor: tokenOrange, .font: boldFont], range: NSRange(location: markerLocation, length: len))
            }
            location += lineRange.length + 1
        }
    }

    private static func applyRegex(_ pattern: String, color: NSColor, font: NSFont, in attributed: NSMutableAttributedString, range: NSRange) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        regex.enumerateMatches(in: attributed.string, range: range) { match, _, _ in
            guard let match else { return }
            attributed.addAttributes([.foregroundColor: color, .font: font], range: match.range)
        }
    }

    private static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        return style
    }

    private static let textColor = semanticColor(light: "#111827", dark: "#CBD5E1")
    private static let strongTextColor = semanticColor(light: "#111827", dark: "#F8FAFC")
    private static let tokenBlue = semanticColor(light: "#0A66E8", dark: "#5CB3FF")
    private static let tokenGreen = semanticColor(light: "#16A34A", dark: "#7BE081")
    private static let tokenOrange = semanticColor(light: "#F97316", dark: "#FA9A45")
    private static let tokenPurple = semanticColor(light: "#7C3AED", dark: "#C49BFF")
    private static let tokenMuted = semanticColor(light: "#6B7280", dark: "#7A8491")

    private static func semanticColor(light: String, dark: String) -> NSColor {
        NSColor(name: nil) { appearance in
            let mode = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(hex: mode == .darkAqua ? dark : light)
        }
    }
}
#else
struct MarkdownHighlightedTextEditor: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    var lineWrap: Bool = true
    var onVariableTokenClick: (String) -> Void = { _ in }
    var body: some View { TextEditor(text: $text) }
}
#endif
