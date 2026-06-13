import Foundation

public enum HermesAppDefaults {
    public static let appGroupIdentifier = "group.com.mahmoudrafati.hermesshare"
    public static let endpointKey = "hermes.endpointURL"
    public static let tokenKey = "hermes.apiToken"
    public static let shareExtensionVersion = "0.1.0"
}

public struct HermesConnectionConfig: Codable, Equatable, Sendable {
    public var endpointURL: URL
    public var defaultCoordinatorAgentId: String
    public var defaultIngestionAgentId: String

    public init(
        endpointURL: URL,
        defaultCoordinatorAgentId: String = "default",
        defaultIngestionAgentId: String = "ingestion"
    ) {
        self.endpointURL = endpointURL
        self.defaultCoordinatorAgentId = defaultCoordinatorAgentId
        self.defaultIngestionAgentId = defaultIngestionAgentId
    }
}

public struct HermesAppConfiguration: Equatable, Sendable {
    public var endpointURL: URL?
    public var hasStoredToken: Bool

    public init(endpointURL: URL?, hasStoredToken: Bool) {
        self.endpointURL = endpointURL
        self.hasStoredToken = hasStoredToken
    }
}

public enum HermesConfigurationError: LocalizedError {
    case invalidEndpoint(String)
    case missingEndpoint
    case missingToken
    case invalidStoredToken
    case keychain(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let value):
            return "Ungültige Endpoint-URL: \(value)"
        case .missingEndpoint:
            return "Bitte zuerst einen Endpoint speichern."
        case .missingToken:
            return "Bitte einen Bearer Token speichern."
        case .invalidStoredToken:
            return "Keychain Token konnte nicht gelesen werden."
        case .keychain(let status):
            return "Keychain error: \(status)"
        }
    }
}

public final class HermesConfigurationStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = UserDefaults(suiteName: HermesAppDefaults.appGroupIdentifier) ?? .standard) {
        self.defaults = defaults
    }

    public func loadEndpointURL() -> URL? {
        guard let raw = defaults.string(forKey: HermesAppDefaults.endpointKey) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    public func saveEndpointURL(_ url: URL) {
        defaults.set(url.absoluteString, forKey: HermesAppDefaults.endpointKey)
    }

    public func validateEndpoint(_ rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            throw HermesConfigurationError.invalidEndpoint(rawValue)
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            throw HermesConfigurationError.invalidEndpoint(rawValue)
        }
        return components.url ?? url
    }

    public func currentConfiguration() -> HermesAppConfiguration {
        HermesAppConfiguration(endpointURL: loadEndpointURL(), hasStoredToken: hasStoredToken())
    }

    public func saveToken(_ token: String) throws {
        try HermesSharedTokenStore.save(token)
    }

    public func loadToken() throws -> String? {
        try HermesSharedTokenStore.load()
    }

    public func hasStoredToken() -> Bool {
        guard let token = try? loadToken() else { return false }
        return token.isEmpty == false
    }

    public func save(endpointURL: URL, token: String?) throws {
        saveEndpointURL(endpointURL)
        if let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try saveToken(token)
        }
    }
}

public enum HermesSharedTokenStore {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: HermesAppDefaults.appGroupIdentifier) ?? .standard
    }

    public static func save(_ token: String) throws {
        defaults.set(token.trimmingCharacters(in: .whitespacesAndNewlines), forKey: HermesAppDefaults.tokenKey)
    }

    public static func load() throws -> String? {
        guard let token = defaults.string(forKey: HermesAppDefaults.tokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return nil
        }
        return token
    }

    public static func delete() throws {
        defaults.removeObject(forKey: HermesAppDefaults.tokenKey)
    }
}

public final class HermesAPIClient: @unchecked Sendable {
    private let config: HermesConnectionConfig
    private let tokenProvider: () throws -> String
    private let session: URLSession

    public init(
        config: HermesConnectionConfig,
        session: URLSession = .shared,
        tokenProvider: @Sendable @escaping () throws -> String
    ) {
        self.config = config
        self.session = session
        self.tokenProvider = tokenProvider
    }

    public func send(_ payload: HermesSharePayload) async throws -> HermesShareResponse {
        let endpoint = config.endpointURL.appending(path: "api/hermes/share")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        let token = try tokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw HermesConfigurationError.missingToken
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HermesAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw HermesAPIError.httpStatus(http.statusCode, body)
        }
        return try JSONDecoder().decode(HermesShareResponse.self, from: data)
    }
}

public struct HermesShareResponse: Codable, Sendable {
    public let ok: Bool
    public let taskId: String?
    public let messageId: String?
    public let artifactPath: String?
    public let statusURL: URL?

    enum CodingKeys: String, CodingKey {
        case ok
        case taskId = "task_id"
        case messageId = "message_id"
        case artifactPath = "artifact_path"
        case statusURL = "status_url"
    }
}

public enum HermesAPIError: Error, LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ungültige Antwort vom Backend"
        case .httpStatus(let status, let body):
            if let body, !body.isEmpty {
                return "HTTP \(status): \(body)"
            }
            return "HTTP \(status)"
        }
    }
}
