import XCTest
@testable import HackPanelApp

final class DiagnosticsFormatterTests: XCTestCase {
    func testRedactToken_doesNotLeakFullToken() {
        let token = "abcd-efgh-ijkl-1234"
        let redacted = DiagnosticsFormatter.redactToken(token)

        XCTAssertFalse(redacted.contains(token), "Should never include the full token")
        XCTAssertTrue(redacted.contains("1234"), "Should include last 4 when possible")
    }

    func testFormat_includesExpectedFields() {
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let errAt = Date(timeIntervalSince1970: 1_700_000_100)
        let until = Date(timeIntervalSince1970: 1_700_000_120)

        let text = DiagnosticsFormatter.format(
            .init(
                appVersion: "1.2.3",
                appBuild: "456",
                gatewayBaseURL: "http://127.0.0.1:18789",
                gatewayToken: "super-secret-token-9999",
                connectionState: "Disconnected",
                lastErrorMessage: "Connection refused",
                lastErrorAt: errAt,
                reconnectBackoffUntil: until
            ),
            now: fixedNow
        )

        XCTAssertTrue(text.contains("App version: 1.2.3 (456)"))
        XCTAssertTrue(text.contains("Gateway base URL: http://127.0.0.1:18789"))
        XCTAssertTrue(text.contains("Connection state: Disconnected"))
        XCTAssertTrue(text.contains("Last error: Connection refused"))
        XCTAssertFalse(text.contains("super-secret-token-9999"), "Must not leak full token")
        XCTAssertTrue(text.contains("9999"), "Should include last4 for debugging")
    }
}
