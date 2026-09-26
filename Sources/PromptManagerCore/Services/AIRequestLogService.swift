import Foundation

public struct AIRequestLogEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var provider: AIProviderKind
    public var modelID: String
    public var requestText: String
    public var responseText: String
    public var status: String

    public init(id: UUID = UUID(), createdAt: Date = .now, provider: AIProviderKind, modelID: String, requestText: String, responseText: String, status: String) {
        self.id = id
        self.createdAt = createdAt
        self.provider = provider
        self.modelID = modelID
        self.requestText = requestText
        self.responseText = responseText
        self.status = status
    }
}

public struct AIRequestLogService {
    public let fileURL: URL
    public var userDefaults: UserDefaults

    public init(fileURL: URL = AIRequestLogService.defaultFileURL(), userDefaults: UserDefaults = .standard) {
        self.fileURL = fileURL
        self.userDefaults = userDefaults
    }

    public static func defaultFileURL() -> URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("PromptManager", isDirectory: true)
            .appendingPathComponent("ai-request-log.json")
    }

    public func append(provider: AIProviderKind, modelID: String, requestText: String, responseText: String, status: String, date: Date = .now) {
        do {
            var entries = (try? load(trim: false)) ?? []
            entries.append(AIRequestLogEntry(createdAt: date, provider: provider, modelID: modelID, requestText: requestText, responseText: responseText, status: status))
            try save(trim(entries, now: date))
        } catch {
            // Logging must never break provider execution.
        }
    }

    public func load(trim shouldTrim: Bool = true, now: Date = .now) throws -> [AIRequestLogEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([AIRequestLogEntry].self, from: data)
        if shouldTrim {
            let trimmed = trim(entries, now: now)
            if trimmed != entries { try save(trimmed) }
            return trimmed
        }
        return entries
    }

    public func clear() throws {
        try save([])
    }

    private func save(_ entries: [AIRequestLogEntry]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
    }

    private func trim(_ entries: [AIRequestLogEntry], now: Date) -> [AIRequestLogEntry] {
        let storedMaxEntries = userDefaults.object(forKey: AppSettingsKeys.aiRequestLogMaxEntries) as? Int
        let maxEntries = max(1, storedMaxEntries ?? 500)
        let storedMaxAgeMinutes = userDefaults.object(forKey: AppSettingsKeys.aiRequestLogMaxAgeMinutes) as? Int
        let maxAgeMinutes = max(0, storedMaxAgeMinutes ?? 1440)
        let ageTrimmed: [AIRequestLogEntry]
        if maxAgeMinutes > 0 {
            let cutoff = now.addingTimeInterval(TimeInterval(-maxAgeMinutes * 60))
            ageTrimmed = entries.filter { $0.createdAt >= cutoff }
        } else {
            ageTrimmed = entries
        }
        return Array(ageTrimmed.suffix(maxEntries))
    }
}
