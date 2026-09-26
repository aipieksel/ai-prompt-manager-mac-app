import AppKit
import SwiftUI
import UniformTypeIdentifiers


struct VariablePromptRunnerView: View {
    @Binding var prompt: Prompt
    let onRun: () -> Void
    let onStop: () -> Void
    let onSaveMarkdown: () -> Void
    let latestRun: (UUID) -> ChainStepRun?
    let latestOutput: (UUID) -> String?
    let latestError: (UUID) -> String?
    let stepRunCount: (UUID) -> Int
    @AppStorage(AppSettingsKeys.storageVariablePromptRunnerCollapsed) private var variableRunCollapsed = AppSettingsDefaults.variablePromptRunnerCollapsed
    @AppStorage(AppSettingsKeys.storageChainCollapsedPreviewLines) private var collapsedPreviewLineCount = 0

    private var step: PromptChainStep { prompt.variableRunnerStep }
    private var syntheticChain: PromptChain {
        PromptChain(sequenceID: prompt.sequenceID, title: prompt.displayTitle, steps: [step], customOutputFolderPath: outputFolderURL.path)
    }
    private var outputFolderURL: URL {
        let path = prompt.variableRunOutputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
        return ChainOutputStore.defaultRootURL()
            .appendingPathComponent("Variable Prompt Outputs", isDirectory: true)
            .appendingPathComponent(prompt.stableStorageID, isDirectory: true)
    }

    var body: some View {
        ChainStepCard(
            step: step,
            chain: syntheticChain,
            prompts: [prompt],
            previousOutputs: [:],
            isCollapsed: variableRunCollapsed,
            collapsedPreviewLineCount: collapsedPreviewLineCount,
            canRemove: false,
            isVariablePrompt: true,
            variableOutputFolderLabel: outputFolderLabel,
            variableHasCustomOutputFolder: !prompt.variableRunOutputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onToggleCollapsed: { variableRunCollapsed.toggle() },
            onRun: onRun,
            onStop: onStop,
            runButtonTitle: "Run Prompt",
            stopButtonTitle: "Stop Prompt",
            onSaveMarkdown: onSaveMarkdown,
            onRemove: {},
            onPromptChange: { _ in },
            onBindingChange: updateBinding,
            onProviderModelChange: { _, _ in },
            onOutputPolicyChange: updateOutputPolicy,
            onFinalOutputTagChange: updateFinalTag,
            onOutputFileOptionsChange: updateOutputFileOptions,
            onChooseOutputFile: chooseOutputFolder,
            onResetVariableOutputFolder: resetOutputFolder,
            outputFolderURL: outputFolderURL,
            latestStepRun: latestRun,
            latestCompletedStepRun: { id in latestRun(id)?.status == .complete ? latestRun(id) : nil },
            latestOutput: latestOutput(step.id),
            latestError: latestError(step.id),
            stepRunCount: stepRunCount,
            showProviderModelControls: false
        )
        .padding(.top, 4)
    }

    private var outputFolderLabel: String {
        let path = prompt.variableRunOutputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? "Output Folder" : URL(fileURLWithPath: path, isDirectory: true).lastPathComponent
    }

    private func updateStep(_ mutate: (inout PromptChainStep) -> Void) {
        var updated = step
        mutate(&updated)
        updated.promptID = prompt.id
        updated.title = prompt.displayTitle
        updated.sortOrder = 0
        updated.variableBindings = Prompt.reconciledVariableBindings(updated.variableBindings, variables: prompt.variables)
        prompt.variableRunStep = updated
        prompt.touch()
    }

    private func updateBinding(_ binding: ChainVariableBinding) {
        updateStep { step in
            if let index = step.variableBindings.firstIndex(where: { $0.variableKey == binding.variableKey }) {
                step.variableBindings[index] = binding
            } else {
                step.variableBindings.append(binding)
            }
        }
    }

    private func updateOutputPolicy(_ policy: ChainOutputPolicy) { updateStep { $0.outputPolicy = policy } }
    private func updateFinalTag(_ tag: String) { updateStep { $0.finalOutputTag = tag.sanitizedXMLTagName(defaultValue: "") } }
    private func updateOutputFileOptions(_ fileName: String?, _ outputFilePath: String?, _ overwrite: Bool?) {
        updateStep { step in
            if let fileName { step.customOutputFileName = fileName }
            if let outputFilePath { step.customOutputFilePath = outputFilePath }
            if let overwrite { step.overwriteOutputFile = overwrite }
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose the output folder for this variable prompt."
        if panel.runModal() == .OK, let url = panel.url {
            prompt.variableRunOutputFolderPath = url.path
            prompt.touch()
        }
    }

    private func resetOutputFolder() {
        prompt.variableRunOutputFolderPath = ""
        prompt.touch()
    }
}

struct ChainListView: View {    let chains: [PromptChain]
    let selectedChainID: UUID?
    let onSelect: (PromptChain) -> Void
    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CHAINED PROMPTS").font(DT.FontToken.headingSection).tracking(0.48).foregroundStyle(DT.ColorToken.textTertiary)
                Spacer()
                Button(action: onNew) { Image(systemName: "plus") }.buttonStyle(.plain).focusEffectDisabled()
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            if chains.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 26)).foregroundStyle(DT.ColorToken.textTertiary)
                    Text("No chains yet").font(DT.FontToken.bodySmallStrong)
                    Text("Create a chained prompt to run saved prompts in sequence.").font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary).multilineTextAlignment(.center)
                    Button("New Chain", action: onNew).buttonStyle(PrimaryButtonStyle(horizontalPadding: 12))
                }.padding(18)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(chains) { chain in
                            ChainListRow(chain: chain, selected: chain.id == selectedChainID) { onSelect(chain) }
                        }
                    }
                }
            }
        }
        .background(DT.ColorToken.surfacePrimary)
    }
}

private struct ChainListRow: View {
    let chain: PromptChain
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccentStyle) private var accent

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "link")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? accent.color : DT.ColorToken.textTertiary)
                    .frame(width: 24, height: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Text(chain.title).font(DT.FontToken.bodySmallStrong).foregroundStyle(DT.ColorToken.textPrimary).lineLimit(1)
                    Text("\(chain.steps.count) steps • \(providerSummary)").font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary).lineLimit(1)
                    HStack(spacing: 5) {
                        Circle().fill(statusColor).frame(width: 7, height: 7)
                        Text(statusText).font(DT.FontToken.caption).foregroundStyle(statusColor)
                    }
                }
                Spacer()
                Image(systemName: "star").font(.system(size: 13)).foregroundStyle(DT.ColorToken.textTertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? accent.softColor : (hovering ? DT.ColorToken.surfaceHover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        Divider().overlay(DT.ColorToken.borderSubtle)
    }

    private var providerSummary: String {
        AppViewModel.settingsDefaultProviderModel().provider.displayName
    }

    private var statusText: String {
        switch chain.status {
        case .complete: chain.lastRunAt == nil ? "Completed" : "Ran recently"
        case .failed: "Failed"
        case .draft: "Draft"
        case .running: "Running"
        case .ready: "Ready"
        default: "Not run"
        }
    }
    private var statusColor: Color {
        switch chain.status {
        case .complete: DT.ColorToken.successGreen
        case .failed: DT.ColorToken.dangerRed
        case .draft: DT.ColorToken.warningYellow
        case .running, .ready: DT.ColorToken.accentBlue
        default: DT.ColorToken.textTertiary
        }
    }
}

