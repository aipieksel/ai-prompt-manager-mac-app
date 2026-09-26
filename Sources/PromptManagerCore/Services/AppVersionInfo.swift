import Foundation

public struct AppVersionInfo: Equatable, Sendable {
    public var shortVersion: String
    public var build: String

    public init(shortVersion: String, build: String) {
        self.shortVersion = shortVersion.trimmedNonEmpty(defaultValue: "0.1.0")
        self.build = build.trimmedNonEmpty(defaultValue: "0")
    }

    public var displayText: String { "Version \(shortVersion)" }

    public static var current: AppVersionInfo {
        let info = Bundle.main.infoDictionary ?? [:]
        return AppVersionInfo(
            shortVersion: info["CFBundleShortVersionString"] as? String ?? "0.1.0",
            build: info["CFBundleVersion"] as? String ?? "0"
        )
    }
}
