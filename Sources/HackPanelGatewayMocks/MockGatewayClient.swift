import Foundation
import HackPanelGateway

public struct MockGatewayClient: GatewayClient {
    public enum Scenario: Sendable {
        case demo
        case gatewayDown
    }

    private let scenario: Scenario

    public init(scenario: Scenario = .demo) {
        self.scenario = scenario
    }

    public func fetchStatus() async throws -> GatewayStatus {
        switch scenario {
        case .demo:
            return GatewayStatus(ok: true, version: "OpenClaw 2026.x", build: "dev", commit: "(mock)", uptimeSeconds: 12_345)
        case .gatewayDown:
            return GatewayStatus(ok: false, version: nil, build: nil, commit: nil, uptimeSeconds: nil)
        }
    }

    public func fetchNodes() async throws -> [NodeSummary] {
        return [
            NodeSummary(id: "node-1", name: "hackstudio", state: .online, lastSeenAt: Date()),
            NodeSummary(id: "node-2", name: "pi-gateway", state: .offline, lastSeenAt: Date().addingTimeInterval(-3600))
        ]
    }
}
