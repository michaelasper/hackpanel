import Foundation

/// Pure helper for comparing and resetting Gateway settings drafts.
///
/// SettingsView keeps user-editable draft strings so we can preserve invalid/incomplete input.
/// This type provides normalization + comparison logic that can be unit-tested.
struct GatewaySettingsDraft: Equatable {
    var baseURL: String
    var token: String

    init(baseURL: String, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    var normalizedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedToken: String {
        GatewaySettingsValidator.normalizeToken(token)
    }

    func differs(fromApplied applied: GatewaySettingsDraft) -> Bool {
        normalizedBaseURL != applied.normalizedBaseURL || normalizedToken != applied.normalizedToken
    }

    enum ResetOutcome: Equatable {
        case resetToApplied
        case resetToDefaultBaseURL
    }

    /// Resets this draft to the applied values.
    /// - Note: If the applied baseURL is empty/missing, this uses `defaultBaseURL`.
    @discardableResult
    mutating func reset(toApplied applied: GatewaySettingsDraft, defaultBaseURL: String) -> ResetOutcome {
        let appliedBase = applied.normalizedBaseURL
        let appliedToken = applied.normalizedToken

        if appliedBase.isEmpty {
            baseURL = defaultBaseURL
            token = appliedToken
            return .resetToDefaultBaseURL
        }

        baseURL = appliedBase
        token = appliedToken
        return .resetToApplied
    }
}
