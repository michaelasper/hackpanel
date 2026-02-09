import CryptoKit
import XCTest
@testable import HackPanelGateway

final class DeviceAuthSigningTests: XCTestCase {
    func testBuildDeviceAuthPayloadV2MatchesSpec() throws {
        let payload = DeviceAuthPayload.build(
            version: .v2,
            deviceId: "deviceid",
            clientId: "hackpanel",
            clientMode: "operator",
            role: "operator",
            scopes: ["operator.read"],
            signedAtMs: 1_737_264_000_000,
            token: "tkn",
            nonce: "nonce"
        )

        XCTAssertEqual(payload, "v2|deviceid|hackpanel|operator|operator|operator.read|1737264000000|tkn|nonce")
    }

    func testDeviceSignatureVerifiesAgainstPublicKey() throws {
        // Deterministic test key.
        let rawPriv = Data((0..<32).map(UInt8.init))
        let priv = try Curve25519.Signing.PrivateKey(rawRepresentation: rawPriv)
        let identity = DeviceIdentity(privateKey: priv)

        let nonce = "32f06b80-f5ff-470d-8a87-b8d91bc51a14"
        let signedAtMs: Int64 = 1_769_763_506_654
        let payload = DeviceAuthPayload.build(
            version: .v2,
            deviceId: identity.deviceId,
            clientId: "hackpanel",
            clientMode: "operator",
            role: "operator",
            scopes: ["operator.read"],
            signedAtMs: signedAtMs,
            token: "token",
            nonce: nonce
        )

        let signatureB64Url = try identity.signConnectPayload(payload)

        let publicKeyRaw = try Base64URL.decode(identity.publicKeyBase64Url)
        let pub = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyRaw)
        let signatureRaw = try Base64URL.decode(signatureB64Url)

        XCTAssertTrue(pub.isValidSignature(signatureRaw, for: Data(payload.utf8)))
    }
}
