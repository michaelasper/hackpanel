import SwiftUI
import HackPanelGateway

@MainActor
final class NodesViewModel: ObservableObject {
    @Published var nodes: [NodeSummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

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

            List(model.nodes) { node in
                HStack {
                    VStack(alignment: .leading) {
                        Text(node.name)
                        Text(node.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(node.state.rawValue.capitalized)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(node.state == .online ? .green : .secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(24)
        .task { await model.refresh() }
    }
}
