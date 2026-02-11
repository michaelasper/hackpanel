import XCTest
@testable import HackPanelApp

final class RefreshBackoffSchedulerTests: XCTestCase {
    private final class NowBox: @unchecked Sendable {
        var value: Date
        init(_ value: Date) { self.value = value }
    }

    func testConsecutiveFailures_increaseDelay_withJitterBounded() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let nowBox = NowBox(t0)

        var scheduler = RefreshBackoffScheduler(
            config: .init(
                pollIntervalSeconds: 15,
                baseBackoffSeconds: 1,
                maxBackoffSeconds: 30,
                jitterRange: 1.0...1.0,
                maxFailureExponent: 8
            ),
            now: { nowBox.value },
            jitter: { 1.0 }
        )

        // failure #1 -> 1s
        let d1 = scheduler.recordFailure(summary: "failure")
        XCTAssertEqual(d1, 1, accuracy: 0.0001)
        XCTAssertEqual(scheduler.observation.currentBackoffSeconds ?? -1, 1, accuracy: 0.0001)
        XCTAssertEqual(scheduler.observation.nextScheduledRefreshAt, t0.addingTimeInterval(1))

        // failure #2 -> 2s
        nowBox.value = t0.addingTimeInterval(10)
        let d2 = scheduler.recordFailure(summary: "failure")
        XCTAssertEqual(d2, 2, accuracy: 0.0001)
        XCTAssertEqual(scheduler.observation.currentBackoffSeconds ?? -1, 2, accuracy: 0.0001)
        XCTAssertEqual(scheduler.observation.nextScheduledRefreshAt, nowBox.value.addingTimeInterval(2))

        // failure #3 -> 4s
        nowBox.value = t0.addingTimeInterval(20)
        let d3 = scheduler.recordFailure(summary: "failure")
        XCTAssertEqual(d3, 4, accuracy: 0.0001)

        // Ensure it caps at maxBackoffSeconds.
        nowBox.value = t0.addingTimeInterval(30)
        for _ in 0..<20 {
            _ = scheduler.recordFailure(summary: "failure")
        }
        XCTAssertNotNil(scheduler.observation.currentBackoffSeconds)
        XCTAssertLessThanOrEqual(scheduler.observation.currentBackoffSeconds!, 30)
    }

    func testSuccess_resetsBackoff_andSchedulesNextPoll() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let nowBox = NowBox(t0)

        var scheduler = RefreshBackoffScheduler(
            config: .init(
                pollIntervalSeconds: 15,
                baseBackoffSeconds: 1,
                maxBackoffSeconds: 30,
                jitterRange: 1.0...1.0,
                maxFailureExponent: 8
            ),
            now: { nowBox.value },
            jitter: { 1.0 }
        )

        _ = scheduler.recordFailure(summary: "failure")
        XCTAssertNotEqual(scheduler.consecutiveFailures, 0)

        nowBox.value = t0.addingTimeInterval(5)
        scheduler.recordSuccess()

        XCTAssertEqual(scheduler.consecutiveFailures, 0)
        XCTAssertEqual(scheduler.observation.lastRefreshResult, "success")
        XCTAssertEqual(scheduler.observation.currentBackoffSeconds ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(scheduler.observation.nextScheduledRefreshAt, nowBox.value.addingTimeInterval(15))
    }

    func testRecordAttempt_setsLastRefreshAttemptAt() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let nowBox = NowBox(t0)

        var scheduler = RefreshBackoffScheduler(
            config: .init(pollIntervalSeconds: 15),
            now: { nowBox.value },
            jitter: { 1.0 }
        )

        XCTAssertNil(scheduler.observation.lastRefreshAttemptAt)

        scheduler.recordAttempt()
        XCTAssertEqual(scheduler.observation.lastRefreshAttemptAt, t0)

        nowBox.value = t0.addingTimeInterval(42)
        scheduler.recordAttempt()
        XCTAssertEqual(scheduler.observation.lastRefreshAttemptAt, nowBox.value)
    }
}
