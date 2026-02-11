import XCTest
@testable import HackPanelApp

final class GatewayProfilesStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "gatewayProfiles")
        UserDefaults.standard.removeObject(forKey: "gatewayActiveProfileId")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "gatewayProfiles")
        UserDefaults.standard.removeObject(forKey: "gatewayActiveProfileId")
        super.tearDown()
    }

    @MainActor
    func testCreateProfile_persistsProfileAndStoresTokenInKeychain() {
        let store = GatewayProfilesStore()

        let created = store.createProfile(
            name: "Remote",
            baseURLString: "https://example.ts.net:18789",
            token: "sekrit"
        )

        XCTAssertEqual(store.activeProfileId, created.id)
        XCTAssertTrue(store.profiles.contains(where: { $0.id == created.id && $0.name == "Remote" }))
        XCTAssertEqual(store.token(for: created.id), "sekrit")

        // Verify the token is NOT stored in UserDefaults JSON payload.
        let raw = UserDefaults.standard.data(forKey: "gatewayProfiles")
        XCTAssertNotNil(raw)
        if let raw, let s = String(data: raw, encoding: .utf8) {
            XCTAssertFalse(s.contains("sekrit"))
            XCTAssertFalse(s.contains("gatewayToken.profile"))
        }

        // Best-effort cleanup.
        _ = Keychain.delete(account: created.tokenKeychainAccount)
    }

    @MainActor
    func testUpdateProfile_updatesFieldsAndToken() {
        let store = GatewayProfilesStore()
        let created = store.createProfile(name: "Remote", baseURLString: "https://example.ts.net:18789", token: "sekrit")

        store.updateProfile(created.id, name: "Prod", baseURLString: "https://prod.ts.net:18789", token: "newtoken")

        XCTAssertEqual(store.profiles.first(where: { $0.id == created.id })?.name, "Prod")
        XCTAssertEqual(store.profiles.first(where: { $0.id == created.id })?.baseURLString, "https://prod.ts.net:18789")
        XCTAssertEqual(store.token(for: created.id), "newtoken")

        _ = Keychain.delete(account: created.tokenKeychainAccount)
    }

    @MainActor
    func testDeleteProfile_deletesProfileAndSwitchesActiveWhenNeeded() {
        let store = GatewayProfilesStore()

        let p1 = store.activeProfile
        store.setToken("t1", for: p1.id)

        let p2 = store.createProfile(name: "Remote", baseURLString: "https://example.ts.net:18789", token: "t2")
        XCTAssertEqual(store.activeProfileId, p2.id)

        store.deleteProfile(p2.id)

        XCTAssertFalse(store.profiles.contains(where: { $0.id == p2.id }))
        XCTAssertNotEqual(store.activeProfileId, p2.id)
        XCTAssertEqual(store.activeProfileId, p1.id)

        // Best-effort verify keychain token removed.
        XCTAssertEqual(store.token(for: p2.id), "")

        _ = Keychain.delete(account: p1.tokenKeychainAccount)
        _ = Keychain.delete(account: p2.tokenKeychainAccount)
    }

    @MainActor
    func testDeleteProfile_doesNotDeleteLastRemainingProfile() {
        let store = GatewayProfilesStore()
        let only = store.activeProfile

        store.deleteProfile(only.id)

        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.profiles.first?.id, only.id)
    }
}
