import Foundation

public struct ImportPreviewRow: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var sourceURL: URL
    public var prompt: Prompt?
    public var status: ImportAuditStatus
    public var messages: [String]
    public var willImport: Bool

    public init(id: UUID = UUID(), sourceURL: URL, prompt: Prompt?, status: ImportAuditStatus, messages: [String], willImport: Bool = true) {
        self.id = id
        self.sourceURL = sourceURL
        self.prompt = prompt
        self.status = status
        self.messages = messages
        self.willImport = willImport
    }
}

public struct ImportPreview: Equatable, Sendable {
    public var sourceURL: URL
    public var rows: [ImportPreviewRow]
    public var scannedAt: Date

    public init(sourceURL: URL, rows: [ImportPreviewRow], scannedAt: Date = .now) {
        self.sourceURL = sourceURL
        self.rows = rows
        self.scannedAt = scannedAt
    }

    public var importableRows: [ImportPreviewRow] { rows.filter { $0.willImport && $0.prompt != nil && $0.status != .error && $0.status != .duplicate } }
    public var promptCount: Int { importableRows.compactMap(\.prompt).filter { $0.type == .prompt }.count }
    public var phraseCount: Int { importableRows.compactMap(\.prompt).filter { $0.type == .phrase }.count }
    public var errorCount: Int { rows.filter { $0.status == .error }.count }
    public var duplicateCount: Int { rows.filter { $0.status == .duplicate }.count }
}

public enum PromptFolderImportService {
    private static let skippedCatalogFiles: Set<String> = ["README.md", "index.md", "dashboard-manifest.md", "subcategory-index.md", "guidance.md", "complete-prompt-collection.md"]

    public static func scanFolder(at url: URL, existingPrompts: [Prompt] = [], duplicateBehavior: String = "skip", preserveSourcePath: Bool = true, defaultVariableType: VariableInputType = .textarea, autoDetectVariables: Bool = true) -> ImportPreview {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return ImportPreview(sourceURL: url, rows: [ImportPreviewRow(sourceURL: url, prompt: nil, status: .error, messages: ["Folder could not be opened."], willImport: false)])
        }
        let existingHashes = Set(existingPrompts.compactMap(\.contentHash))
        let existingPaths = Set(existingPrompts.compactMap(\.sourceFilePath))
        let existingSlugs = Set(existingPrompts.map { $0.title.slugKey })
        var seenSlugs: Set<String> = []
        var seenHashes: Set<String> = []
        var rows: [ImportPreviewRow] = []

