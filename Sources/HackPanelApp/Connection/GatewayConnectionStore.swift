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

    var lastErrorMessage: String? { lastError?.message }
    var lastErrorAt: Date? { lastError?.lastEmittedAt }

    /// Bump this to cause views to refresh their data.
    @Published private(set) var refreshToken: UUID = UUID()

    private var client: any GatewayClient

    private var monitorTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var countdownToken: UUID?

    private var consecutiveFailures: Int = 0

    // Tunables
    private let pollIntervalSeconds: TimeInterval = 15
    private let baseBackoffSeconds: TimeInterval = 1
    private let maxBackoffSeconds: TimeInterval = 30
    private let errorDedupeWindowSeconds: TimeInterval = 10

    init(client: any GatewayClient) {
        self.client = client

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
    /// This is DEBUG-only and is ignored for empty/falsey values.
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
        consecutiveFailures = max(consecutiveFailures, 1) // ensure backoff is active
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
                lastHealthCheckAt = Date()
                _ = try await client.fetchStatus()
                consecutiveFailures = 0
                clearErrorOnSuccess()
                stopCountdown()
                state = .connected
                refreshToken = UUID()

                try await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
            } catch {
                consecutiveFailures += 1
                emit(error: error)

                state = .disconnected

                let delay = computeBackoffDelaySeconds(failureCount: consecutiveFailures)
                let nextRetryAt = Date().addingTimeInterval(delay)
                state = .reconnecting(nextRetryAt: nextRetryAt)
                startCountdown(to: nextRetryAt)

                // Sleep until next retry.
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                if Task.isCancelled { return }
            }
        }
    }

    private func computeBackoffDelaySeconds(failureCount: Int) -> TimeInterval {
        let capped = min(8, max(1, failureCount))
        let exp = pow(2.0, Double(capped - 1))
        let raw = min(maxBackoffSeconds, baseBackoffSeconds * exp)
        // Jitter in [0.6, 1.4]
        let jitter = Double.random(in: 0.6...1.4)
        return max(0.5, min(maxBackoffSeconds, raw * jitter))
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
        try await trackCall { try await client.fetchStatus() }
    }

    func fetchNodes() async throws -> [NodeSummary] {
        try await trackCall { try await client.fetchNodes() }
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

