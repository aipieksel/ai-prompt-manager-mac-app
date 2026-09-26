import Foundation

public enum PromptBackupService {
    public static func backupDirectory(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
    }

    public static func runIfNeeded(library: PromptLibrary, settings: ImportExportBehaviorSettings, storeURL: URL, now: Date = .now) throws {
        guard settings.autoBackup else { return }
        let directory = backupDirectory(for: storeURL)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = directory.appendingPathComponent("last-backup.txt")
        let interval = intervalForFrequency(settings.backupFrequency)
        if let previous = try? String(contentsOf: marker, encoding: .utf8), let timestamp = TimeInterval(previous), now.timeIntervalSince1970 - timestamp < interval { return }
        let formatter = ISO8601DateFormatter()
        let safeDate = formatter.string(from: now).replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("library-backup-\(safeDate).json")
        try PromptExportService.backupData(library: library).write(to: url, options: [.atomic])
        try String(now.timeIntervalSince1970).write(to: marker, atomically: true, encoding: .utf8)
        try pruneBackups(in: directory, keepDays: Int(settings.keepBackupsFor) ?? 30, now: now)
    }

    public static func pruneBackups(in directory: URL, keepDays: Int, now: Date = .now) throws {
        let cutoff = now.addingTimeInterval(-Double(max(1, keepDays)) * 86_400)
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for url in urls where url.lastPathComponent.hasPrefix("library-backup-") {
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
            if (values.contentModificationDate ?? now) < cutoff { try? FileManager.default.removeItem(at: url) }
        }
    }

    private static func intervalForFrequency(_ frequency: String) -> TimeInterval {
        switch frequency { case "daily": return 86_400; case "monthly": return 30 * 86_400; default: return 7 * 86_400 }
    }
}
