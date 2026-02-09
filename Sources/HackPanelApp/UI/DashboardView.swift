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
            VStack(alignment: .leading, spacing: AppTheme.Layout.stackSpacing) {
                HStack(alignment: .firstTextBaseline) {
                    Text("HackPanel")
                        .font(AppTheme.Typography.pageTitle)

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
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Gateway health")
                            .font(AppTheme.Typography.sectionTitle)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connection")
                                    .font(AppTheme.Typography.captionLabel)
                                    .foregroundStyle(.secondary)
                                Text(connection.state.displayName)
                                    .font(AppTheme.Typography.bodyEmphasis)
                            }

                            Divider().opacity(0.25)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Status")
                                    .font(AppTheme.Typography.captionLabel)
                                    .foregroundStyle(.secondary)
                                StatusPill(ok: model.status?.ok)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Last check")
                                    .font(AppTheme.Typography.captionLabel)
                                    .foregroundStyle(.secondary)
                                if let last = connection.lastHealthCheckAt {
                                    Text(last, format: .dateTime.month().day().hour().minute().second())
                                        .font(AppTheme.Typography.captionLabel)
                                } else {
                                    Text("Never")
                                        .font(AppTheme.Typography.captionLabel)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            Text(model.status?.version ?? "Unknown version")
                                .font(.body)
                            Spacer()
                            if let uptime = model.status?.uptimeSeconds {
                                Text("Uptime: \(Int(uptime))s")
                                    .font(AppTheme.Typography.captionLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nodes")
                            .font(AppTheme.Typography.sectionTitle)
                        Text("\(model.nodes.count) total")
                            .font(AppTheme.Typography.captionLabel)
                            .foregroundStyle(.secondary)

                        Divider().opacity(0.3)

                        ForEach(model.nodes.prefix(5)) { node in
                            HStack {
                                Text(node.name)
                                Spacer()
                                Text(node.state.rawValue.capitalized)
                                    .font(AppTheme.Typography.captionLabel)
                                    .foregroundStyle(node.state == .online ? .green : .secondary)
                            }
                            .padding(.vertical, AppTheme.Layout.rowVerticalPadding)
                        }
                    }
                }
            }
            .padding(AppTheme.Layout.pagePadding)
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

        GlassSurface {
            Text(text)
                .font(AppTheme.Typography.captionEmphasis)
                .padding(.horizontal, AppTheme.Glass.pillHorizontalPadding)
                .padding(.vertical, AppTheme.Glass.pillVerticalPadding)
        }
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .fill(color.opacity(0.10))
        }
        .overlay {
            Capsule()
                .strokeBorder(color.opacity(0.35), lineWidth: 1)
        }
        .accessibilityLabel("Gateway status: \(text)")
    }
}
