import SwiftUI

@MainActor
final class ProvidersViewModel: ObservableObject {
    @Published var providers: [ProviderHealth] = []

    var sortedProviders: [ProviderHealth] {
        providers.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status.sortRank < rhs.status.sortRank
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func refreshStub() {
        // NOTE: This is intentionally a stub until the Gateway exposes provider health.
        // When the API exists, replace this with a real fetch (and keep the UI contract).
        providers = [
            ProviderHealth(key: "openai", name: "OpenAI", status: .unknown, message: nil),
            ProviderHealth(key: "discord", name: "Discord", status: .unknown, message: nil),
            ProviderHealth(key: "telegram", name: "Telegram", status: .unknown, message: nil),
            ProviderHealth(key: "signal", name: "Signal", status: .unknown, message: nil)
        ]
    }
}

struct ProvidersView: View {
    @EnvironmentObject private var connection: GatewayConnectionStore
    @StateObject private var model = ProvidersViewModel()

    private let onOpenSettings: (() -> Void)?

    init(onOpenSettings: (() -> Void)? = nil) {
        self.onOpenSettings = onOpenSettings
    }

    private var shouldShowGatewayUnavailableState: Bool {
        connection.state != .connected
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
            return "Update your gateway token in Settings, then reconnect."
        case .disconnected, .reconnecting:
            return "Check your gateway URL in Settings, then reconnect."
        case .connected:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.sectionSpacing) {
            HStack {
                Text("Providers")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    model.refreshStub()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(shouldShowGatewayUnavailableState)
                .accessibilityHint(Text("Refreshes provider status"))
            }

            if shouldShowGatewayUnavailableState {
                GlassCard {
                    ContentUnavailableView {
                        Label(gatewayUnavailableTitle, systemImage: gatewayUnavailableIcon)
                    } description: {
                        Text(gatewayUnavailableDescription)
                    } actions: {
                        if let onOpenSettings {
                            Button("Open Settings") { onOpenSettings() }
                        }

                        Button("Retry") {
                            connection.retryNow()
                        }
                        .accessibilityHint(Text("Retries connecting to the gateway"))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                GlassSurface {
                    List(model.sortedProviders) { provider in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Self.color(for: provider.status))
                                .frame(width: 8, height: 8)
                                .padding(.top, AppTheme.Layout.rowVerticalPadding)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.name)
                                    .font(.body)

                                if let message = provider.message, !message.isEmpty {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(provider.status.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Self.color(for: provider.status))
                        }
                        .padding(.vertical, AppTheme.Layout.rowVerticalPadding)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                GlassCard {
                    Text("Provider health is currently stubbed until the Gateway exposes an API.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppTheme.Layout.pagePadding)
        .task(id: connection.refreshToken) {
            if connection.state == .connected {
                model.refreshStub()
            }
        }
    }

    private static func color(for status: ProviderHealth.Status) -> Color {
        switch status {
        case .ok:
            return .green
        case .degraded:
            return .orange
        case .down:
            return .red
        case .unknown:
            return .secondary
        }
    }
}
