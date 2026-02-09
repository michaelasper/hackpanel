import XCTest
@testable import HackPanelGateway

final class GatewayStatusDecodingTests: XCTestCase {
    func testDecodesGatewayStatusFixture() throws {
        let decoded = try FixtureLoader.decode(GatewayStatus.self, fromFixture: "gateway_status.json", decoder: ISO8601.decoder)
        XCTAssertEqual(decoded.ok, true)
        XCTAssertEqual(decoded.version, "OpenClaw 2026.2.6-3")
    }
}
