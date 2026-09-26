import SwiftUI

private enum SidebarGrid {
    static let disclosureWidth: CGFloat = 14
    static let iconWidth: CGFloat = 18
    static let countWidth: CGFloat = 30
    static let actionWidth: CGFloat = 16
}

struct LibrarySidebarView: View {
    @ObservedObject var model: AppViewModel
    let onSettings: () -> Void
    @AppStorage(AppSettingsKeys.librarySidebarShowCounts) private var showCounts = true
    @AppStorage(AppSettingsKeys.librarySidebarShowIcons) private var showIcons = true
    @AppStorage(AppSettingsKeys.librarySidebarFooterShortcuts) private var showFooterShortcuts = true
    @AppStorage(AppSettingsKeys.librarySidebarShowFolderCounts) private var showFolderCounts = true
    @AppStorage(AppSettingsKeys.librarySidebarFolderIndentation) private var folderIndentation = "compact"
    @State private var variablesExpanded = true
    @State private var chainsExpanded = true
    @State private var phrasesExpanded = true

    private var activePrompts: [Prompt] { model.activePrompts }
    private var activePhrases: [Prompt] { model.activePhrases }
    private var activeVariablePrompts: [Prompt] { model.activeVariablePrompts }
    private var activeChains: [PromptChain] { model.activeChains }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarSectionView(title: "LIBRARY") {
                SidebarRowView(icon: "doc.text", label: "All Prompts", count: activePrompts.count, showCount: showCounts, showIcon: showIcons, active: model.selection == .all && model.librarySection == .prompts && model.metadataFilters.type == nil) {
                    model.librarySection = .prompts
                    model.selection = .all
                    model.metadataFilters.clear()
                }
                SidebarRowView(icon: "star", label: "Favorites", count: activePrompts.filter(\.isFavorite).count, showCount: showCounts, showIcon: showIcons, active: model.selection == .favorites && model.librarySection == .prompts) {
                    model.librarySection = .prompts
                    model.selection = .favorites
                    model.metadataFilters.clear()
                }

                ScopedLibraryRootView(
                    icon: "curlybraces",
                    label: "Variable Prompts",
                    count: activeVariablePrompts.count,
                    showCount: showCounts,
                    showIcon: showIcons,
                    expanded: $variablesExpanded,
                    active: model.librarySection == .prompts && (model.selection == .variablePrompts || model.metadataFilters.type == .variablePrompt),
                    select: {
                        model.librarySection = .prompts
                        model.selection = .variablePrompts
                        model.metadataFilters.type = nil
                    },
                    addFolder: { model.createFolder(scope: .variablePrompts) }
                )
                if variablesExpanded {
                    scopedFolders(scope: .variablePrompts, prompts: activeVariablePrompts, chains: [])
                }

                ScopedLibraryRootView(
                    icon: "point.3.connected.trianglepath.dotted",
                    label: "Chained Prompts",
                    count: activeChains.count,
                    showCount: showCounts,
                    showIcon: showIcons,
                    expanded: $chainsExpanded,
                    active: model.librarySection == .chains,
                    select: {
                        model.librarySection = .chains
                        model.selection = .all
                        model.metadataFilters.clear()
                        if model.selectedChainID == nil { model.selectedChainID = model.activeChains.first?.id }
                    },
                    addFolder: { model.createFolder(scope: .chains) }
                )
                if chainsExpanded {
                    scopedFolders(scope: .chains, prompts: [], chains: activeChains)
                }

                ScopedLibraryRootView(
                    icon: "text.quote",
                    label: "Phrases",
                    count: activePhrases.count,
                    showCount: showCounts,
                    showIcon: showIcons,
                    expanded: $phrasesExpanded,
                    active: model.librarySection == .phrases,
                    select: {
                        model.librarySection = .phrases
                        model.selection = .all
                        model.metadataFilters.clear()
                    },
                    addFolder: { model.createFolder(scope: .phrases) }
                )
                if phrasesExpanded {
                    scopedFolders(scope: .phrases, prompts: activePhrases, chains: [])
                }
            }
            Spacer(minLength: 12)
            if showFooterShortcuts {
                HStack(spacing: 20) {
                    Button(action: onSettings) { Image(systemName: "gearshape") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    Spacer()
                    Text(AppVersionInfo.current.displayText)
                        .font(DT.FontToken.caption)
                }
                .font(.system(size: 20)).foregroundStyle(DT.ColorToken.textTertiary).padding(.top, 16)
            }
        }
        .padding(.top, 16).padding(.horizontal, 14).padding(.bottom, 16)
        .background(DT.ColorToken.surfaceSecondary)
    }

    @ViewBuilder
    private func scopedFolders(scope: FolderScope, prompts: [Prompt], chains: [PromptChain]) -> some View {
        let folderIndex = SidebarFolderIndex(scope: scope, folders: model.folders, prompts: prompts, chains: chains)
        let roots = folderIndex.children(of: nil)
        if roots.isEmpty {
            Text("No folders")
                .font(DT.FontToken.caption)
                .foregroundStyle(DT.ColorToken.textTertiary)
                .padding(.leading, showIcons ? 42 : 12)
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 2) {
                ForEach(roots) { folder in
                    ScopedFolderTreeView(folder: folder, scope: scope, model: model, folderIndex: folderIndex, level: 0, showCounts: showFolderCounts, indentationMode: folderIndentation)
                }
            }
            .padding(.top, 2)
        }
    }
}

