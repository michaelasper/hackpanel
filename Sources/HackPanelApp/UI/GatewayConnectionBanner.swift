import SwiftUI

struct GatewayConnectionBanner: View {
    @EnvironmentObject private var connection: GatewayConnectionStore

    var body: some View {
        if shouldShow {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Divider().opacity(0.25)
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var shouldShow: Bool {
        switch connection.state {
        case .connected:
            return connection.lastError != nil
        case .disconnected, .reconnecting, .authFailed:
            return true
        }
    }

    @ViewBuilder
    private var content: some View {
        HStack(alignment: .center, spacing: 10) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.subheadline.weight(.semibold))

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            Button {
                connection.retryNow()
            } label: {
                Text("Reconnect")
            }
            .buttonStyle(.bordered)
        }
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        switch connection.state {
        case .connected:
            return "Gateway error"
        case .disconnected, .reconnecting:
            return "Disconnected from Gateway"
        case .authFailed:
            return "Authentication failed"
        }
    }

    private var detail: String? {
        var parts: [String] = []

        if case .reconnecting = connection.state {
            if let s = connection.countdownSeconds {
                parts.append(s == 0 ? "Retrying now…" : "Retrying in \(s)s")
            } else {
                parts.append("Retrying…")
            }
        }

        if let msg = connection.lastError?.message {
            parts.append(msg)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    @ViewBuilder
    private var icon: some View {
        switch connection.state {
        case .connected:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .disconnected:
            Image(systemName: "wifi.slash")
        case .authFailed:
            Image(systemName: "lock.slash.fill")
                .foregroundStyle(.orange)
        case .reconnecting:
            ProgressView()
                .controlSize(.small)
        }
    }
}
