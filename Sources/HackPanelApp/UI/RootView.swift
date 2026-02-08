import SwiftUI
import HackPanelGateway

struct RootView: View {
    enum Route: Hashable {
        case overview
        case nodes
        case settings
    }

    @StateObject private var gateway: GatewayConnectionStore
    @State private var route: Route? = .overview

    init(client: any GatewayClient) {
        _gateway = StateObject(wrappedValue: GatewayConnectionStore(client: client))
    }

    var body: some View {
        VStack(spacing: 0) {
            if gateway.state != .connected {
                ConnectionBannerView(
                    data: bannerData,
                    onOpenSettings: { route = .settings }
                )
            }

            NavigationSplitView {
                List(selection: $route) {
                    NavigationLink("Overview", value: Route.overview)
                    NavigationLink("Nodes", value: Route.nodes)
                    NavigationLink("Settings", value: Route.settings)
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            } detail: {
                switch route ?? .overview {
                case .overview:
                    DashboardView(gateway: gateway)
                case .nodes:
                    NodesView(gateway: gateway)
                case .settings:
                    SettingsView()
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var bannerData: ConnectionBannerData {
        let state = gateway.state

        let timestampText: String? = gateway.lastErrorAt.map { date in
            let df = DateFormatter()
            df.dateStyle = .none
            df.timeStyle = .medium
            return "Last error at \(df.string(from: date))"
        }

        let secondsSinceError: TimeInterval? = gateway.lastErrorAt.map { Date().timeIntervalSince($0) }

        let (icon, color): (String, Color) = {
            switch state {
            case .connected:
                return ("checkmark.circle.fill", .green)
            case .reconnecting:
                return ("arrow.triangle.2.circlepath.circle.fill", .orange)
            case .authFailed:
                return ("lock.slash.fill", .red)
            case .disconnected:
                // Treat recent failures as likely transient flaps; soften the appearance a bit.
                if let s = secondsSinceError, s < 15 {
                    return ("wifi.exclamationmark", .orange)
                }
                return ("wifi.exclamationmark", .red)
            }
        }()

        let shortMessage: String? = {
            switch state {
            case .authFailed:
                return "Authentication failed — open Settings to update your token"
            default:
                return gateway.lastErrorMessage
            }
        }()

        return ConnectionBannerData(
            stateText: state.displayName,
            message: shortMessage,
            fullMessage: gateway.lastErrorMessage,
            timestampText: timestampText,
            color: color,
            icon: icon,
            showsOpenSettings: state == .authFailed
        )
    }
}