struct ChainBuilderView: View {
    @Binding var chain: PromptChain
    let prompts: [Prompt]
    let previousOutputs: (PromptChainStep) -> [UUID: String]
    let onSave: () -> Void
    let onRunChain: () -> Void
    let onRunLoop: () -> Void
    let onStopChain: () -> Void
    let onOpenOutputFolder: () -> Void
    let onAddStep: () -> Void
    let onRunStep: (UUID) -> Void
    let onStopStep: (UUID) -> Void
    let onSaveStepMarkdown: (UUID) -> Void
    let onRemoveStep: (UUID) -> Void
    let onDelete: () -> Void
    let onPromptChange: (UUID, UUID?) -> Void
    let onBindingChange: (UUID, ChainVariableBinding) -> Void
    let onProviderModelChange: (UUID, AIProviderKind, String?) -> Void
    let onOutputPolicyChange: (UUID, ChainOutputPolicy) -> Void
    let onFinalOutputTagChange: (UUID, String) -> Void
    let onOutputFileOptionsChange: (UUID, String?, String?, Bool?) -> Void
    let onChooseOutputFile: (UUID) -> Void
    let onLoopChange: (UUID?, UUID?, Int, [ChainOutputMonitorRule]) -> Void
    let onToggleStepCollapsed: (UUID) -> Void
    let chainOutputFolderURL: (PromptChain) -> URL
    let latestStepRun: (UUID) -> ChainStepRun?
    let latestCompletedStepRun: (UUID) -> ChainStepRun?
    let latestOutput: (UUID) -> String?
    let latestError: (UUID) -> String?
    let stepRunCount: (UUID) -> Int
    @State private var showingLoopSettings = false
    @AppStorage(AppSettingsKeys.storageChainCustomStatuses) private var chainCustomStatusesRaw = ChainCustomStatusSettings.encode(ChainCustomStatusSettings.defaults)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DT.ColorToken.borderDefault)
            ScrollView {
                VStack(spacing: 14) {
                    let sortedSteps = chain.steps.sorted(by: { $0.sortOrder < $1.sortOrder })
                    ForEach(sortedSteps) { step in
                        ChainStepCard(
                            step: step,
                            chain: chain,
                            prompts: prompts,
                            previousOutputs: previousOutputs(step),
                            isCollapsed: chain.collapsedStepIDs.contains(step.id),
                            collapsedPreviewLineCount: chain.collapsedOutputPreviewLineCount,
                            canRemove: step.id == sortedSteps.last?.id,
                            isVariablePrompt: false,
                            variableOutputFolderLabel: "",
                            variableHasCustomOutputFolder: false,
                            onToggleCollapsed: { onToggleStepCollapsed(step.id) },
                            onRun: { onRunStep(step.id) },
                            onStop: { onStopStep(step.id) },
                            runButtonTitle: "Run Step",
                            stopButtonTitle: "Stop Step",
                            onSaveMarkdown: { onSaveStepMarkdown(step.id) },
                            onRemove: { onRemoveStep(step.id) },
                            onPromptChange: { onPromptChange(step.id, $0) },
                            onBindingChange: { onBindingChange(step.id, $0) },
                            onProviderModelChange: { provider, model in onProviderModelChange(step.id, provider, model) },
                            onOutputPolicyChange: { onOutputPolicyChange(step.id, $0) },
                            onFinalOutputTagChange: { onFinalOutputTagChange(step.id, $0) },
                            onOutputFileOptionsChange: { fileName, outputFilePath, overwrite in onOutputFileOptionsChange(step.id, fileName, outputFilePath, overwrite) },
                            onChooseOutputFile: { onChooseOutputFile(step.id) },
                            onResetVariableOutputFolder: {},
                            outputFolderURL: chainOutputFolderURL(chain),
                            latestStepRun: latestStepRun,
                            latestCompletedStepRun: latestCompletedStepRun,
                            latestOutput: latestOutput(step.id),
                            latestError: latestError(step.id),
                            stepRunCount: stepRunCount,
                            showProviderModelControls: false
                        )
                        if step.id != sortedSteps.last?.id {
                            StepConnectorView()
                        }
                    }
                    Button { onAddStep() } label: { Label("Step", systemImage: "plus") }.buttonStyle(SecondaryButtonStyle(horizontalPadding: 14))
                }
                .padding(18)
            }
        }
        .background(DT.ColorToken.surfaceSecondary)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "link.circle")
                .font(.system(size: 30))
                .foregroundStyle(DT.ColorToken.textTertiary)
                .frame(width: 38, height: 46, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                TextField("Chain name", text: $chain.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DT.ColorToken.textPrimary)
                    .frame(minWidth: 220, idealWidth: 300, maxWidth: 320, minHeight: 22, maxHeight: 24, alignment: .leading)
                    .focusEffectDisabled()
                    .help("Edit the chain name. Press Return or Save Chain to save.")
                    .onSubmit { onSave() }
                Text("\(chain.isDraft ? "Draft" : "Saved") • \(chain.lastRunAt == nil ? "Not run" : "Last run recently")")
                    .font(DT.FontToken.caption)
                    .foregroundStyle(chain.isDraft ? DT.ColorToken.warningYellow : DT.ColorToken.successGreen)
                    .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 12)
            HStack(alignment: .center, spacing: 10) {
                Button { showingLoopSettings.toggle() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .focusable(false)
                    .contentShape(Rectangle())
                    .popover(isPresented: $showingLoopSettings, arrowEdge: .bottom) {
                        ChainLoopPopover(
                            chain: chain,
                            customStatuses: ChainCustomStatusSettings.decode(chainCustomStatusesRaw),
                            onSave: { startID, endID, count, monitorRules in
                                onLoopChange(startID, endID, count, monitorRules)
                                showingLoopSettings = false
                            }
                        )
                    }
                    .help("Configure loop range")
                if chain.status != .running {
                    Button { onRunLoop() } label: { headerLabel("Run Loop", systemImage: "repeat") }
                        .buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                        .fixedSize(horizontal: true, vertical: false)
                }
                if chain.status == .running {
                    Button { onStopChain() } label: { headerLabel("Stop Chain", systemImage: "stop.fill") }
                        .buttonStyle(SecondaryButtonStyle(destructive: true, horizontalPadding: 12))
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    Button { onRunChain() } label: { headerLabel("Run Chain", systemImage: "play") }
                        .buttonStyle(PrimaryButtonStyle(horizontalPadding: 12))
                        .fixedSize(horizontal: true, vertical: false)
                }
                Button { onOpenOutputFolder() } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                    .buttonStyle(SecondaryButtonStyle(horizontalPadding: 8))
                    .focusEffectDisabled()
                    .focusable(false)
                    .fixedSize(horizontal: true, vertical: false)
                    .help("Open this chain's Markdown output folder in Finder")
                Button { onAddStep() } label: { headerLabel("Step", systemImage: "plus") }
                    .buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                    .fixedSize(horizontal: true, vertical: false)
                Button(action: onSave) { FloppySaveIcon() }
                    .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("Save Chain")
                    .help("Save chain")
                Button(action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(IconToolbarButtonStyle())
                    .accessibilityLabel("Archive Chain")
            }
            .layoutPriority(2)
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(DT.ColorToken.surfaceSecondary)
    }

    private func headerLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title).lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
        }
    }

    private var loopButtonTitle: String {
        let sorted = chain.steps.sorted { $0.sortOrder < $1.sortOrder }
        guard let startID = chain.loopStartStepID,
              let endID = chain.loopEndStepID,
              let start = sorted.first(where: { $0.id == startID }),
              let end = sorted.first(where: { $0.id == endID }),
              start.id != end.id else { return "Loop" }
        return "Loop \(start.sortOrder + 1)-\(end.sortOrder + 1) ×\(chain.loopCount)"
    }
}

private struct LoopSettingRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(DT.FontToken.bodySmall)
                .foregroundStyle(DT.ColorToken.textSecondary)
                .frame(width: 72, alignment: .leading)
            Spacer(minLength: 12)
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 30)
    }
}

private struct FloppySaveIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(lineWidth: 1.6)
                .frame(width: 16, height: 16)
            Rectangle()
                .strokeBorder(lineWidth: 1.2)
                .frame(width: 8, height: 4)
                .offset(x: -1.5, y: -4.5)
            Rectangle()
                .frame(width: 2.4, height: 2.4)
                .offset(x: 5, y: -4.5)
            RoundedRectangle(cornerRadius: 1)
                .strokeBorder(lineWidth: 1.2)
                .frame(width: 9, height: 5.5)
                .offset(y: 4.5)
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

