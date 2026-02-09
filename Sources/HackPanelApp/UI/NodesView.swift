import SwiftUI
import HackPanelGateway

@MainActor
final class NodesViewModel: ObservableObject {
    @Published var nodes: [NodeSummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var sortedNodes: [NodeSummary] {
        nodes.sorted { lhs, rhs in
            if lhs.state != rhs.state {
                // Online first, then offline, then unknown.
                return lhs.state.sortRank < rhs.state.sortRank
            }
            if lhs.name != rhs.name {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }

    private let gateway: GatewayConnectionStore

    init(gateway: GatewayConnectionStore) {
        self.gateway = gateway
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            nodes = try await gateway.fetchNodes()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}

struct NodesView: View {
    private static let lastSeenFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    @EnvironmentObject private var connection: GatewayConnectionStore
    @StateObject private var model: NodesViewModel

    init(gateway: GatewayConnectionStore) {
        _model = StateObject(wrappedValue: NodesViewModel(gateway: gateway))
    }

    private var shouldShowGatewayUnavailableState: Bool {
        // If we're disconnected/auth-failed and we have no data to show, make it obvious.
        connection.state != .connected && model.nodes.isEmpty && !model.isLoading
    }

    private var gatewayUnavailableTitle: String {
        connection.state == .authFailed ? "Authentication required" : "Gateway unavailable"
    }

    private var gatewayUnavailableIcon: String {
        connection.state == .authFailed ? "lock.slash" : "wifi.exclamationmark"
    }

    private var gatewayUnavailableDescription: String {
        switch connection.state {
        case .authFailed:
            return "Update your gateway token in Settings, then retry."
        case .disconnected, .reconnecting:
            return "Check your gateway URL in Settings, or try again."
        case .connected:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nodes")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
            }

            if let error = model.errorMessage {
                GlassCard {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.body)
                    }
                }
            }

            if shouldShowGatewayUnavailableState {
                ContentUnavailableView {
                    Label(gatewayUnavailableTitle, systemImage: gatewayUnavailableIcon)
                } description: {
                    Text(gatewayUnavailableDescription)
                } actions: {
                    Button("Retry now") {
                        connection.retryNow()
                        Task { await model.refresh() }
                    }
                    .disabled(model.isLoading)
                }
            } else if model.nodes.isEmpty, !model.isLoading, model.errorMessage == nil {
                ContentUnavailableView {
                    Label("No paired nodes", systemImage: "sensor.tag.radiowaves.forward")
                } description: {
                    Text("Pair a node in your gateway, then refresh.")
                } actions: {
                    Button("Refresh") { Task { await model.refresh() } }
                        .disabled(model.isLoading)
                }
            } else {
                List(model.sortedNodes) { node in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Circle()
                            .fill(Self.color(for: node.state))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.name)
                                .font(.body)

                            HStack(spacing: 8) {
                                Text(node.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let lastSeen = node.lastSeenAt {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(Self.lastSeenText(for: lastSeen))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()

                        Text(node.state.rawValue.capitalized)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(node.state == .online ? .green : .secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(24)
        .task(id: connection.refreshToken) { await model.refresh() }
    }

    private static func lastSeenText(for date: Date) -> String {
        Self.lastSeenFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static func color(for state: NodeConnectionState) -> Color {
        switch state {
        case .online: return .green
        case .offline: return .gray
        case .unknown: return .orange
        }
    }
}

private extension NodeConnectionState {
    var sortRank: Int {
        switch self {
        case .online: return 0
        case .offline: return 1
        case .unknown: return 2
        }
    }
}