struct SidebarSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View { VStack(alignment: .leading, spacing: 8) { SidebarSectionHeader(title: title); VStack(spacing: 2) { content } } }
}

struct SidebarSectionHeader: View {
    let title: String
    var trailing: AnyView? = nil
    var body: some View {
        HStack { Text(title).font(.system(size: 11, weight: .bold)).tracking(0.48).foregroundStyle(DT.ColorToken.textTertiary); Spacer(); if let trailing { trailing } }
            .frame(height: 16)
    }
}

struct SidebarRowView: View {
    let icon: String; let label: String; let count: Int; let showCount: Bool; let showIcon: Bool; let active: Bool; let height: CGFloat; let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccentStyle) private var accent
    @Environment(\.appFontScale) private var scale
    init(icon: String, label: String, count: Int, showCount: Bool = true, showIcon: Bool = true, active: Bool, height: CGFloat = 36, action: @escaping () -> Void) { self.icon = icon; self.label = label; self.count = count; self.showCount = showCount; self.showIcon = showIcon; self.active = active; self.height = height; self.action = action }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Color.clear.frame(width: SidebarGrid.disclosureWidth)
                if showIcon { Image(systemName: icon).font(.system(size: 18 * scale.scale, weight: .regular)).frame(width: SidebarGrid.iconWidth) }
                Text(label).font(.system(size: 13 * scale.scale, weight: active ? .semibold : .medium)).lineLimit(1)
                Spacer(minLength: 6)
                if showCount { Text("\(count)").font(DT.FontToken.caption).frame(width: SidebarGrid.countWidth, alignment: .trailing) }
                Color.clear.frame(width: SidebarGrid.actionWidth)
            }
            .foregroundStyle(active ? accent.color : DT.ColorToken.textSecondary)
            .padding(.horizontal, 4)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private struct ScopedLibraryRootView: View {
    let icon: String
    let label: String
    let count: Int
    let showCount: Bool
    let showIcon: Bool
    @Binding var expanded: Bool
    let active: Bool
    let select: () -> Void
    let addFolder: () -> Void
    @Environment(\.appAccentStyle) private var accent

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleExpanded) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DT.ColorToken.textTertiary)
                    .frame(width: SidebarGrid.disclosureWidth)
            }
            .buttonStyle(.plain)
            Button(action: activateRow) {
                HStack(spacing: 8) {
                    if showIcon { Image(systemName: icon).font(.system(size: 18)).frame(width: SidebarGrid.iconWidth) }
                    Text(label).font(.system(size: 13, weight: active ? .semibold : .medium)).lineLimit(1)
                    Spacer(minLength: 6)
                    Button(action: addFolder) { Image(systemName: "plus").font(.system(size: 12, weight: .semibold)) }
                        .buttonStyle(.plain)
                        .help("New folder")
                        .frame(width: SidebarGrid.countWidth, alignment: .trailing)
                }
                .foregroundStyle(active ? accent.color : DT.ColorToken.textSecondary)
                .padding(.horizontal, 4)
                .frame(height: 36)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: activateRow)
    }

    private func toggleExpanded() { expanded.toggle() }

    private func activateRow() {
        if !expanded { expanded = true }
        select()
    }
}

private struct SidebarFolderIndex {
    private let childrenByParentID: [UUID?: [Folder]]
    private let countsByFolderID: [UUID: Int]

