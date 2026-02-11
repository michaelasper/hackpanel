import Foundation

public struct GatewayStatus: Codable, Sendable, Equatable {
    public var ok: Bool

    /// Gateway version string (semver-ish). Shape depends on the server.
    public var version: String?

    /// Optional build/commit metadata when the server exposes it.
    ///
    /// The upstream Gateway status payload is not strictly specified, so we decode these
    /// best-effort and treat them as purely informational.
    public var build: String?
    public var commit: String?

    public var uptimeSeconds: Double?

    public init(
        ok: Bool,
        version: String? = nil,
        build: String? = nil,
        commit: String? = nil,
        uptimeSeconds: Double? = nil
    ) {
        self.ok = ok
        self.version = version
        self.build = build
        self.commit = commit
        self.uptimeSeconds = uptimeSeconds
    }
}
