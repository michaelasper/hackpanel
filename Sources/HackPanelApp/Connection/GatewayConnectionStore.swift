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

    // Auto-refresh diagnostics (for copy/paste debugging)
    @Published private(set) var lastRefreshAttemptAt: Date?
    @Published private(set) var lastRefreshResult: String?
    @Published private(set) var nextScheduledRefreshAt: Date?
    @Published private(set) var currentBackoffSeconds: TimeInterval?

    var lastErrorMessage: String? { lastError?.message }
    var lastErrorAt: Date? { lastError?.lastEmittedAt }

    /// Bump this to cause views to refresh their data.
    @Published private(set) var refreshToken: UUID = UUID()

    private var client: any GatewayClient

    private var monitorTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var countdownToken: UUID?

    private var refreshScheduler: RefreshBackoffScheduler = .init()

    // Coalesce duplicate refresh triggers so we never execute >1 concurrent request per endpoint.
    private var inFlightStatusTask: Task<GatewayStatus, Error>?
    private var inFlightNodesTask: Task<[NodeSummary], Error>?

    // Tunables
    private let pollIntervalSeconds: TimeInterval = 15
    private let errorDedupeWindowSeconds: TimeInterval = 10

    init(client: any GatewayClient) {
        self.client = client
        self.refreshScheduler = RefreshBackoffScheduler(
            config: .init(pollIntervalSeconds: pollIntervalSeconds)
        )

        #if DEBUG
        applyForcedStateIfPresent(environment: ProcessInfo.processInfo.environment, now: Date())
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

        monitorTask = Task { [weak self] in
            guard let self else { return }
            await self.runMonitorLoop()
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        countdownTask?.cancel()
        countdownTask = nil
    }

    func retryNow() {
        refreshScheduler.resetForManualRetry()
        currentBackoffSeconds = refreshScheduler.observation.currentBackoffSeconds
        nextScheduledRefreshAt = refreshScheduler.observation.nextScheduledRefreshAt

        state = .reconnecting(nextRetryAt: Date())
        countdownSeconds = 0
        refreshToken = UUID()

        // Cancelling and restarting the loop forces an immediate attempt.
        stop()
        start()
    }

    func updateClient(_ client: any GatewayClient) {
        self.client = client
        retryNow()
    }

    /// Perform a one-shot status request against the currently-configured Gateway.
    ///
    /// Used by Settings "Test connection" without altering the monitor loop/state.
    func testConnection() async throws {
        lastHealthCheckAt = Date()
        _ = try await client.fetchStatus()
    }

    private func runMonitorLoop() async {
        // Attempt immediately.
        while !Task.isCancelled {
            do {
                refreshScheduler.recordAttempt()
                lastRefreshAttemptAt = refreshScheduler.observation.lastRefreshAttemptAt

                // Use the coalesced fetchStatus path so view-initiated refreshes don't cause parallel health checks.
                _ = try await fetchStatus()

                refreshScheduler.recordSuccess()
                lastRefreshResult = refreshScheduler.observation.lastRefreshResult
                currentBackoffSeconds = refreshScheduler.observation.currentBackoffSeconds
                nextScheduledRefreshAt = refreshScheduler.observation.nextScheduledRefreshAt

                clearErrorOnSuccess()
                stopCountdown()
                state = .connected
                refreshToken = UUID()

                try await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
            } catch {
                emit(error: error)

                let summary = "failure: \(GatewayErrorPresenter.message(for: error))"
                let delay = refreshScheduler.recordFailure(summary: summary)
                lastRefreshResult = refreshScheduler.observation.lastRefreshResult
                currentBackoffSeconds = refreshScheduler.observation.currentBackoffSeconds
                nextScheduledRefreshAt = refreshScheduler.observation.nextScheduledRefreshAt

                state = .disconnected

                let nextRetryAt = Date().addingTimeInterval(delay)
                state = .reconnecting(nextRetryAt: nextRetryAt)
                startCountdown(to: nextRetryAt)

                // Sleep until next retry.
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                if Task.isCancelled { return }
            }
        }
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
        let now = Date()

        if var current = lastError, current.message == message {
            // Dedupe: do not re-emit identical errors too frequently (prevents banner timestamp spam).
            if now.timeIntervalSince(current.lastEmittedAt) < errorDedupeWindowSeconds {
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
            clearErrorOnSuccess()
            stopCountdown()
            state = .connected
            return value
        } catch {
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

