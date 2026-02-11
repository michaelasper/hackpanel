import SwiftUI

struct TimelineView: View {
    private static let timestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()

    @EnvironmentObject private var connection: GatewayConnectionStore
    @StateObject private var timeline: OperatorTimelineStore = OperatorTimelineStore()

    private let onOpenSettings: (() -> Void)?

    init(onOpenSettings: (() -> Void)? = nil) {
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
                Button("Clear") { timeline.clear() }
                    .disabled(timeline.events.isEmpty)
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
                        Button("Reconnect") {
                            connection.retryNow()
                        }
                        .accessibilityHint(Text("Retries connecting to the gateway"))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if timeline.events.isEmpty {
                GlassCard {
                    ContentUnavailableView {
                        Label("No events yet", systemImage: "clock")
                    } description: {
                        Text("Connection and error events will show up here as you use the app.")
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                GlassSurface {
                    List(timeline.events) { event in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: icon(for: event.kind))
                                .foregroundStyle(color(for: event.kind))
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(event.title)
                                        .font(.body)

                                    Spacer()

                                    Text(Self.timestampFormatter.string(from: event.timestamp))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let detail = event.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, AppTheme.Layout.rowVerticalPadding)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .padding(AppTheme.Layout.pagePadding)
        .task {
            timeline.startObserving(connection: connection)
        }
    }

    private func icon(for kind: OperatorTimelineStore.Event.Kind) -> String {
        switch kind {
        case .connectionState:
            return "antenna.radiowaves.left.and.right"
        case .connectionError:
            return "exclamationmark.triangle.fill"
        }
    }

    private func color(for kind: OperatorTimelineStore.Event.Kind) -> Color {
        switch kind {
        case .connectionState:
            return .secondary
        case .connectionError:
            return .red
        }
    }
}
