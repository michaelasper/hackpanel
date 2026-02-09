import XCTest
@testable import HackPanelGateway

final class GatewayFrameContractDecodingTests: XCTestCase {
    // Best-guess shape for connect.challenge.
    // TODO: Confirm exact field names with Gateway protocol docs / live capture.
    private struct ConnectChallengePayload: Decodable, Sendable, Equatable {
        var nonce: String?
        var algorithm: String?
        var expiresAt: Date?
    }

    func testDecodesConnectChallengeEventFixture() throws {
        let decoded = try FixtureLoader.decode(GatewayEventFrame<ConnectChallengePayload>.self, fromFixture: "connect_challenge.json", decoder: ISO8601.decoder)

        XCTAssertEqual(decoded.type, "event")
        XCTAssertEqual(decoded.event, "connect.challenge")

        let payload = try XCTUnwrap(decoded.normalizedPayload)
        XCTAssertEqual(payload.algorithm, "ed25519")
        XCTAssertEqual(payload.nonce, "b8c1a1f0c6c84c6a9e2c9e1b66f9d101")
        XCTAssertEqual(payload.expiresAt, ISO8601.date("2026-02-08T22:05:00Z"))
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

private extension ISO8601 {
    static func date(_ iso: String, file: StaticString = #filePath, line: UInt = #line) -> Date {
        // ISO8601.decoder is configured for OpenClaw timestamps, so reuse it.
        let data = Data(("\"" + iso + "\"").utf8)
        do {
            return try ISO8601.decoder.decode(Date.self, from: data)
        } catch {
            XCTFail("Failed parsing ISO8601 date: \(iso) error=\(error)", file: file, line: line)
            return Date(timeIntervalSince1970: 0)
        }
    }
}
