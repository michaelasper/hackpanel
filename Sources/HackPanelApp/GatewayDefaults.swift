import Foundation

enum GatewayDefaults {
    /// OpenClaw Gateway multiplexes WS + HTTP on the same port.
    static let defaultPort: Int = 18789

    static let baseURLString: String = "http://127.0.0.1:\(defaultPort)"
}
