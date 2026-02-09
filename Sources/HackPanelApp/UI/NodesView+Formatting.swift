import SwiftUI
import HackPanelGateway

extension NodesView {
    static func color(for state: NodeConnectionState) -> Color {
        switch state {
        case .online:
            return .green
        case .offline:
            return .gray
        case .unknown:
            return .orange
        }
    }

    static func lastSeenText(for date: Date?) -> String {
        guard let date else { return "Last seen: unknown" }
        return "Last seen \(lastSeenFormatter.localizedString(for: date, relativeTo: Date()))"
    }
}

extension NodeConnectionState {
    var sortRank: Int {
        switch self {
        case .online: 0
        case .offline: 1
        case .unknown: 2
        }
    }
}
