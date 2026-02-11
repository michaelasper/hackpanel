import Foundation

struct ProviderHealth: Identifiable, Equatable {
    enum Status: String, CaseIterable, Equatable {
        case ok
        case degraded
        case down
        case unknown

        var displayName: String {
            switch self {
            case .ok: return "OK"
            case .degraded: return "Degraded"
            case .down: return "Down"
            case .unknown: return "Unknown"
            }
        }

        var sortRank: Int {
            switch self {
            case .down: return 0
            case .degraded: return 1
            case .unknown: return 2
            case .ok: return 3
            }
        }
    }

    var id: String { key }

    /// Stable key for the integration/provider (used for identity + future diffing).
    var key: String
    var name: String
    var status: Status
    var message: String?
}
