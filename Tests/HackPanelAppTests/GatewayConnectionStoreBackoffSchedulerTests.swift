import XCTest
@testable import HackPanelApp
import HackPanelGateway

@MainActor
final class GatewayConnectionStoreBackoffSchedulerTests: XCTestCase {
    final class Clock: @unchecked Sendable {
        private(set) var current: Date

        init(start: Date) {
            self.current = start
        }

        func now() -> Date { current }

        func advance(by seconds: TimeInterval) {
            current = current.addingTimeInterval(seconds)
        }
    }
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

        func fetchNodes() async throws -> [NodeSummary] { [] }
    }

    func testMonitorLoop_usesDeterministicBackoffWithJitter_andSetsNextScheduledRefreshAt() async throws {
        let driver = SleepDriver()
        let clock = Clock(start: Date(timeIntervalSince1970: 0))

        // Force jitter to the minimum (0.6) for deterministic expectations.
        let randomUnit: @Sendable () -> Double = { 0 }

        let tuning = GatewayConnectionStore.MonitorTuning(
            pollIntervalSeconds: 99,
            inactivePollIntervalSeconds: 99,
            baseBackoffSeconds: 1,
            maxBackoffSeconds: 100,
            errorDedupeWindowSeconds: 0.01,
            sleepQuantumSeconds: 99
        )

        let client = SequencedGatewayClient(statusResults: [
            .failure(GatewayClientError.timedOut(operation: "fetchStatus")),
            .failure(GatewayClientError.timedOut(operation: "fetchStatus")),
            .failure(GatewayClientError.timedOut(operation: "fetchStatus")),
        ])

        let store = GatewayConnectionStore(
            client: client,
            tuning: tuning,
            now: { clock.now() },
            randomUnit: randomUnit,
            sleep: { seconds in
                await driver.sleep(seconds)
                clock.advance(by: seconds)
            }
        )

        store.start()
        defer { store.stop() }

        let first = await driver.waitForNextSleepRequest()
        XCTAssertEqual(first, 0.6, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(store.currentBackoffSeconds), 0.6, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(store.nextScheduledRefreshAt).timeIntervalSince1970, 0.6, accuracy: 0.0001)
        await driver.resumeNextSleep()

        let second = await driver.waitForNextSleepRequest()
        XCTAssertEqual(second, 1.2, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(store.currentBackoffSeconds), 1.2, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(store.nextScheduledRefreshAt).timeIntervalSince1970, 0.6 + 1.2, accuracy: 0.0001)
        await driver.resumeNextSleep()

        let third = await driver.waitForNextSleepRequest()
        XCTAssertEqual(third, 2.4, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(store.currentBackoffSeconds), 2.4, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(store.nextScheduledRefreshAt).timeIntervalSince1970, 0.6 + 1.2 + 2.4, accuracy: 0.0001)
    }

    func testMonitorLoop_successResetsBackoffAndSchedulesNextPoll() async throws {
        let driver = SleepDriver()
        let clock = Clock(start: Date(timeIntervalSince1970: 0))

        let randomUnit: @Sendable () -> Double = { 0 }

        let tuning = GatewayConnectionStore.MonitorTuning(
            pollIntervalSeconds: 5,
            inactivePollIntervalSeconds: 5,
            baseBackoffSeconds: 1,
            maxBackoffSeconds: 100,
            errorDedupeWindowSeconds: 0.01,
            sleepQuantumSeconds: 10
        )

        let client = SequencedGatewayClient(statusResults: [
            .failure(GatewayClientError.timedOut(operation: "fetchStatus")),
            .success(GatewayStatus(ok: true, version: "test", uptimeSeconds: 1)),
        ])

        let store = GatewayConnectionStore(
            client: client,
            tuning: tuning,
            now: { clock.now() },
            randomUnit: randomUnit,
            sleep: { seconds in
                await driver.sleep(seconds)
                clock.advance(by: seconds)
            }
        )

        store.start()
        defer { store.stop() }

        let backoff = await driver.waitForNextSleepRequest()
        XCTAssertEqual(backoff, 0.6, accuracy: 0.0001)
        await driver.resumeNextSleep()

        let poll = await driver.waitForNextSleepRequest()
        XCTAssertEqual(poll, 5, accuracy: 0.0001)
        XCTAssertNil(store.currentBackoffSeconds)
        XCTAssertEqual(store.lastRefreshResult, "success")
        XCTAssertEqual(try XCTUnwrap(store.nextScheduledRefreshAt).timeIntervalSince1970, 0.6 + 5, accuracy: 0.0001)
    }
}
