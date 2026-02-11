import Foundation
import HackPanelGateway

/// Mapping logic for Settings "Test connection".
///
/// Keep this separate from the monitor-loop error mapping so Settings can present a clear,
/// action-oriented result (Success/Auth/Cannot connect/Timeout/Unknown).
enum GatewayTestConnectionPresenter {
    enum ResultKind: Equatable {
        case success
        case authFailed
        case cannotConnect
        case timedOut
        case unknown
    }

    struct PresentedResult: Equatable {
        var kind: ResultKind
        var message: String
    }

    static func presentSuccess() -> PresentedResult {
        PresentedResult(kind: .success, message: "Connection OK.")
    }

    static func present(error: Error) -> PresentedResult {
        if GatewayErrorPresenter.isAuthFailure(error) {
            return PresentedResult(kind: .authFailed, message: "Auth failed. Check your Gateway token.")
        }

        if let gce = error as? GatewayClientError {
            switch gce {
            case .timedOut:
                return PresentedResult(kind: .timedOut, message: "Gateway timed out. Check the URL/network, then try again.")
            default:
                break
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .cannotFindHost, .cannotLoadFromNetwork, .resourceUnavailable, .notConnectedToInternet:
                return PresentedResult(kind: .cannotConnect, message: "Can’t reach the Gateway. Check the URL and that the Gateway is running.")
            case .timedOut:
                return PresentedResult(kind: .timedOut, message: "Gateway request timed out. Check the URL/network, then try again.")
            default:
                break
            }
        }

        return PresentedResult(kind: .unknown, message: GatewayErrorPresenter.message(for: error))
    }
}
