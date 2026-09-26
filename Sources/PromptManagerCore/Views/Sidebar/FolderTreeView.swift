import SwiftUI

struct FolderTreeView: View {
    let folder: Folder
    @ObservedObject var model: AppViewModel
    let prompts: [Prompt]
    let level: Int
    var showCounts: Bool = true
    var indentationMode: String = "compact"
    @AppStorage(AppSettingsKeys.librarySidebarRememberExpanded) private var rememberExpanded = true
    @AppStorage(AppSettingsKeys.librarySidebarAutoExpand) private var autoExpand = false
    @State private var expanded = true
    private var indentWidth: CGFloat { indentationMode == "standard" ? 18 : 10 }

    private var children: [Folder] { model.folders.filter { $0.parentFolderID == folder.id }.sorted { $0.sortOrder < $1.sortOrder } }
    private var count: Int { let ids = LibraryFilterService.folderScopeIDs(for: .folder(folder.id), folders: model.folders); return prompts.filter { $0.folderID.map(ids.contains) == true }.count }
    private var active: Bool { model.selection == .folder(folder.id) }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                if children.isEmpty {
                    Image(systemName: children.isEmpty ? "chevron.right" : (expanded ? "chevron.down" : "chevron.right"))
                        .font(.system(size: 12)).foregroundStyle(DT.ColorToken.textTertiary).opacity(children.isEmpty ? 0 : 1)
                        .frame(width: 14)
                } else {
                    Button(action: { expanded.toggle(); persistExpanded() }) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12)).foregroundStyle(DT.ColorToken.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 14)
                    .accessibilityLabel(expanded ? "Collapse \(folder.name)" : "Expand \(folder.name)")
                }
                FolderEditableRow(
                    folder: folder,
                    active: active,
                    count: count,
                    showCount: showCounts,
                    height: level == 0 ? 30 : 28,
                    renameRequested: model.folderRenameRequestID == folder.id,
                    select: activateFolder,
                    rename: { model.renameFolder(folder.id, to: $0) }
                )
            }
            .padding(.leading, CGFloat(level) * indentWidth)
            .background(Color.clear, in: RoundedRectangle(cornerRadius: DT.Radius.md))
            .contextMenu {
                Button("New Prompt in Folder") { model.selection = .folder(folder.id); model.createPrompt() }
                Button("New Subfolder") { model.createFolder(parentFolderID: folder.id) }
                Button("Rename Folder") { model.requestFolderRename(folder.id) }
                Divider()
                Button("Delete Folder", role: .destructive) { model.deleteFolder(folder.id) }
            }
            if expanded { ForEach(children) { FolderTreeView(folder: $0, model: model, prompts: prompts, level: level + 1, showCounts: showCounts, indentationMode: indentationMode) } }
        }
        .onAppear {
            if rememberExpanded { expanded = UserDefaults.standard.object(forKey: expandedKey) as? Bool ?? true }
            autoExpandIfNeeded()
        }
        .onChange(of: model.selection) { _, _ in autoExpandIfNeeded() }
    }

    private var expandedKey: String { "folder.expanded.\(folder.id.uuidString)" }
    private func persistExpanded() { if rememberExpanded { UserDefaults.standard.set(expanded, forKey: expandedKey) } }
    private func activateFolder() {
        if !children.isEmpty && !expanded {
            expanded = true
            persistExpanded()
        }
        model.selection = .folder(folder.id)
    }

    private func autoExpandIfNeeded() {
        guard autoExpand, !children.isEmpty else { return }
        if containsSelectedFolder(in: folder) {
            expanded = true
            persistExpanded()
        }
    }

    private func containsSelectedFolder(in parent: Folder) -> Bool {
        guard case let .folder(selectedID) = model.selection else { return false }
        if selectedID == parent.id { return true }
        var current = model.folders.first { $0.id == selectedID }
        while let folder = current {
            if folder.parentFolderID == parent.id { return true }
            current = folder.parentFolderID.flatMap { parentID in model.folders.first { $0.id == parentID } }
        }
        return false
    }
}

struct FolderEditableRow: View {
    let folder: Folder
    let active: Bool
    let count: Int
    var showCount: Bool = true
    let height: CGFloat
    let renameRequested: Bool
    let select: () -> Void
    let rename: (String) -> Void
    @State private var draftName: String = ""
    @State private var hovering = false
    @State private var renaming = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder").font(.system(size: 14.5)).frame(width: 18)
            if renaming {
                TextField("Folder", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .focusEffectDisabled()
                    .focused($focused)
                    .onSubmit(commitRename)
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused && renaming { commitRename() }
                    }
            } else {
                Text(folder.name)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if showCount { Text("\(count)").font(DT.FontToken.caption).frame(width: 30, alignment: .trailing) }
            Color.clear.frame(width: 16)
        }
        .foregroundStyle(active ? DT.ColorToken.textPrimary : DT.ColorToken.textSecondary)
        .padding(.horizontal, 4)
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(active ? DT.ColorToken.surfaceTertiary : (hovering ? DT.ColorToken.surfaceHover : Color.clear), in: RoundedRectangle(cornerRadius: DT.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).strokeBorder(active ? DT.ColorToken.borderStrong : Color.clear, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { if !renaming { select() } }
        .onHover { hovering = $0 }
        .onAppear {
            draftName = folder.name
            if renameRequested { beginRename() }
        }
        .onChange(of: folder.name) { _, newValue in draftName = newValue }
        .onChange(of: renameRequested) { _, requested in
            if requested { beginRename() }
        }
    }

    private func beginRename() {
        draftName = folder.name
        renaming = true
        DispatchQueue.main.async { focused = true }
    }

    private func commitRename() {
        let clean = draftName.trimmedNonEmpty(defaultValue: folder.name)
        if clean != folder.name { rename(clean) }
        draftName = clean
        renaming = false
        focused = false
    }
}
