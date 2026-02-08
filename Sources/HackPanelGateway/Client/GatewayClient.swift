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

    case invalidBaseURL(String)
    case timedOut(operation: String)
    case unexpectedFrame
    case gatewayError(code: String?, message: String?, details: String?)

    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Not implemented yet."
        case .invalidBaseURL(let raw):
            return "Invalid Gateway base URL: \(raw)"
        case .timedOut(let operation):
            return "Timed out while \(operation)."
        case .unexpectedFrame:
            return "Unexpected Gateway response."
        case .gatewayError(let code, let message, let details):
            var parts: [String] = []
            if let code, !code.isEmpty { parts.append(code) }
            if let message, !message.isEmpty { parts.append(message) }
            if let details, !details.isEmpty { parts.append(details) }
            return parts.isEmpty ? "Gateway error." : parts.joined(separator: ": ")
        }
    }
}
