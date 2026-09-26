import SwiftUI

struct PromptListView: View {
    let prompts: [Prompt]
    let selectedPromptID: UUID?
    @Binding var filters: MetadataFilterState
    let section: LibrarySection
    let categories: [String]
    let subcategories: [String]
    var displaySettings: PromptListDisplaySettings = .defaultValue
    var showFilterChips: Bool = true
    let onSelect: (Prompt) -> Void
    let onCopy: (Prompt) -> Void
    let onDuplicate: (Prompt) -> Void
    let onArchive: (Prompt) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if showFilterChips {
                MetadataFilterBar(filters: $filters, section: section, categories: categories, subcategories: subcategories)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: 48, alignment: .center)
                Divider().overlay(DT.ColorToken.borderDefault)
            }
            if prompts.isEmpty {
                ContentUnavailableView(section == .phrases ? "No matching phrases" : "No matching prompts", systemImage: section == .phrases ? "text.quote" : "magnifyingglass", description: Text("Try a different search term or clear the filters."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView { LazyVStack(spacing: 0) { ForEach(prompts) { prompt in PromptListRowView(prompt: prompt, selected: selectedPromptID == prompt.id, displaySettings: displaySettings) { onSelect(prompt) }.contextMenu { Button("Open") { onSelect(prompt) }; Button(prompt.type == .phrase ? "Copy Phrase" : "Copy Prompt") { onCopy(prompt) }; Button("Duplicate") { onDuplicate(prompt) }; Divider(); Button("Delete", role: .destructive) { onArchive(prompt) } }; Divider().overlay(DT.ColorToken.borderSubtle) } } }
            }
        }
        .background(DT.ColorToken.surfacePrimary)
    }
}

struct MetadataFilterBar: View {
    @Binding var filters: MetadataFilterState
    let section: LibrarySection
    let categories: [String]
    let subcategories: [String]
    var displaySettings: PromptListDisplaySettings = .defaultValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                FilterChip(title: "Type", value: filters.type?.displayName ?? "All", active: filters.type != nil, onClear: { filters.type = nil }) {
                    Button("All") { filters.type = nil }
                    Divider()
                    ForEach(typeOptions) { type in Button(type.displayName) { filters.type = type } }
                }
                .frame(maxWidth: .infinity)
                FilterChip(title: "Category", value: filters.category?.humanizedTitle ?? "All", active: filters.category != nil, onClear: { filters.category = nil; filters.subcategory = nil }) {
                    Button("All") { filters.category = nil; filters.subcategory = nil }
                    Divider()
                    ForEach(categories, id: \.self) { category in Button(category.humanizedTitle) { filters.category = category; filters.subcategory = nil } }
                }
                .frame(maxWidth: .infinity)
                FilterChip(title: "Subcategory", value: filters.subcategory?.humanizedTitle ?? "All", active: filters.subcategory != nil, onClear: { filters.subcategory = nil }) {
                    Button("All") { filters.subcategory = nil }
                    Divider()
                    ForEach(subcategories, id: \.self) { subcategory in Button(subcategory.humanizedTitle) { filters.subcategory = subcategory } }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var typeOptions: [PromptTypeFilter] { PromptTypeFilter.allCases }
}

struct FilterChip<Content: View>: View {
    let title: String
    let value: String
    let active: Bool
    let onClear: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.appAccentStyle) private var accent

