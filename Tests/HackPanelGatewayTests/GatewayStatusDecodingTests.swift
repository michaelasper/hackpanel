import XCTest
@testable import HackPanelGateway

final class GatewayStatusDecodingTests: XCTestCase {
    func testDecodesGatewayStatusFixture() throws {
        let data = try XCTUnwrap(Self.fixture(named: "gateway_status.json"))
        let decoded = try ISO8601.decoder.decode(GatewayStatus.self, from: data)
        XCTAssertEqual(decoded.ok, true)
        XCTAssertEqual(decoded.version, "OpenClaw 2026.2.6-3")
    }

    private static func fixture(named name: String) -> Data? {
        let url = Bundle.module.url(forResource: name, withExtension: nil)
        return url.flatMap { try? Data(contentsOf: $0) }
    }
}
