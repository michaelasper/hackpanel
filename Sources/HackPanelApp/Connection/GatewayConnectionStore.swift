import Foundation
import HackPanelGateway

@MainActor
final class GatewayConnectionStore: ObservableObject {
    enum State: Equatable {
        case connected
        case reconnecting(nextRetryAt: Date)
        case disconnected
        case authFailed

        var displayName: String {
            switch self {
            case .connected: return "Connected"
            case .reconnecting: return "Reconnecting"
            case .disconnected: return "Disconnected"
            case .authFailed: return "Auth failed"
            }
        }
    }

    struct ConnectionError: Equatable {
        var message: String
        /// The time we first observed this error message (used for dedupe/throttle).
        var firstSeenAt: Date
        /// The last time we allowed the UI to update for this message.
        var lastEmittedAt: Date
    }

    @Published private(set) var state: State = .disconnected
    @Published private(set) var lastError: ConnectionError?
    @Published private(set) var countdownSeconds: Int?
    @Published private(set) var lastHealthCheckAt: Date?

    /// Best-effort recent log lines for support/diagnostics export.
    ///
    /// Intentionally avoids secrets (token) and avoids full URLs.
    @Published private(set) var recentLogLines: [String] = []

    // Diagnostics/debug for refresh scheduling.
    @Published private(set) var isRefreshPaused: Bool = false
    @Published private(set) var lastActiveAt: Date?

    var lastErrorMessage: String? { lastError?.message }
    var lastErrorAt: Date? { lastError?.lastEmittedAt }

    /// Bump this to cause views to refresh their data.
    @Published private(set) var refreshToken: UUID = UUID()

    private var client: any GatewayClient

    private var monitorTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var countdownToken: UUID?

    // Used to interrupt sleeps when app active/inactive flips.
    private var monitorWakeToken: UUID = UUID()
    private var pendingImmediateRefresh: Bool = false

    private var consecutiveFailures: Int = 0

    // Coalesce duplicate refresh triggers so we never execute >1 concurrent request per endpoint.
    private var inFlightStatusTask: Task<GatewayStatus, Error>?
    private var inFlightNodesTask: Task<[NodeSummary], Error>?

    struct MonitorTuning: Sendable {
        var pollIntervalSeconds: TimeInterval = 15
        /// While app is inactive/backgrounded, use a much slower interval to avoid refresh storms.
        var inactivePollIntervalSeconds: TimeInterval = 120
        var baseBackoffSeconds: TimeInterval = 1
        var maxBackoffSeconds: TimeInterval = 30
        var errorDedupeWindowSeconds: TimeInterval = 10
        /// Sleep granularity so we can react quickly to active/inactive changes.
        var sleepQuantumSeconds: TimeInterval = 0.25
    }

    private let maxRecentLogLines: Int = 400

    private let tuning: MonitorTuning
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async -> Void

