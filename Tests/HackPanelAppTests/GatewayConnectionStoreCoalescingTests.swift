import XCTest
import HackPanelGateway
@testable import HackPanelApp

@MainActor
final class GatewayConnectionStoreCoalescingTests: XCTestCase {
    func testFetchNodes_coalescesConcurrentCalls() async throws {
        actor Counter {
            var calls: Int = 0
            func bump() { calls += 1 }
            func get() -> Int { calls }
        }

        struct CountingClient: GatewayClient {
            let counter: Counter

            func fetchStatus() async throws -> GatewayStatus {
                // Not used in this test.
                throw URLError(.unsupportedURL)
            }

            func fetchNodes() async throws -> [NodeSummary] {
                await counter.bump()
                // Simulate a slow network call so concurrent callers overlap.
                try await Task.sleep(nanoseconds: 75_000_000)
                return []
            }
        }

        let counter = Counter()
        let store = GatewayConnectionStore(client: CountingClient(counter: counter))

        try await withThrowingTaskGroup(of: [NodeSummary].self) { group in
            for _ in 0..<8 {
                group.addTask { try await store.fetchNodes() }
            }

            for try await _ in group {
                // drain
            }
        }

        let calls = await counter.get()
        XCTAssertEqual(calls, 1)
    }
}
