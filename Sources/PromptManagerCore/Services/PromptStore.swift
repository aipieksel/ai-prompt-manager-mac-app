import Foundation

public final class PromptStore: @unchecked Sendable {
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL = PromptStore.defaultStoreURL()) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public static func defaultStoreURL() -> URL {
        let defaults = UserDefaults.standard
        let location = defaults.string(forKey: AppSettingsKeys.storageLocation) ?? "Application Support"
        let base: URL
        switch location {
        case "Documents":
            base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
        case "Custom":
            if let custom = defaults.string(forKey: AppSettingsKeys.storageCustomLocation), !custom.isEmpty {
                base = URL(fileURLWithPath: custom)
            } else {
                base = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("PromptManagerCustom", isDirectory: true)
            }
        default:
            base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        }
        return base.appendingPathComponent("PromptManager", isDirectory: true).appendingPathComponent("library.json")
    }

    public static func migrateCurrentStore(to location: String, customPath: String? = nil) throws -> URL {
        let defaults = UserDefaults.standard
        let oldURL = defaultStoreURL()
        defaults.set(location, forKey: AppSettingsKeys.storageLocation)
        if let customPath { defaults.set(customPath, forKey: AppSettingsKeys.storageCustomLocation) }
        let newURL = defaultStoreURL()
        if oldURL != newURL, FileManager.default.fileExists(atPath: oldURL.path) {
            try FileManager.default.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: newURL.path) { try? FileManager.default.removeItem(at: newURL) }
            try FileManager.default.copyItem(at: oldURL, to: newURL)
        }
        return newURL
    }

    public func load() throws -> PromptLibrary {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return SampleData.demoLibrary() }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(PromptLibrary.self, from: data)
    }

    public func save(_ library: PromptLibrary) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(library).write(to: fileURL, options: [.atomic])
    }
}
