import XCTest
@testable import HackPanelApp

final class ProviderHealthTests: XCTestCase {
    func testStatus_sortRank_ordersDownDegradedUnknownOk() {
        XCTAssertLessThan(ProviderHealth.Status.down.sortRank, ProviderHealth.Status.degraded.sortRank)
        XCTAssertLessThan(ProviderHealth.Status.degraded.sortRank, ProviderHealth.Status.unknown.sortRank)
        XCTAssertLessThan(ProviderHealth.Status.unknown.sortRank, ProviderHealth.Status.ok.sortRank)
    }

    func testStatus_displayName_isStable() {
        XCTAssertEqual(ProviderHealth.Status.ok.displayName, "OK")
        XCTAssertEqual(ProviderHealth.Status.degraded.displayName, "Degraded")
        XCTAssertEqual(ProviderHealth.Status.down.displayName, "Down")
        XCTAssertEqual(ProviderHealth.Status.unknown.displayName, "Unknown")
    }
}
