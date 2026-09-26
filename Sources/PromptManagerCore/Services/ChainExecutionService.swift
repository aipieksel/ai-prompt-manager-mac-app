import Foundation

public enum ChainExecutionError: Error, LocalizedError, Sendable {
    case missingPrompt(String)
    case missingRequiredVariable(String)
    case unavailablePreviousOutput(String)
    case unsupportedAttachment(String)
    case emptyPrompt(String)
    case emptyOutput(String)

    public var errorDescription: String? {
        switch self {
        case .missingPrompt(let title): "Missing prompt for step: \(title)"
        case .missingRequiredVariable(let key): "Required variable is empty: \(key)"
        case .unavailablePreviousOutput(let key): "Previous output is not available for: \(key)"
        case .unsupportedAttachment(let name): "Unsupported attachment type: \(name)"
        case .emptyPrompt(let title): "Step has no prompt content: \(title)"
        case .emptyOutput(let title): "Provider returned an empty output for step: \(title)"
        }
    }
}

public protocol ChainProviderClient: Sendable {
    func complete(prompt: String, provider: AIProviderKind, modelID: String) async throws -> String
}

public struct DeterministicChainProviderClient: ChainProviderClient {
    public init() {}
    public func complete(prompt: String, provider: AIProviderKind, modelID: String) async throws -> String {
        let compact = prompt.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        # Chain Output

        Provider: \(provider.displayName)  
        Model: \(modelID)

        ## Resolved Prompt Summary
        \(String(compact.prefix(360)))\(compact.count > 360 ? "…" : "")

        ## Result
        Deterministic local response generated for verification. Live OpenAI and DeepSeek clients are wired behind the provider seam for a later network-verified pass.
        """
    }
}

public struct ChainExecutionService: Sendable {
    public var client: ChainProviderClient
    public init(client: ChainProviderClient = LiveAIProviderClient()) { self.client = client }

    public func resolve(
        step: PromptChainStep,
        prompt: Prompt,
        previousOutputs: [UUID: String],
        currentStepSavedOutput: String? = nil,
        loopFeedbackUsesInitialFileOnly: Bool = false
    ) throws -> (String, [String: String], [ChainFileAttachment]) {
        var values: [String: String] = [:]
        var files: [ChainFileAttachment] = []
        for variable in prompt.variables.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let binding = step.variableBindings.first { $0.variableKey == variable.key } ?? ChainVariableBinding(variableKey: variable.key)
            let value: String
            switch binding.inputType {
            case .text:
                value = binding.textValue.trimmedNonEmpty(defaultValue: variable.defaultValue)
            case .file:
                guard let attachment = binding.fileAttachment else {
                    if variable.required { throw ChainExecutionError.missingRequiredVariable(variable.key) }
                    value = ""
                    break
                }
                let refreshed = try Self.refreshedAttachment(attachment)
                files.append(refreshed)
                value = refreshed.snapshotText
            case .folder:
                throw ChainExecutionError.missingRequiredVariable("\(variable.key) folder must be expanded into Markdown files before running")
            case .previousStepOutput:
                guard let sourceID = binding.sourceStepID, let rawOutput = previousOutputs[sourceID], !rawOutput.isEmpty else {
                    throw ChainExecutionError.unavailablePreviousOutput(variable.key)
                }
                value = Self.transformedPreviousOutput(rawOutput, tagName: binding.sourceOutputTag, transform: binding.sourceOutputTransform)
            case .loopFeedbackFile:
                guard let attachment = binding.fileAttachment else {
                    if variable.required { throw ChainExecutionError.missingRequiredVariable(variable.key) }
                    value = ""
                    break
                }
                let refreshed = try Self.refreshedAttachment(attachment)
                files.append(refreshed)
                if loopFeedbackUsesInitialFileOnly {
                    value = refreshed.snapshotText
                } else {
                    let savedOutput = currentStepSavedOutput?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? currentStepSavedOutput! : ""
                    let feedback: String
                    if let sourceID = binding.sourceStepID, let rawOutput = previousOutputs[sourceID], !rawOutput.isEmpty {
                        feedback = Self.transformedPreviousOutput(rawOutput, tagName: binding.sourceOutputTag, transform: binding.sourceOutputTransform)
                    } else {
                        feedback = ""
                    }
                    value = Self.loopFeedbackValue(originalInput: refreshed.snapshotText, currentSavedOutput: savedOutput, feedbackOutput: feedback)
                }
            }
            if variable.required && value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw ChainExecutionError.missingRequiredVariable(variable.key) }
            values[variable.key] = value
        }
        let resolved = VariableDetector.filledPrompt(content: prompt.content, values: values).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolved.isEmpty else { throw ChainExecutionError.emptyPrompt(prompt.displayTitle) }
        return (resolved, values, files)
    }

    public func run(
        step: PromptChainStep,
        prompt: Prompt,
        previousOutputs: [UUID: String],
        currentStepSavedOutput: String? = nil,
        loopFeedbackUsesInitialFileOnly: Bool = false
    ) async throws -> ChainStepRun {
        let (resolved, values, files) = try resolve(step: step, prompt: prompt, previousOutputs: previousOutputs, currentStepSavedOutput: currentStepSavedOutput, loopFeedbackUsesInitialFileOnly: loopFeedbackUsesInitialFileOnly)
        try Task.checkCancellation()
        let output = try await client.complete(prompt: resolved, provider: step.providerKind, modelID: step.modelID)
        try Task.checkCancellation()
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ChainExecutionError.emptyOutput(step.title) }
        return ChainStepRun(stepID: step.id, resolvedPrompt: resolved, providerKind: step.providerKind, modelID: step.modelID, inputSnapshot: values, fileSnapshots: files, outputText: output, status: .complete, startedAt: .now, finishedAt: .now)
    }

    private static func transformedPreviousOutput(_ rawOutput: String, tagName: String, transform: ChainOutputTransform) -> String {
        let output = ChainFinalMarkdownExtractor.downloadableMarkdown(from: rawOutput, tagName: tagName)
        switch transform {
        case .rawMarkdown: return output
        case .plainText: return output.replacingOccurrences(of: #"[#*_`>\-]+"#, with: "", options: .regularExpression)
        }
    }

    public static func markdownAttachments(in folder: ChainFolderAttachment) throws -> [ChainFileAttachment] {
        let folderURL = URL(fileURLWithPath: folder.originalPath, isDirectory: true)
        let urls = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            .filter { url in
                ["md", "markdown"].contains(url.pathExtension.lowercased())
            }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        return try urls.map { url in
            let data = try Data(contentsOf: url)
            return ChainFileAttachment(fileName: url.lastPathComponent, fileExtension: url.pathExtension.lowercased(), byteCount: data.count, originalPath: url.path, snapshotText: String(decoding: data, as: UTF8.self))
        }
    }

    public static func refreshedAttachment(_ attachment: ChainFileAttachment) throws -> ChainFileAttachment {
        guard attachment.isSupportedTextAttachment else { throw ChainExecutionError.unsupportedAttachment(attachment.fileName) }
        guard let path = attachment.originalPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            return attachment
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return attachment }
        let data = try Data(contentsOf: url)
        return ChainFileAttachment(
            id: attachment.id,
            fileName: url.lastPathComponent,
            fileExtension: url.pathExtension.lowercased(),
            byteCount: data.count,
            originalPath: url.path,
            snapshotText: String(decoding: data, as: UTF8.self)
        )
    }

    private static func loopFeedbackValue(originalInput: String, currentSavedOutput: String, feedbackOutput: String) -> String {
        let original = originalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = currentSavedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let feedback = feedbackOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !feedback.isEmpty || !current.isEmpty else { return original }
        var sections: [String] = []
        if !original.isEmpty {
            sections.append("""
            ## Original input file

            \(original)
            """)
        }
        if !current.isEmpty {
            sections.append("""
            ## Current saved output

            \(current)
            """)
        }
        if !feedback.isEmpty {
            sections.append("""
            ## Feedback from loop step

            \(feedback)
            """)
        }
        return sections.joined(separator: "\n\n")
    }

}

public enum ChainFinalMarkdownExtractor {
    public static func downloadableMarkdown(from output: String, tagName: String = "") -> String {
        guard let tagged = taggedMarkdown(from: output, tagName: tagName) else { return output }
        return tagged
    }

    public static func taggedMarkdown(from output: String, tagName: String = "") -> String? {
        let tag = tagName.sanitizedXMLTagName(defaultValue: "")
        guard !tag.isEmpty else { return nil }
        let startTag = "<\(tag)>"
        let endTag = "</\(tag)>"
        var searchStart = output.startIndex
        var matches: [String] = []
        while let startRange = output.range(of: startTag, options: [.caseInsensitive], range: searchStart..<output.endIndex),
              let endRange = output.range(of: endTag, options: [.caseInsensitive], range: startRange.upperBound..<output.endIndex) {
            let raw = String(output[startRange.upperBound..<endRange.lowerBound])
            let normalized = normalizeTaggedMarkdown(raw)
            if !normalized.isEmpty && normalized != "...final markdown file only..." {
                matches.append(normalized)
            }
            searchStart = endRange.upperBound
        }
        return matches.last
    }

    public static func containsTaggedMarkdown(in output: String, tagName: String = "") -> Bool {
        taggedMarkdown(from: output, tagName: tagName) != nil
    }

    private static func normalizeTaggedMarkdown(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
        let indents = lines
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in line.prefix { $0 == " " || $0 == "\t" }.count }
        let commonIndent = indents.min() ?? 0
        guard commonIndent > 0 else { return trimmed }
        return lines.map { line in
            guard line.count >= commonIndent else { return line }
            let index = line.index(line.startIndex, offsetBy: commonIndent)
            return String(line[index...])
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct ChainOutputStore: Sendable {
    public let rootURL: URL
    public init(rootURL: URL = ChainOutputStore.defaultRootURL()) { self.rootURL = rootURL }
    public static func defaultRootURL() -> URL {
        if let configured = UserDefaults.standard.string(forKey: AppSettingsKeys.storageChainMarkdownOutputFolder)?.trimmedNonEmpty(defaultValue: ""),
           !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true)
        }
        return builtInDefaultRootURL()
    }

    public static func builtInDefaultRootURL() -> URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("PromptManager", isDirectory: true)
            .appendingPathComponent("Chain Outputs", isDirectory: true)
    }

    public func folderURL(for chain: PromptChain) -> URL {
        if !chain.customOutputFolderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: chain.customOutputFolderPath, isDirectory: true)
        }
        return rootURL.appendingPathComponent(chain.stableStorageID, isDirectory: true)
    }

    public func saveMarkdown(_ text: String, chainTitle: String, stepTitle: String, date: Date = .now) throws -> URL {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: date).replacingOccurrences(of: ":", with: "-")
        let name = "\(chainTitle.slugKey)-\(stepTitle.slugKey)-\(stamp).md"
        let url = rootURL.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public func saveStepMarkdown(_ text: String, chain: PromptChain, step: PromptChainStep, sourceAttachment: ChainFileAttachment?) throws -> URL {
        let url: URL
        if let customURL = Self.customOutputURL(for: step) {
            try FileManager.default.createDirectory(at: customURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            url = availableURL(customURL, overwrite: step.overwriteOutputFile)
        } else {
            let folderURL = folderURL(for: chain)
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let name = Self.outputFileName(for: text, attachment: sourceAttachment, step: step)
            url = availableURL(folderURL.appendingPathComponent(name), overwrite: step.overwriteOutputFile)
        }
        try ChainFinalMarkdownExtractor.downloadableMarkdown(from: text, tagName: step.finalOutputTag).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public func saveResponseMarkdown(_ text: String, chainTitle: String, sourceAttachment: ChainFileAttachment?) throws -> URL {
        let fallbackChain = PromptChain(title: chainTitle)
        let fallbackStep = PromptChainStep(title: chainTitle, sortOrder: 0)
        return try saveStepMarkdown(text, chain: fallbackChain, step: fallbackStep, sourceAttachment: sourceAttachment)
    }

    public static func responseFileName(for attachment: ChainFileAttachment?, step: PromptChainStep? = nil) -> String {
        let includeStepPrefix = UserDefaults.standard.object(forKey: AppSettingsKeys.storageChainOutputIncludeStepPrefix) as? Bool ?? true
        let includeSuffix = UserDefaults.standard.object(forKey: AppSettingsKeys.storageChainOutputIncludeSuffix) as? Bool ?? true
        let suffix = UserDefaults.standard.string(forKey: AppSettingsKeys.storageChainOutputSuffix) ?? "response"
        let fallback = step?.title.trimmedNonEmpty(defaultValue: "chain-output") ?? "chain-output"
        let rawName = attachment?.fileName.trimmedNonEmpty(defaultValue: fallback) ?? fallback
        let base = (rawName as NSString).deletingPathExtension.trimmedNonEmpty(defaultValue: fallback)
        var parts: [String] = []
        if includeStepPrefix, let step { parts.append(String(format: "step-%02d", step.sortOrder + 1)) }
        var stem = safeFileStem(base, fallback: fallback)
        if includeSuffix {
            let safeSuffix = safeFileStem(suffix, fallback: "")
            if !safeSuffix.isEmpty { stem += "_\(safeSuffix)" }
        }
        parts.append(stem)
        return parts.joined(separator: "-") + ".md"
    }

    public static func taggedResponseFileName(for step: PromptChainStep) -> String {
        "\(step.finalOutputTag.sanitizedXMLTagName(defaultValue: "chain-output")).md"
    }

    public static func outputFileName(for text: String, attachment: ChainFileAttachment?, step: PromptChainStep) -> String {
        if let customURL = customOutputURL(for: step) {
            return customURL.lastPathComponent
        }
        if !step.customOutputFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return safeMarkdownFileName(step.customOutputFileName)
        }
        let tagEnabled = UserDefaults.standard.object(forKey: AppSettingsKeys.storageChainOutputShowTagControls) as? Bool ?? true
        if tagEnabled && ChainFinalMarkdownExtractor.containsTaggedMarkdown(in: text, tagName: step.finalOutputTag) {
            return taggedResponseFileName(for: step)
        }
        return responseFileName(for: attachment, step: step)
    }

    public static func configuredOutputFileName(for step: PromptChainStep, attachment: ChainFileAttachment?) -> String {
        if let customURL = customOutputURL(for: step) {
            return customURL.lastPathComponent
        }
        if !step.customOutputFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return safeMarkdownFileName(step.customOutputFileName)
        }
        return responseFileName(for: attachment, step: step)
    }

    public static func configuredOutputURL(for step: PromptChainStep, chain: PromptChain, attachment: ChainFileAttachment?, rootURL: URL = ChainOutputStore.defaultRootURL()) -> URL {
        if let customURL = customOutputURL(for: step) {
            return customURL
        }
        return ChainOutputStore(rootURL: rootURL)
            .folderURL(for: chain)
            .appendingPathComponent(configuredOutputFileName(for: step, attachment: attachment))
    }

    private static func customOutputURL(for step: PromptChainStep) -> URL? {
        let rawPath = step.customOutputFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawPath.isEmpty else { return nil }
        let url = URL(fileURLWithPath: rawPath)
        if url.pathExtension.isEmpty {
            return url.appendingPathExtension("md")
        }
        return url
    }

    private func availableURL(_ url: URL, overwrite: Bool) -> URL {
        guard !overwrite, FileManager.default.fileExists(atPath: url.path) else { return url }
        let ext = url.pathExtension
        let base = url.deletingPathExtension()
        for index in 2...10_000 {
            let candidate = base.deletingLastPathComponent().appendingPathComponent("\(base.lastPathComponent)-\(index)").appendingPathExtension(ext)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return url
    }

    private static func safeMarkdownFileName(_ raw: String) -> String {
        let withoutExtension = (raw as NSString).deletingPathExtension
        return safeFileStem(withoutExtension, fallback: "chain-output") + ".md"
    }

    private static func safeFileStem(_ raw: String, fallback: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
            .trimmedNonEmpty(defaultValue: fallback)
    }
}