    init(scope: FolderScope, folders: [Folder], prompts: [Prompt], chains: [PromptChain]) {
        let scopedFolders = folders.filter { $0.scope == scope }
        let childrenByParentID = Dictionary(grouping: scopedFolders, by: \.parentFolderID)
            .mapValues { folders in folders.sorted { $0.sortOrder < $1.sortOrder } }

        var directCounts: [UUID: Int] = [:]
        switch scope {
        case .chains:
            for chain in chains {
                if let folderID = chain.folderID { directCounts[folderID, default: 0] += 1 }
            }
        default:
            for prompt in prompts {
                if let folderID = prompt.folderID { directCounts[folderID, default: 0] += 1 }
            }
        }

        var totals: [UUID: Int] = [:]
        func totalCount(for folder: Folder) -> Int {
            if let cached = totals[folder.id] { return cached }
            let total = directCounts[folder.id, default: 0] + (childrenByParentID[folder.id] ?? []).reduce(0) { $0 + totalCount(for: $1) }
            totals[folder.id] = total
            return total
        }
        for folder in scopedFolders { _ = totalCount(for: folder) }
        self.childrenByParentID = childrenByParentID
        countsByFolderID = totals
    }

    func children(of parentID: UUID?) -> [Folder] { childrenByParentID[parentID] ?? [] }
    func count(for folderID: UUID) -> Int { countsByFolderID[folderID, default: 0] }
}

private struct ScopedFolderTreeView: View {
    let folder: Folder
    let scope: FolderScope
    @ObservedObject var model: AppViewModel
    let folderIndex: SidebarFolderIndex
    let level: Int
    var showCounts = true
    var indentationMode = "compact"
    @State private var expanded = true
    private var indentWidth: CGFloat { indentationMode == "standard" ? 18 : 10 }
    private var children: [Folder] { folderIndex.children(of: folder.id) }
    private var count: Int { folderIndex.count(for: folder.id) }
    private var active: Bool {
        guard case let .folder(id) = model.selection, id == folder.id else { return false }
        switch scope {
        case .variablePrompts: return model.librarySection == .prompts && model.metadataFilters.type == .variablePrompt
        case .chains: return model.librarySection == .chains
        case .phrases: return model.librarySection == .phrases
        case .prompts: return model.librarySection == .prompts
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if children.isEmpty {
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(DT.ColorToken.textTertiary).opacity(0).frame(width: SidebarGrid.disclosureWidth)
                } else {
                    Button(action: { expanded.toggle() }) { Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.system(size: 12)).foregroundStyle(DT.ColorToken.textTertiary) }
                        .buttonStyle(.plain)
                        .frame(width: SidebarGrid.disclosureWidth)
                }
                FolderEditableRow(folder: folder, active: active, count: count, showCount: showCounts, height: level == 0 ? 28 : 26, renameRequested: model.folderRenameRequestID == folder.id, select: activateFolder, rename: { model.renameFolder(folder.id, to: $0) })
            }
            .padding(.leading, CGFloat(level + 1) * indentWidth)
            .contextMenu {
                Button(newItemTitle, action: createItem)
                Button("New Subfolder") { model.createFolder(parentFolderID: folder.id, scope: scope) }
                Button("Rename Folder") { selectFolder(); model.folderRenameRequestID = folder.id }
                Divider()
                Button("Delete Folder", role: .destructive) { model.deleteFolder(folder.id) }
            }
            if expanded {
                ForEach(children) { child in
                    ScopedFolderTreeView(folder: child, scope: scope, model: model, folderIndex: folderIndex, level: level + 1, showCounts: showCounts, indentationMode: indentationMode)
                }
            }
        }
    }

    private var newItemTitle: String {
        switch scope {
        case .chains: "New Chain in Folder"
        case .phrases: "New Phrase in Folder"
        case .variablePrompts: "New Variable Prompt in Folder"
        case .prompts: "New Prompt in Folder"
        }
    }

    private func selectFolder() {
        model.selection = .folder(folder.id)
        switch scope {
        case .variablePrompts:
            model.librarySection = .prompts
            model.metadataFilters.type = .variablePrompt
        case .chains:
            model.librarySection = .chains
            model.metadataFilters.clear()
        case .phrases:
            model.librarySection = .phrases
            model.metadataFilters.clear()
        case .prompts:
            model.librarySection = .prompts
            model.metadataFilters.clear()
        }
    }

    private func activateFolder() {
        if !children.isEmpty && !expanded { expanded = true }
        selectFolder()
    }

    private func createItem() {
        selectFolder()
        switch scope {
        case .chains: model.createChainDraft()
        case .phrases: model.createPhrase()
        default: model.createPrompt()
        }
    }
}
