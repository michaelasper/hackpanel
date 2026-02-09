import Foundation

/// Internal decoding models for Gateway JSON frames.
///
/// These are kept `internal` so the test target can validate contract fixtures
/// without needing a live Gateway connection.
struct GatewayResponseFrame<P: Decodable & Sendable>: Decodable, Sendable {
    var type: String
    var id: String
    var ok: Bool?

    /// Success payload (variously called `payload` by the Gateway).
    var payload: P?

    /// Error payload (best-effort, varies by server version).
    var error: GatewayErrorPayload?

    /// Some servers may include a top-level message even when `error` is present.
    var message: String?
}

struct GatewayErrorPayload: Decodable, Sendable {
    var code: String?
    var message: String?
    var details: String?
    var data: JSONValue?
}

/// Generic event frame.
///
/// Known example: `connect.challenge` may be emitted before/around connect.
struct GatewayEventFrame<P: Decodable & Sendable>: Decodable, Sendable {
    var type: String
    var event: String
    var payload: P?

    /// Some gateway builds use `data` instead of `payload`.
    var data: P?

    var normalizedPayload: P? { payload ?? data }

    enum CodingKeys: String, CodingKey {
        case type
        case event
        case payload
        case data
    }
}

/// JSON catch-all used for best-effort error detail decoding.
enum JSONValue: Decodable, Sendable, Equatable {
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
