import CryptoKit
import Foundation
import Security

/// Minimal device identity used to correlate logs/bug reports across runs.
///
/// - Generates an Ed25519 keypair on first access.
/// - Stores the private key in Keychain.
/// - Derives a stable `deviceId` fingerprint from the public key.
enum DeviceIdentity {
    enum DeviceIdentityError: Error {
        case keychainUnhandledStatus(OSStatus)
        case keychainUnexpectedItem
    }

    private static let service = "com.hackpanel.device-identity"
    private static let account = "ed25519-private-key"

    static func loadOrCreateKeypair() throws -> Curve25519.Signing.PrivateKey {
        if let existing = try loadPrivateKey() {
            return existing
        }

        let created = Curve25519.Signing.PrivateKey()
        try savePrivateKey(created)
        return created
    }

    static func deviceId() throws -> String {
        let key = try loadOrCreateKeypair()
        return fingerprint(publicKeyRawRepresentation: key.publicKey.rawRepresentation)
    }

    /// Deterministic fingerprint derivation (no Keychain access).
    ///
    /// Current format: lowercased hex SHA-256 of the public key bytes.
    static func fingerprint(publicKeyRawRepresentation: Data) -> String {
        let digest = SHA256.hash(data: publicKeyRawRepresentation)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Keychain

    private static func loadPrivateKey() throws -> Curve25519.Signing.PrivateKey? {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw DeviceIdentityError.keychainUnexpectedItem }
            return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        case errSecItemNotFound:
            return nil
        default:
            throw DeviceIdentityError.keychainUnhandledStatus(status)
        }
    }

    private static func savePrivateKey(_ key: Curve25519.Signing.PrivateKey) throws {
        let data = key.rawRepresentation

        // Prefer update if it already exists (handles races / multiple callers).
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        // If it didn't exist, add it.
        if updateStatus == errSecItemNotFound {
            query.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            if addStatus == errSecSuccess {
                return
            }
            // If another caller added it between our update attempt and add, treat as success.
            if addStatus == errSecDuplicateItem {
                return
            }
            throw DeviceIdentityError.keychainUnhandledStatus(addStatus)
        }

        throw DeviceIdentityError.keychainUnhandledStatus(updateStatus)
    }
}
