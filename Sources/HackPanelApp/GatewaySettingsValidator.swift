import Foundation

enum GatewaySettingsValidator {
    struct ValidationError: LocalizedError, Equatable {
        let message: String
        var errorDescription: String? { message }
    }

    static func validateBaseURL(_ raw: String) -> Result<URL, ValidationError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.init(message: "Base URL is required."))
        }

        guard let url = URL(string: trimmed) else {
            return .failure(.init(message: "Invalid URL. Include a scheme like \(GatewayDefaults.baseURLString)"))
        }

        guard let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            return .failure(.init(message: "URL must start with http:// or https://"))
        }

        guard let host = url.host, !host.isEmpty else {
            return .failure(.init(message: "URL must include a host (e.g. 127.0.0.1)"))
        }


        if let path = url.pathComponents.dropFirst().first, !path.isEmpty {
            return .failure(.init(message: "Base URL should not include a path; use e.g. \(GatewayDefaults.baseURLString)"))
        }

        if url.query != nil || url.fragment != nil {
            return .failure(.init(message: "Base URL should not include query/fragment parameters"))
        }

        // If the user omits a port, assume the default Gateway port.
        if url.port == nil {
            guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return .failure(.init(message: "Invalid URL. Include a scheme like \(GatewayDefaults.baseURLString)"))
            }
            comps.port = GatewayDefaults.defaultPort
            if let ported = comps.url {
                return .success(ported)
            }
        }

        return .success(url)
    }
}
