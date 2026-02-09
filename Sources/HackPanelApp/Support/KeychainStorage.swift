import Foundation
import SwiftUI
import Security

enum Keychain {
    /// A stable service name for this app.
    /// Using bundle id keeps it unique per-app, while still predictable.
    private static var service: String {
        Bundle.main.bundleIdentifier ?? "HackPanel"
    }

    static func readString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func writeString(_ value: String, account: String) -> OSStatus {
        let data = Data(value.utf8)

        // Upsert.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            return SecItemAdd(addQuery as CFDictionary, nil)
        }

        return updateStatus
    }

    @discardableResult
    static func delete(account: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary)
    }
}

/// Lightweight `@AppStorage`-like wrapper backed by Keychain.
///
/// Notes:
/// - Empty strings delete the key to avoid storing "empty secret".
/// - Performs a one-time migration from UserDefaults for the same key.
@propertyWrapper
struct KeychainStorage: DynamicProperty {
    @State private var value: String

    private let key: String

    /// Supports `@KeychainStorage("foo") var bar: String = ""`.
    init(wrappedValue: String, _ key: String, default defaultValue: String = "") {
        self.key = key

        // One-time migration from UserDefaults (legacy @AppStorage usage).
        if let legacy = UserDefaults.standard.string(forKey: key), !legacy.isEmpty {
            _ = Keychain.writeString(legacy, account: key)
            UserDefaults.standard.removeObject(forKey: key)
        }

        let initial = Keychain.readString(account: key) ?? (wrappedValue.isEmpty ? defaultValue : wrappedValue)
        _value = State(initialValue: initial)
    }

    /// Convenience for callers who want to construct it directly (tests).
    init(_ key: String, default defaultValue: String = "") {
        self.init(wrappedValue: defaultValue, key, default: defaultValue)
    }

    var wrappedValue: String {
        get { value }
        nonmutating set {
            value = newValue
            persist(newValue)
        }
    }

    var projectedValue: Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }

    private func persist(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            _ = Keychain.delete(account: key)
        } else {
            _ = Keychain.writeString(trimmed, account: key)
        }
    }
}
