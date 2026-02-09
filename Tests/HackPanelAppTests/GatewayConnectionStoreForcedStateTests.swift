#if DEBUG

import XCTest
import HackPanelGateway
@testable import HackPanelApp

@MainActor
final class GatewayConnectionStoreForcedStateTests: XCTestCase {
    private struct NoopClient: GatewayClient {
        func fetchStatus() async throws -> GatewayStatus { GatewayStatus(ok: true, version: nil, uptimeSeconds: nil) }
        func fetchNodes() async throws -> [NodeSummary] { [] }
    }

    func testForcedState_connected() {
        let now = Date(timeIntervalSince1970: 123)
        let forced = GatewayConnectionStore.forcedState(from: "connected", now: now)
        XCTAssertEqual(forced?.state, .connected)
        XCTAssertNil(forced?.lastError)
        XCTAssertNil(forced?.countdownSeconds)
    }

    func testForcedState_reconnecting_hasCountdownAndError() {
        let now = Date(timeIntervalSince1970: 123)
        let forced = GatewayConnectionStore.forcedState(from: "reconnecting", now: now)

        guard let forced else {
            XCTFail("Expected a forced state")
            return
        }

        if case .reconnecting(let nextRetryAt) = forced.state {
            XCTAssertEqual(nextRetryAt.timeIntervalSince1970, now.addingTimeInterval(12).timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("Expected reconnecting")
        }

        XCTAssertEqual(forced.countdownSeconds, 12)
        XCTAssertEqual(forced.lastError?.message, "Connection lost (simulated)")
        XCTAssertEqual(forced.lastError?.firstSeenAt, now)
        XCTAssertEqual(forced.lastError?.lastEmittedAt, now)
    }

    func testApplyForcedState_falseyValue_isIgnored() {
        let now = Date(timeIntervalSince1970: 123)
        let store = GatewayConnectionStore(client: NoopClient())
        XCTAssertEqual(store.state, .disconnected)

        store.applyForcedStateIfPresent(environment: ["HACKPANEL_FORCE_STATE": "off"], now: now)
        XCTAssertEqual(store.state, .disconnected)
    }

    func testApplyForcedState_unknownValue_isIgnored() {
        let now = Date(timeIntervalSince1970: 123)
        let store = GatewayConnectionStore(client: NoopClient())

        store.applyForcedStateIfPresent(environment: ["HACKPANEL_FORCE_STATE": "banana"], now: now)
        XCTAssertEqual(store.state, .disconnected)
    }
}

#endif
