import SwiftUI

struct OperatorTimelineView: View {
    @EnvironmentObject private var connection: GatewayConnectionStore
    @StateObject private var timeline: OperatorTimelineStore

    private let onOpenSettings: (() -> Void)?

    init(gateway: GatewayConnectionStore, onOpenSettings: (() -> Void)? = nil) {
        _timeline = StateObject(wrappedValue: OperatorTimelineStore(observing: gateway))
        self.onOpenSettings = onOpenSettings
    }

    private var shouldShowGatewayUnavailableState: Bool {
        connection.state != .connected && timeline.events.isEmpty
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
                Text("Timeline")
                    .font(.title2.weight(.semibold))
                Spacer()
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

                        Button("Reconnect") { connection.retryNow() }
                            .accessibilityHint(Text("Retries connecting to the gateway"))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if timeline.events.isEmpty {
                GlassCard {
                    ContentUnavailableView {
                        Label("No events yet", systemImage: "clock")
                    } description: {
                        Text("Connection events and errors will appear here as they happen.")
                    } actions: {
                        Button("Reconnect") { connection.retryNow() }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                GlassSurface {
                    List(timeline.events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: icon(for: event.kind))
                                    .foregroundStyle(color(for: event.kind))

                                Text(event.title)
                                    .font(.body.weight(.medium))

                                Spacer()

                                Text(event.date, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let detail = event.detail {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .padding(AppTheme.Layout.pagePadding)
    }

    private func icon(for kind: OperatorTimelineStore.Event.Kind) -> String {
        switch kind {
        case .connectionState:
            return "antenna.radiowaves.left.and.right"
        case .connectionError:
            return "exclamationmark.triangle.fill"
        case .session:
            return "bolt.horizontal.circle"
        }
    }

    private func color(for kind: OperatorTimelineStore.Event.Kind) -> Color {
        switch kind {
        case .connectionState:
            return .blue
        case .connectionError:
            return .orange
        case .session:
            return .purple
        }
    }
}
