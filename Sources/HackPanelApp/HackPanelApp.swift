import SwiftUI
import HackPanelGateway
import HackPanelGatewayMocks

@main
struct HackPanelApp: App {
    // Default to mock data so the app runs even without a live Gateway.
    private let client: any GatewayClient = MockGatewayClient(scenario: .demo)

    var body: some Scene {
        WindowGroup {
            RootView(client: client)
        }
        .windowStyle(.automatic)
    }
}