        for case let fileURL as URL in enumerator {
            guard ["md", "markdown", "txt"].contains(fileURL.pathExtension.lowercased()) else { continue }
            guard !skippedCatalogFiles.contains(fileURL.lastPathComponent) else { continue }
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                let markdown = try String(contentsOf: fileURL, encoding: .utf8)
                var messages: [String] = []
                var prompt = promptFromFile(url: fileURL, rootURL: url, markdown: markdown, messages: &messages, defaultVariableType: defaultVariableType, autoDetectVariables: autoDetectVariables)
                let hash = deterministicHash(markdown)
                prompt.contentHash = hash
                prompt.sourceFilePath = preserveSourcePath ? fileURL.path : nil
                let isDuplicate = existingHashes.contains(hash) || seenHashes.contains(hash) || existingPaths.contains(fileURL.path) || existingSlugs.contains(prompt.title.slugKey) || seenSlugs.contains(prompt.title.slugKey)
                if isDuplicate && duplicateBehavior == "skip" {
                    rows.append(ImportPreviewRow(sourceURL: fileURL, prompt: prompt, status: .duplicate, messages: messages + ["Duplicate detected by hash, path, or normalized title."], willImport: false))
                } else {
                    if isDuplicate && duplicateBehavior == "copy" { prompt.title = "\(prompt.title) Copy" }
                    if isDuplicate && duplicateBehavior == "update" { messages.append("Duplicate will update matching prompt on import.") }
                    let status: ImportAuditStatus = messages.isEmpty ? .complete : .fixed
                    rows.append(ImportPreviewRow(sourceURL: fileURL, prompt: prompt, status: status, messages: messages, willImport: true))
                    seenHashes.insert(hash)
                    seenSlugs.insert(prompt.title.slugKey)
                }
            } catch {
                rows.append(ImportPreviewRow(sourceURL: fileURL, prompt: nil, status: .error, messages: [error.localizedDescription], willImport: false))
            }
        }

        return ImportPreview(sourceURL: url, rows: rows.sorted { $0.sourceURL.path.localizedCaseInsensitiveCompare($1.sourceURL.path) == .orderedAscending })
    }

    public static func importRows(from preview: ImportPreview, into prompts: inout [Prompt], importedAt: Date = .now) -> ImportBatch {
        var ignoredFolders: [Folder] = []
        return importRows(from: preview, into: &prompts, folders: &ignoredFolders, importedAt: importedAt)
    }

    public static func importRows(from preview: ImportPreview, into prompts: inout [Prompt], folders: inout [Folder], importedAt: Date = .now, folderBehavior: String = "preserve", duplicateBehavior: String = "skip") -> ImportBatch {
        let batchID = UUID()
        var imported: [Prompt] = []
        for row in preview.importableRows {
            guard var prompt = row.prompt else { continue }
            prompt.importBatchId = batchID
            prompt.lastImportedAt = importedAt
            prompt.createdAt = importedAt
            prompt.updatedAt = importedAt
            prompt.folderID = folderBehavior == "flatten" ? nil : folderIDForImportedPrompt(prompt, sourceRootURL: preview.sourceURL, folders: &folders, createdAt: importedAt)
            if duplicateBehavior == "update", let existingIndex = prompts.firstIndex(where: { $0.contentHash == prompt.contentHash || $0.sourceFilePath == prompt.sourceFilePath || $0.title.slugKey == prompt.title.slugKey }) {
                prompts[existingIndex] = prompt
            } else {
                imported.append(prompt)
            }
        }
        prompts.insert(contentsOf: imported, at: 0)
        let report = reportMarkdown(for: preview, importedCount: imported.count)
        return ImportBatch(id: batchID, sourcePath: preview.sourceURL.path, importedCount: imported.count, skippedCount: preview.rows.count - imported.count, phraseCount: imported.filter { $0.type == .phrase }.count, promptCount: imported.filter { $0.type == .prompt }.count, createdAt: importedAt, report: report)
    }

    public static func reportMarkdown(for preview: ImportPreview, importedCount: Int? = nil) -> String {
        var lines = ["# Prompt Import Report", "", "Source: `\(preview.sourceURL.path)`", "Scanned: \(preview.scannedAt.formatted(date: .abbreviated, time: .shortened))", "", "| File | Type | Category | Status | Notes |", "| --- | --- | --- | --- | --- |"]
        for row in preview.rows {
            let prompt = row.prompt
            lines.append("| \(row.sourceURL.lastPathComponent) | \(prompt?.type.rawValue ?? "-") | \(prompt?.primaryCategory ?? "-") | \(row.status.rawValue) | \(row.messages.joined(separator: "; ").replacingOccurrences(of: "|", with: "/")) |")
        }
        if let importedCount { lines.insert(contentsOf: ["Imported: \(importedCount)", ""], at: 4) }
        return lines.joined(separator: "\n")
    }

    private static func promptFromFile(url: URL, rootURL: URL, markdown: String, messages: inout [String], defaultVariableType: VariableInputType = .textarea, autoDetectVariables: Bool = true) -> Prompt {
        let parsed = PromptMarkdownParser.parse(markdown)
        let relativeParts = relativePathParts(fileURL: url, rootURL: rootURL)
        let topCategory = relativeParts.first?.slugKey ?? "uncategorized"
        let subcategory = relativeParts.dropFirst().dropLast().last?.slugKey ?? "general"
        let metadata = parsed.metadata
        let sourceType = metadata["type"]?.stringValue?.slugKey
        let explicitPrompt = sourceType == "prompt"
        let appType: PromptEntryType = {
            if sourceType == "cheat-sheet" || sourceType == "phrase" { return .phrase }
            if explicitPrompt { return .prompt }
            let hint = (url.lastPathComponent + " " + (metadata["title"]?.stringValue ?? "")).lowercased()
            if hint.contains("cheat") || hint.contains("wording") || hint.contains("phrase") { return .phrase }
            return PromptEntryType(rawValue: sourceType ?? "") ?? .prompt
        }()
        if sourceType == nil { messages.append("Missing type; inferred \(appType.rawValue).") }
        let title = metadata["title"]?.stringValue ?? parsed.title ?? cleanedTitle(from: url)
        if metadata["title"]?.stringValue == nil { messages.append("Missing title; inferred from heading or file name.") }
        let primary = metadata["primary_category"]?.stringValue ?? metadata["primaryCategory"]?.stringValue ?? topCategory
        if metadata["primary_category"]?.stringValue == nil && metadata["primaryCategory"]?.stringValue == nil { messages.append("Missing primary_category; inferred from top-level folder \(topCategory).") }
        let categories = metadata["categories"]?.listValue ?? [primary]
        let sub = metadata["subcategory"]?.stringValue ?? subcategory
        if metadata["subcategory"]?.stringValue == nil { messages.append("Missing subcategory; inferred \(sub).") }
        let whenToUse = metadata["when_to_use"]?.stringValue ?? metadata["whenToUse"]?.stringValue ?? inferWhenToUse(title: title, type: appType)
        if metadata["when_to_use"]?.stringValue == nil && metadata["whenToUse"]?.stringValue == nil { messages.append("Missing when_to_use; inferred from title.") }
        let searchTerms = metadata["search_terms"]?.listValue ?? inferredSearchTerms(title: title, primary: primary, subcategory: sub)
        let normalizedContent = VariableDetector.normalizedContent(parsed.body)
        let variables: [VariableDefinition] = autoDetectVariables ? VariableDetector.definitions(in: normalizedContent).map { variable in var copy = variable; copy.type = defaultVariableType; return copy } : []
        return Prompt(title: title, content: normalizedContent, type: appType, sourceType: sourceType, primaryCategory: primary, categories: categories, subcategory: sub, whenToUse: whenToUse, searchTerms: searchTerms, variables: variables, sourceFilePath: url.path)
    }

    private static func relativePathParts(fileURL: URL, rootURL: URL) -> [String] {
        let root = rootURL.standardizedFileURL.pathComponents
        let file = fileURL.standardizedFileURL.pathComponents
        return Array(file.dropFirst(root.count))
    }

    private static func folderIDForImportedPrompt(_ prompt: Prompt, sourceRootURL: URL, folders: inout [Folder], createdAt: Date) -> UUID? {
        guard let path = prompt.sourceFilePath else { return nil }
        let parts = relativePathParts(fileURL: URL(fileURLWithPath: path), rootURL: sourceRootURL).dropLast()
        guard !parts.isEmpty else { return nil }
        var parentID: UUID?
        var lastID: UUID?
        for (offset, part) in parts.enumerated() {
            let name = displayFolderName(for: part)
            if let existing = folders.first(where: { $0.parentFolderID == parentID && $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                parentID = existing.id
                lastID = existing.id
            } else {
                let nextSort = folders.filter { $0.parentFolderID == parentID }.count + offset + 1
                let folder = Folder(name: name, parentFolderID: parentID, createdAt: createdAt, updatedAt: createdAt, sortOrder: nextSort)
                folders.append(folder)
                parentID = folder.id
                lastID = folder.id
            }
        }
        return lastID
    }

    private static func displayFolderName(for pathPart: String) -> String {
        pathPart.replacingOccurrences(of: "-", with: " ").humanizedTitle
    }

    private static func cleanedTitle(from url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: ".prompt", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .humanizedTitle
    }

    private static func inferWhenToUse(title: String, type: PromptEntryType) -> String {
        type == .phrase ? "Use as reusable wording when speaking to an agent." : "Use when you need \(title.lowercased())."
    }

    private static func inferredSearchTerms(title: String, primary: String, subcategory: String) -> [String] {
        Array(Set((title.slugKey.split(separator: "-").map(String.init) + [primary.slugKey, subcategory.slugKey]).filter { !$0.isEmpty })).sorted()
    }

    public static func deterministicHash(_ value: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }
}
