import Foundation
import XCTest

final class SettingsViewRenderingRegressionTests: XCTestCase {
    func testSettingsSource_containsGatewayURLAndTokenLabels() throws {
        // NOTE: This is a lightweight regression test intended to catch cases where
        // Settings accidentally stops rendering the core Gateway URL/Token fields.
        // We assert on the SettingsView source so the test is stable on CI without
        // requiring a full SwiftUI view inspection framework.

        let settingsViewPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // .../Tests/HackPanelAppTests
            .deletingLastPathComponent() // .../Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Sources/HackPanelApp/UI/SettingsView.swift")

        let source = try String(contentsOf: settingsViewPath, encoding: .utf8)

        XCTAssertTrue(
            source.contains("LabeledContent(\"Gateway URL\")") || source.contains("\"Gateway URL\""),
            "Expected SettingsView to contain the 'Gateway URL' label"
        )

        XCTAssertTrue(
            source.contains("LabeledContent(\"Token\")") || source.contains("\"Token\""),
            "Expected SettingsView to contain the 'Token' label"
        )
    }

    func testSettingsSource_containsDraftDirtyStateAndDisablesNoOpApply() throws {
        let settingsViewPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // .../Tests/HackPanelAppTests
            .deletingLastPathComponent() // .../Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Sources/HackPanelApp/UI/SettingsView.swift")

        let source = try String(contentsOf: settingsViewPath, encoding: .utf8)

        XCTAssertTrue(
            source.contains("isDraftDirty"),
            "Expected SettingsView to define an isDraftDirty flag"
        )

        XCTAssertTrue(
            source.contains("Draft has changes") && source.contains("No changes"),
            "Expected SettingsView to render draft dirty-state text"
        )

        XCTAssertTrue(
            source.contains("!isDraftDirty"),
            "Expected SettingsView to use isDraftDirty to disable no-op applies"
        )
    }

    func testSettingsSource_containsDiagnosticsConnectionLastSuccessAndLastError() throws {
        let settingsViewPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // .../Tests/HackPanelAppTests
            .deletingLastPathComponent() // .../Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Sources/HackPanelApp/UI/SettingsView.swift")

        let source = try String(contentsOf: settingsViewPath, encoding: .utf8)

        XCTAssertTrue(
            source.contains("Section(\"Diagnostics\")"),
            "Expected SettingsView to contain a Diagnostics section"
        )

        XCTAssertTrue(
            source.contains("LabeledContent(\"Connection\")"),
            "Expected Diagnostics to include a 'Connection' field"
        )

        XCTAssertTrue(
            source.contains("LabeledContent(\"Last success\")"),
            "Expected Diagnostics to include a 'Last success' field"
        )

        XCTAssertTrue(
            source.contains("LabeledContent(\"Last error\")"),
            "Expected Diagnostics to include a 'Last error' field"
        )

        // Stable accessibility identifiers for future UI tests.
        XCTAssertTrue(source.contains("settings.diagnostics.connectionState"))
        XCTAssertTrue(source.contains("settings.diagnostics.lastSuccessAt"))
        XCTAssertTrue(source.contains("settings.diagnostics.lastError"))
    }

    func testSettingsSource_rendersGatewayConnectionErrorBannerWhenOffline() throws {
        let settingsViewPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // .../Tests/HackPanelAppTests
            .deletingLastPathComponent() // .../Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Sources/HackPanelApp/UI/SettingsView.swift")

        let source = try String(contentsOf: settingsViewPath, encoding: .utf8)

        XCTAssertTrue(
            source.contains("Not connected to Gateway"),
            "Expected SettingsView to render an explicit offline/unreachable gateway banner"
        )

        XCTAssertTrue(
            source.contains("gateway.lastErrorMessage"),
            "Expected SettingsView offline banner to surface gateway.lastErrorMessage"
        )
    }
}
