import SwiftUI

struct ImportReviewSheet: View {
    let preview: ImportPreview
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import Review").font(.system(size: 20, weight: .semibold))
                    Text(preview.sourceURL.path).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary).lineLimit(1)
                }
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(SecondaryButtonStyle())
                Button("Import \(preview.importableRows.count)", action: onConfirm).buttonStyle(PrimaryButtonStyle()).disabled(preview.importableRows.isEmpty)
            }
            HStack(spacing: 12) {
                SummaryTile(title: "Prompts", value: "\(preview.promptCount)", color: DT.ColorToken.accentBlueSoft)
                SummaryTile(title: "Phrases", value: "\(preview.phraseCount)", color: DT.ColorToken.purpleSoft)
                SummaryTile(title: "Duplicates", value: "\(preview.duplicateCount)", color: DT.ColorToken.warningYellowSoft)
                SummaryTile(title: "Errors", value: "\(preview.errorCount)", color: DT.ColorToken.dangerRedSoft)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(preview.rows) { row in
                        ImportRowView(row: row)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(20)
        .frame(width: 760, height: 560)
        .background(DT.ColorToken.surfacePrimary)
    }
}

struct SummaryTile: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary)
            Text(value).font(.system(size: 20, weight: .semibold)).foregroundStyle(DT.ColorToken.textPrimary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: DT.Radius.lg))
    }
}

struct ImportRowView: View {
    let row: ImportPreviewRow
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StatusBadgeView(status: row.status)
            VStack(alignment: .leading, spacing: 5) {
                Text(row.prompt?.title ?? row.sourceURL.lastPathComponent).font(DT.FontToken.bodySmallStrong).foregroundStyle(DT.ColorToken.textPrimary)
                Text(row.sourceURL.lastPathComponent).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textTertiary)
                if !row.messages.isEmpty { Text(row.messages.joined(separator: " • ")).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary).lineLimit(2) }
            }
            Spacer()
            if let prompt = row.prompt {
                VStack(alignment: .trailing, spacing: 5) {
                    Text(prompt.type.displayName).font(DT.FontToken.captionStrong)
                    Text("\(prompt.primaryCategory) / \(prompt.subcategory)").font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary)
                }
            }
        }
        .padding(10)
        .background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.borderSubtle))
    }
}

struct StatusBadgeView: View {
    let status: ImportAuditStatus
    var body: some View {
        Text(status.rawValue)
            .font(DT.FontToken.captionStrong)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(colors.background, in: Capsule())
    }
    private var colors: (background: Color, text: Color) {
        switch status {
        case .complete: return (DT.ColorToken.successGreenSoft, DT.ColorToken.successGreen)
        case .fixed: return (DT.ColorToken.accentBlueSoft, DT.ColorToken.accentBlue)
        case .missing, .needsReview: return (DT.ColorToken.warningYellowSoft, DT.ColorToken.warningYellow)
        case .duplicate: return (DT.ColorToken.surfaceTertiary, DT.ColorToken.textSecondary)
        case .error: return (DT.ColorToken.dangerRedSoft, DT.ColorToken.dangerRed)
        }
    }
}

struct ExportSheet: View {
    let selectedTitle: String?
    let onExport: (PromptExportScope) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Export Library").font(.system(size: 20, weight: .semibold)); Spacer(); Button("Done", action: onCancel).buttonStyle(SecondaryButtonStyle()) }
            Text("Choose what to export. Markdown exports include normalized YAML metadata; backup exports JSON.").font(DT.FontToken.bodySmall).foregroundStyle(DT.ColorToken.textSecondary)
            VStack(spacing: 10) {
                ExportOptionButton(title: "Export Selected Entry", subtitle: selectedTitle ?? "No entry selected", icon: "doc", disabled: selectedTitle == nil) { onExport(.selected) }
                ExportOptionButton(title: "Export Current Folder", subtitle: "Exports visible entries in the selected folder scope.", icon: "folder") { onExport(.currentFolder) }
                ExportOptionButton(title: "Export Current Category", subtitle: "Exports entries matching the active category filter.", icon: "tag") { onExport(.currentCategory) }
                ExportOptionButton(title: "Export All Entries", subtitle: "Exports all prompts and phrases as normalized markdown.", icon: "tray.full") { onExport(.all) }
                ExportOptionButton(title: "Export Library Backup", subtitle: "Exports the full JSON library, including presets and import history.", icon: "externaldrive") { onExport(.backup) }
            }
        }
        .padding(20)
        .frame(width: 540)
        .background(DT.ColorToken.surfacePrimary)
    }
}

struct ExportOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 18)).frame(width: 24)
                VStack(alignment: .leading, spacing: 3) { Text(title).font(DT.FontToken.bodySmallStrong); Text(subtitle).font(DT.FontToken.caption).foregroundStyle(DT.ColorToken.textSecondary).lineLimit(1) }
                Spacer()
                Image(systemName: "square.and.arrow.down").foregroundStyle(DT.ColorToken.textTertiary)
            }
            .padding(12).background(DT.ColorToken.surfaceSecondary, in: RoundedRectangle(cornerRadius: DT.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DT.Radius.md).stroke(DT.ColorToken.borderDefault))
        }.buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.5 : 1)
    }
}

struct AuditReportSheet: View {
    let report: String
    let onCopy: () -> Void
    let onExport: () -> Void
    let onClose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Metadata Audit").font(.system(size: 20, weight: .semibold)); Spacer(); Button("Copy Report", action: onCopy).buttonStyle(SecondaryButtonStyle()); Button("Export", action: onExport).buttonStyle(SecondaryButtonStyle()); Button("Done", action: onClose).buttonStyle(PrimaryButtonStyle()) }
            ScrollView { Text(report).font(.system(.body, design: .monospaced)).foregroundStyle(DT.ColorToken.textPrimary).frame(maxWidth: .infinity, alignment: .leading).padding(12) }
                .fieldChrome(focused: false, radius: DT.Radius.lg)
        }
        .padding(20)
        .frame(width: 760, height: 560)
        .background(DT.ColorToken.surfacePrimary)
    }
}
