import Foundation

/// Minimal OpenClaw Gateway WebSocket RPC client.
///
/// Notes:
/// - This intentionally keeps the surface area tiny: connect + one-shot RPC calls.
/// - We do **not** currently implement device identity signing/pairing. This is expected to work
///   for common local/dev setups and can be expanded later.
private enum Constants {
    static let protocolVersion = 3
    static let clientId = "hackpanel"
    static let clientVersion = "0.1"
    static let clientPlatform = "ios"
    static let clientMode = "operator"

    static let role = "operator"
    static let scopes = ["operator.read"]

    static let connectTimeoutSeconds: TimeInterval = 5
    static let requestTimeoutSeconds: TimeInterval = 10
    static let receiveTimeoutSeconds: TimeInterval = 10
}

public struct LiveGatewayClient: GatewayClient {
    private let configuration: GatewayConfiguration

    public init(configuration: GatewayConfiguration) {
        self.configuration = configuration
    }

    public func fetchStatus() async throws -> GatewayStatus {
        let rpc = GatewayRPC(configuration: configuration)
        let payload: StatusPayload = try await rpc.call(method: "status", params: EmptyParams())
        return GatewayStatus(
            ok: payload.ok ?? true,
            version: payload.version,
            uptimeSeconds: payload.uptimeSeconds ?? payload.uptimeMs.map { $0 / 1000.0 }
        )
    }

    public func fetchNodes() async throws -> [NodeSummary] {
        let rpc = GatewayRPC(configuration: configuration)
        let payload: NodeListPayload = try await rpc.call(method: "node.list", params: EmptyParams())

        let entries = payload.nodes ?? payload.items ?? []

        return entries.enumerated().map { offset, entry in
            let stableFallbackID: String = {
                if let host = entry.host, !host.isEmpty { return "host:\(host)" }
                if let name = entry.name, !name.isEmpty { return "name:\(name)" }
                return "unknown:\(offset)"
            }()

            return NodeSummary(
                id: entry.id ?? entry.nodeId ?? entry.deviceId ?? stableFallbackID,
                name: entry.name ?? entry.host ?? entry.id ?? entry.nodeId ?? "(unknown)",
                state: (entry.connected ?? false) ? .online : .offline,
                lastSeenAt: entry.lastSeenAt
            )
        }
    }
}

// MARK: - RPC plumbing

private struct GatewayRPC: Sendable {
    let configuration: GatewayConfiguration

    func call<P: Encodable, R: Decodable>(method: String, params: P) async throws -> R {
        let wsURL: URL
        do {
            wsURL = try configuration.baseURL.asWebSocketURL()
        } catch {
            throw GatewayClientError.invalidBaseURL(configuration.baseURL.absoluteString)
        }

        let session = URLSession(configuration: .ephemeral)
        let task = session.webSocketTask(with: wsURL)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }

        // 1) Send connect request promptly.
        // The Gateway may send an optional pre-connect "challenge" event, but waiting on it can hang
        // when the server stays silent. We send connect immediately and ignore any unrelated frames.
        let connectId = UUID().uuidString
        let connect = GatewayFrame.makeReq(
            id: connectId,
            method: "connect",
            params: ConnectParams(
                minProtocol: Constants.protocolVersion,
                maxProtocol: Constants.protocolVersion,
                client: ConnectClient(
                    id: Constants.clientId,
                    version: Constants.clientVersion,
                    platform: Constants.clientPlatform,
                    mode: Constants.clientMode
                ),
                role: Constants.role,
                scopes: Constants.scopes,
                auth: configuration.token.flatMap { $0.isEmpty ? nil : ConnectAuth(token: $0) }
            )
        )
        try await sendJSONFrame(task: task, frame: connect)

        // 2) Wait for hello-ok.
        try await withTimeout(Constants.connectTimeoutSeconds, operation: "connecting to Gateway") {
            while true {
                let any = try await receiveJSONFrame(task: task)
                if let res: GatewayResponseFrame<HelloOK> = try? decode(any, as: GatewayResponseFrame<HelloOK>.self),
                   res.type == "res",
                   res.id == connectId {
                    if res.ok == true {
                        return ()
                    }
                    throw GatewayClientError.gatewayError(
                        code: res.error?.code,
                        message: res.error?.message ?? res.message,
                        details: res.error?.details
                    )
                }
            }
        }

        // 3) Send actual request.
        let id = UUID().uuidString
        let req = GatewayFrame.makeReq(id: id, method: method, params: params)
        try await sendJSONFrame(task: task, frame: req)

