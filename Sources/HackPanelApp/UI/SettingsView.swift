import SwiftUI

struct SettingsView: View {
    // NOTE: OpenClaw Gateway multiplexes WS + HTTP on the same port (default 18789).
    // HackPanel will eventually use the Gateway WebSocket protocol (not plain REST).
    @AppStorage("gatewayBaseURL") private var gatewayBaseURL: String = "http://127.0.0.1:18789"
    @AppStorage("gatewayToken") private var gatewayToken: String = ""

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

            Section("Appearance") {
                Text("Liquid glass defaults will live here (blur intensity, contrast, reduce motion).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}
