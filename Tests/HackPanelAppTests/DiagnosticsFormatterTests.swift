import XCTest
@testable import HackPanelApp

final class DiagnosticsFormatterTests: XCTestCase {
    func testRedactToken_table() {
        struct Case {
            let input: String
            let expected: String
        }

        let cases: [Case] = [
            .init(input: "", expected: "(empty)"),
            .init(input: "   ", expected: "(empty)"),
            .init(input: "a", expected: "***redacted***"),
            .init(input: "abc", expected: "***redacted***"),
            .init(input: "abcd", expected: "***redacted*** (last4: abcd)"),
            .init(input: "abcdef", expected: "***redacted*** (last4: cdef)"),
        ]

        for c in cases {
            XCTAssertEqual(DiagnosticsFormatter.redactToken(c.input), c.expected)
        }
    }

    func testRedactToken_doesNotLeakFullToken_whenLongerThan4() {
        let token = "abcd-efgh-ijkl-1234"
        let redacted = DiagnosticsFormatter.redactToken(token)

        XCTAssertFalse(redacted.contains(token), "Should never include the full token when longer than 4")
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
                osVersion: "macOS 14.0 (23A344)",
                deviceId: "deadbeef",
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
        XCTAssertTrue(text.contains("OS: macOS 14.0 (23A344)"))
        XCTAssertTrue(text.contains("Device ID: deadbeef"))
        XCTAssertTrue(text.contains("Gateway base URL: http://127.0.0.1:18789"))
        XCTAssertTrue(text.contains("Connection state: Disconnected"))
        XCTAssertTrue(text.contains("Last error: Connection refused"))
        XCTAssertFalse(text.contains("super-secret-token-9999"), "Must not leak full token")
        XCTAssertTrue(text.contains("9999"), "Should include last4 for debugging")
    }

    func testFormatSettingsSummary_isRedactedAndStripsURLDetails() {
        let text = DiagnosticsFormatter.formatSettingsSummary(
            appVersion: "1.2.3",
            appBuild: "456",
            osVersion: "macOS 14.0 (23A344)",
            gatewayBaseURL: "http://example.com:18789/path?token=abc#frag",
            gatewayAutoApply: false,
            connectionState: "Connected",
            lastErrorMessage: ""
        )

        XCTAssertTrue(text.contains("HackPanel settings summary"))
        XCTAssertTrue(text.contains("App version: 1.2.3 (456)"))
        XCTAssertTrue(text.contains("OS: macOS 14.0 (23A344)"))
        XCTAssertTrue(text.contains("Gateway base URL: http://example.com:18789"))
        XCTAssertFalse(text.contains("/path"), "Should not include path/query/fragment")
        XCTAssertFalse(text.contains("token=abc"), "Should not include query")
        XCTAssertTrue(text.contains("Auto-apply: Off"))
        XCTAssertTrue(text.contains("Last error: (none)"))
    }

    func testRedactSecrets_redactsExactTokenAndBearerPatterns() {
        let token = "super-secret-token-9999"
        let bearer = "Authorization: Bearer abc.def.ghi"
        let sample = """
        ok line
        token=hello123
        \(bearer)
        embedded \(token) token
        """

        let out = DiagnosticsFormatter.redactSecrets(in: sample, gatewayToken: token)

        XCTAssertFalse(out.contains(token))
        XCTAssertFalse(out.contains("abc.def.ghi"))
        XCTAssertFalse(out.contains("token=hello123"))
        XCTAssertTrue(out.contains("ok line"))
        XCTAssertTrue(out.contains("Authorization: Bearer [REDACTED]"))
        XCTAssertTrue(out.contains("token=[REDACTED]"))
        XCTAssertTrue(out.contains("embedded [REDACTED] token"))
    }
}