    init(
        client: any GatewayClient,
        tuning: MonitorTuning = MonitorTuning(),
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        }
    ) {
        self.client = client
        self.tuning = tuning
        self.now = now
        self.sleep = sleep

        #if DEBUG
        applyForcedStateIfPresent(environment: ProcessInfo.processInfo.environment, now: now())
        #endif
    }

    #if DEBUG
    /// Screenshot/debug helper to force the connection banner into a specific state.
    ///
    /// Usage:
    /// `HACKPANEL_FORCE_STATE=connected|reconnecting|disconnected|authFailed`
    ///
    /// This is DEBUG-only and is ignored for empty/falsy values.
    func applyForcedStateIfPresent(environment: [String: String], now: Date) {
        guard let raw = environment["HACKPANEL_FORCE_STATE"] else { return }
        let forced = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !forced.isEmpty else { return }
        guard !["0", "false", "off", "no"].contains(forced) else { return }

        guard let forcedState = Self.forcedState(from: forced, now: now) else { return }
        state = forcedState.state
        lastError = forcedState.lastError
        countdownSeconds = forcedState.countdownSeconds
    }

    struct ForcedState: Equatable {
        var state: State
        var lastError: ConnectionError?
        var countdownSeconds: Int?
    }

    static func forcedState(from forced: String, now: Date) -> ForcedState? {
        switch forced {
        case "connected":
            return ForcedState(state: .connected, lastError: nil, countdownSeconds: nil)

        case "reconnecting":
            return ForcedState(
                state: .reconnecting(nextRetryAt: now.addingTimeInterval(12)),
                lastError: ConnectionError(
                    message: "Connection lost (simulated)",
                    firstSeenAt: now,
                    lastEmittedAt: now
                ),
                countdownSeconds: 12
            )

        case "authfailed", "auth_failed", "auth":
            return ForcedState(
                state: .authFailed,
                lastError: ConnectionError(
                    message: "Invalid token (simulated)",
                    firstSeenAt: now,
                    lastEmittedAt: now
                ),
                countdownSeconds: nil
            )

        case "disconnected":
            return ForcedState(
                state: .disconnected,
                lastError: ConnectionError(
                    message: "Gateway unreachable (simulated)",
                    firstSeenAt: now,
                    lastEmittedAt: now
                ),
                countdownSeconds: nil
            )

        default:
            return nil
        }
    }
    #endif

    deinit {
        monitorTask?.cancel()
        countdownTask?.cancel()
    }

    func start() {
        guard monitorTask == nil else { return }
        log("monitor: start")

        monitorTask = Task { [weak self] in
            guard let self else { return }
            await self.runMonitorLoop()
        }
    }

    func stop() {
        log("monitor: stop")
        monitorTask?.cancel()
        monitorTask = nil
        countdownTask?.cancel()
        countdownTask = nil
    }

    /// Called by the root SwiftUI scene when app focus/foreground changes.
    ///
    /// When we become active again, we trigger exactly one immediate refresh, and interrupt any pending sleep.
    func setAppActive(_ active: Bool) {
        let wasPaused = isRefreshPaused
        isRefreshPaused = !active

        if active {
            lastActiveAt = now()
            if wasPaused {
                pendingImmediateRefresh = true
                monitorWakeToken = UUID()
            }
        }
    }

    func retryNow() {
        log("user: retryNow")
        consecutiveFailures = max(consecutiveFailures, 1) // ensure backoff is active
        state = .reconnecting(nextRetryAt: Date())
        countdownSeconds = 0
        refreshToken = UUID()

        // Cancelling and restarting the loop forces an immediate attempt.
        stop()
        start()
    }

    func updateClient(_ client: any GatewayClient) {
        log("client: update")
        self.client = client
        retryNow()
    }

    /// Perform a one-shot status request against the currently-configured Gateway.
    ///
    /// Used by Settings "Test connection" without altering the monitor loop/state.
    func testConnection() async throws {
        log("settings: testConnection")
        lastHealthCheckAt = Date()
        _ = try await client.fetchStatus()
    }

    private func runMonitorLoop() async {
        // Attempt immediately.
        while !Task.isCancelled {
            do {
                // Use the coalesced fetchStatus path so view-initiated refreshes don't cause parallel health checks.
                _ = try await fetchStatus()
                log("monitor: fetchStatus ok")
                consecutiveFailures = 0
                clearErrorOnSuccess()
                stopCountdown()
                state = .connected
                refreshToken = UUID()

                await sleepUntilNextPoll()
            } catch {
                // consecutiveFailures + lastError were already updated by `trackCall` inside `fetchStatus()`.
                let delay = computeBackoffDelaySeconds(failureCount: consecutiveFailures)
                log("monitor: fetchStatus failed; backoff=\(String(format: "%.1f", delay))s")
                let nextRetryAt = Date().addingTimeInterval(delay)
                state = .reconnecting(nextRetryAt: nextRetryAt)
                startCountdown(to: nextRetryAt)

                // Sleep until next retry.
                await sleep(delay)

                if Task.isCancelled { return }
            }
        }
    }

    private func sleepUntilNextPoll() async {
        // If we just became active, trigger one immediate refresh attempt.
        if pendingImmediateRefresh {
            pendingImmediateRefresh = false
            refreshToken = UUID()
            return
        }

        let token = monitorWakeToken
        let interval = isRefreshPaused ? tuning.inactivePollIntervalSeconds : tuning.pollIntervalSeconds

        var elapsed: TimeInterval = 0
        while !Task.isCancelled, elapsed < interval {
            // Break early if we became active/inactive.
            if monitorWakeToken != token {
                return
            }
            if pendingImmediateRefresh {
                pendingImmediateRefresh = false
                refreshToken = UUID()
                return
            }

            let quantum = min(tuning.sleepQuantumSeconds, interval - elapsed)
            await sleep(quantum)
            elapsed += quantum
        }
    }

    private func computeBackoffDelaySeconds(failureCount: Int) -> TimeInterval {
        let capped = min(8, max(1, failureCount))
        let exp = pow(2.0, Double(capped - 1))
        let raw = min(tuning.maxBackoffSeconds, tuning.baseBackoffSeconds * exp)
        // Jitter in [0.6, 1.4]
        let jitter = Double.random(in: 0.6...1.4)
        return max(0.5, min(tuning.maxBackoffSeconds, raw * jitter))
    }

    private func startCountdown(to date: Date) {
        let token = UUID()
        countdownToken = token

        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                // Guard against the cancel race: even after cancellation, a Task can still
                // execute one more loop iteration and write stale countdownSeconds.
                guard self.countdownToken == token else { return }

                let remaining = max(0, Int(ceil(date.timeIntervalSinceNow)))

                guard !Task.isCancelled else { return }
                guard self.countdownToken == token else { return }

                self.countdownSeconds = remaining
                if remaining <= 0 { return }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stopCountdown() {
        countdownToken = nil
        countdownTask?.cancel()
        countdownTask = nil
        countdownSeconds = nil
    }

    private func emit(error: Error) {
        let message = GatewayErrorPresenter.message(for: error)
        log("error: \(message)")
        let now = Date()

        if var current = lastError, current.message == message {
            // Dedupe: do not re-emit identical errors too frequently (prevents banner timestamp spam).
            if now.timeIntervalSince(current.lastEmittedAt) < tuning.errorDedupeWindowSeconds {
                return
            }
            current.lastEmittedAt = now
            lastError = current
            return
        }

        lastError = ConnectionError(message: message, firstSeenAt: now, lastEmittedAt: now)
    }

    private func clearErrorOnSuccess() {
        lastError = nil
    }

    private func log(_ message: String, now: Date = Date()) {
        // Keep it deterministic and support-friendly.
        let line = "\(ISO8601DateFormatter().string(from: now)) \(message)"
        recentLogLines.append(line)
        if recentLogLines.count > maxRecentLogLines {
            recentLogLines.removeFirst(recentLogLines.count - maxRecentLogLines)
        }
    }

    func fetchStatus() async throws -> GatewayStatus {
        if let task = inFlightStatusTask {
            return try await task.value
        }

        let task = Task { @MainActor in
            defer { self.inFlightStatusTask = nil }
            return try await self.trackCall { try await self.client.fetchStatus() }
        }
        inFlightStatusTask = task
        return try await task.value
    }

    func fetchNodes() async throws -> [NodeSummary] {
        if let task = inFlightNodesTask {
            return try await task.value
        }

        let task = Task { @MainActor in
            defer { self.inFlightNodesTask = nil }
            return try await self.trackCall { try await self.client.fetchNodes() }
        }
        inFlightNodesTask = task
        return try await task.value
    }

    private func trackCall<T>(_ work: () async throws -> T) async throws -> T {
        lastHealthCheckAt = Date()
        do {
            let value = try await work()
            consecutiveFailures = 0
            clearErrorOnSuccess()
            stopCountdown()
            state = .connected
            return value
        } catch {
            consecutiveFailures += 1
            emit(error: error)
            if isAuthFailure(error: error) {
                state = .authFailed
            } else {
                state = .disconnected
            }
            throw error
        }
    }

    private func isAuthFailure(error: Error) -> Bool {
        GatewayErrorPresenter.isAuthFailure(error)
    }
}

