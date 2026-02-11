import XCTest
@testable import HackPanelApp

final class RootViewRedactionTests: XCTestCase {
    func testRedactBannerText_redactsTokenAndBearer() {
        let token = "super-secret-token-9999"
        let input = "Authorization: Bearer abc.def.ghi\nembedded \(token) token"

        let out = RootView.redactBannerText(input, gatewayToken: token) ?? ""

        XCTAssertFalse(out.contains(token))
        XCTAssertFalse(out.contains("abc.def.ghi"))
        XCTAssertTrue(out.contains("Authorization: Bearer [REDACTED]"))
        XCTAssertTrue(out.contains("embedded [REDACTED] token"))
    }

    func testRedactBannerText_nilAndEmpty_passthrough() {
        XCTAssertNil(RootView.redactBannerText(nil, gatewayToken: "x"))
        XCTAssertEqual(RootView.redactBannerText("", gatewayToken: "x"), "")
    }
}
