import XCTest
import HackPanelGateway
import HackPanelGatewayMocks
@testable import HackPanelApp

@MainActor
final class GatewayConnectionStoreHealthCheckTests: XCTestCase {
    func testLastHealthCheckAt_isSetAfterSuccessfulFetchStatus() async throws {
        let store = GatewayConnectionStore(client: MockGatewayClient(scenario: .demo))
        XCTAssertNil(store.lastHealthCheckAt)

        _ = try await store.fetchStatus()

        XCTAssertNotNil(store.lastHealthCheckAt)
    }

    func testLastHealthCheckAt_isSetAfterFailedFetchStatus() async {
        struct ThrowingClient: GatewayClient {
            func fetchStatus() async throws -> GatewayStatus { throw URLError(.cannotConnectToHost) }
            func fetchNodes() async throws -> [NodeSummary] { [] }
        }

        let store = GatewayConnectionStore(client: ThrowingClient())
        XCTAssertNil(store.lastHealthCheckAt)

        do {
            _ = try await store.fetchStatus()
            XCTFail("Expected fetchStatus to throw")
        } catch {
            // expected
        }

        XCTAssertNotNil(store.lastHealthCheckAt)
    }
}
