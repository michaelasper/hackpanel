import XCTest
import HackPanelGateway
@testable import HackPanelApp

final class NodesSortingTests: XCTestCase {
    func testSort_onlineFirst_ordersByStateThenNameThenId() {
        let nodes: [NodeSummary] = [
            .init(id: "3", name: "Bravo", state: .offline),
            .init(id: "2", name: "alpha", state: .online),
            .init(id: "1", name: "Alpha", state: .online),
            .init(id: "4", name: "Charlie", state: .unknown),
        ]

        let sorted = NodesViewModel.sort(nodes, by: .onlineFirst)

        XCTAssertEqual(sorted.map(\.id), [
            // online: name (case-insensitive) then id
            "1", "2",
            // offline
            "3",
            // unknown
            "4",
        ])
    }

    func testSort_name_ordersByNameThenStateThenId_forStability() {
        let nodes: [NodeSummary] = [
            .init(id: "b", name: "Alpha", state: .offline),
            .init(id: "a", name: "alpha", state: .online),
            .init(id: "c", name: "Bravo", state: .online),
        ]

        let sorted = NodesViewModel.sort(nodes, by: .name)

        XCTAssertEqual(sorted.map(\.id), [
            // alpha rows grouped first (case-insensitive), then stable by state then id
            "a", "b",
            "c",
        ])
    }
}
