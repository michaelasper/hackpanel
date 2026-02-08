import SwiftUI
import HackPanelGateway
import HackPanelGatewayMocks

@main
struct HackPanelApp: App {
    @AppStorage("gatewayBaseURL") private var gatewayBaseURL: String = "http://127.0.0.1:18789"
    @AppStorage("gatewayToken") private var gatewayToken: String = ""

    private var client: any GatewayClient {
        guard let url = URL(string: gatewayBaseURL) else {
            return MockGatewayClient(scenario: .demo)
        }

        let token = gatewayToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let cfg = GatewayConfiguration(baseURL: url, token: token.isEmpty ? nil : token)
        return LiveGatewayClient(configuration: cfg)
    }

    var body: some Scene {
        WindowGroup {
            RootView(client: client)
        }
        .windowStyle(.automatic)
    }
}
