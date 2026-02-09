import XCTest
import HackPanelGateway
@testable import HackPanelApp

final class GatewayErrorPresenterTests: XCTestCase {
    func testMessage_invalidBaseURL_isFriendly() {
        let err = GatewayClientError.invalidBaseURL("127.0.0.1:18789")
        XCTAssertEqual(
            GatewayErrorPresenter.message(for: err),
            "Invalid Gateway URL. Include a scheme like http://127.0.0.1:18789"
        )
    }

    func testMessage_authFailure_gatewayError_isFriendly() {
        let err = GatewayClientError.gatewayError(code: "unauthorized", message: "unauthorized", details: nil)
        XCTAssertEqual(
            GatewayErrorPresenter.message(for: err),
            "Authentication failed. Check your Gateway token."
        )
        XCTAssertTrue(GatewayErrorPresenter.isAuthFailure(err))
    }

    func testMessage_gatewayError_includesServerSummary() {
        let err = GatewayClientError.gatewayError(code: "bad_request", message: "missing param", details: "x")
        XCTAssertEqual(
            GatewayErrorPresenter.message(for: err),
            "Gateway error: missing param"
        )
    }

    func testMessage_urlError_cannotConnect_isFriendly() {
        let err = URLError(.cannotConnectToHost)
        XCTAssertEqual(
            GatewayErrorPresenter.message(for: err),
            "Can’t reach the Gateway. Check the URL and that the Gateway is running."
        )
    }
}
