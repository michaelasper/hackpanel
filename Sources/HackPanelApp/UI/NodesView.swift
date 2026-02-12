import SwiftUI
import HackPanelGateway

enum NodesSortOption: String, CaseIterable, Sendable {
    case onlineFirst = "online-first"
    case name = "name"

    var title: String {
        switch self {
        case .onlineFirst: return "Online first"
        case .name: return "Name"
        }
    }
}

@MainActor
final class NodesViewModel: ObservableObject {
    @Published var nodes: [NodeSummary] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    nonisolated static func sort(_ nodes: [NodeSummary], by option: NodesSortOption) -> [NodeSummary] {
        nodes.sorted { lhs, rhs in
            switch option {
            case .onlineFirst:
                if lhs.state != rhs.state {
                    // Online first, then offline, then unknown.
                    return lhs.state.sortRank < rhs.state.sortRank
                }
                let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }
                // Stable tie-breakers to avoid flicker during refresh.
                return lhs.id < rhs.id

            case .name:
                let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }
                // Stable tie-breakers to avoid flicker during refresh.
                if lhs.state != rhs.state {
                    return lhs.state.sortRank < rhs.state.sortRank
                }
                return lhs.id < rhs.id
            }
        }
    }

    nonisolated static func filter(_ nodes: [NodeSummary], query rawQuery: String) -> [NodeSummary] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nodes }

        return nodes.filter { node in
            node.name.localizedCaseInsensitiveContains(query)
                || node.id.localizedCaseInsensitiveContains(query)
        }
    }

    private let gateway: GatewayConnectionStore

    init(gateway: GatewayConnectionStore) {
        self.gateway = gateway
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            nodes = try await gateway.fetchNodes()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}

struct NodesView: View {
    static let lastSeenFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    @EnvironmentObject private var connection: GatewayConnectionStore
    @StateObject private var model: NodesViewModel
    @State private var searchText: String = ""

    @AppStorage("nodes.sortOption") private var sortOptionRawValue: String = NodesSortOption.onlineFirst.rawValue

    private let onOpenSettings: (() -> Void)?

    private var sortOption: NodesSortOption {
        NodesSortOption(rawValue: sortOptionRawValue) ?? .onlineFirst
    }

    private var sortedNodes: [NodeSummary] {
        NodesViewModel.sort(model.nodes, by: sortOption)
    }

    private var visibleNodes: [NodeSummary] {
        NodesViewModel.filter(sortedNodes, query: searchText)
    }

    init(gateway: GatewayConnectionStore, onOpenSettings: (() -> Void)? = nil) {
        _model = StateObject(wrappedValue: NodesViewModel(gateway: gateway))
        self.onOpenSettings = onOpenSettings
    }

    private var shouldShowGatewayUnavailableState: Bool {
        // If we're disconnected/auth-failed and we have no data to show, make it obvious.
        connection.state != .connected && model.nodes.isEmpty && !model.isLoading
    }

    private var gatewayUnavailableTitle: String {
        connection.state == .authFailed ? "Authentication required" : "Gateway unavailable"
    }

    private var gatewayUnavailableIcon: String {
        connection.state == .authFailed ? "lock.slash" : "wifi.exclamationmark"
    }

    private var gatewayUnavailableDescription: String {
        switch connection.state {
        case .authFailed:
            return "Update your gateway token in Settings, then reconnect."
        case .disconnected, .reconnecting:
            return "Check your gateway URL in Settings, then reconnect."
        case .connected:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.sectionSpacing) {
            HStack {
                Text("Nodes")
                    .font(.title2.weight(.semibold))

                Spacer()

                Menu {
                    Picker("Sort", selection: $sortOptionRawValue) {
                        ForEach(NodesSortOption.allCases, id: \.rawValue) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } label: {
                    Label("Sort: \(sortOption.title)", systemImage: "arrow.up.arrow.down")
                }
                .disabled(model.isLoading)

                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
            }

            if let error = model.errorMessage {
                GlassCard {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.body)
                    }
                }
            }

            if shouldShowGatewayUnavailableState {
                GlassCard {
                    ContentUnavailableView {
                        Label(gatewayUnavailableTitle, systemImage: gatewayUnavailableIcon)
                    } description: {
                        Text(gatewayUnavailableDescription)
                    } actions: {
                        if let onOpenSettings {
                            Button("Open Settings") { onOpenSettings() }
                                .disabled(model.isLoading)
                        }

                        Button("Retry") {
                            connection.retryNow()
                            Task { await model.refresh() }
                        }
                        .disabled(model.isLoading)
                        .accessibilityHint(Text("Retries connecting to the gateway and refreshes the Nodes list"))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if model.nodes.isEmpty, !model.isLoading, model.errorMessage == nil {
                GlassCard {
                    ContentUnavailableView {
                        Label("No paired nodes", systemImage: "sensor.tag.radiowaves.forward")
                    } description: {
                        Text("Pair a node in your gateway, then refresh.")
                    } actions: {
                        Button("Refresh") { Task { await model.refresh() } }
                            .disabled(model.isLoading)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if visibleNodes.isEmpty, !model.isLoading {
                GlassCard {
                    ContentUnavailableView {
                        Label("No matching nodes", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try a different search.")
                    } actions: {
                        Button("Clear search") { searchText = "" }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                GlassSurface {
                    List(visibleNodes) { node in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Circle()
                                .fill(Self.color(for: node.state))
                                .frame(width: 8, height: 8)
                                .padding(.top, AppTheme.Layout.rowVerticalPadding)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.name)
                                    .font(.body)

                                HStack(spacing: 8) {
                                    Text(node.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(Self.lastSeenText(for: node.lastSeenAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(node.state.rawValue.capitalized)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(node.state == .online ? .green : .secondary)
                        }
                        .padding(.vertical, AppTheme.Layout.rowVerticalPadding)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .searchable(text: $searchText, placement: .automatic, prompt: "Search nodes")
            }
        }
        .padding(AppTheme.Layout.pagePadding)
        .task(id: connection.refreshToken) { await model.refresh() }
    }
}
