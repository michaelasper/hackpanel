import Foundation

public struct GatewayConfiguration: Sendable {
    public var baseURL: URL
    public var token: String?

    public init(baseURL: URL, token: String? = nil) {
        self.baseURL = baseURL
        self.token = token
    }
}

public protocol GatewayClient: Sendable {
    func fetchStatus() async throws -> GatewayStatus
    func fetchNodes() async throws -> [NodeSummary]
}

public enum GatewayClientError: Error, LocalizedError, Sendable {
    case notImplemented
    case timeout(operation: String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Not implemented yet."
        case .timeout(let operation):
            return "Timed out while waiting for gateway during: \(operation)"
        }
    }
}
