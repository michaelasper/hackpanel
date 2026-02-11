import XCTest
@testable import HackPanelApp

final class GatewaySettingsValidatorTests: XCTestCase {
    func testValidateBaseURL_acceptsValidLocalhostURL_withPort() throws {
        let result = GatewaySettingsValidator.validateBaseURL("http://127.0.0.1:18789")
        switch result {
        case .success(let url):
            XCTAssertEqual(url.scheme, "http")
            XCTAssertEqual(url.host, "127.0.0.1")
            XCTAssertEqual(url.port, 18789)
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error.message)")
        }
    }

    func testValidateBaseURL_acceptsValidURL_withoutPort() {
        let result = GatewaySettingsValidator.validateBaseURL("http://127.0.0.1")
        switch result {
        case .success(let url):
            XCTAssertEqual(url.scheme, "http")
            XCTAssertEqual(url.host, "127.0.0.1")
            XCTAssertNil(url.port)
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error.message)")
        }
    }

    func testValidateBaseURL_rejectsMissingScheme() {
        let result = GatewaySettingsValidator.validateBaseURL("127.0.0.1:18789")
        XCTAssertFailure(result)
    }

    func testValidateBaseURL_rejectsNonHttpScheme() {
        let result = GatewaySettingsValidator.validateBaseURL("ws://127.0.0.1:18789")
        XCTAssertFailure(result)
    }

    func testValidateBaseURL_rejectsMissingHost() {
        let result = GatewaySettingsValidator.validateBaseURL("http://:18789")
        XCTAssertFailure(result)
    }

    func testValidateBaseURL_rejectsPath() {
        let result = GatewaySettingsValidator.validateBaseURL("http://127.0.0.1:18789/ws")
        XCTAssertFailure(result)
    }

    func testValidateBaseURL_rejectsQueryAndFragment() {
        XCTAssertFailure(GatewaySettingsValidator.validateBaseURL("http://127.0.0.1:18789?x=1"))
        XCTAssertFailure(GatewaySettingsValidator.validateBaseURL("http://127.0.0.1:18789#frag"))
    }

    private func XCTAssertFailure(_ result: Result<URL, GatewaySettingsValidator.ValidationError>, file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case .success(let url):
            XCTFail("Expected failure, got success: \(url)", file: file, line: line)
        case .failure:
            XCTAssertTrue(true)
        }
    }
}
