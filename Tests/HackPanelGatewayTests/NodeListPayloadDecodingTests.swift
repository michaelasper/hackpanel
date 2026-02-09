import XCTest
@testable import HackPanelGateway

final class NodeListPayloadDecodingTests: XCTestCase {
    func testDecodesNodeList_itemsShape() throws {
        let decoded = try FixtureLoader.decode(NodeListPayload.self, fromFixture: "node_list_items.json", decoder: ISO8601.decoder)
        XCTAssertNil(decoded.nodes)
        XCTAssertEqual(decoded.items?.count, 2)
        XCTAssertEqual(decoded.items?.first?.id, "node-1")
    }

    func testDecodesNodeList_nodesShape() throws {
        let decoded = try FixtureLoader.decode(NodeListPayload.self, fromFixture: "node_list_nodes.json", decoder: ISO8601.decoder)
        XCTAssertEqual(decoded.nodes?.count, 2)
        XCTAssertNil(decoded.items)
        XCTAssertEqual(decoded.nodes?.first?.nodeId, "node-1")
        XCTAssertEqual(decoded.nodes?.first?.host, "hackstudio")
    }

    func testDecodesNodeList_arrayShape() throws {
        let decoded = try FixtureLoader.decode(NodeListPayload.self, fromFixture: "node_list_array.json", decoder: ISO8601.decoder)
        XCTAssertNil(decoded.nodes)
        XCTAssertEqual(decoded.items?.count, 2)
        XCTAssertEqual(decoded.items?.last?.name, "pi-gateway")
    }
}
