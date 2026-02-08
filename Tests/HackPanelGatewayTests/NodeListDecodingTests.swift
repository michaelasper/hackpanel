import XCTest
@testable import HackPanelGateway

final class NodeListDecodingTests: XCTestCase {
    func testDecodesNodeListItemsFixture() throws {
        let url = Bundle.module.url(forResource: "node_list_items", withExtension: "json")!
        let data = try Data(contentsOf: url)

        let payload = try ISO8601.decoder.decode(NodeListPayload.self, from: data)
        let entries = payload.nodes ?? payload.items ?? []

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].id, "node-1")
        XCTAssertEqual(entries[0].name, "hackstudio")
        XCTAssertEqual(entries[0].connected, true)

        XCTAssertEqual(entries[1].id, "node-2")
        XCTAssertEqual(entries[1].name, "pi-gateway")
        XCTAssertEqual(entries[1].connected, false)
    }
}
