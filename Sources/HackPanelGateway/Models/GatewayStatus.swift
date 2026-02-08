import Foundation

public struct GatewayStatus: Codable, Sendable, Equatable {
    public var ok: Bool
    public var version: String?
    public var uptimeSeconds: Double?

    public init(ok: Bool, version: String? = nil, uptimeSeconds: Double? = nil) {
        self.ok = ok
        self.version = version
        self.uptimeSeconds = uptimeSeconds
    }
}
