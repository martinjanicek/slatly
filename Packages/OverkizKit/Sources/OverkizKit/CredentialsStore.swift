import Foundation
import Security

/// Stores Somfy username + password in the iCloud-synced Keychain.
/// Persistence survives app reinstalls; sharing across paired devices
/// requires iCloud Keychain enabled in System Settings.
public enum CredentialsStore {
    private static let service = "com.punkhive.zaluzky"
    private static let userKey = "somfy.username"
    private static let passwordKey = "somfy.password"

    public struct Credentials: Sendable, Equatable {
        public let username: String
        public let password: String
        public init(username: String, password: String) {
            self.username = username
            self.password = password
        }
    }

    public static func save(_ creds: Credentials) {
        saveItem(creds.username, account: userKey)
        saveItem(creds.password, account: passwordKey)
    }

    public static func load() -> Credentials? {
        guard let user = loadItem(account: userKey),
              let pw = loadItem(account: passwordKey),
              !user.isEmpty, !pw.isEmpty else { return nil }
        return Credentials(username: user, password: pw)
    }

    public static func clear() {
        deleteItem(account: userKey)
        deleteItem(account: passwordKey)
    }

    private static func saveItem(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func loadItem(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
