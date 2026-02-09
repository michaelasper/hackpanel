import Foundation

/// Formats a plain-text diagnostics bundle suitable for copy/paste into bug reports.
///
/// Intentionally avoids including secrets like the full Gateway token.
enum DiagnosticsFormatter {
    struct Input: Sendable {
        var appVersion: String
        var appBuild: String
        var osVersion: String
        var gatewayBaseURL: String
        var gatewayToken: String
        var connectionState: String
        var lastErrorMessage: String?
        var lastErrorAt: Date?

        init(
            appVersion: String,
            appBuild: String,
            osVersion: String,
            gatewayBaseURL: String,
            gatewayToken: String,
            connectionState: String,
            lastErrorMessage: String? = nil,
            lastErrorAt: Date? = nil
        ) {
            self.appVersion = appVersion
            self.appBuild = appBuild
            self.osVersion = osVersion
            self.gatewayBaseURL = gatewayBaseURL
            self.gatewayToken = gatewayToken
            self.connectionState = connectionState
            self.lastErrorMessage = lastErrorMessage
            self.lastErrorAt = lastErrorAt
        }
    }

    static func format(_ input: Input, now: Date = Date()) -> String {
        var lines: [String] = []
        lines.append("HackPanel diagnostics")
        lines.append("Generated: \(iso8601(now))")
        lines.append("")

        lines.append("App version: \(input.appVersion) (\(input.appBuild))")
        lines.append("OS: \(input.osVersion)")
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

        return lines.joined(separator: "\n") + "\n"
    }

    /// Redacts all but the last 4 characters.
    static func redactToken(_ raw: String) -> String {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return "(empty)" }
        let last4 = token.count >= 4 ? String(token.suffix(4)) : nil
        if let last4 {
            return "***redacted*** (last4: \(last4))"
        }
        return "***redacted***"
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
