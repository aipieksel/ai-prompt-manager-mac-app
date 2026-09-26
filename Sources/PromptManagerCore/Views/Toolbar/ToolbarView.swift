import SwiftUI

struct ToolbarView: View {
    @Binding var searchQuery: String
    @Binding var sortMode: SortMode
    @Binding var appearance: AppAppearance
    let metrics: AppLayoutMetrics
    let newPromptTitle: String
    let saveStatus: String
    @Binding var leftSidebarVisible: Bool
    @Binding var rightDetailsSidebarVisible: Bool
    @AppStorage(AppSettingsKeys.headingFontWeight) private var headingFontWeight = "bold"
    @AppStorage(AppSettingsKeys.headingFontSize) private var headingFontSize = "14"
    @Environment(\.appFontScale) private var scale
    let onNewPrompt: () -> Void
    let onNewChain: () -> Void
    let onNewFolder: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    let onAudit: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 86)
            Button {
                leftSidebarVisible.toggle()
            } label: {
                Image(systemName: leftSidebarVisible ? "sidebar.left" : "sidebar.leading")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(IconToolbarButtonStyle())
            .accessibilityLabel(leftSidebarVisible ? "Hide library sidebar" : "Show library sidebar")
            .help(leftSidebarVisible ? "Hide library sidebar" : "Show library sidebar")
            Text("Prompt Manager")
                .font(.system(size: CGFloat(Double(headingFontSize) ?? 14) * scale.scale, weight: headingFontWeight.appTextWeight))
                .foregroundStyle(DT.ColorToken.textPrimary)
                .lineLimit(1)
                .frame(width: metrics.compactToolbar ? 150 : 220, alignment: .leading)
            Spacer(minLength: 10)
            SearchFieldView(text: $searchQuery)
                .frame(width: metrics.compactToolbar ? 330 : 400, height: 38)
            Spacer(minLength: 12)
            Text(saveStatus)
                .font(DT.FontToken.caption)
                .foregroundStyle(saveStatus.lowercased().contains("saved") ? DT.ColorToken.successGreen : DT.ColorToken.textTertiary)
                .lineLimit(1)
                .frame(width: metrics.compactToolbar ? 72 : 126, alignment: .trailing)
            PrimaryToolbarButton(title: metrics.compactToolbar ? "New" : newPromptTitle, systemImage: "plus", action: onNewPrompt)
            SecondaryToolbarButton(title: metrics.compactToolbar ? "Chain" : "New Chained Prompt", systemImage: "link.badge.plus", action: onNewChain)
            SecondaryToolbarButton(title: metrics.compactToolbar ? "Folder" : "New Folder", systemImage: "plus", action: onNewFolder)
            Menu(metrics.compactToolbar ? "Sort" : "Sort: \(sortMode.rawValue)") { ForEach(SortMode.allCases) { mode in Button(mode.rawValue) { sortMode = mode } } }
                .buttonStyle(SecondaryMenuButtonStyle())
            Menu {
                Button("Import Prompt Folder", systemImage: "square.and.arrow.down") { onImport() }
                Button("Export Selected Prompt", systemImage: "doc") { onExport() }
                Button("Export Current Folder", systemImage: "folder") { onExport() }
                Button("Export Library Backup", systemImage: "externaldrive") { onExport() }
                Divider()
                Button("Run Metadata Audit", systemImage: "checklist") { onAudit() }
                Button("Settings", systemImage: "gearshape") { onSettings() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(IconToolbarButtonStyle())
            .accessibilityLabel("Library actions")
            Button {
                appearance = appearance.next
            } label: {
                Image(systemName: appearance.toolbarIcon)
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(IconToolbarButtonStyle())
            .accessibilityLabel("Appearance: \(appearance.displayName)")
            .help("Appearance: \(appearance.displayName). Click to switch to \(appearance.next.displayName).")
            Button {
                rightDetailsSidebarVisible.toggle()
            } label: {
                Image(systemName: rightDetailsSidebarVisible ? "sidebar.right" : "sidebar.trailing")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(IconToolbarButtonStyle())
            .accessibilityLabel(rightDetailsSidebarVisible ? "Hide details sidebar" : "Show details sidebar")
            .help(rightDetailsSidebarVisible ? "Hide details sidebar" : "Show details sidebar")
        }
        .padding(.leading, 12)
        .padding(.trailing, 20)
        .frame(height: DT.Size.compactToolbarHeight)
        .background(DT.ColorToken.surfacePrimary)
    }
}

struct SearchFieldView: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundStyle(DT.ColorToken.textTertiary)
            TextField("Search prompts...", text: $text)
                .textFieldStyle(.plain)
                .font(DT.FontToken.bodyDefault)
                .focusEffectDisabled()
                .focused($focused)
            Text("⌘F").font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .fieldChrome(focused: focused, radius: DT.Radius.md)
    }
}
