import Foundation

// Internal payload models used by LiveGatewayClient for best-effort decoding.
// Kept internal so tests can validate decoding without needing a live Gateway.

struct StatusPayload: Codable, Sendable {
    var ok: Bool?
    var version: String?
    var uptimeSeconds: Double?
    var uptimeMs: Double?
}

struct NodeListPayload: Codable, Sendable {
    /// Common shape: {"nodes": [ ... ]}
    var nodes: [NodeListEntry]?

    /// Alternate shape: {"items": [ ... ]}
    var items: [NodeListEntry]?

    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
            self.nodes = try keyed.decodeIfPresent([NodeListEntry].self, forKey: .nodes)
            self.items = try keyed.decodeIfPresent([NodeListEntry].self, forKey: .items)
            return
        }

        // Fallback: payload is directly an array.
        var unkeyed = try decoder.unkeyedContainer()
        var arr: [NodeListEntry] = []
        while !unkeyed.isAtEnd {
            arr.append(try unkeyed.decode(NodeListEntry.self))
        }
        self.items = arr
        self.nodes = nil
    }

    enum CodingKeys: String, CodingKey { case nodes, items }
}

struct NodeListEntry: Codable, Sendable {
    var id: String?
    var nodeId: String?
    var deviceId: String?

    var name: String?
    var host: String?

    var connected: Bool?

    /// Some shapes use lastSeenAt (ISO-8601 string).
    var lastSeenAt: Date?
}
