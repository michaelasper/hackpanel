import XCTest
import HackPanelGateway
@testable import HackPanelApp

@MainActor
final class GatewayConnectionStoreBackoffJitterTests: XCTestCase {
    actor SleepDriver {
        struct SleepRequest {
            var seconds: TimeInterval
            var continuation: CheckedContinuation<Void, Never>
        }

        private var pending: [SleepRequest] = []
        private var nextRequestContinuation: CheckedContinuation<TimeInterval, Never>?

        func sleep(_ seconds: TimeInterval) async {
            if let cont = nextRequestContinuation {
                nextRequestContinuation = nil
                cont.resume(returning: seconds)
            }

            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                pending.append(SleepRequest(seconds: seconds, continuation: cont))
            }
        }

        func waitForNextSleepRequest() async -> TimeInterval {
            if let first = pending.first {
                return first.seconds
            }

            return await withCheckedContinuation { (cont: CheckedContinuation<TimeInterval, Never>) in
                nextRequestContinuation = cont
            }
        }

        func resumeNextSleep() {
            guard !pending.isEmpty else { return }
            let req = pending.removeFirst()
            req.continuation.resume()
        }
    }

    final class NowDriver {
        private(set) var current: Date

        init(_ start: Date) {
            self.current = start
        }

        func now() -> Date { current }

        func advance(_ seconds: TimeInterval) {
            current = current.addingTimeInterval(seconds)
        }
    }

    struct AlwaysFailClient: GatewayClient {
        func fetchStatus() async throws -> GatewayStatus {
            throw URLError(.cannotConnectToHost)
        }
        func fetchNodes() async throws -> [NodeSummary] { [] }
    }

    func testMonitorLoop_increasesBackoffExponentially_andIsDeterministicWithJitterDisabled() async {
        let driver = SleepDriver()
        let clock = NowDriver(Date(timeIntervalSince1970: 0))

        let tuning = GatewayConnectionStore.MonitorTuning(
            pollIntervalSeconds: 999,
            inactivePollIntervalSeconds: 999,
            baseBackoffSeconds: 1,
            maxBackoffSeconds: 30,
            jitterMin: 1,
            jitterMax: 1,
            errorDedupeWindowSeconds: 0.01,
            sleepQuantumSeconds: 999
        )

        let store = GatewayConnectionStore(
            client: AlwaysFailClient(),
            tuning: tuning,
            now: { clock.now() },
            randomUnit: { 0.0 },
            sleep: { seconds in
                clock.advance(seconds)
                await driver.sleep(seconds)
            }
        )

        store.start()
        defer { store.stop() }

        // First failure: baseBackoffSeconds * 2^(1-1) = 1
        let first = await driver.waitForNextSleepRequest()
        XCTAssertEqual(first, 1, accuracy: 0.0001)
        XCTAssertNotNil(store.currentBackoffSeconds)
        XCTAssertEqual(store.currentBackoffSeconds ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(store.lastRefreshResult, "failure")

        await driver.resumeNextSleep()

        // Second consecutive failure: baseBackoffSeconds * 2^(2-1) = 2
        let second = await driver.waitForNextSleepRequest()
        XCTAssertEqual(second, 2, accuracy: 0.0001)
        XCTAssertNotNil(store.currentBackoffSeconds)
        XCTAssertEqual(store.currentBackoffSeconds ?? 0, 2, accuracy: 0.0001)
    }
}
