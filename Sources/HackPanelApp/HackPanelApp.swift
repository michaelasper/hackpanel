import SwiftUI
import HackPanelGateway
import HackPanelGatewayMocks

@main
struct HackPanelApp: App {
    @AppStorage("gatewayBaseURL") private var gatewayBaseURL: String = "http://127.0.0.1:18789"
    @KeychainStorage("gatewayToken") private var gatewayToken: String = ""

    private var client: any GatewayClient {
        guard let url = URL(string: gatewayBaseURL) else {
            #if DEBUG
            return MockGatewayClient(scenario: .demo)
            #else
            return InvalidGatewayClient(rawBaseURL: gatewayBaseURL)
            #endif
        }

        let token = gatewayToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let cfg = GatewayConfiguration(baseURL: url, token: token.isEmpty ? nil : token)
        return LiveGatewayClient(configuration: cfg)
    }

    private struct InvalidGatewayClient: GatewayClient {
        let rawBaseURL: String

        func fetchStatus() async throws -> GatewayStatus {
            throw GatewayClientError.invalidBaseURL(rawBaseURL)
        }

        func fetchNodes() async throws -> [NodeSummary] {
            throw GatewayClientError.invalidBaseURL(rawBaseURL)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(client: client)
        }
        .windowStyle(.automatic)
    }
}
