import Foundation

/// Small, testable backoff scheduler used by `GatewayConnectionStore`.
///
/// Design goals:
/// - Deterministic in tests (inject clock + jitter)
/// - Minimal surface area (PR-sized slice)
struct RefreshBackoffScheduler: Sendable {
    struct Config: Sendable {
        var pollIntervalSeconds: TimeInterval
        var baseBackoffSeconds: TimeInterval
        var maxBackoffSeconds: TimeInterval
        /// Jitter multiplier range applied to the exponential backoff value.
        var jitterRange: ClosedRange<Double>
        /// Caps the exponent to keep backoff growth bounded.
        var maxFailureExponent: Int

        init(
            pollIntervalSeconds: TimeInterval = 15,
            baseBackoffSeconds: TimeInterval = 1,
            maxBackoffSeconds: TimeInterval = 30,
            jitterRange: ClosedRange<Double> = 0.6...1.4,
            maxFailureExponent: Int = 8
        ) {
            self.pollIntervalSeconds = pollIntervalSeconds
            self.baseBackoffSeconds = baseBackoffSeconds
            self.maxBackoffSeconds = maxBackoffSeconds
            self.jitterRange = jitterRange
            self.maxFailureExponent = maxFailureExponent
        }
    }

    struct Observation: Equatable, Sendable {
        var lastRefreshAttemptAt: Date?
        var lastRefreshResult: String?
        var nextScheduledRefreshAt: Date?
        var currentBackoffSeconds: TimeInterval?
    }

    private(set) var consecutiveFailures: Int = 0
    private(set) var observation: Observation = .init()

    var config: Config
    private let now: @Sendable () -> Date
    private let jitter: @Sendable () -> Double

    init(
        config: Config = .init(),
        now: @escaping @Sendable () -> Date = { Date() },
        jitter: @escaping @Sendable () -> Double = { Double.random(in: 0.6...1.4) }
    ) {
        self.config = config
        self.now = now
        self.jitter = jitter
    }

    mutating func recordAttempt() {
        observation.lastRefreshAttemptAt = now()
    }

    mutating func recordSuccess() {
        consecutiveFailures = 0
        observation.lastRefreshResult = "success"
        observation.currentBackoffSeconds = 0
        observation.nextScheduledRefreshAt = now().addingTimeInterval(config.pollIntervalSeconds)
    }

    mutating func recordFailure(summary: String) -> TimeInterval {
        consecutiveFailures += 1
        observation.lastRefreshResult = summary

        let delay = computeBackoffDelaySeconds(failureCount: consecutiveFailures)
        observation.currentBackoffSeconds = delay
        observation.nextScheduledRefreshAt = now().addingTimeInterval(delay)
        return delay
    }

    mutating func resetForManualRetry() {
        consecutiveFailures = max(consecutiveFailures, 1)
        observation.currentBackoffSeconds = 0
        observation.nextScheduledRefreshAt = now()
    }

    private func computeBackoffDelaySeconds(failureCount: Int) -> TimeInterval {
        let cappedCount = min(config.maxFailureExponent, max(1, failureCount))
        let exp = pow(2.0, Double(cappedCount - 1))
        let raw = min(config.maxBackoffSeconds, config.baseBackoffSeconds * exp)
        let jitterMultiplier = min(config.jitterRange.upperBound, max(config.jitterRange.lowerBound, jitter()))
        let jittered = raw * jitterMultiplier
        return max(0.5, min(config.maxBackoffSeconds, jittered))
    }
}
