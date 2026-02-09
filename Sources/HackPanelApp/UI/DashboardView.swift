import SwiftUI
import HackPanelGateway

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var status: GatewayStatus?
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
            async let s = gateway.fetchStatus()
            async let n = gateway.fetchNodes()
            status = try await s
            nodes = try await n
        } catch {
            // Keep local surface area (so the page can show errors inline), but also let the
            // global banner track connection failures via GatewayConnectionStore.
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var connection: GatewayConnectionStore
    @StateObject private var model: DashboardViewModel

    init(gateway: GatewayConnectionStore) {
        _model = StateObject(wrappedValue: DashboardViewModel(gateway: gateway))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("HackPanel")
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))

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
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(error)
                                .font(.body)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gateway")
                            .font(.title3.weight(.semibold))
                        HStack(spacing: 12) {
                            StatusPill(ok: model.status?.ok)
                            Text(model.status?.version ?? "Unknown version")
                                .font(.body)
                            Spacer()
                            if let uptime = model.status?.uptimeSeconds {
                                Text("Uptime: \(Int(uptime))s")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nodes")
                            .font(.title3.weight(.semibold))
                        Text("\(model.nodes.count) total")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Divider().opacity(0.3)

                        ForEach(model.nodes.prefix(5)) { node in
                            HStack {
                                Text(node.name)
                                Spacer()
                                Text(node.state.rawValue.capitalized)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(node.state == .online ? .green : .secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(24)
        }
        .task(id: connection.refreshToken) {
            await model.refresh()
        }
    }
}

struct StatusPill: View {
    let ok: Bool?

    var body: some View {
        let (text, color): (String, Color) = {
            switch ok {
            case .some(true): return ("Running", .green)
            case .some(false): return ("Down", .red)
            case .none: return ("Unknown", .gray)
            }
        }()

        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
            .accessibilityLabel("Gateway status: \(text)")
    }
}
