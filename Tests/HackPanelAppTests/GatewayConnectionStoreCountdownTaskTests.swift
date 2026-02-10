import XCTest
@testable import HackPanelApp
import HackPanelGateway

final class GatewayConnectionStoreCountdownTaskTests: XCTestCase {
    actor SequencedGatewayClient: GatewayClient {
        private var statusResults: [Result<GatewayStatus, Error>]

        init(statusResults: [Result<GatewayStatus, Error>]) {
            self.statusResults = statusResults
        }

        func fetchStatus() async throws -> GatewayStatus {
            guard !statusResults.isEmpty else {
                return GatewayStatus(ok: true, version: "test", uptimeSeconds: 0)
            }
            let next = statusResults.removeFirst()
            return try next.get()
        }

        func fetchNodes() async throws -> [NodeSummary] {
            return []
        }
    }

    @MainActor
    func testCountdownTaskStopsAfterSuccessfulConnect_inMonitorLoop() async {
        let client = SequencedGatewayClient(statusResults: [
            .failure(GatewayClientError.timedOut(operation: "fetchStatus")),
            .success(GatewayStatus(ok: true, version: "test", uptimeSeconds: 1)),
        ])

        let store = GatewayConnectionStore(client: client)
        store.start()

        // Wait long enough for one failure (countdown starts) + next retry success.
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        XCTAssertEqual(store.state, .connected)

        // If countdownTask wasn't cancelled, it can keep writing countdownSeconds after connected.
        XCTAssertNil(store.countdownSeconds)

        // Give it another tick to catch the bug (would flip countdownSeconds back to a number).
        try? await Task.sleep(nanoseconds: 1_250_000_000)
        XCTAssertNil(store.countdownSeconds)

        store.stop()
    }
}
