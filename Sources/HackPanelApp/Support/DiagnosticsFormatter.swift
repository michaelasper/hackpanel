import Foundation

/// Formats a plain-text diagnostics bundle suitable for copy/paste into bug reports.
///
/// Intentionally avoids including secrets like the full Gateway token.
enum DiagnosticsFormatter {
    struct Input: Sendable {
        var appVersion: String
        var appBuild: String
        var osVersion: String
        var deviceId: String?
        var gatewayBaseURL: String
        var gatewayToken: String
        var connectionState: String
        var lastErrorMessage: String?
        var lastErrorAt: Date?
        /// If present, indicates when the next reconnect attempt is allowed.
        var reconnectBackoffUntil: Date?

        init(
            appVersion: String,
            appBuild: String,
            osVersion: String,
            deviceId: String? = nil,
            gatewayBaseURL: String,
            gatewayToken: String,
            connectionState: String,
            lastErrorMessage: String? = nil,
            lastErrorAt: Date? = nil,
            reconnectBackoffUntil: Date? = nil
        ) {
            self.appVersion = appVersion
            self.appBuild = appBuild
            self.osVersion = osVersion
            self.deviceId = deviceId
            self.gatewayBaseURL = gatewayBaseURL
            self.gatewayToken = gatewayToken
            self.connectionState = connectionState
            self.lastErrorMessage = lastErrorMessage
            self.lastErrorAt = lastErrorAt
            self.reconnectBackoffUntil = reconnectBackoffUntil
        }
    }

    static func format(_ input: Input, now: Date = Date()) -> String {
        var lines: [String] = []
        lines.append("HackPanel diagnostics")
        lines.append("Generated: \(iso8601(now))")
        lines.append("")

        lines.append("App version: \(input.appVersion) (\(input.appBuild))")
        lines.append("OS: \(input.osVersion)")
        if let deviceId = input.deviceId, !deviceId.isEmpty {
            lines.append("Device ID: \(deviceId)")
        }
        lines.append("")

        lines.append("Gateway base URL: \(input.gatewayBaseURL)")
        lines.append("Gateway token: \(redactToken(input.gatewayToken))")
        lines.append("")

        lines.append("Connection state: \(input.connectionState)")

        if let msg = input.lastErrorMessage, !msg.isEmpty {
            lines.append("Last error: \(msg)")
            if let at = input.lastErrorAt {
                lines.append("Last error at: \(iso8601(at))")
            }
        } else {
            lines.append("Last error: (none)")
        }

        if let until = input.reconnectBackoffUntil {
            let remaining = max(0, Int(until.timeIntervalSince(now).rounded(.up)))
            lines.append("Reconnect backoff: \(remaining)s remaining (until \(iso8601(until)))")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func redactToken(_ raw: String) -> String {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return "(empty)" }
        guard token.count >= 4 else { return "***redacted***" }
        let last4 = String(token.suffix(4))
        return "***redacted*** (last4: \(last4))"
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
