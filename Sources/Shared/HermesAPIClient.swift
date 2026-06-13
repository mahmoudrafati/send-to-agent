import Foundation

public struct HermesConnectionConfig: Codable, Equatable {
    public var baseURL: URL
    public var tokenReference: String
    public var defaultCoordinatorAgentId: String
    public var defaultIngestionAgentId: String

    public init(
        baseURL: URL,
        tokenReference: String,
        defaultCoordinatorAgentId: String = "default",
        defaultIngestionAgentId: String = "ingestion"
    ) {
        self.baseURL = baseURL
        self.tokenReference = tokenReference
        self.defaultCoordinatorAgentId = defaultCoordinatorAgentId
        self.defaultIngestionAgentId = defaultIngestionAgentId
    }
}

public final class HermesAPIClient {
    private let config: HermesConnectionConfig
    private let tokenProvider: () throws -> String
    private let session: URLSession

    public init(
        config: HermesConnectionConfig,
        session: URLSession = .shared,
        tokenProvider: @escaping () throws -> String
    ) {
        self.config = config
        self.session = session
        self.tokenProvider = tokenProvider
    }

    public func send(_ payload: HermesSharePayload) async throws -> HermesShareResponse {
        let endpoint = config.baseURL.appending(path: "api/hermes/share")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(try tokenProvider())", forHTTPHeaderField: "authorization")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HermesAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HermesAPIError.httpStatus(http.statusCode, data)
        }
        return try JSONDecoder().decode(HermesShareResponse.self, from: data)
    }
}

public struct HermesShareResponse: Codable {
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

public enum HermesAPIError: Error {
    case invalidResponse
    case httpStatus(Int, Data)
}
