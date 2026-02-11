import XCTest
@testable import HackPanelApp

final class GatewayOnboardingGateTests: XCTestCase {
    func test_isBaseURLInvalid_empty_isInvalid() {
        XCTAssertTrue(GatewayOnboardingGate.isBaseURLInvalid(""))
        XCTAssertTrue(GatewayOnboardingGate.isBaseURLInvalid("   \n"))
    }

    func test_isBaseURLInvalid_garbage_isInvalid() {
        XCTAssertTrue(GatewayOnboardingGate.isBaseURLInvalid("not a url"))
    }

    func test_isBaseURLInvalid_validURL_isValid() {
        XCTAssertFalse(GatewayOnboardingGate.isBaseURLInvalid("http://127.0.0.1:3001"))
    }

    func test_shouldShowOnboarding_invalidBaseURL_alwaysShows() {
        XCTAssertTrue(
            GatewayOnboardingGate.shouldShowOnboarding(
                hasEverConnected: true,
                baseURL: "",
                connectionState: .connected
            )
        )
    }

    func test_shouldShowOnboarding_neverConnected_andDisconnected_shows() {
        XCTAssertTrue(
            GatewayOnboardingGate.shouldShowOnboarding(
                hasEverConnected: false,
                baseURL: "http://127.0.0.1:3001",
                connectionState: .disconnected
            )
        )
    }

    func test_shouldShowOnboarding_hasConnected_andDisconnected_doesNotShow() {
        XCTAssertFalse(
            GatewayOnboardingGate.shouldShowOnboarding(
                hasEverConnected: true,
                baseURL: "http://127.0.0.1:3001",
                connectionState: .disconnected
            )
        )
    }
}
