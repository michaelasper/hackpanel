import Foundation
import Combine

@MainActor
final class OperatorTimelineStore: ObservableObject {
    struct Event: Identifiable, Equatable {
        enum Kind: Equatable {
            case connectionState
            case connectionError
        }

        var id: UUID = UUID()
        var kind: Kind
        var timestamp: Date
        var title: String
        var detail: String?
    }

    @Published private(set) var events: [Event] = []

    private let maxEvents: Int
    private var cancellables: Set<AnyCancellable> = []

    init(maxEvents: Int = 200) {
        self.maxEvents = maxEvents
    }

    func startObserving(connection: GatewayConnectionStore) {
        cancellables.removeAll()

        // Connection state changes.
        connection.$state
            .removeDuplicates()
            .sink { [weak self] state in
                self?.record(state: state, at: Date())
            }
            .store(in: &cancellables)

        // Error message changes.
        connection.$lastError
            .removeDuplicates()
            .sink { [weak self] err in
                guard let self else { return }
                guard let err else { return }
                self.record(errorMessage: err.message, at: err.lastEmittedAt)
            }
            .store(in: &cancellables)
    }

    func clear() {
        events.removeAll()
    }

    // MARK: - Recording (testable)

    func record(state: GatewayConnectionStore.State, at timestamp: Date) {
        let title: String
        let detail: String?

        switch state {
        case .connected:
            title = "Gateway connected"
            detail = nil
        case .disconnected:
            title = "Gateway disconnected"
            detail = nil
        case .authFailed:
            title = "Gateway auth failed"
            detail = "Update your token in Settings, then reconnect."
        case .reconnecting(let nextRetryAt):
            title = "Gateway reconnecting"
            let seconds = max(0, Int(nextRetryAt.timeIntervalSince(timestamp)))
            detail = seconds > 0 ? "Retrying in ~\(seconds)s" : "Retrying now"
        }

        append(Event(kind: .connectionState, timestamp: timestamp, title: title, detail: detail))
    }

    func record(errorMessage: String, at timestamp: Date) {
        append(Event(kind: .connectionError, timestamp: timestamp, title: "Connection error", detail: errorMessage))
    }

    private func append(_ event: Event) {
        events.insert(event, at: 0)
        if events.count > maxEvents {
            events.removeLast(events.count - maxEvents)
        }
    }
}
