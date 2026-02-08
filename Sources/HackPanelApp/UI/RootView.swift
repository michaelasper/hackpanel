import SwiftUI
import HackPanelGateway

struct RootView: View {
    let client: any GatewayClient

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("Overview") { DashboardView(client: client) }
                NavigationLink("Nodes") { NodesView(client: client) }
                NavigationLink("Settings") { SettingsView() }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            DashboardView(client: client)
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
