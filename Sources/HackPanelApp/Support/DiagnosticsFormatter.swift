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

        // Refresh scheduling diagnostics.
        var isRefreshPaused: Bool
        var lastActiveAt: Date?

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
            reconnectBackoffUntil: Date? = nil,
            isRefreshPaused: Bool = false,
            lastActiveAt: Date? = nil
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
            self.isRefreshPaused = isRefreshPaused
            self.lastActiveAt = lastActiveAt
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

        lines.append("")
        lines.append("Refresh paused: \(input.isRefreshPaused ? "Yes" : "No")")
        if let lastActiveAt = input.lastActiveAt {
            lines.append("Last active at: \(iso8601(lastActiveAt))")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Formats a short, redacted settings summary suitable for support/debug.
    ///
    /// Intentionally excludes the gateway token and strips URL details down to scheme/host/port.
    static func formatSettingsSummary(
        appVersion: String,
        appBuild: String,
        osVersion: String,
        gatewayBaseURL: String,
        gatewayAutoApply: Bool,
        connectionState: String,
        lastErrorMessage: String?
    ) -> String {
        var lines: [String] = []
        lines.append("HackPanel settings summary")
        lines.append("App version: \(appVersion) (\(appBuild))")
        lines.append("OS: \(osVersion)")
        lines.append("Gateway base URL: \(safeHostPortURLString(gatewayBaseURL))")
        lines.append("Auto-apply: \(gatewayAutoApply ? "On" : "Off")")
        lines.append("Connection state: \(connectionState)")
        lines.append("Last error: \((lastErrorMessage?.isEmpty == false) ? lastErrorMessage! : "(none)")")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func safeHostPortURLString(_ raw: String) -> String {
        guard let url = URL(string: raw) else { return "(invalid)" }
        guard let scheme = url.scheme, let host = url.host else { return "(invalid)" }
        if let port = url.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    static func redactToken(_ raw: String) -> String {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return "(empty)" }
        guard token.count >= 4 else { return "***redacted***" }
        let last4 = String(token.suffix(4))
        return "***redacted*** (last4: \(last4))"
    }

    /// Best-effort, deterministic redaction pass for logs/diagnostic text that may contain secrets.
    ///
    /// Keep this intentionally small and test-backed; it is not meant to be a full PII redaction system.
    static func redactSecrets(in text: String, gatewayToken: String) -> String {
        var out = text

        // 1) Exact token match (when known).
        let token = gatewayToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            out = out.replacingOccurrences(of: token, with: "[REDACTED]")
        }

        // 2) Common header/query patterns.
        // Authorization: Bearer <value>
        out = replacingRegex(
            in: out,
            pattern: "(?i)(authorization:\\s*bearer\\s+)([^\\s]+)",
            template: "$1[REDACTED]"
        )

        // token=<value>
        out = replacingRegex(
            in: out,
            pattern: "(?i)(token=)([^\\s&]+)",
            template: "$1[REDACTED]"
        )

        return out
    }

    private static func replacingRegex(in text: String, pattern: String, template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return re.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
