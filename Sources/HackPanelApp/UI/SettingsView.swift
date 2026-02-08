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

                Text("Used for upcoming live Gateway wiring. For now the app uses mock data.")
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

