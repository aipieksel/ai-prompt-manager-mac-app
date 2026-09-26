import Foundation

public struct ParsedPromptFile: Equatable, Sendable {
    public var metadata: [String: MetadataValue]
    public var body: String
    public var title: String?
}

public enum MetadataValue: Equatable, Sendable {
    case string(String)
    case list([String])

    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }
    public var listValue: [String]? {
        if case let .list(values) = self { return values }
        return nil
    }
}

public enum PromptMarkdownParser {
    public static func parse(_ markdown: String) -> ParsedPromptFile {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let parts = splitFrontMatter(normalized)
        let metadata = parseMetadata(parts.frontMatter ?? "")
        let title = metadata["title"]?.stringValue ?? firstHeading(in: parts.body)
        return ParsedPromptFile(metadata: metadata, body: parts.body.trimmingCharacters(in: .whitespacesAndNewlines), title: title)
    }

    public static func canonicalMarkdown(for prompt: Prompt) -> String {
        var lines: [String] = ["---"]
        lines.append("id: \(prompt.sourceFilePath.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent.slugKey } ?? prompt.title.slugKey)")
        lines.append("title: \(prompt.title)")
        lines.append("type: \(prompt.type.rawValue)")
        if let sourceType = prompt.sourceType { lines.append("source_type: \(sourceType)") }
        lines.append("primary_category: \(prompt.primaryCategory)")
        lines.append("categories:")
        for category in prompt.categories { lines.append("  - \(category)") }
        lines.append("subcategory: \(prompt.subcategory)")
        if !prompt.whenToUse.isEmpty { lines.append("when_to_use: \(prompt.whenToUse)") }
        lines.append("search_terms:")
        for term in prompt.searchTerms { lines.append("  - \(term)") }
        if !prompt.variables.isEmpty {
            lines.append("variables:")
            for variable in prompt.variables.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                lines.append("  - key: \(variable.key)")
                lines.append("    label: \(variable.label)")
                lines.append("    type: \(variable.type.rawValue)")
                lines.append("    required: \(variable.required)")
                if !variable.description.isEmpty { lines.append("    description: \(variable.description)") }
            }
        }
        lines.append("---")
        lines.append("")
        if !prompt.content.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#") {
            lines.append("# \(prompt.title)")
            lines.append("")
        }
        lines.append(prompt.content)
        return lines.joined(separator: "\n")
    }

    private static func splitFrontMatter(_ markdown: String) -> (frontMatter: String?, body: String) {
        guard markdown.hasPrefix("---\n") else { return (nil, markdown) }
        let remainderStart = markdown.index(markdown.startIndex, offsetBy: 4)
        guard let endRange = markdown[remainderStart...].range(of: "\n---") else { return (nil, markdown) }
        let front = String(markdown[remainderStart..<endRange.lowerBound])
        var bodyStart = endRange.upperBound
        if bodyStart < markdown.endIndex, markdown[bodyStart] == "\n" { bodyStart = markdown.index(after: bodyStart) }
        return (front, String(markdown[bodyStart...]))
    }

    private static func parseMetadata(_ frontMatter: String) -> [String: MetadataValue] {
        var result: [String: MetadataValue] = [:]
        let lines = frontMatter.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty, !line.trimmingCharacters(in: .whitespaces).hasPrefix("#"), let colon = line.firstIndex(of: ":") else { index += 1; continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if rawValue.isEmpty {
                var values: [String] = []
                index += 1
                while index < lines.count {
                    let child = lines[index]
                    if !child.hasPrefix(" ") && child.contains(":") { break }
                    let trimmed = child.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("-") {
                        values.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces).trimmedQuotes)
                    }
                    index += 1
                }
                result[key] = .list(values)
                continue
            } else if rawValue == ">-" || rawValue == "|" {
                var collected: [String] = []
                index += 1
                while index < lines.count, lines[index].hasPrefix(" ") {
                    collected.append(lines[index].trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                result[key] = .string(collected.joined(separator: " ").trimmedQuotes)
                continue
            } else {
                result[key] = .string(rawValue.trimmedQuotes)
            }
            index += 1
        }
        return result
    }

    private static func firstHeading(in body: String) -> String? {
        body.split(separator: "\n").first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("# ") }
            .map { String($0).replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

private extension String {
    var trimmedQuotes: String {
        trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
}
