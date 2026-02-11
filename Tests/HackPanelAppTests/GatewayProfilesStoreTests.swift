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
}
