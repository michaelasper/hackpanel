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
            if lhs.name != rhs.name { return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }
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
    static let lastSeenFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    @EnvironmentObject private var connection: GatewayConnectionStore
    @StateObject private var model: NodesViewModel

    init(gateway: GatewayConnectionStore) {
        _model = StateObject(wrappedValue: NodesViewModel(gateway: gateway))
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
                Text(error)
                    .foregroundStyle(.red)
            }

            if model.nodes.isEmpty, !model.isLoading, model.errorMessage == nil {
                ContentUnavailableView("No paired nodes", systemImage: "sensor.tag.radiowaves.forward")
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

                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(Self.lastSeenText(for: node.lastSeenAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
}
