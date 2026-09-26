import Foundation
#if os(macOS)
import Security
#endif

public enum AIKeychainError: Error, LocalizedError, Sendable {
    case unavailable
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Keychain is unavailable on this platform."
        case .unexpectedStatus(let status):
            return "Keychain error: \(status)"
        }
    }
}

public struct AIKeychainService: Sendable {
    public let service: String
    public init(service: String = "co.aipieksel.prompt-manager.ai") { self.service = service }

    public func account(for provider: AIProviderKind) -> String { "api-key.\(provider.rawValue)" }

    public func readKey(for provider: AIProviderKind) throws -> String {
        try read(account: account(for: provider)) ?? ""
    }

    public func saveKey(_ key: String, for provider: AIProviderKind) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try deleteKey(for: provider)
        } else {
            try save(trimmed, account: account(for: provider))
        }
    }

    public func deleteKey(for provider: AIProviderKind) throws {
        try delete(account: account(for: provider))
    }

    public func read(account: String) throws -> String? {
        #if os(macOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw AIKeychainError.unexpectedStatus(status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
        #else
        throw AIKeychainError.unavailable
        #endif
    }

    public func save(_ value: String, account: String) throws {
        #if os(macOS)
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound { throw AIKeychainError.unexpectedStatus(updateStatus) }
        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw AIKeychainError.unexpectedStatus(addStatus) }
        #else
        throw AIKeychainError.unavailable
        #endif
    }

    public func delete(account: String) throws {
        #if os(macOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AIKeychainError.unexpectedStatus(status) }
        #else
        throw AIKeychainError.unavailable
        #endif
    }
}
