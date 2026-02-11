import Foundation

struct DiagnosticsExportBundle: Sendable {
    struct Entry: Sendable {
        var filename: String
        var data: Data

        init(filename: String, data: Data) {
            self.filename = filename
            self.data = data
        }
    }

    var entries: [Entry]
}

enum DiagnosticsExportBuilder {
    struct Input: Sendable {
        var appVersion: String
        var appBuild: String
        var osVersion: String
        var generatedAt: Date

        /// Already redacted; must never include tokens.
        var settingsSummaryText: String

        /// Best-effort recent logs (app-side). Should never include tokens.
        var logsText: String

        init(
            appVersion: String,
            appBuild: String,
            osVersion: String,
            generatedAt: Date,
            settingsSummaryText: String,
            logsText: String
        ) {
            self.appVersion = appVersion
            self.appBuild = appBuild
            self.osVersion = osVersion
            self.generatedAt = generatedAt
            self.settingsSummaryText = settingsSummaryText
            self.logsText = logsText
        }
    }

    static func build(_ input: Input) throws -> DiagnosticsExportBundle {
        let manifest = Manifest(
            generatedAt: ISO8601DateFormatter().string(from: input.generatedAt),
            appVersion: input.appVersion,
            appBuild: input.appBuild,
            osVersion: input.osVersion
        )

        let manifestData = try JSONEncoder().encode(manifest)

        return DiagnosticsExportBundle(entries: [
            .init(filename: "settings.txt", data: Data(input.settingsSummaryText.utf8)),
            .init(filename: "logs.txt", data: Data(input.logsText.utf8)),
            .init(filename: "manifest.json", data: manifestData)
        ])
    }

    private struct Manifest: Codable {
        var generatedAt: String
        var appVersion: String
        var appBuild: String
        var osVersion: String
    }
}
