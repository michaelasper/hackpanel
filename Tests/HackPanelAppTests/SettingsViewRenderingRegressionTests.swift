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
}