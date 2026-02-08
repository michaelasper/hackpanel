import Foundation

/// Minimal OpenClaw Gateway WebSocket RPC client.
///
/// Notes:
/// - This intentionally keeps the surface area tiny: connect + one-shot RPC calls.
/// - We do **not** currently implement device identity signing/pairing. This is expected to work
///   for common local/dev setups and can be expanded later.
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

        let entries = payload.nodes ?? payload
            .items
            ?? []

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
        let wsURL = try configuration.baseURL.asWebSocketURL()
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
                minProtocol: 3,
                maxProtocol: 3,
                client: ConnectClient(id: "hackpanel", version: "0.1", platform: "ios", mode: "operator"),
                role: "operator",
                scopes: ["operator.read"],
                auth: configuration.token.flatMap { $0.isEmpty ? nil : ConnectAuth(token: $0) }
            )
        )
        try await sendJSONFrame(task: task, frame: connect)

        // 2) Wait for hello-ok with an overall timeout to avoid infinite hangs.
        let hello: GatewayResponseFrame<HelloOK> = try await waitForResponse(
            task: task,
            id: connectId,
            operation: "connect/hello",
            timeoutSeconds: 5,
            decodeAs: GatewayResponseFrame<HelloOK>.self
        )
        if hello.ok != true {
            throw GatewayClientError.notImplemented
        }

        // 3) Send actual request.
        let id = UUID().uuidString
        let req = GatewayFrame.makeReq(id: id, method: method, params: params)
        try await sendJSONFrame(task: task, frame: req)

        // 4) Await response (bounded).
        let res: GatewayResponseFrame<R> = try await waitForResponse(
            task: task,
            id: id,
            operation: "rpc(\(method))",
            timeoutSeconds: 10,
            decodeAs: GatewayResponseFrame<R>.self
        )

        if res.ok == true, let payload = res.payload {
            return payload
        }
        throw GatewayClientError.notImplemented
    }

    private func receiveJSONFrame(task: URLSessionWebSocketTask, timeoutSeconds: Double) async throws -> Any {
        try await withTimeout(seconds: timeoutSeconds, operation: "receive-frame") {
            let message = try await task.receive()
            switch message {
            case .string(let str):
                let data = Data(str.utf8)
                return try JSONSerialization.jsonObject(with: data)
            case .data(let data):
                return try JSONSerialization.jsonObject(with: data)
            @unknown default:
                throw GatewayClientError.notImplemented
            }
        }
    }

    private func waitForResponse<T: Decodable & Sendable>(
        task: URLSessionWebSocketTask,
        id: String,
        operation: String,
        timeoutSeconds: Double,
        decodeAs: T.Type
    ) async throws -> T {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while true {
            try Task.checkCancellation()

            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                throw GatewayClientError.timeout(operation: operation)
            }

            // Bound each receive so cancellation can cut through even if the socket stays silent.
            let any = try await receiveJSONFrame(task: task, timeoutSeconds: min(2.0, remaining))
            if let res = try? decode(any, as: decodeAs) {
                // Only return frames that match our request id. Ignore other events/responses.
                if let maybeRes = res as? any GatewayResponseFrameProtocol,
                   maybeRes.type == "res",
                   maybeRes.id == id {
                    return res
                }
            }
        }
    }

    private func withTimeout<T>(seconds: Double, operation: String, _ body: @Sendable @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await body()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw GatewayClientError.timeout(operation: operation)
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
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
    var payload: P?
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

// MARK: - Payload decoding (best-effort)

private struct StatusPayload: Codable, Sendable {
    var ok: Bool?
    var version: String?
    var uptimeSeconds: Double?
    var uptimeMs: Double?
}

private struct NodeListPayload: Codable, Sendable {
    /// Common shape: {"nodes": [ ... ]}
    var nodes: [NodeListEntry]?

    /// Fallback: payload is directly an array.
    var items: [NodeListEntry]?

    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self) {
            self.nodes = try keyed.decodeIfPresent([NodeListEntry].self, forKey: .nodes)
            self.items = nil
            return
        }

        var unkeyed = try decoder.unkeyedContainer()
        var arr: [NodeListEntry] = []
        while !unkeyed.isAtEnd {
            arr.append(try unkeyed.decode(NodeListEntry.self))
        }
        self.items = arr
        self.nodes = nil
    }

    enum CodingKeys: String, CodingKey { case nodes }
}

private struct NodeListEntry: Codable, Sendable {
    var id: String?
    var nodeId: String?
    var deviceId: String?

    var name: String?
    var host: String?

    var connected: Bool?

    /// Some shapes use lastSeenAt (ISO-8601 string).
    var lastSeenAt: Date?
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
