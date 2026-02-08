import SwiftUI
import HackPanelGateway

struct RootView: View {
    @StateObject private var gateway: GatewayConnectionStore

    init(client: any GatewayClient) {
        _gateway = StateObject(wrappedValue: GatewayConnectionStore(client: client))
    }

    var body: some View {
        VStack(spacing: 0) {
            ConnectionBannerView(data: bannerData)

            NavigationSplitView {
                List {
                    NavigationLink("Overview") { DashboardView(gateway: gateway) }
                    NavigationLink("Nodes") { NodesView(gateway: gateway) }
                    NavigationLink("Settings") { SettingsView() }
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            } detail: {
                DashboardView(gateway: gateway)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var bannerData: ConnectionBannerData {
        let state = gateway.state
        let (icon, color): (String, Color) = {
            switch state {
            case .connected: return ("checkmark.circle.fill", .green)
            case .reconnecting: return ("arrow.triangle.2.circlepath.circle.fill", .orange)
            case .authFailed: return ("lock.slash.fill", .red)
            case .disconnected: return ("xmark.octagon.fill", .red)
            }
        }()

        let timestampText: String? = gateway.lastErrorAt.map { date in
            let df = DateFormatter()
            df.dateStyle = .none
            df.timeStyle = .medium
            return df.string(from: date)
        }

        return ConnectionBannerData(
            stateText: state.displayName,
            message: gateway.lastErrorMessage,
            timestampText: timestampText,
            color: color,
            icon: icon
        )
    }
}
