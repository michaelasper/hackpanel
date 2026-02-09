import CryptoKit
import Foundation
import Security

/// A stable device identity backed by an Ed25519 keypair stored in the macOS Keychain.
///
/// This is used to sign `connect.challenge` nonces during the Gateway connect handshake.
struct DeviceIdentity: Sendable {
    let deviceId: String
    let publicKeyBase64Url: String
    fileprivate let privateKey: Curve25519.Signing.PrivateKey

    static func loadOrCreate(service: String = "ai.openclaw.hackpanel",
                             account: String = "device-identity-ed25519") throws -> DeviceIdentity {
        if let existing = try Keychain.loadData(service: service, account: account) {
            let key = try Curve25519.Signing.PrivateKey(rawRepresentation: existing)
            return DeviceIdentity(privateKey: key)
        }

        let key = Curve25519.Signing.PrivateKey()
        try Keychain.saveData(key.rawRepresentation, service: service, account: account)
        return DeviceIdentity(privateKey: key)
    }

    init(privateKey: Curve25519.Signing.PrivateKey) {
        self.privateKey = privateKey
        let pub = privateKey.publicKey.rawRepresentation
        self.publicKeyBase64Url = Base64URL.encode(pub)
        self.deviceId = DeviceIdentity.fingerprintDeviceId(publicKeyRaw: pub)
    }

    func signConnectPayload(_ payload: String) throws -> String {
        let sig = try privateKey.signature(for: Data(payload.utf8))
        return Base64URL.encode(sig)
    }

    private static func fingerprintDeviceId(publicKeyRaw: Data) -> String {
        let digest = SHA256.hash(data: publicKeyRaw)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private enum Keychain {
    static func loadData(service: String, account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func saveData(_ data: Data, service: String, account: String) throws {
        // Upsert.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // Keep items scoped to this Mac.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(updateStatus) }
            return
        }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }
}
