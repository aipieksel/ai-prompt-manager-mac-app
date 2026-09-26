import Foundation

public enum FolderScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case prompts
    case variablePrompts
    case chains
    case phrases

    public var id: String { rawValue }
}

public struct Folder: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var parentFolderID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var sortOrder: Int
    public var icon: String?
    public var color: String?
    public var scope: FolderScope

    public init(id: UUID = UUID(), name: String, parentFolderID: UUID? = nil, createdAt: Date = .now, updatedAt: Date = .now, sortOrder: Int = 0, icon: String? = "folder", color: String? = nil, scope: FolderScope = .prompts) {
        self.id = id
        self.name = name.trimmedNonEmpty(defaultValue: "Untitled Folder")
        self.parentFolderID = parentFolderID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        self.icon = icon
        self.color = color
        self.scope = scope
    }

    private enum CodingKeys: String, CodingKey { case id, name, parentFolderID, createdAt, updatedAt, sortOrder, icon, color, scope }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled Folder",
            parentFolderID: try c.decodeIfPresent(UUID.self, forKey: .parentFolderID),
            createdAt: try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now,
            updatedAt: try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now,
            sortOrder: try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0,
            icon: try c.decodeIfPresent(String.self, forKey: .icon) ?? "folder",
            color: try c.decodeIfPresent(String.self, forKey: .color),
            scope: try c.decodeIfPresent(FolderScope.self, forKey: .scope) ?? .prompts
        )
    }

    public mutating func rename(to newName: String, at date: Date = .now) {
        name = newName.trimmedNonEmpty(defaultValue: "Untitled Folder")
        updatedAt = date
    }
}