private struct InlineDropdown<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(title(option), systemImage: "checkmark")
                    } else {
                        Text(title(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(title(selection))
                    .font(DT.FontToken.bodySmallStrong)
                    .foregroundStyle(DT.ColorToken.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DT.ColorToken.textTertiary)
            }
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }
}

private struct StepConnectorView: View {
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(DT.ColorToken.borderDefault).frame(height: 1)
            Image(systemName: "plus.circle")
                .font(.system(size: 18))
                .foregroundStyle(DT.ColorToken.textTertiary)
            Rectangle().fill(DT.ColorToken.borderDefault).frame(height: 1)
        }
        .padding(.horizontal, 16)
        .frame(height: 18)
    }
}

private struct ChainLoopPopover: View {
    let chain: PromptChain
    let customStatuses: [String]
    let onSave: (UUID?, UUID?, Int, [ChainOutputMonitorRule]) -> Void

    private var sortedSteps: [PromptChainStep] { chain.steps.sorted { $0.sortOrder < $1.sortOrder } }
    @State private var draftStartStepID: UUID?
    @State private var draftEndStepID: UUID?
    @State private var draftLoopCount: Int
    @State private var draftMonitorRules: [ChainOutputMonitorRule]
    @State private var draftPhrase = ""
    @State private var draftStatus: String
    @State private var draftTargetStepID: UUID?
    @State private var isAddingMonitorRule: Bool

    init(chain: PromptChain, customStatuses: [String], onSave: @escaping (UUID?, UUID?, Int, [ChainOutputMonitorRule]) -> Void) {
        self.chain = chain
        self.customStatuses = customStatuses.isEmpty ? ChainCustomStatusSettings.defaults : customStatuses
        self.onSave = onSave
        let steps = chain.steps.sorted { $0.sortOrder < $1.sortOrder }
        let fallbackStart = steps.first?.id
        let fallbackEnd = steps.count > 1 ? steps.dropFirst().first?.id : steps.first?.id
        _draftStartStepID = State(initialValue: chain.loopStartStepID ?? fallbackStart)
        _draftEndStepID = State(initialValue: chain.loopEndStepID ?? fallbackEnd)
        _draftLoopCount = State(initialValue: max(1, chain.loopCount))
        _draftMonitorRules = State(initialValue: chain.monitorRules)
        _draftStatus = State(initialValue: customStatuses.first ?? ChainCustomStatusSettings.defaults.first ?? "Stopped")
        _draftTargetStepID = State(initialValue: nil)
        _isAddingMonitorRule = State(initialValue: chain.monitorRules.isEmpty)
    }

