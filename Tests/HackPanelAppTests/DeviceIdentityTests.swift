import Foundation
import XCTest
@testable import HackPanelApp

final class DeviceIdentityTests: XCTestCase {
    func testFingerprint_isDeterministic() {
        let publicKey = Data(repeating: 0x01, count: 32)
        let fingerprint = DeviceIdentity.fingerprint(publicKeyRawRepresentation: publicKey)

        XCTAssertEqual(
            fingerprint,
            "72cd6e8422c407fb6d098690f1130b7ded7ec2f7f5e1d30bd9d521f015363793"
        )

        // Same input should always yield same output.
        XCTAssertEqual(fingerprint, DeviceIdentity.fingerprint(publicKeyRawRepresentation: publicKey))
    }
}
