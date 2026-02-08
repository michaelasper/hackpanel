import SwiftUI

struct SettingsView: View {
    @AppStorage("gatewayBaseURL") private var gatewayBaseURL: String = "http://127.0.0.1:8787"

    var body: some View {
        Form {
            Section("Gateway") {
                TextField("Base URL", text: $gatewayBaseURL)
                    .textFieldStyle(.roundedBorder)
                Text("Remote hosts are allowed. For now this is used only for future live API wiring.")
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