    private var canSave: Bool { validatedRange(start: draftStartStepID, end: draftEndStepID) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Loop settings")
                .font(DT.FontToken.bodySmallStrong)
            Text("Choose the contiguous step range to run when you press Run Loop.")
                .font(DT.FontToken.caption)
                .foregroundStyle(DT.ColorToken.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            LoopSettingRow(label: "Start") {
                InlineDropdown(
                    selection: Binding(get: { draftStartStepID }, set: { draftStartStepID = normalizedRange(start: $0, end: draftEndStepID).start; draftEndStepID = normalizedRange(start: $0, end: draftEndStepID).end }),
                    options: sortedSteps.map { Optional($0.id) },
                    title: { stepTitle(for: $0) }
                )
                .frame(width: 132)
            }
            LoopSettingRow(label: "End") {
                InlineDropdown(
                    selection: Binding(get: { draftEndStepID }, set: { draftStartStepID = normalizedRange(start: draftStartStepID, end: $0).start; draftEndStepID = normalizedRange(start: draftStartStepID, end: $0).end }),
                    options: sortedSteps.map { Optional($0.id) },
                    title: { stepTitle(for: $0) }
                )
                .frame(width: 132)
            }
            LoopSettingRow(label: "Loops") {
                Stepper(value: $draftLoopCount, in: 1...100) {
                    Text("\(draftLoopCount)")
                        .font(DT.FontToken.bodySmallStrong)
                        .foregroundStyle(DT.ColorToken.textSecondary)
                }
                .frame(width: 96, alignment: .trailing)
            }
            Text(summary)
                .font(DT.FontToken.caption)
                .foregroundStyle(DT.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(DT.ColorToken.borderDefault)
            monitorRulesSection
            HStack {
                Button("Set default 2-step loop") {
                    let start = sortedSteps.dropFirst().first?.id ?? sortedSteps.first?.id
                    let end = sortedSteps.dropFirst(2).first?.id ?? sortedSteps.last?.id
                    update(start: start, end: end, count: chain.loopCount)
                }
                .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                Spacer()
                Button("Save") { onSave(draftStartStepID, draftEndStepID, draftLoopCount, normalizedRules) }
                    .buttonStyle(PrimaryButtonStyle(horizontalPadding: 14))
                    .disabled(!canSave)
            }
        }
        .padding(16)
        .frame(width: 500)
        .background(DT.ColorToken.surfacePrimary)
    }

    private var monitorRulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Stop/status rules")
                    .font(DT.FontToken.bodySmallStrong)
                Spacer()
                Text("\(draftMonitorRules.filter(\.isEnabled).count) active")
                    .font(DT.FontToken.caption)
                    .foregroundStyle(DT.ColorToken.textTertiary)
            }
            Text("Exact case-sensitive phrase checks run after a step output returns, before the next step starts.")
                .font(DT.FontToken.caption)
                .foregroundStyle(DT.ColorToken.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach($draftMonitorRules) { $rule in
                HStack(spacing: 8) {
                    Toggle("", isOn: $rule.isEnabled).labelsHidden()
                    TextField("Phrase", text: $rule.phrase)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 180, maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                        .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
                    InlineDropdown(
                        selection: monitorTargetBinding(for: $rule),
                        options: monitorTargetOptions,
                        title: { monitorTargetTitle($0) }
                    )
                    .frame(width: 92)
                    InlineDropdown(
                        selection: Binding(get: { customStatuses.contains(rule.statusLabel) ? rule.statusLabel : customStatuses.first ?? "Stopped" }, set: { rule.statusLabel = $0 }),
                        options: customStatuses,
                        title: { $0 }
                    )
                    .frame(width: 92)
                    Spacer(minLength: 0)
                    Button {
                        draftMonitorRules.removeAll { $0.id == rule.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(IconToolbarButtonStyle())
                    .accessibilityLabel("Delete stop rule")
                }
                .padding(.vertical, 4)
            }
            if isAddingMonitorRule {
                Divider().overlay(DT.ColorToken.borderDefault)
                HStack(spacing: 8) {
                    TextField("e.g. 9.7", text: $draftPhrase)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 180, maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                        .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
                    InlineDropdown(selection: $draftTargetStepID, options: monitorTargetOptions, title: { monitorTargetTitle($0) })
                        .frame(width: 92)
                    InlineDropdown(selection: $draftStatus, options: customStatuses, title: { $0 })
                        .frame(width: 92)
                    Spacer(minLength: 0)
                    Button {
                        addDraftRule()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                    .disabled(draftPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Button {
                    isAddingMonitorRule = true
                } label: {
                    Label("Add rule", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
            }
        }
    }

    private var monitorTargetOptions: [UUID?] {
        [nil] + sortedSteps.map { Optional($0.id) }
    }

    private func monitorTargetTitle(_ id: UUID?) -> String {
        guard let id else { return "Any step" }
        return stepTitle(for: id)
    }

    private func monitorTargetBinding(for rule: Binding<ChainOutputMonitorRule>) -> Binding<UUID?> {
        Binding(
            get: {
                rule.wrappedValue.stepScope == .specificStep ? rule.wrappedValue.stepID : nil
            },
            set: { target in
                rule.wrappedValue.stepID = target
                rule.wrappedValue.stepScope = target == nil ? .anyLoopStep : .specificStep
            }
        )
    }

    private var normalizedRules: [ChainOutputMonitorRule] {
        draftMonitorRules.map { rule in
            var copy = rule
            copy.phrase = copy.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            if !customStatuses.contains(copy.statusLabel) {
                copy.statusLabel = customStatuses.first ?? "Stopped"
            }
            if copy.stepScope == .anyLoopStep { copy.stepID = nil }
            if copy.stepScope == .specificStep, copy.stepID == nil { copy.stepID = sortedSteps.first?.id }
            return copy
        }
    }

    private func addDraftRule() {
        let phrase = draftPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }
        draftMonitorRules.append(ChainOutputMonitorRule(phrase: phrase, statusLabel: draftStatus, stepScope: draftTargetStepID == nil ? .anyLoopStep : .specificStep, stepID: draftTargetStepID))
        draftPhrase = ""
        draftTargetStepID = nil
        isAddingMonitorRule = false
    }

    private var defaultEndStepID: UUID? {
        guard sortedSteps.count > 1 else { return sortedSteps.first?.id }
        return sortedSteps.dropFirst().first?.id
    }

    private var summary: String {
        let range = validatedRange(start: draftStartStepID, end: draftEndStepID)
        guard let range else { return "Choose at least two adjacent/contiguous steps to repeat." }
        let names = sortedSteps[range].map { "Step \($0.sortOrder + 1)" }.joined(separator: " → ")
        return "Run order: \(names) repeated \(draftLoopCount) time\(draftLoopCount == 1 ? "" : "s")."
    }

    private func update(start: UUID?, end: UUID?, count: Int) {
        let range = normalizedRange(start: start, end: end)
        draftStartStepID = range.start
        draftEndStepID = range.end
        draftLoopCount = max(1, min(count, 100))
    }

    private func stepTitle(for id: UUID?) -> String {
        guard let id, let step = sortedSteps.first(where: { $0.id == id }) else { return "Step" }
        return "Step \(step.sortOrder + 1)"
    }

    private func normalizedRange(start: UUID?, end: UUID?) -> (start: UUID?, end: UUID?) {
        guard !sortedSteps.isEmpty else { return (nil, nil) }
        let startIndex = start.flatMap { id in sortedSteps.firstIndex { $0.id == id } } ?? 0
        let endIndex = end.flatMap { id in sortedSteps.firstIndex { $0.id == id } } ?? min(startIndex + 1, sortedSteps.count - 1)
        let lower = min(startIndex, endIndex)
        let upper = max(startIndex, endIndex)
        return (sortedSteps[lower].id, sortedSteps[upper].id)
    }

    private func validatedRange(start: UUID?, end: UUID?) -> ClosedRange<Int>? {
        guard let start,
              let end,
              let startIndex = sortedSteps.firstIndex(where: { $0.id == start }),
              let endIndex = sortedSteps.firstIndex(where: { $0.id == end }) else { return nil }
        let lower = min(startIndex, endIndex)
        let upper = max(startIndex, endIndex)
        guard upper > lower else { return nil }
        return lower...upper
    }
}

private struct ChainStepCard: View {
    let step: PromptChainStep
    let chain: PromptChain
    let prompts: [Prompt]
    let previousOutputs: [UUID: String]
    let isCollapsed: Bool
    let collapsedPreviewLineCount: Int
    let canRemove: Bool
    let isVariablePrompt: Bool
    let variableOutputFolderLabel: String
    let variableHasCustomOutputFolder: Bool
    let onToggleCollapsed: () -> Void
    let onRun: () -> Void
    let onStop: () -> Void
    let runButtonTitle: String
    let stopButtonTitle: String
    let onSaveMarkdown: () -> Void
    let onRemove: () -> Void
    let onPromptChange: (UUID?) -> Void
    let onBindingChange: (ChainVariableBinding) -> Void
    let onProviderModelChange: (AIProviderKind, String?) -> Void
    let onOutputPolicyChange: (ChainOutputPolicy) -> Void
    let onFinalOutputTagChange: (String) -> Void
    let onOutputFileOptionsChange: (String?, String?, Bool?) -> Void
    let onChooseOutputFile: () -> Void
    let onResetVariableOutputFolder: () -> Void
    let outputFolderURL: URL
    let latestStepRun: (UUID) -> ChainStepRun?
    let latestCompletedStepRun: (UUID) -> ChainStepRun?
    let latestOutput: String?
    let latestError: String?
    let stepRunCount: (UUID) -> Int
    let showProviderModelControls: Bool
    @State private var showingRunInfo = false

    private var selectedPrompt: Prompt? { step.promptID.flatMap { id in prompts.first { $0.id == id } } }
    private var validModelID: String { step.providerKind.models.contains { $0.id == step.modelID } ? step.modelID : step.providerKind.defaultModelID }
    private var loopFeedbackSourceSteps: [PromptChainStep] {
        let candidates = chain.steps.filter { $0.id != step.id }.sorted { $0.sortOrder < $1.sortOrder }
        guard let startID = chain.loopStartStepID,
              let endID = chain.loopEndStepID,
              let startOrder = chain.steps.first(where: { $0.id == startID })?.sortOrder,
              let endOrder = chain.steps.first(where: { $0.id == endID })?.sortOrder,
              startOrder <= endOrder else { return candidates }
        let range = startOrder...endOrder
        return candidates.sorted { lhs, rhs in
            let lhsInLoop = range.contains(lhs.sortOrder)
            let rhsInLoop = range.contains(rhs.sortOrder)
            if lhsInLoop != rhsInLoop { return lhsInLoop && !rhsInLoop }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private var outputSourceSteps: [PromptChainStep] {
        chain.steps.filter { $0.id != step.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Button(action: onToggleCollapsed) {
                    Color.clear
                        .frame(height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isCollapsed ? "Expand step" : "Collapse step")

                HStack(spacing: 10) {
                    if !isVariablePrompt {
                        Text("\(step.sortOrder + 1)").font(DT.FontToken.bodyStrong).frame(width: 28, height: 28).overlay(Circle().stroke(DT.ColorToken.borderStrong))
                        InlineDropdown(
                            selection: Binding(get: { step.promptID }, set: { onPromptChange($0) }),
                            options: [Optional<UUID>.none] + prompts.filter { !$0.isArchived && $0.type != .phrase }.map { Optional($0.id) },
                            title: { id in
                                id.flatMap { promptID in prompts.first { $0.id == promptID }?.displayTitle } ?? "Choose prompt"
                            }
                        )
                        .frame(width: 250)
                    }
                    if showProviderModelControls && !isVariablePrompt {
                        InlineDropdown(
                            selection: Binding(get: { step.providerKind }, set: { onProviderModelChange($0, nil) }),
                            options: AIProviderKind.allCases,
                            title: { $0.displayName }
                        )
                        .frame(width: 120)
                        InlineDropdown(
                            selection: Binding(get: { validModelID }, set: { onProviderModelChange(step.providerKind, $0) }),
                            options: step.providerKind.models.map(\.id),
                            title: { id in step.providerKind.models.first { $0.id == id }?.displayName ?? id }
                        )
                        .frame(width: 150)
                    }
                    Spacer(minLength: 12)
                    StepStatusPill(status: step.status, customLabel: step.monitorStatusLabel, color: statusColor)
                    RunStepButton(isRunning: step.status == .running, runTitle: runButtonTitle, stopTitle: stopButtonTitle, action: onRun, stopAction: onStop)
                    Button(action: onToggleCollapsed) {
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    }
                    .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                    .help(isCollapsed ? "Expand step" : "Collapse step")
                    if canRemove {
                        Button(role: .destructive, action: onRemove) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(SecondaryButtonStyle(destructive: true, horizontalPadding: 10))
                        .help("Delete this step")
                        .accessibilityLabel("Delete Step")
                    }
                }
            }
            .frame(height: 32)
            if let prompt = selectedPrompt {
                if isCollapsed {
                    collapsedOutputPreview
                } else {
                    Divider().overlay(DT.ColorToken.borderDefault)
                    if prompt.variables.isEmpty {
                        Text("No variables required for this prompt.")
                            .font(DT.FontToken.bodySmall)
                            .foregroundStyle(DT.ColorToken.textTertiary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("Variables (\(prompt.variables.count))").font(DT.FontToken.bodySmallStrong); Spacer() }
                            ForEach(prompt.variables.sorted(by: { $0.sortOrder < $1.sortOrder })) { variable in
                                ChainVariableRow(
                                    variable: variable,
                                    binding: step.variableBindings.first { $0.variableKey == variable.key } ?? ChainVariableBinding(variableKey: variable.key),
                                    outputSourceSteps: outputSourceSteps,
                                    feedbackSteps: loopFeedbackSourceSteps,
                                    previousOutputs: previousOutputs,
                                    onChange: onBindingChange
                                )
                            }
                        }
                    }
                    HStack(alignment: .center, spacing: 12) {
                        Text("Output Behavior")
                            .font(DT.FontToken.captionStrong)
                            .frame(width: ChainLayout.labelColumnWidth, alignment: .leading)
                        Menu {
                            ForEach(outputPolicyOptions) { policy in
                                Button(outputPolicyDisplayName(policy)) { onOutputPolicyChange(policy) }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(outputPolicyDisplayName(activeOutputPolicy))
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(DT.ColorToken.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DT.ColorToken.accentBlue)
                        .frame(width: ChainLayout.sourceColumnWidth, alignment: .leading)
                        .help(isVariablePrompt ? "Choose whether this variable prompt auto-saves its output Markdown after each run." : "Choose whether this step auto-saves its output Markdown after each run.")
                        if isVariablePrompt {
                            Button(action: onChooseOutputFile) {
                                Label(variableOutputFolderLabel.isEmpty ? "Output Folder" : variableOutputFolderLabel, systemImage: "folder")
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                            .help("Choose the folder where variable prompt outputs should be saved.")
                            Button("Default", action: onResetVariableOutputFolder)
                                .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                                .disabled(!variableHasCustomOutputFolder)
                        }
                        HStack(spacing: 6) {
                            TextField("Output file name", text: Binding(get: { step.customOutputFileName }, set: { onOutputFileOptionsChange($0, nil, nil) }))
                                .textFieldStyle(.plain)
                                .font(DT.FontToken.caption)
                                .padding(.horizontal, 8)
                                .frame(minWidth: 180, maxWidth: 260, minHeight: 28, maxHeight: 28)
                                .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
                                .overlay(RoundedRectangle(cornerRadius: DT.Radius.sm).stroke(DT.ColorToken.borderDefault))
                            if !isVariablePrompt {
                                Button(action: onChooseOutputFile) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .buttonStyle(SecondaryButtonStyle(horizontalPadding: 9))
                                .accessibilityLabel("Choose Output File")
                                .help("Choose the exact folder and Markdown file for this step's saved output.")
                            }
                        }
                        .help(outputFileHelpText)
                        Toggle("Overwrite", isOn: Binding(get: { step.overwriteOutputFile }, set: { onOutputFileOptionsChange(nil, nil, $0) }))
                            .font(DT.FontToken.caption)
                            .toggleStyle(.checkbox)
                        if showTagControls {
                            HStack(spacing: 6) {
                                Text("Tag").font(DT.FontToken.captionStrong).foregroundStyle(DT.ColorToken.textTertiary)
                                TextField("tag-name", text: Binding(get: { step.finalOutputTag }, set: { onFinalOutputTagChange($0) }))
                                    .textFieldStyle(.plain)
                                    .font(DT.FontToken.caption)
                                    .padding(.horizontal, 8)
                                    .frame(width: 160, height: 28)
                                    .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
                                    .overlay(RoundedRectangle(cornerRadius: DT.Radius.sm).stroke(DT.ColorToken.borderDefault))
                                    .help("Optional expected wrapper tag. If set and the response contains this tag, only its content is saved as <tag>.md.")
                            }
                        }
                        Spacer()
                    }
                    outputPreview
                    HStack(spacing: 10) {
                        Spacer()
                        Button { copyOutputPreview() } label: { Label("Copy", systemImage: "doc.on.doc") }
                            .buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                        Button("Save Markdown", action: onSaveMarkdown)
                            .buttonStyle(SecondaryButtonStyle(horizontalPadding: 12))
                            .help(isVariablePrompt ? "Manually save this prompt's latest output as Markdown, or save the resolved prompt if no output exists yet." : "Manually save this step's latest output as Markdown, or save the resolved chained prompt if no output exists yet.")
                            .accessibilityLabel("Save Markdown")
                        Button {
                            showingRunInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
                        .help("Show the latest run terminal details")
                        .accessibilityLabel("Show Run Info")
                        .popover(isPresented: $showingRunInfo, arrowEdge: .bottom) {
                            RunInfoPopover(text: latestTerminalText)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose an existing saved prompt before running this step.")
                        .font(DT.FontToken.bodySmall)
                        .foregroundStyle(DT.ColorToken.textTertiary)
                    if let latestError {
                        Text(latestError)
                            .font(DT.FontToken.captionStrong)
                            .foregroundStyle(DT.ColorToken.dangerRed)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DT.ColorToken.surfaceTertiary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.xl).stroke(DT.ColorToken.borderDefault))
    }

    @AppStorage(AppSettingsKeys.storageChainOutputShowTagControls) private var showTagControls = true

    @ViewBuilder private var collapsedOutputPreview: some View {
        if collapsedPreviewLineCount > 0 {
            Text(collapsedPreviewText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(outputPreviewColor)
                .lineLimit(collapsedPreviewLineCount)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(10)
                .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
        }
    }

    private var outputPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(step.status == .running ? "Output Preview (Terminal)" : "Output Preview (Markdown)").font(DT.FontToken.captionStrong)
                Spacer()
                if latestError != nil && step.status != .running {
                    Text("Error").font(DT.FontToken.captionStrong).foregroundStyle(DT.ColorToken.dangerRed)
                }
            }
            Text(outputPreviewText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(outputPreviewColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                .padding(10)
                .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
        }
    }

    private var outputPreviewText: String {
        if step.status == .running { return runningTerminalText }
        if let latestError { return latestError }
        if let latestOutput { return latestOutput }
        return isVariablePrompt ? "Run this prompt to generate output." : "Run this step to generate output."
    }

    private var collapsedPreviewText: String {
        outputPreviewText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(collapsedPreviewLineCount)
            .joined(separator: "\n")
    }

    private func copyOutputPreview() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputPreviewText, forType: .string)
    }

    private var runningTerminalText: String {
        terminalText(status: "running", provider: step.providerKind.displayName, model: validModelID, outputFilePath: nil, footer: "thinking: waiting for provider response…\noutput: pending")
    }

    private var outputFileHelpText: String {
        let path = step.customOutputFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty { return "Saves to \(path)" }
        if isVariablePrompt { return "Optional custom Markdown filename. Batch runs use each input Markdown filename." }
        return "Optional custom Markdown filename. Use the folder button to choose an exact save location."
    }

    private var runningCountLines: String {
        let count = stepRunCount(step.id)
        if step.status == .running {
            if isVariablePrompt {
                return """
                prompt run count before this run: \(count)
                this prompt run number: \(count + 1)
                """
            }
            return """
            step run count before this run: \(count)
            this step run number: \(count + 1)
            configured loop count: \(chain.loopCount)
            """
        }
        return "step run count: \(count)"
    }

    private var latestTerminalText: String {
        if step.status == .running { return runningTerminalText }
        guard let run = latestStepRun(step.id) else {
            return "No run details recorded for this step yet."
        }
        let status = run.status.displayName.lowercased()
        let outputPath = run.outputFilePath?.trimmedNonEmpty(defaultValue: "")
        var footer = "finished: \(run.finishedAt?.formatted(date: .abbreviated, time: .standard) ?? "not finished")"
        if let error = run.errorMessage?.trimmedNonEmpty(defaultValue: "") {
            footer += "\nerror: \(error)"
        } else if !run.outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            footer += "\noutput: received"
        } else {
            footer += "\noutput: none"
        }
        if !run.monitorStatusLabel.isEmpty {
            footer += "\nmonitor status: \(run.monitorStatusLabel)"
            if !run.monitorMatchedPhrase.isEmpty {
                footer += "\nmatched phrase: \(run.monitorMatchedPhrase)"
            }
        }
        return terminalText(status: status, provider: run.providerKind.displayName, model: run.modelID, outputFilePath: outputPath, footer: footer)
    }

    private func terminalText(status: String, provider: String, model: String, outputFilePath: String?, footer: String) -> String {
        let promptTitle = selectedPrompt?.displayTitle ?? step.title
        let inputLines = runningInputLines
        let outputName = outputFileName(for: outputFilePath)
        let outputPath = resolvedOutputPath(for: outputFilePath)
        let tagLine = runningTagOutputLine
        let command = isVariablePrompt ? "$ prompt-manager variable-prompt run" : "$ prompt-manager chain run --step \(step.sortOrder + 1)"
        return """
        \(command)
        status: \(status)
        prompt: \(promptTitle)
        provider: \(provider)
        model: \(model)
        \(runningCountLines)
        input:
        \(inputLines)
        output behavior: \(outputPolicyDisplayName(activeOutputPolicy))
        output folder: \(outputFolderURL.path)
        output filename: \(outputName)
        output path: \(outputPath)
        \(tagLine)
        overwrite: \(step.overwriteOutputFile ? "yes" : "no")
        \(footer)
        """
    }

    private var outputPolicyOptions: [ChainOutputPolicy] {
        isVariablePrompt ? ChainOutputPolicy.variablePromptOptions : ChainOutputPolicy.allCases
    }

    private var activeOutputPolicy: ChainOutputPolicy {
        isVariablePrompt && step.outputPolicy != .viewOnly ? .saveMarkdown : step.outputPolicy
    }

    private func outputPolicyDisplayName(_ policy: ChainOutputPolicy) -> String {
        if isVariablePrompt && policy != .viewOnly { return "Auto-save Markdown" }
        return policy.displayName
    }

    private func outputFileName(for outputFilePath: String? = nil) -> String {
        if let savedName = outputFilePath.flatMap({ URL(fileURLWithPath: $0).lastPathComponent.trimmedNonEmpty(defaultValue: "") }) {
            return savedName
        }
        if hasVariablePromptFolderBatchInput {
            return "each input Markdown filename"
        }
        return ChainOutputStore.configuredOutputFileName(for: step, attachment: step.variableBindings.compactMap(\.fileAttachment).first)
    }

    private func resolvedOutputPath(for outputFilePath: String? = nil) -> String {
        if let savedPath = outputFilePath?.trimmedNonEmpty(defaultValue: "") {
            return savedPath
        }
        if hasVariablePromptFolderBatchInput {
            return outputFolderURL.appendingPathComponent("<input-markdown-filename>").path
        }
        let outputName = outputFileName(for: outputFilePath)
        let selectedPath = step.customOutputFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return !selectedPath.isEmpty ? selectedPath : outputFolderURL.appendingPathComponent(outputName).path
    }

    private var hasVariablePromptFolderBatchInput: Bool {
        isVariablePrompt && step.variableBindings.contains { binding in
            binding.inputType == .folder && binding.folderAttachment != nil
        }
    }

    private var runningTagOutputLine: String {
        guard showTagControls else { return "" }
        let tag = step.finalOutputTag.sanitizedXMLTagName(defaultValue: "")
        guard !tag.isEmpty else { return "" }
        return "tag output: \(ChainOutputStore.taggedResponseFileName(for: step)) if <\(tag)> is returned"
    }

    private var runningInputLines: String {
        let lines = step.variableBindings.sorted { $0.variableKey < $1.variableKey }.map { binding -> String in
            switch binding.inputType {
            case .file:
                guard let attachment = binding.fileAttachment else { return "  - input file name: not selected" }
                let location = attachment.originalPath?.trimmedNonEmpty(defaultValue: "") ?? ""
                if location.isEmpty { return "  - input file name: \(attachment.fileName)" }
                return """
                  - input file name: \(attachment.fileName)
                  - input file path: \(location)
                """
            case .folder:
                guard let folder = binding.folderAttachment else { return "  - input folder: not selected" }
                return """
                  - input folder name: \(folder.folderName)
                  - input folder path: \(folder.originalPath)
                  - batch markdown files: \(folder.markdownFileCount)
                """
            case .previousStepOutput:
                guard let sourceID = binding.sourceStepID else {
                    return "  - input file name: previous output not selected"
                }
                let run = latestCompletedStepRun(sourceID) ?? latestStepRun(sourceID)
                let tag = showTagControls ? binding.sourceOutputTag.sanitizedXMLTagName(defaultValue: "") : ""
                if let outputFilePath = run?.outputFilePath?.trimmedNonEmpty(defaultValue: "") {
                    let fileName = URL(fileURLWithPath: outputFilePath).lastPathComponent
                    return """
                      - input file name: \(fileName)
                      - input file path: \(outputFilePath)\(tag.isEmpty ? "" : "\n  - input output tag: <\(tag)>")
                    """
                }
                if previousOutputs[sourceID] != nil {
                    return "  - input file name: latest in-app output\(tag.isEmpty ? "" : "\n  - input output tag: <\(tag)>")"
                }
                return "  - input file name: previous output not available yet"
            case .loopFeedbackFile:
                let inputName = binding.fileAttachment?.fileName ?? "not selected"
                let inputPath = binding.fileAttachment?.originalPath?.trimmedNonEmpty(defaultValue: "") ?? ""
                let savedOutputName = outputFileName()
                let savedOutputPath = resolvedOutputPath()
                let feedbackLine: String
                if let sourceID = binding.sourceStepID {
                    let run = latestCompletedStepRun(sourceID) ?? latestStepRun(sourceID)
                    let tag = showTagControls ? binding.sourceOutputTag.sanitizedXMLTagName(defaultValue: "") : ""
                    if let outputFilePath = run?.outputFilePath?.trimmedNonEmpty(defaultValue: "") {
                        feedbackLine = "  - feedback file path: \(outputFilePath)\(tag.isEmpty ? "" : "\n  - feedback output tag: <\(tag)>")"
                    } else if previousOutputs[sourceID] != nil {
                        feedbackLine = "  - feedback source: latest in-app output\(tag.isEmpty ? "" : "\n  - feedback output tag: <\(tag)>")"
                    } else {
                        feedbackLine = "  - feedback source: not available yet"
                    }
                } else {
                    feedbackLine = "  - feedback source: not selected"
                }
                return """
                  - loop initial file name: \(inputName)
                \(inputPath.isEmpty ? "" : "  - loop initial file path: \(inputPath)\n")  - loop later-pass input file name: \(savedOutputName)
                  - loop later-pass input file path: \(savedOutputPath)
                \(feedbackLine)
                """
            case .text:
                return "  - input text: \(binding.variableKey)"
            }
        }
        return lines.isEmpty ? "  - none" : lines.joined(separator: "\n")
    }

    private var outputPreviewColor: Color {
        if latestError != nil && step.status != .running { return DT.ColorToken.dangerRed }
        if !step.monitorStatusLabel.isEmpty { return step.monitorStatusLabel == "Success" ? DT.ColorToken.successGreen : DT.ColorToken.warningYellow }
        if step.status == .running { return DT.ColorToken.successGreen }
        return DT.ColorToken.textSecondary
    }

    private var statusColor: Color {
        switch step.status {
        case .complete: DT.ColorToken.successGreen
        case .failed: DT.ColorToken.dangerRed
        case .cancelled: DT.ColorToken.warningYellow
        case .running: DT.ColorToken.accentBlue
        case .ready: DT.ColorToken.accentBlue
        case .draft: DT.ColorToken.warningYellow
        default: DT.ColorToken.textTertiary
        }
    }
}

private struct RunInfoPopover: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Run terminal details")
                    .font(DT.FontToken.bodySmallStrong)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .buttonStyle(SecondaryButtonStyle(horizontalPadding: 10))
            }
            ScrollView {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DT.ColorToken.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
                    .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
            }
            .frame(width: 560, height: 280)
        }
        .padding(14)
        .background(DT.ColorToken.surfacePrimary)
    }
}

private struct StepStatusPill: View {
    let status: ChainRunStatus
    let customLabel: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            if status == .running {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.62)
                    .tint(color)
                    .frame(width: 12, height: 12)
            }
            Text(customLabel.isEmpty ? status.displayName : "Stopped: \(customLabel)")
                .font(DT.FontToken.captionStrong)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(status == .running ? 0.22 : 0.16), in: RoundedRectangle(cornerRadius: DT.Radius.sm))
    }
}


private struct RunStepButton: View {
    let isRunning: Bool
    let runTitle: String
    let stopTitle: String
    let action: () -> Void
    let stopAction: () -> Void

    var body: some View {
        if isRunning {
            Button(action: stopAction) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.72)
                        .tint(DT.ColorToken.dangerRed)
                    Text(stopTitle)
                }
                .font(DT.FontToken.captionStrong)
                .foregroundStyle(DT.ColorToken.dangerRed)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(DT.ColorToken.surfacePrimary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.promptCardBorder))
            }
            .buttonStyle(.plain)
            .help(stopTitle)
            .accessibilityLabel(stopTitle)
        } else {
            Button(runTitle, action: action)
                .buttonStyle(PrimaryButtonStyle(horizontalPadding: 18))
                .help(runTitle)
        }
    }
}

