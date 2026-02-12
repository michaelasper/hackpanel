import XCTest
import HackPanelGateway
@testable import HackPanelApp

final class NodesFilteringTests: XCTestCase {
    func testFilter_emptyQuery_returnsAllNodes() {
        let nodes: [NodeSummary] = [
            .init(id: "abc", name: "Alpha", state: .online),
            .init(id: "def", name: "Bravo", state: .offline),
        ]

        XCTAssertEqual(NodesViewModel.filter(nodes, query: "").map(\.id), ["abc", "def"])
        XCTAssertEqual(NodesViewModel.filter(nodes, query: "   ").map(\.id), ["abc", "def"])
    }

    func testFilter_matchesNameOrId_caseInsensitive_contains() {
        let nodes: [NodeSummary] = [
            .init(id: "node-123", name: "Kitchen Pi", state: .online),
            .init(id: "NODE-999", name: "Garage", state: .offline),
        ]

        XCTAssertEqual(NodesViewModel.filter(nodes, query: "kitch").map(\.id), ["node-123"])
        XCTAssertEqual(NodesViewModel.filter(nodes, query: "999").map(\.id), ["NODE-999"])
        XCTAssertEqual(NodesViewModel.filter(nodes, query: "node-").map(\.id), ["node-123", "NODE-999"])
    }
}
