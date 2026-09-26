import Foundation

public enum PromptExportScope: String, CaseIterable, Identifiable, Sendable {
    case selected = "Selected Entry"
    case currentFolder = "Current Folder"
    case currentCategory = "Current Category"
    case all = "All Entries"
    case backup = "Library Backup"
    public var id: String { rawValue }
}

public enum PromptExportService {
    public static func markdownDocument(for prompt: Prompt) -> String {
        PromptMarkdownParser.canonicalMarkdown(for: prompt)
    }

    public static func markdownCollection(for prompts: [Prompt]) -> String {
        prompts.map(markdownDocument).joined(separator: "\n\n---\n\n")
    }

    public static func backupData(library: PromptLibrary) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(library)
    }

    public static func auditReport(for prompts: [Prompt]) -> String {
        var lines = ["# Prompt Metadata Audit", "", "Generated: \(Date().formatted(date: .abbreviated, time: .shortened))", "", "| Title | Type | Category | Subcategory | Variables | Status |", "| --- | --- | --- | --- | ---: | --- |"]
        for prompt in prompts.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }) {
            let missing = missingFields(for: prompt)
            lines.append("| \(prompt.title.replacingOccurrences(of: "|", with: "/")) | \(prompt.type.rawValue) | \(prompt.primaryCategory) | \(prompt.subcategory) | \(prompt.variableCount) | \(missing.isEmpty ? "Complete" : "Needs Review: \(missing.joined(separator: ", "))") |")
        }
        return lines.joined(separator: "\n")
    }

    public static func missingFields(for prompt: Prompt) -> [String] {
        var missing: [String] = []
        if prompt.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("title") }
        if prompt.primaryCategory == "uncategorized" || prompt.primaryCategory.isEmpty { missing.append("primary_category") }
        if prompt.categories.isEmpty { missing.append("categories") }
        if prompt.subcategory == "general" || prompt.subcategory.isEmpty { missing.append("subcategory") }
        if prompt.whenToUse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("when_to_use") }
        if prompt.searchTerms.isEmpty { missing.append("search_terms") }
        return missing
    }
}