private enum ChainLayout {
    static let labelColumnWidth: CGFloat = 132
    static let sourceColumnWidth: CGFloat = 150
}

private struct ChainVariableRow: View {
    let variable: VariableDefinition
    var binding: ChainVariableBinding
    let outputSourceSteps: [PromptChainStep]
    let feedbackSteps: [PromptChainStep]
    let previousOutputs: [UUID: String]
    let onChange: (ChainVariableBinding) -> Void
    @State private var showingFileImporter = false
    @State private var attachmentError: String?
    @AppStorage(AppSettingsKeys.storageChainOutputShowTagControls) private var showTagControls = true

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(variable.label)
                .font(DT.FontToken.bodySmall)
                .foregroundStyle(DT.ColorToken.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: ChainLayout.labelColumnWidth, alignment: .leading)
            InlineDropdown(
                selection: Binding(get: { binding.inputType }, set: { var b = binding; b.inputType = $0; onChange(b) }),
                options: ChainVariableInputType.allCases,
                title: { $0.displayName }
            )
            .frame(width: ChainLayout.sourceColumnWidth)
            valueControl
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
    }

    @ViewBuilder private var valueControl: some View {
        switch binding.inputType {
        case .text:
            TextField("Value", text: Binding(get: { binding.textValue }, set: { var b = binding; b.textValue = $0; onChange(b) }))
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.borderDefault))
        case .file:
            fileAttachmentControl
        case .folder:
            folderAttachmentControl
        case .loopFeedbackFile:
            HStack(spacing: 8) {
                fileAttachmentControl
                    .frame(minWidth: 220)
                InlineDropdown(
                    selection: Binding(get: { binding.sourceStepID }, set: { var b = binding; b.sourceStepID = $0; onChange(b) }),
                    options: [Optional<UUID>.none] + feedbackSteps.map { Optional($0.id) },
                    title: { id in
                        guard let id, let step = feedbackSteps.first(where: { $0.id == id }) else { return "Choose step output" }
                        return stepOutputTitle(step)
                    }
                )
                .frame(width: 190)
                if showTagControls {
                    TextField("tag", text: Binding(
                        get: { binding.sourceOutputTag.trimmedNonEmpty(defaultValue: selectedFeedbackStep?.finalOutputTag ?? "") },
                        set: { var b = binding; b.sourceOutputTag = $0; onChange(b) }
                    ))
                    .textFieldStyle(.plain)
                    .font(DT.FontToken.caption)
                    .padding(.horizontal, 8)
                    .frame(width: 150, height: 30)
                    .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DT.Radius.sm).stroke(DT.ColorToken.borderDefault))
                    .help("Optional tag to extract from the selected step output before injecting it.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .previousStepOutput:
            previousStepOutputControl
        }
    }

    @ViewBuilder private var fileAttachmentControl: some View {
            VStack(alignment: .leading, spacing: 4) {
                Button { showingFileImporter = true } label: {
                    HStack {
                        Image(systemName: "doc.text")
                        Text(binding.fileAttachment?.fileName ?? "Attach .md, .txt, or .html")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(binding.fileAttachment?.displaySize ?? "")
                    }
                    .font(DT.FontToken.caption)
                    .foregroundStyle(DT.ColorToken.textSecondary)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
                }
                .buttonStyle(.plain)
                .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.plainText, .text, .html, UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "markdown") ?? .plainText], allowsMultipleSelection: false) { result in
                    handleFileImport(result)
                }
                if let attachmentError {
                    Text(attachmentError).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.dangerRed).lineLimit(2)
                }
            }
    }

    @ViewBuilder private var folderAttachmentControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { chooseFolder() } label: {
                HStack {
                    Image(systemName: "folder")
                    Text(binding.folderAttachment?.folderName ?? "Choose Markdown folder")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(binding.folderAttachment?.displayCount ?? "")
                }
                .font(DT.FontToken.caption)
                .foregroundStyle(DT.ColorToken.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
            }
            .buttonStyle(.plain)
            .help("Choose a folder of top-level Markdown files to run one at a time.")
            if let attachmentError {
                Text(attachmentError).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.dangerRed).lineLimit(2)
            }
        }
    }

    @ViewBuilder private var previousStepOutputControl: some View {
            HStack(spacing: 8) {
                InlineDropdown(
                    selection: Binding(get: { binding.sourceStepID }, set: { var b = binding; b.sourceStepID = $0; onChange(b) }),
                    options: [Optional<UUID>.none] + outputSourceSteps.map { Optional($0.id) },
                    title: { id in
                        guard let id, let step = outputSourceSteps.first(where: { $0.id == id }) else { return "Choose step output" }
                        return stepOutputTitle(step)
                    }
                )
                .frame(width: 190)
                if showTagControls {
                    TextField("tag", text: Binding(
                        get: { binding.sourceOutputTag.trimmedNonEmpty(defaultValue: selectedPreviousStep?.finalOutputTag ?? "") },
                        set: { var b = binding; b.sourceOutputTag = $0; onChange(b) }
                    ))
                    .textFieldStyle(.plain)
                    .font(DT.FontToken.caption)
                    .padding(.horizontal, 8)
                    .frame(width: 180, height: 30)
                    .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DT.Radius.sm).stroke(DT.ColorToken.borderDefault))
                    .help("Tag to extract from the selected step output before injecting this variable.")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedPreviousStep: PromptChainStep? {
        guard let sourceStepID = binding.sourceStepID else { return nil }
        return outputSourceSteps.first { $0.id == sourceStepID }
    }

    private var selectedFeedbackStep: PromptChainStep? {
        guard let sourceStepID = binding.sourceStepID else { return nil }
        return feedbackSteps.first { $0.id == sourceStepID }
    }

    private func stepOutputTitle(_ step: PromptChainStep) -> String {
        "Step \(step.sortOrder + 1) Output\(previousOutputs[step.id] == nil ? " — not run" : "")"
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder containing top-level Markdown files."
        if panel.runModal() == .OK, let url = panel.url {
            let count = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
                .filter { ["md", "markdown"].contains($0.pathExtension.lowercased()) }
                .count) ?? 0
            var b = binding
            b.folderAttachment = ChainFolderAttachment(folderName: url.lastPathComponent, originalPath: url.path, markdownFileCount: count)
            b.fileAttachment = nil
            b.inputType = .folder
            attachmentError = count == 0 ? "No top-level Markdown files found." : nil
            onChange(b)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                attachmentError = "Could not access selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()
            let attachment = ChainFileAttachment(
                fileName: url.lastPathComponent,
                fileExtension: ext,
                byteCount: data.count,
                originalPath: url.path,
                snapshotText: String(decoding: data, as: UTF8.self)
            )
            guard attachment.isSupportedTextAttachment else {
                attachmentError = "Unsupported file type. Use .md, .txt, or .html."
                return
            }
            var updated = binding
            updated.fileAttachment = attachment
            attachmentError = nil
            onChange(updated)
        } catch {
            attachmentError = error.localizedDescription
        }
    }

}

