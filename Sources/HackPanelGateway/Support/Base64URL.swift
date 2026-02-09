import Foundation

enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ string: String) throws -> Data {
        let normalized = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padLen = (4 - (normalized.count % 4)) % 4
        let padded = normalized + String(repeating: "=", count: padLen)

        guard let data = Data(base64Encoded: padded) else {
            throw Base64URLError.invalidBase64
        }
        return data
    }

    enum Base64URLError: Error {
        case invalidBase64
    }
}
