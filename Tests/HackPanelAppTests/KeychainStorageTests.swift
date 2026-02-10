import XCTest
@testable import HackPanelApp

final class KeychainStorageTests: XCTestCase {
    func testKeychain_readWriteDelete_roundTrips() {
        let key = "test.keychain.\(UUID().uuidString)"

        // Write + read
        XCTAssertEqual(Keychain.writeString("sekrit", account: key), errSecSuccess)
        XCTAssertEqual(Keychain.readString(account: key), "sekrit")

        // Delete + read
        XCTAssertEqual(Keychain.delete(account: key), errSecSuccess)
        XCTAssertNil(Keychain.readString(account: key))
    }

    func testKeychainStorage_emptyStringDeletes() {
        let key = "test.keychain.storage.\(UUID().uuidString)"
        let storage = KeychainStorage(key)

        storage.wrappedValue = "  sekrit  "
        XCTAssertEqual(Keychain.readString(account: key), "sekrit")

        storage.wrappedValue = "   "
        XCTAssertNil(Keychain.readString(account: key))
    }

    func testKeychainStorage_migratesFromUserDefaults() {
        let key = "test.keychain.migrate.\(UUID().uuidString)"
        UserDefaults.standard.set("legacy", forKey: key)

        // Constructing the wrapper should migrate legacy -> keychain and clear UserDefaults.
        _ = KeychainStorage(key)

        XCTAssertNil(UserDefaults.standard.string(forKey: key))
        XCTAssertEqual(Keychain.readString(account: key), "legacy")

        _ = Keychain.delete(account: key)
    }
}
