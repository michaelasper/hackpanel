import Foundation

enum DeviceAuthPayload {
    /// Matches OpenClaw Gateway `buildDeviceAuthPayload`.
    static func build(
        version: Version? = nil,
        deviceId: String,
        clientId: String,
        clientMode: String,
        role: String,
        scopes: [String],
        signedAtMs: Int64,
        token: String?,
        nonce: String?
    ) -> String {
        let inferred: Version = version ?? ((nonce?.isEmpty == false) ? .v2 : .v1)
        let scopesStr = scopes.joined(separator: ",")
        let tokenStr = token ?? ""

        var parts: [String] = [
            inferred.rawValue,
            deviceId,
            clientId,
            clientMode,
            role,
            scopesStr,
            String(signedAtMs),
            tokenStr,
        ]

        if inferred == .v2 {
            parts.append(nonce ?? "")
        }

        return parts.joined(separator: "|")
    }

    enum Version: String {
        case v1
        case v2
    }
}
