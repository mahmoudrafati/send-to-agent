import Foundation

public enum HermesDestination: String, Codable, CaseIterable, Identifiable {
    case coordinator
    case ingestion

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .coordinator: return "Coordinator"
        case .ingestion: return "Ingestion"
        }
    }
}

public struct HermesSharePayload: Codable {
    public let schemaVersion: String
    public let destination: HermesDestination
    public let agentId: String?
    public let prompt: String?
    public let source: HermesShareSource
    public let content: HermesSharedContent
    public let client: HermesClientMetadata

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case destination
        case agentId = "agent_id"
        case prompt
        case source
        case content
        case client
    }
}

public struct HermesShareSource: Codable {
    public let platform: String
    public let app: String?
    public let shareExtensionVersion: String

    enum CodingKeys: String, CodingKey {
        case platform
        case app
        case shareExtensionVersion = "share_extension_version"
    }
}

public struct HermesSharedContent: Codable {
    public let type: String
    public let title: String?
    public let url: URL?
    public let text: String?
    public let files: [HermesSharedFile]
}

public struct HermesSharedFile: Codable {
    public let filename: String
    public let mimeType: String?
    public let sizeBytes: Int?
    public let localIdentifier: String?

    enum CodingKeys: String, CodingKey {
        case filename
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case localIdentifier = "local_identifier"
    }
}

public struct HermesClientMetadata: Codable {
    public let requestId: UUID
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case createdAt = "created_at"
    }
}
