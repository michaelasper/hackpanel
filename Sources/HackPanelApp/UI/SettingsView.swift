import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @ObservedObject var gateway: GatewayConnectionStore

    // NOTE: OpenClaw Gateway multiplexes WS + HTTP on the same port (default 18789).
    // HackPanel will eventually use the Gateway WebSocket protocol (not plain REST).
    @AppStorage("gatewayBaseURL") private var gatewayBaseURL: String = "http://127.0.0.1:18789"
    @AppStorage("gatewayToken") private var gatewayToken: String = ""

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
                TextField("Base URL", text: $gatewayBaseURL)
                    .textFieldStyle(.roundedBorder)

                SecureField("Token", text: $gatewayToken)
                    .textFieldStyle(.roundedBorder)

                Text("HackPanel connects to the OpenClaw Gateway WebSocket RPC endpoint (same port as HTTP; default 18789). Token is optional unless your gateway requires it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
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

                ScrollView {
                    Text(diagnosticsText)
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 180)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                }

                Text("Token is fully redacted (last-4 shown).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                GlassPrimitivesDemoView()
            }
        }
        .padding(24)
    }

    private var diagnosticsText: String {
        DiagnosticsFormatter.format(
            .init(
                appVersion: appVersion,
                appBuild: appBuild,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                gatewayBaseURL: gatewayBaseURL,
                gatewayToken: gatewayToken,
                connectionState: gateway.state.displayName,
                lastErrorMessage: gateway.lastErrorMessage,
                lastErrorAt: gateway.lastErrorAt
            )
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
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
