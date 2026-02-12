import XCTest
@testable import HackPanelApp

final class GatewaySettingsDraftTests: XCTestCase {
    func testDiffersFromAppliedNormalizesWhitespaceAndToken() {
        let applied = GatewaySettingsDraft(baseURL: "http://localhost:18789", token: "abc")
        let draft = GatewaySettingsDraft(baseURL: "  http://localhost:18789\n", token: "  abc  ")
        XCTAssertFalse(draft.differs(fromApplied: applied))
    }

    func testResetToAppliedRestoresAppliedValues() {
        var draft = GatewaySettingsDraft(baseURL: "http://example.com", token: "bad")
        let applied = GatewaySettingsDraft(baseURL: "http://localhost:18789", token: "good")

        let outcome = draft.reset(toApplied: applied, defaultBaseURL: GatewayDefaults.baseURLString)

        XCTAssertEqual(outcome, .resetToApplied)
        XCTAssertEqual(draft.normalizedBaseURL, "http://localhost:18789")
        XCTAssertEqual(draft.normalizedToken, "good")
    }

    func testResetToAppliedUsesDefaultWhenAppliedBaseURLEmpty() {
        var draft = GatewaySettingsDraft(baseURL: "http://example.com", token: "bad")
        let applied = GatewaySettingsDraft(baseURL: "   ", token: "")

        let outcome = draft.reset(toApplied: applied, defaultBaseURL: GatewayDefaults.baseURLString)

        XCTAssertEqual(outcome, .resetToDefaultBaseURL)
        XCTAssertEqual(draft.normalizedBaseURL, GatewayDefaults.baseURLString)
        XCTAssertEqual(draft.normalizedToken, "")
    }
}
