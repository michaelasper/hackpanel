import Foundation

/// Centralizes the heuristics for when we should show the first-run onboarding UI.
///
/// Goal: avoid a "blank/confusing" first launch when the Gateway isn't configured yet,
/// while not nagging users who have successfully connected before.
enum GatewayOnboardingGate {
    /// Returns true when the configured base URL string looks missing/invalid.
    static func isBaseURLInvalid(_ raw: String) -> Bool {
        if case .failure = GatewaySettingsValidator.validateBaseURL(raw) {
            return true
        }
        return false
    }

    /// Should we show onboarding right now?
    ///
    /// - Parameters:
    ///   - hasEverConnected: persisted flag; becomes true after any successful connection.
    ///   - baseURL: current raw base URL string (AppStorage).
    ///   - connectionState: current gateway connection state.
    static func shouldShowOnboarding(
        hasEverConnected: Bool,
        baseURL: String,
        connectionState: GatewayConnectionStore.State
    ) -> Bool {
        // Always show if configuration is currently invalid.
        if isBaseURLInvalid(baseURL) { return true }

        // If the user has *never* successfully connected, be explicit on first run.
        if !hasEverConnected && connectionState != .connected { return true }

        return false
    }
}
