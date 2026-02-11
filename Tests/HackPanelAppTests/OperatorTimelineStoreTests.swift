import XCTest
import Combine
@testable import HackPanelApp

@MainActor
final class OperatorTimelineStoreTests: XCTestCase {
    private final class TestGateway: GatewayConnectionObserving {
        @Published var state: GatewayConnectionStore.State = .disconnected
        @Published var lastError: GatewayConnectionStore.ConnectionError?

        var statePublisher: AnyPublisher<GatewayConnectionStore.State, Never> { $state.eraseToAnyPublisher() }
        var lastErrorPublisher: AnyPublisher<GatewayConnectionStore.ConnectionError?, Never> { $lastError.eraseToAnyPublisher() }
    }

    func testRecordsConnectionStateChangesInReverseChronologicalOrder() async {
        let gateway = TestGateway()
        let store = OperatorTimelineStore(observing: gateway)

        XCTAssertTrue(store.events.isEmpty)

        gateway.state = .connected
        await Task.yield()

        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.events[0].kind, .connectionState)
        XCTAssertEqual(store.events[0].title, "Gateway connected")

        gateway.state = .disconnected
        await Task.yield()

        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events[0].title, "Gateway disconnected")
        XCTAssertEqual(store.events[1].title, "Gateway connected")
    }

    func testDedupesRepeatedErrorMessages() async {
        let gateway = TestGateway()
        let store = OperatorTimelineStore(observing: gateway)

        gateway.lastError = GatewayConnectionStore.ConnectionError(message: "No route to host", firstSeenAt: Date(), lastEmittedAt: Date())
        await Task.yield()
        XCTAssertEqual(store.events.count, 1)

        gateway.lastError = GatewayConnectionStore.ConnectionError(message: "No route to host", firstSeenAt: Date(), lastEmittedAt: Date())
        await Task.yield()
        XCTAssertEqual(store.events.count, 1)

        gateway.lastError = GatewayConnectionStore.ConnectionError(message: "Invalid token", firstSeenAt: Date(), lastEmittedAt: Date())
        await Task.yield()
        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events[0].detail, "Invalid token")
    }
}
