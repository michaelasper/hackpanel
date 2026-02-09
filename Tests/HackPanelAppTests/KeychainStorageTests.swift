import XCTest
@testable import HackPanelApp

final class KeychainStorageTests: XCTestCase {
    func testKeychainWriteReadDelete_roundTrip() {
        let key = "test.gatewayToken.\(UUID().uuidString)"
        defer { _ = Keychain.delete(account: key) }

        XCTAssertNil(Keychain.readString(account: key))

        XCTAssertEqual(Keychain.writeString("abc123", account: key), errSecSuccess)
        XCTAssertEqual(Keychain.readString(account: key), "abc123")

        _ = Keychain.delete(account: key)
        XCTAssertNil(Keychain.readString(account: key))
    }

    func testKeychainStorage_migratesFromUserDefaults() {
        let key = "test.migrateToken.\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removeObject(forKey: key)
            _ = Keychain.delete(account: key)
        }

        UserDefaults.standard.set("legacy", forKey: key)
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "legacy")

        var storage = KeychainStorage(key)
        // Force access to trigger init + migration.
        XCTAssertEqual(storage.wrappedValue, "legacy")

        XCTAssertNil(UserDefaults.standard.string(forKey: key))
        XCTAssertEqual(Keychain.readString(account: key), "legacy")
    }
}
