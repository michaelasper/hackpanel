import XCTest
import HackPanelGateway
@testable import HackPanelApp

final class GatewayTestConnectionPresenterTests: XCTestCase {
    func testPresent_success() {
        XCTAssertEqual(
            GatewayTestConnectionPresenter.presentSuccess(),
            .init(kind: .success, message: "Connection OK.")
        )
    }

    func testPresent_authFailure_isAuthFailed() {
        let err = GatewayClientError.gatewayError(code: "unauthorized", message: "unauthorized", details: nil)
        XCTAssertEqual(
            GatewayTestConnectionPresenter.present(error: err).kind,
            .authFailed
        )
    }

    func testPresent_urlError_cannotConnect_isCannotConnect() {
        let err = URLError(.cannotConnectToHost)
        XCTAssertEqual(
            GatewayTestConnectionPresenter.present(error: err).kind,
            .cannotConnect
        )
    }

    func testPresent_urlError_timedOut_isTimedOut() {
        let err = URLError(.timedOut)
        XCTAssertEqual(
            GatewayTestConnectionPresenter.present(error: err).kind,
            .timedOut
        )
    }

    func testPresent_unknown_fallsBackToGatewayErrorPresenterMessage() {
        struct Weird: LocalizedError { var errorDescription: String? { "weird" } }
        let result = GatewayTestConnectionPresenter.present(error: Weird())
        XCTAssertEqual(result.kind, .unknown)
        XCTAssertEqual(result.message, "weird")
    }
}
