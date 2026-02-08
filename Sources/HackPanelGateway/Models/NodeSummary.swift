import Foundation

public enum NodeConnectionState: String, Codable, Sendable {
    case online
    case offline
    case unknown
}

public struct NodeSummary: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var state: NodeConnectionState
    public var lastSeenAt: Date?

    public init(id: String, name: String, state: NodeConnectionState, lastSeenAt: Date? = nil) {
        self.id = id
        self.name = name
        self.state = state
        self.lastSeenAt = lastSeenAt
    }
}
