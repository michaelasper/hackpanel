import Foundation
import HackPanelGateway

@MainActor
final class GatewayConnectionStore: ObservableObject {
    enum State: Equatable {
        case connected
        case reconnecting(nextRetryAt: Date)
        case disconnected
    }

    struct ConnectionError: Equatable {
        var message: String
        /// The time we first observed this error message (used for dedupe/throttle).
        var firstSeenAt: Date
        /// The last time we allowed the UI to update for this message.
        var lastEmittedAt: Date
    }

    @Published private(set) var state: State = .connected
    @Published private(set) var lastError: ConnectionError?
    @Published private(set) var countdownSeconds: Int?

    /// Bump this to cause views to refresh their data.
    @Published private(set) var refreshToken: UUID = UUID()

    private var client: any GatewayClient

    private var monitorTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    private var consecutiveFailures: Int = 0

    // Tunables
    private let pollIntervalSeconds: TimeInterval = 15
    private let baseBackoffSeconds: TimeInterval = 1
    private let maxBackoffSeconds: TimeInterval = 30
    private let errorDedupeWindowSeconds: TimeInterval = 10

    init(client: any GatewayClient) {
        self.client = client
    }

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

    private func runMonitorLoop() async {
        // Attempt immediately.
        while !Task.isCancelled {
            do {
                _ = try await client.fetchStatus()
                consecutiveFailures = 0
                clearErrorOnSuccess()
                state = .connected
                countdownSeconds = nil
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
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let remaining = max(0, Int(ceil(date.timeIntervalSinceNow)))
                self.countdownSeconds = remaining
                if remaining <= 0 { return }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func emit(error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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
}