        // 4) Await response.
        return try await withTimeout(Constants.requestTimeoutSeconds, operation: "waiting for \(method) response") {
            while true {
                let any = try await receiveJSONFrame(task: task)
                if let res: GatewayResponseFrame<R> = try? decode(any, as: GatewayResponseFrame<R>.self),
                   res.type == "res",
                   res.id == id {
                    if res.ok == true, let payload = res.payload {
                        return payload
                    }
                    throw GatewayClientError.gatewayError(
                        code: res.error?.code,
                        message: res.error?.message ?? res.message,
                        details: res.error?.details
                    )
                }
            }
        }
    }

    private func receiveJSONFrame(task: URLSessionWebSocketTask) async throws -> Any {
        let message = try await withTimeout(Constants.receiveTimeoutSeconds, operation: "waiting for Gateway frame") {
            try await task.receive()
        }
        switch message {
        case .string(let str):
            let data = Data(str.utf8)
            return try JSONSerialization.jsonObject(with: data)
        case .data(let data):
            return try JSONSerialization.jsonObject(with: data)
        @unknown default:
            throw GatewayClientError.unexpectedFrame
        }
    }

    private func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        operation: String,
        _ work: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await work()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw GatewayClientError.timedOut(operation: operation)
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    private func sendJSONFrame(task: URLSessionWebSocketTask, frame: GatewayFrame) async throws {
        let data = try ISO8601.encoder.encode(frame)
        try await task.send(.data(data))
    }

    private func decode<T: Decodable>(_ any: Any, as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: any)
        return try ISO8601.decoder.decode(T.self, from: data)
    }
}

private enum GatewayFrame: Codable, Sendable {
    case req(id: String, method: String, params: EncodableValue)

    enum CodingKeys: String, CodingKey { case type, id, method, params }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .req(id, method, params):
            try c.encode("req", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(method, forKey: .method)
            try c.encode(params, forKey: .params)
        }
    }

    init(from decoder: Decoder) throws {
        throw DecodingError.typeMismatch(GatewayFrame.self, .init(codingPath: decoder.codingPath, debugDescription: "decoding not supported"))
    }

    static func makeReq<P: Encodable>(id: String, method: String, params: P) -> GatewayFrame {
        .req(id: id, method: method, params: EncodableValue(params))
    }
}

private protocol GatewayResponseFrameProtocol {
    var type: String { get }
    var id: String { get }
}

private struct GatewayResponseFrame<P: Decodable & Sendable>: Decodable, Sendable, GatewayResponseFrameProtocol {
    var type: String
    var id: String
    var ok: Bool?

    // Success payload
    var payload: P?

    // Error payload (best-effort)
    var error: GatewayErrorPayload?
    var message: String?
}

private struct GatewayErrorPayload: Decodable, Sendable {
    var code: String?
    var message: String?
    var details: String?
    var data: JSONValue?
}

private enum JSONValue: Decodable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        if let c = try? decoder.singleValueContainer() {
            if c.decodeNil() { self = .null; return }
            if let b = try? c.decode(Bool.self) { self = .bool(b); return }
            if let n = try? c.decode(Double.self) { self = .number(n); return }
            if let s = try? c.decode(String.self) { self = .string(s); return }
        }

        if var a = try? decoder.unkeyedContainer() {
            var arr: [JSONValue] = []
            while !a.isAtEnd { arr.append(try a.decode(JSONValue.self)) }
            self = .array(arr)
            return
        }
        if let o = try? decoder.container(keyedBy: DynamicKey.self) {
            var dict: [String: JSONValue] = [:]
            for k in o.allKeys { dict[k.stringValue] = try o.decode(JSONValue.self, forKey: k) }
            self = .object(dict)
            return
        }
        throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON"))
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    }
}

private struct EncodableValue: Encodable, Sendable {
    private let encodeFn: @Sendable (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        self.encodeFn = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeFn(encoder)
    }
}

private struct EmptyParams: Codable, Sendable {}

private struct ConnectParams: Codable, Sendable {
    var minProtocol: Int
    var maxProtocol: Int
    var client: ConnectClient

    var role: String
    var scopes: [String]

    var auth: ConnectAuth?
}

private struct ConnectClient: Codable, Sendable {
    var id: String
    var version: String
    var platform: String
    var mode: String
}

private struct ConnectAuth: Codable, Sendable {
    var token: String
}

private struct HelloOK: Codable, Sendable {
    var type: String?
    var protocolVersion: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case protocolVersion = "protocol"
    }
}

private extension URL {
    func asWebSocketURL() throws -> URL {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        switch comps.scheme?.lowercased() {
        case "ws", "wss":
            break
        case "http":
            comps.scheme = "ws"
        case "https":
            comps.scheme = "wss"
        default:
            // If someone pastes 127.0.0.1:18789, they will need to include a scheme.
            throw URLError(.unsupportedURL)
        }
        guard let url = comps.url else { throw URLError(.badURL) }
        return url
    }
}
