import Foundation

public enum VariableDetector {
    public static func definitions(in content: String) -> [VariableDefinition] {
        guard content.contains("{") && content.contains("}") else { return [] }
        var orderedKeys: [String] = []
        for pattern in [#"\{\{\s*([^{}]+?)\s*\}\}"#, #"\{\s*([A-Za-z][A-Za-z0-9_\- ]{1,60})\s*\}"#] {
            for raw in matches(pattern: pattern, in: content) {
                let key = raw.variableKey
                guard key.count >= 2, !orderedKeys.contains(key), !looksLikeMarkdownLink(raw) else { continue }
                orderedKeys.append(key)
            }
        }
        return orderedKeys.enumerated().map { index, key in
            VariableDefinition(key: key, type: .textarea, required: true, description: "Provide \(key.humanizedTitle.lowercased()).", sortOrder: index)
        }
    }

    public static func normalizedContent(_ content: String) -> String {
        guard content.contains("{{") && content.contains("}}") else { return content }
        var output = content
        for pattern in [#"\{\{\s*([^{}]+?)\s*\}\}"#] {
            let regex = try? NSRegularExpression(pattern: pattern)
            let ns = output as NSString
            let matches = regex?.matches(in: output, range: NSRange(location: 0, length: ns.length)).reversed() ?? []
            for match in matches where match.numberOfRanges > 1 {
                let raw = ns.substring(with: match.range(at: 1))
                let key = raw.variableKey
                output = (output as NSString).replacingCharacters(in: match.range(at: 0), with: "{\(key)}")
            }
        }
        return output
    }

    public static func filledPrompt(content: String, values: [String: String]) -> String {
        var output = normalizedContent(content)
        for (key, value) in values {
            output = output.replacingOccurrences(of: "{\(key.variableKey)}", with: value)
        }
        return output
    }

    public static func missingRequiredVariables(definitions: [VariableDefinition], values: [String: String]) -> [VariableDefinition] {
        definitions.filter { $0.required && (values[$0.key]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
    }

    private static func matches(pattern: String, in content: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = content as NSString
        return regex.matches(in: content, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func looksLikeMarkdownLink(_ raw: String) -> Bool { raw.contains("://") || raw.contains(".") }
}
