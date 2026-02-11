import SwiftUI

#if os(macOS)
import AppKit
#endif

struct LogsView: View {
    @EnvironmentObject private var connection: GatewayConnectionStore

    private let onOpenSettings: (() -> Void)?

    init(onOpenSettings: (() -> Void)? = nil) {
        self.onOpenSettings = onOpenSettings
    }

    private var logsText: String {
        let lines = connection.recentLogLines
        guard !lines.isEmpty else {
            return ""
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private var shouldShowGatewayUnavailableState: Bool {
        connection.state != .connected && connection.recentLogLines.isEmpty
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
                Text("Logs")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    copyToPasteboard(logsText)
                } label: {
                    Label("Copy visible logs", systemImage: "doc.on.doc")
                }
                .disabled(connection.recentLogLines.isEmpty)
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
            } else if connection.recentLogLines.isEmpty {
                GlassCard {
                    ContentUnavailableView {
                        Label("No logs yet", systemImage: "doc.text")
                    } description: {
                        Text("Recent gateway logs will appear here after the app makes a connection attempt.")
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                GlassSurface {
                    ScrollView {
                        Text(logsText)
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(minHeight: 220)
                }
            }
        }
        .padding(AppTheme.Layout.pagePadding)
    }

    private func copyToPasteboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
