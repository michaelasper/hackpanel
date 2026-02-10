import Foundation
import HackPanelGateway

/// Maps low-level Gateway / networking errors into user-facing messages.
///
/// Keep this logic centralized so UI banners and diagnostics stay consistent.
enum GatewayErrorPresenter {
    static func message(for error: Error) -> String {
        // Prefer our typed gateway errors.
        if let gce = error as? GatewayClientError {
            switch gce {
            case .invalidBaseURL:
                return "Invalid Gateway URL. Include a scheme like \(GatewayDefaults.baseURLString)"
            case .timedOut(let operation):
                return "Gateway timed out while \(operation)."
            case .unexpectedFrame:
                return "Gateway returned an unexpected response. Check Gateway version and reconnect."
            case .gatewayError(let code, let message, _):
                if looksLikeAuthFailure(code: code, message: message) {
                    return "Authentication failed. Check your Gateway token."
                }

                // Surface a short, human-friendly server message when available.
                let summary = [message, code]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty }

                if let summary {
                    return "Gateway error: \(summary)"
                }

                return "Gateway error."
            case .notImplemented:
                return "This feature isn’t implemented yet."
            }
        }

        // Map common URLSession errors into friendlier, actionable text.
        if let urlError = error as? URLError {
            switch urlError.code {
            case .unsupportedURL, .badURL:
                return "Invalid Gateway URL. Include a scheme like \(GatewayDefaults.baseURLString)"
            case .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .cannotFindHost:
                return "Can’t reach the Gateway. Check the URL and that the Gateway is running."
            case .notConnectedToInternet:
                return "No network connection."
            case .timedOut:
                return "Gateway request timed out."
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
                return "Secure connection to Gateway failed. If you’re using HTTPS, check certificates."
            default:
                break
            }
        }

        return (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    static func isAuthFailure(_ error: Error) -> Bool {
        if let gce = error as? GatewayClientError {
            switch gce {
            case .gatewayError(let code, let message, _):
                return looksLikeAuthFailure(code: code, message: message)
            default:
                break
            }
        }

        if let urlError = error as? URLError {
            // Auth issues usually aren't represented as URLError, but keep this for completeness.
            if urlError.code == .userAuthenticationRequired { return true }
        }

        let msg = (error as? LocalizedError)?.errorDescription?.lowercased() ?? String(describing: error).lowercased()
        return msg.contains("unauthorized") || msg.contains("forbidden")
    }

    private static func looksLikeAuthFailure(code: String?, message: String?) -> Bool {
        let haystack = [code, message]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        return haystack.contains("auth") || haystack.contains("unauthorized") || haystack.contains("forbidden")
    }
}
