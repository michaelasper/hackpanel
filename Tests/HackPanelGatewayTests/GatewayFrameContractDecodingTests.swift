import XCTest
@testable import HackPanelGateway

final class GatewayFrameContractDecodingTests: XCTestCase {
    // Contract shape for `connect.challenge` per the Gateway protocol docs.
    // Source: docs/gateway/protocol.md (openclaw/openclaw).
    private struct ConnectChallengePayload: Decodable, Sendable, Equatable {
        var nonce: String
        var ts: Int64
    }

    func testDecodesConnectChallengeEventFixture() throws {
        let decoded = try FixtureLoader.decode(GatewayEventFrame<ConnectChallengePayload>.self, fromFixture: "connect_challenge.json", decoder: ISO8601.decoder)

        XCTAssertEqual(decoded.type, "event")
        XCTAssertEqual(decoded.event, "connect.challenge")

        let payload = try XCTUnwrap(decoded.normalizedPayload)
        XCTAssertEqual(payload.nonce, "b8c1a1f0c6c84c6a9e2c9e1b66f9d101")
        XCTAssertEqual(payload.ts, 1737264000000)
    }

    func testDecodesConnectAuthFailureFixture() throws {
        // Note: payload type is irrelevant on error paths; use an empty placeholder.
        struct Empty: Decodable, Sendable {}

        let decoded = try FixtureLoader.decode(GatewayResponseFrame<Empty>.self, fromFixture: "connect_auth_failure.json", decoder: ISO8601.decoder)

        XCTAssertEqual(decoded.type, "res")
        XCTAssertEqual(decoded.id, "connect-1")
        XCTAssertEqual(decoded.ok, false)

        let err = try XCTUnwrap(decoded.error)
        XCTAssertEqual(err.code, "auth.invalid")
        XCTAssertEqual(err.message, "Invalid token")
        XCTAssertEqual(err.details, "Token was missing or expired")
        XCTAssertEqual(err.data, .object(["reason": .string("missing")]))
    }
}
