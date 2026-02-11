import Foundation
import Combine

/// Lightweight, in-app operator timeline for answering: "what happened? when?"
///
/// Intentionally simple: the backing data source can evolve from local observation
/// (connection state + errors) to real gateway event streaming later.
@MainActor
final class OperatorTimelineStore: ObservableObject {
    struct Event: Identifiable, Equatable {
        enum Kind: Equatable {
            case connectionState
            case connectionError
            case session
        }

        var id: UUID = UUID()
        var kind: Kind
        var date: Date
        var title: String
        var detail: String?
    }

    @Published private(set) var events: [Event] = []

    private var cancellables: Set<AnyCancellable> = []
    private var lastState: GatewayConnectionStore.State?
    private var lastErrorMessage: String?

    init(observing gateway: any GatewayConnectionObserving) {
        // Seed current state so we don't immediately double-log at init.
        lastState = gateway.state

        gateway.statePublisher
            .sink { [weak self] newState in
                self?.record(state: newState)
            }
            .store(in: &cancellables)

        gateway.lastErrorPublisher
            .compactMap { $0?.message }
            .sink { [weak self] message in
                self?.record(errorMessage: message)
            }
            .store(in: &cancellables)
    }

    func record(state: GatewayConnectionStore.State, at date: Date = Date()) {
        guard lastState != state else { return }
        lastState = state

        let title: String = {
            switch state {
            case .connected:
                return "Gateway connected"
            case .disconnected:
                return "Gateway disconnected"
            case .authFailed:
                return "Gateway auth failed"
            case .reconnecting:
                return "Gateway reconnecting"
            }
        }()

        append(Event(kind: .connectionState, date: date, title: title, detail: nil))
    }

    func record(errorMessage: String, at date: Date = Date()) {
        // Dedupe identical messages so we don't spam timeline on repeated failures.
        guard lastErrorMessage != errorMessage else { return }
        lastErrorMessage = errorMessage

        append(Event(kind: .connectionError, date: date, title: "Connection error", detail: errorMessage))
    }

    private func append(_ event: Event) {
        events.insert(event, at: 0) // reverse chronological
        // Keep a reasonable cap for now.
        if events.count > 200 {
            events.removeLast(events.count - 200)
        }
    }
}

/// Abstraction so the timeline can be unit-tested without spinning up the full monitor loop.
@MainActor
protocol GatewayConnectionObserving: AnyObject {
    var state: GatewayConnectionStore.State { get }
    var statePublisher: AnyPublisher<GatewayConnectionStore.State, Never> { get }
    var lastErrorPublisher: AnyPublisher<GatewayConnectionStore.ConnectionError?, Never> { get }
}

extension GatewayConnectionStore: GatewayConnectionObserving {
    var statePublisher: AnyPublisher<State, Never> { $state.eraseToAnyPublisher() }
    var lastErrorPublisher: AnyPublisher<ConnectionError?, Never> { $lastError.eraseToAnyPublisher() }
}
