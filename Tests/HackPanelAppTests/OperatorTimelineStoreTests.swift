import XCTest
@testable import HackPanelApp

@MainActor
final class OperatorTimelineStoreTests: XCTestCase {
    func testRecordState_insertsMostRecentFirst() {
        let store = OperatorTimelineStore(maxEvents: 10)

        let t0 = Date(timeIntervalSince1970: 1)
        let t1 = Date(timeIntervalSince1970: 2)

        store.record(state: .disconnected, at: t0)
        store.record(state: .connected, at: t1)

        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events[0].timestamp, t1)
        XCTAssertEqual(store.events[0].title, "Gateway connected")
        XCTAssertEqual(store.events[1].timestamp, t0)
        XCTAssertEqual(store.events[1].title, "Gateway disconnected")
    }

    func testRecordError_usesMessageAsDetail() {
        let store = OperatorTimelineStore(maxEvents: 10)
        let ts = Date(timeIntervalSince1970: 123)

        store.record(errorMessage: "Cannot connect", at: ts)

        XCTAssertEqual(store.events.first?.title, "Connection error")
        XCTAssertEqual(store.events.first?.detail, "Cannot connect")
    }

    func testMaxEvents_isCapped() {
        let store = OperatorTimelineStore(maxEvents: 2)
        let t0 = Date(timeIntervalSince1970: 1)
        let t1 = Date(timeIntervalSince1970: 2)
        let t2 = Date(timeIntervalSince1970: 3)

        store.record(state: .disconnected, at: t0)
        store.record(state: .connected, at: t1)
        store.record(errorMessage: "Boom", at: t2)

        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events[0].timestamp, t2)
        XCTAssertEqual(store.events[1].timestamp, t1)
    }
}
