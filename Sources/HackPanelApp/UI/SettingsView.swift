import SwiftUI
import HackPanelGateway
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @ObservedObject var gateway: GatewayConnectionStore

    // NOTE: OpenClaw Gateway multiplexes WS + HTTP on the same port (default 18789).
    // HackPanel will eventually use the Gateway WebSocket protocol (not plain REST).
    @AppStorage("gatewayBaseURL") private var gatewayBaseURL: String = "http://127.0.0.1:18789"
    @KeychainStorage("gatewayToken") private var gatewayToken: String = ""

    @State private var draftBaseURL: String = ""
    @State private var draftToken: String = ""
    @State private var validationError: String?

    @State private var copiedAt: Date?

    private static let uiTimestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium
        return df
    }()

    var body: some View {
        Form {
            Section("Gateway") {
                TextField("Base URL", text: $draftBaseURL)
                    .textFieldStyle(.roundedBorder)

                SecureField("Token", text: $draftToken)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Apply & Reconnect") {
                        applyAndReconnect()
                    }

                    Button("Reset to Local Default") {
                        draftBaseURL = "http://127.0.0.1:18789"
                    }
                    .buttonStyle(.link)

                    Spacer()
                }

                if let validationError {
                    Text(validationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("HackPanel connects to the OpenClaw Gateway WebSocket RPC endpoint (same port as HTTP; default 18789). Token is optional unless your gateway requires it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Connection") {
                            Text(gateway.state.displayName)
                        }

                        LabeledContent("Last error") {
                            Text(gateway.lastErrorMessage ?? "(none)")
                                .textSelection(.enabled)
                        }

                        if let at = gateway.lastErrorAt {
                            LabeledContent("Last error at") {
                                Text(Self.uiTimestampFormatter.string(from: at))
                            }
                        }

                        if let until = reconnectBackoffUntil, until > Date() {
                            let remaining = max(0, Int(until.timeIntervalSince(Date()).rounded(.up)))
                            LabeledContent("Reconnect backoff") {
                                Text("\(remaining)s")
                            }
                        }

                        Button {
                            copyToPasteboard(diagnosticsText)
                            copiedAt = Date()
                        } label: {
                            Label("Copy Diagnostics", systemImage: "doc.on.doc")
                        }

                        if let copiedAt {
                            Text("Copied at \(Self.uiTimestampFormatter.string(from: copiedAt)).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        GlassSurface {
                            ScrollView {
                                Text(diagnosticsText)
                                    .textSelection(.enabled)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                            }
                            .frame(minHeight: 180)
                        }

                        Text("Token is fully redacted (last-4 shown).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Appearance") {
                GlassCard {
                    GlassPrimitivesDemoView()
                }
            }
        }
        .padding(24)
        .onAppear {
            if draftBaseURL.isEmpty { draftBaseURL = gatewayBaseURL }
            if draftToken.isEmpty { draftToken = gatewayToken }
        }
    }

    private func applyAndReconnect() {
        let trimmedBaseURL = draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = draftToken.trimmingCharacters(in: .whitespacesAndNewlines)

        let url: URL
        switch GatewaySettingsValidator.validateBaseURL(trimmedBaseURL) {
        case .success(let validated):
            url = validated
            validationError = nil
        case .failure(let error):
            validationError = error.message
            return
        }

        // Persist settings.
        gatewayBaseURL = trimmedBaseURL
        gatewayToken = trimmedToken

        // Apply immediately to the live connection store.
        let cfg = GatewayConfiguration(baseURL: url, token: trimmedToken.isEmpty ? nil : trimmedToken)
        gateway.updateClient(LiveGatewayClient(configuration: cfg))
    }

    private var diagnosticsText: String {
        DiagnosticsFormatter.format(
            .init(
                appVersion: appVersion,
                appBuild: appBuild,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                deviceId: deviceId,
                gatewayBaseURL: gatewayBaseURL,
                gatewayToken: gatewayToken,
                connectionState: gateway.state.displayName,
                lastErrorMessage: gateway.lastErrorMessage,
                lastErrorAt: gateway.lastErrorAt,
                reconnectBackoffUntil: reconnectBackoffUntil
            )
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var reconnectBackoffUntil: Date? {
        switch gateway.state {
        case .reconnecting(let nextRetryAt):
            return nextRetryAt
        default:
            return nil
        }
    }

    private var deviceId: String? {
        try? DeviceIdentity.deviceId()
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    private func copyToPasteboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
