#if os(macOS)
import AppKit
#endif
import Foundation

public enum ClipboardService {
    public static func formattedPrompt(_ prompt: Prompt, settings: ClipboardBehaviorSettings, bodyOverride: String? = nil) -> String {
        var parts: [String] = []
        if settings.includeTitle { parts.append("# \(prompt.title)") }
        if settings.includeMetadata {
            parts.append("Category: \(prompt.primaryCategory.humanizedTitle)\nSubcategory: \(prompt.subcategory.humanizedTitle)\nWhen to use: \(prompt.whenToUse.trimmedNonEmpty(defaultValue: "Not specified"))")
        }
        let body = bodyOverride ?? prompt.content
        parts.append(settings.preserveMarkdown ? body : plainText(fromMarkdown: body))
        return parts.joined(separator: "\n\n")
    }

    public static func plainText(fromMarkdown markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"^#+\s*"#, with: "", options: [.regularExpression, .anchored])
    }

    public static func copy(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}
