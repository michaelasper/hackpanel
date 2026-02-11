import XCTest
import HackPanelGateway
import HackPanelGatewayMocks
@testable import HackPanelApp

@MainActor
final class GatewayConnectionStoreInactiveRefreshTests: XCTestCase {
    actor SleepDriver {
        struct SleepRequest {
            var seconds: TimeInterval
            var continuation: CheckedContinuation<Void, Never>
        }

        private var pending: [SleepRequest] = []
        private var nextRequestContinuation: CheckedContinuation<TimeInterval, Never>?

        func sleep(_ seconds: TimeInterval) async {
            // Notify the test that a sleep was requested.
            if let cont = nextRequestContinuation {
                nextRequestContinuation = nil
                cont.resume(returning: seconds)
            } else {
                // If nobody is waiting yet, enqueue a signal via pending.
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

        func pendingCount() -> Int { pending.count }
    }

    func testMonitorLoop_usesInactiveInterval_andTriggersSingleImmediateRefreshOnReactivation() async throws {
        let driver = SleepDriver()

        let tuning = GatewayConnectionStore.MonitorTuning(
            pollIntervalSeconds: 1,
            inactivePollIntervalSeconds: 5,
            baseBackoffSeconds: 0.01,
            maxBackoffSeconds: 0.01,
            errorDedupeWindowSeconds: 0.01,
            sleepQuantumSeconds: 10 // >= interval so each poll sleep is a single call
        )

        let store = GatewayConnectionStore(
            client: MockGatewayClient(scenario: .demo),
            tuning: tuning,
            now: { Date(timeIntervalSince1970: 0) },
            sleep: { seconds in await driver.sleep(seconds) }
        )

        store.start()
        defer { store.stop() }

        // First successful cycle should sleep at the foreground poll interval.
        let first = await driver.waitForNextSleepRequest()
        XCTAssertEqual(first, 1, accuracy: 0.0001)

        // Make app inactive; next cycle should use inactive interval.
        store.setAppActive(false)
        await driver.resumeNextSleep()

        let second = await driver.waitForNextSleepRequest()
        XCTAssertEqual(second, 5, accuracy: 0.0001)

        // Reactivate; the next poll should *not* sleep (immediate refresh) and then return to normal interval.
        store.setAppActive(true)
        await driver.resumeNextSleep()

        // After reactivation, there should be no additional sleep queued immediately; we expect the loop
        // to re-run and then request the normal foreground sleep.
        let third = await driver.waitForNextSleepRequest()
        XCTAssertEqual(third, 1, accuracy: 0.0001)
    }
}