    var body: some View {
        HStack(spacing: 0) {
            Menu { content } label: {
                HStack(spacing: 6) {
                    Text(displayText)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DT.ColorToken.textTertiary)
                }
                .font(DT.FontToken.captionStrong)
                .foregroundStyle(DT.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityLabel("\(title): \(value)")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            if active {
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 22, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DT.ColorToken.textTertiary)
                .accessibilityLabel("Clear \(title) filter")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var displayText: String { value == "All" ? title : value }
}

struct PromptListRowView: View {
    let prompt: Prompt
    let selected: Bool
    var displaySettings: PromptListDisplaySettings = .defaultValue
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.appAccentStyle) private var accent
    @Environment(\.appFontScale) private var scale
    @AppStorage(AppSettingsKeys.headingFontWeight) private var headingFontWeight = "semibold"
    @AppStorage(AppSettingsKeys.paragraphFontWeight) private var paragraphFontWeight = "regular"
    @AppStorage(AppSettingsKeys.labelFontWeight) private var labelFontWeight = "regular"
    @AppStorage(AppSettingsKeys.headingFontSize) private var headingFontSize = "13"
    @AppStorage(AppSettingsKeys.paragraphFontSize) private var paragraphFontSize = "13"
    @AppStorage(AppSettingsKeys.labelFontSize) private var labelFontSize = "12"

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: displaySettings.showIcons ? 12 : 8) {
                if displaySettings.showIcons {
                    PromptIconTile(prompt: prompt)
                }
                VStack(alignment: .leading, spacing: displaySettings.showDescription || displaySettings.showMetadata ? 6 : 0) {
                    Text(prompt.displayTitle)
                        .font(.system(size: CGFloat(Double(headingFontSize) ?? 13) * scale.scale, weight: headingFontWeight.appTextWeight))
                        .foregroundStyle(prompt.title.isEmpty ? DT.ColorToken.textMuted : DT.ColorToken.textPrimary)
                        .lineLimit(displaySettings.truncateLongTitles ? 1 : 2)
                        .truncationMode(.tail)
                    if displaySettings.showDescription {
                        Text(prompt.previewSnippet)
                            .font(.system(size: CGFloat(Double(paragraphFontSize) ?? 13) * scale.scale, weight: paragraphFontWeight.appTextWeight))
                            .foregroundStyle(DT.ColorToken.textSecondary)
                            .lineLimit(displaySettings.previewLineCount)
                            .truncationMode(.tail)
                    }
                    if displaySettings.showMetadata {
                        HStack(spacing: 6) {
                            Text(StableRelativeDateFormatter.string(from: prompt.updatedAt))
                            if prompt.primaryCategory != "uncategorized" { Text("•"); Text(prompt.primaryCategory.humanizedTitle) }
                            if prompt.hasVariables { Text("•"); Text("\(prompt.variableCount) vars") }
                        }
                        .font(.system(size: CGFloat(Double(labelFontSize) ?? 12) * scale.scale, weight: labelFontWeight.appTextWeight))
                        .foregroundStyle(DT.ColorToken.textTertiary)
                    }
                }
                Spacer(minLength: 6)
                Image(systemName: prompt.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 17 * scale.scale)).foregroundStyle(prompt.isFavorite ? DT.ColorToken.warningYellow : DT.ColorToken.textMuted)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(height: dynamicRowHeight)
            .background(selected ? accent.softColor : (hovering ? DT.ColorToken.surfaceHover : DT.ColorToken.surfacePrimary))
            .overlay(alignment: .leading) { Rectangle().fill(selected ? accent.color : Color.clear).frame(width: 3) }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var verticalPadding: CGFloat {
        switch displaySettings.rowDensity {
        case .compact: return displaySettings.showDescription || displaySettings.showMetadata ? 10 : 7
        case .comfortable: return displaySettings.showDescription || displaySettings.showMetadata ? 14 : 10
        case .spacious: return displaySettings.showDescription || displaySettings.showMetadata ? 18 : 13
        }
    }

    private var horizontalPadding: CGFloat {
        displaySettings.showIcons ? (displaySettings.rowDensity == .compact ? 12 : 16) : 12
    }

    private var dynamicRowHeight: CGFloat {
        let titleLines: CGFloat = displaySettings.truncateLongTitles ? 1 : 2
        let titleHeight = titleLines * 17 * scale.scale
        let descriptionHeight = displaySettings.showDescription ? CGFloat(displaySettings.previewLineCount) * 16 * scale.scale : 0
        let metadataHeight = displaySettings.showMetadata ? 15 * scale.scale : 0
        let descriptionSpacing: CGFloat = displaySettings.showDescription ? 6 : 0
        let metadataSpacing: CGFloat = displaySettings.showMetadata ? 6 : 0
        let contentHeight = titleHeight + descriptionSpacing + descriptionHeight + metadataSpacing + metadataHeight
        let iconHeight: CGFloat = displaySettings.showIcons ? 32 : 0
        let densityBreathingRoom: CGFloat = switch displaySettings.rowDensity {
        case .compact: 0
        case .comfortable: displaySettings.showDescription || displaySettings.showMetadata ? 2 : 0
        case .spacious: displaySettings.showDescription || displaySettings.showMetadata ? 8 : 4
        }
        return max(42, max(iconHeight, contentHeight) + (verticalPadding * 2) + densityBreathingRoom)
    }
}

enum StableRelativeDateFormatter {
    static func string(from date: Date, now: Date = .now) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "Just now" }
        if seconds < 3_600 { return "\(seconds / 60) min ago" }
        if seconds < 86_400 { return "\(seconds / 3_600) hr ago" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        if seconds < 7 * 86_400 { return "\(seconds / 86_400)d ago" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct PromptIconTile: View {
    let prompt: Prompt
    var body: some View {
        RoundedRectangle(cornerRadius: DT.Radius.md)
            .fill(colors.background)
            .frame(width: 32, height: 32)
            .overlay(Image(systemName: icon).font(.system(size: 18, weight: .regular)).foregroundStyle(colors.foreground))
    }
    private var lower: String { prompt.title.lowercased() }
    private var icon: String { prompt.type == .phrase ? "text.quote" : lower.contains("react") ? "chevron.left.forwardslash.chevron.right" : lower.contains("email") ? "envelope" : lower.contains("workflow") ? "point.3.connected.trianglepath.dotted" : lower.contains("blog") ? "doc.text" : lower.contains("ad") ? "megaphone" : lower.contains("competitor") ? "chart.bar" : lower.contains("product") ? "bag" : "doc.text.magnifyingglass" }
    private var colors: (background: Color, foreground: Color) {
        if prompt.type == .phrase { return (DT.ColorToken.purpleSoft, DT.ColorToken.purpleAccent) }
        if lower.contains("seo") || lower.contains("email") { return (DT.ColorToken.successGreenSoft, DT.ColorToken.successGreen) }
        if lower.contains("product") || lower.contains("blog") { return (DT.ColorToken.purpleSoft, DT.ColorToken.purpleAccent) }
        if lower.contains("react") || lower.contains("competitor") { return (DT.ColorToken.accentBlueSoft, DT.ColorToken.accentBlue) }
        if lower.contains("workflow") { return (DT.ColorToken.orangeSoft, DT.ColorToken.orangeAccent) }
        if lower.contains("ad") { return (DT.ColorToken.dangerRedSoft, DT.ColorToken.dangerRed) }
        return (DT.ColorToken.accentBlueSoft, DT.ColorToken.accentBlue)
    }
}
