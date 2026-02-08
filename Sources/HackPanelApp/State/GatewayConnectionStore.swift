import Foundation
import HackPanelGateway

@MainActor
final class GatewayConnectionStore: ObservableObject {
    enum ConnectionState: String, Sendable {
        case connected
        case disconnected
        case reconnecting
        case authFailed

        var displayName: String {
            switch self {
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            case .reconnecting: return "Reconnecting"
            case .authFailed: return "Auth failed"
            }
        }
    }

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastErrorAt: Date?

    private let client: any GatewayClient

    init(client: any GatewayClient) {
        self.client = client
    }

    func fetchStatus() async throws -> GatewayStatus {
        try await trackCall { try await client.fetchStatus() }
    }

    func fetchNodes() async throws -> [NodeSummary] {
        try await trackCall { try await client.fetchNodes() }
    }

    private func trackCall<T>(_ work: () async throws -> T) async throws -> T {
        // If we were previously disconnected or authFailed, show a transient "reconnecting" state
        // while an operation is in flight.
        switch state {
        case .connected:
            break
        case .disconnected, .authFailed, .reconnecting:
            state = .reconnecting
        }

        do {
            let value = try await work()
            state = .connected
            return value
        } catch {
            record(error: error)
            throw error
        }
    }

    private func record(error: Error) {
        lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        lastErrorAt = Date()

        if isAuthFailure(error: error) {
            state = .authFailed
        } else {
            state = .disconnected
        }
    }

    private func isAuthFailure(error: Error) -> Bool {
        guard let gce = error as? GatewayClientError else { return false }
        switch gce {
        case .gatewayError(let code, let message, _):
            let haystack = [code, message]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            return haystack.contains("auth") || haystack.contains("unauthorized") || haystack.contains("forbidden")
        default:
            return false
        }
    }
}