struct ChainRunInspectorView: View {
    let chain: PromptChain?
    let selectedStep: PromptChainStep?
    let providers: [AIProviderConfiguration]
    let chainRuns: [ChainRun]
    let onCollapsedPreviewLineChange: (Int) -> Void
    let onChooseOutputFolder: () -> Void
    @AppStorage(AppSettingsKeys.aiThinkingMode) private var thinkingMode = "Disabled"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inspectorSection("Run Configuration") {
                    metadataRow("Provider", settingsProviderModel.provider.displayName)
                    metadataRow("Model", settingsProviderModel.modelID)
                    metadataRow("Max tokens", "6000")
                    metadataRow("Thinking mode", normalizedThinkingMode)
                    metadataRow("Monitor rules", chain.map { "\($0.monitorRules.filter { $0.isEnabled && !$0.phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)" } ?? "—")
                }
                inspectorSection("Output Behavior") {
                    metadataRow("Save Markdown", "On")
                    metadataRow("Auto-feed next step", "On")
                    actionRow("Output folder", value: chainOutputFolderName, systemImage: "folder", action: onChooseOutputFolder)
                    stepperRow(
                        "Collapsed preview",
                        value: chain?.collapsedOutputPreviewLineCount ?? 0,
                        range: 0...20,
                        suffix: "lines",
                        onChange: onCollapsedPreviewLineChange
                    )
                }
                inspectorSection("Selected Step") {
                    metadataRow("Prompt", selectedStep?.title ?? "None")
                    metadataRow("Step", selectedStep.map { "\($0.sortOrder + 1) of \(chain?.steps.count ?? 0)" } ?? "—")
                    metadataRow("Variables", "\(selectedStep?.variableBindings.count ?? 0)")
                    metadataRow("Status", selectedStep.map { statusDisplay(for: $0) } ?? "—")
                    metadataRow("Step runs", selectedStep.map { "\(stepRunCount($0.id))" } ?? "—")
                }
                inspectorSection("Loop Metrics") {
                    metadataRow("Configured loops", chain.map { "\($0.loopCount)" } ?? "—")
                    metadataRow("Last loop count", chain.map { "\($0.lastLoopRunCount)" } ?? "—")
                    metadataRow("Total loop count", chain.map { "\($0.totalLoopRunCount)" } ?? "—")
                    metadataRow("Step run total", chain.map { "\(totalStepRunCount(for: $0))" } ?? "—")
                }
                inspectorSection("Run Metadata") {
                    metadataRow("Created", chain?.createdAt.formatted(date: .numeric, time: .shortened) ?? "—")
                    metadataRow("Updated", chain?.updatedAt.formatted(date: .numeric, time: .shortened) ?? "—")
                    metadataRow("Last Run", chain?.lastRunAt?.formatted(date: .omitted, time: .shortened) ?? "Not run")
                    metadataRow("Provider", latestRunProvider)
                    if let chain, !chain.lastMonitorStatusLabel.isEmpty {
                        metadataRow("Monitor stop", "\(chain.lastMonitorStatusLabel) • \(chain.lastMonitorMatchedPhrase)")
                    }
                }
            }.padding(18)
        }.background(DT.ColorToken.surfacePrimary)
    }

    private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(DT.FontToken.bodyStrong); content() }
    }

    private var chainOutputFolderName: String {
        guard let chain else { return "—" }
        let customPath = chain.customOutputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !customPath.isEmpty else { return "Chain Outputs" }
        return URL(fileURLWithPath: customPath).lastPathComponent
    }

    private var normalizedThinkingMode: String {
        thinkingMode == "Disabled" ? "Disabled" : "Enabled"
    }

    private var settingsProviderModel: (provider: AIProviderKind, modelID: String) {
        AppViewModel.settingsDefaultProviderModel()
    }

    private var latestRunProvider: String {
        if let latest = chainRuns.first(where: { run in
            guard let chain else { return false }
            return run.chainID == chain.id && run.stepRuns.contains { $0.status == .complete || $0.status == .running }
        })?.stepRuns.first {
            return latest.providerKind.displayName
        }
        guard let chain else { return "—" }
        let completedSteps = chain.steps.filter { $0.status == .complete || $0.status == .running }.sorted { $0.sortOrder > $1.sortOrder }
        return completedSteps.first?.providerKind.displayName ?? settingsProviderModel.provider.displayName
    }

    private func stepRunCount(_ stepID: UUID) -> Int {
        chainRuns.reduce(0) { total, run in
            total + run.stepRuns.filter { $0.stepID == stepID }.count
        }
    }

    private func totalStepRunCount(for chain: PromptChain) -> Int {
        let stepIDs = Set(chain.steps.map(\.id))
        return chainRuns
            .filter { $0.chainID == chain.id }
            .reduce(0) { total, run in total + run.stepRuns.filter { stepIDs.contains($0.stepID) }.count }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(DT.ColorToken.textSecondary); Spacer(); Text(value).foregroundStyle(DT.ColorToken.textPrimary).lineLimit(1) }.font(DT.FontToken.caption).frame(minHeight: 26)
    }

    private func statusDisplay(for step: PromptChainStep) -> String {
        step.monitorStatusLabel.isEmpty ? step.status.displayName : "Stopped: \(step.monitorStatusLabel)"
    }

    private func actionRow(_ label: String, value: String, systemImage: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .foregroundStyle(DT.ColorToken.textSecondary)
            Spacer(minLength: 8)
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                    Text(value)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(DT.ColorToken.textPrimary)
            .help("Choose this chain's output folder")
        }
        .font(DT.FontToken.caption)
        .frame(minHeight: 26)
    }

    private func stepperRow(_ label: String, value: Int, range: ClosedRange<Int>, suffix: String, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .foregroundStyle(DT.ColorToken.textSecondary)
            Spacer(minLength: 8)
            Text("\(value) \(suffix)")
                .foregroundStyle(DT.ColorToken.textPrimary)
                .frame(width: 58, alignment: .trailing)
            Stepper(
                value: Binding(
                    get: { value },
                    set: { onChange(min(max($0, range.lowerBound), range.upperBound)) }
                ),
                in: range,
                step: 1
            ) {
                Text("\(value) \(suffix)")
                    .foregroundStyle(DT.ColorToken.textPrimary)
                    .lineLimit(1)
            }
            .labelsHidden()
        }
        .font(DT.FontToken.caption)
        .frame(minHeight: 26)
    }
}

struct EmptyChainBuilderView: View {
    let onNewChain: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 34)).foregroundStyle(DT.ColorToken.textTertiary)
            Text("No chain selected").font(.system(size: 20, weight: .bold)).foregroundStyle(DT.ColorToken.textPrimary)
            Text("Create a chained prompt to run saved prompts in sequence.").font(DT.FontToken.bodySmall).foregroundStyle(DT.ColorToken.textSecondary)
            Button("New Chain", action: onNewChain).buttonStyle(PrimaryButtonStyle(horizontalPadding: 14))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DT.ColorToken.surfaceSecondary)
    }
}
