import Foundation

// MARK: - Health Check Response

public struct HealthServices: Codable, Sendable {
    public let r2Bucket: String

    public init(r2Bucket: String) {
        self.r2Bucket = r2Bucket
    }
}

public struct HealthResponse: Codable, Sendable {
    public let status: String
    public let timestamp: String
    public let version: String
    public let environment: String
    public let services: HealthServices

    public init(status: String, timestamp: String, version: String, environment: String, services: HealthServices) {
        self.status = status
        self.timestamp = timestamp
        self.version = version
        self.environment = environment
        self.services = services
    }
}

// MARK: - Error Response

public struct ApiErrorDetail: Codable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct ApiErrorResponse: Codable, Sendable, LocalizedError {
    public let success: Bool
    public let error: ApiErrorDetail

    public init(success: Bool, error: ApiErrorDetail) {
        self.success = success
        self.error = error
    }

    public var errorDescription: String? {
        return "[\(error.code)] \(error.message)"
    }
}

// MARK: - Presign Request & Response

public struct PresignUploadRequest: Codable, Sendable {
    public let fileName: String
    public let contentType: String
    public let key: String?
    public let contentLength: Int64?
    public let customMetadata: [String: String]?
    public let expiresInSeconds: Int?

    public init(
        fileName: String,
        contentType: String,
        key: String? = nil,
        contentLength: Int64? = nil,
        customMetadata: [String: String]? = nil,
        expiresInSeconds: Int? = nil
    ) {
        self.fileName = fileName
        self.contentType = contentType
        self.key = key
        self.contentLength = contentLength
        self.customMetadata = customMetadata
        self.expiresInSeconds = expiresInSeconds
    }
}

public struct PresignedUrlData: Codable, Sendable {
    public let key: String
    public let uploadUrl: String
    public let method: String
    public let headers: [String: String]
    public let publicUrl: String
    public let expiresAt: String
    public let expiresInSeconds: Int

    public init(
        key: String,
        uploadUrl: String,
        method: String,
        headers: [String: String],
        publicUrl: String,
        expiresAt: String,
        expiresInSeconds: Int
    ) {
        self.key = key
        self.uploadUrl = uploadUrl
        self.method = method
        self.headers = headers
        self.publicUrl = publicUrl
        self.expiresAt = expiresAt
        self.expiresInSeconds = expiresInSeconds
    }
}

public struct PresignedUrlResponse: Codable, Sendable {
    public let success: Bool
    public let data: PresignedUrlData

    public init(success: Bool, data: PresignedUrlData) {
        self.success = success
        self.data = data
    }
}

// MARK: - Asset Metadata & Management

public struct AssetMetadata: Codable, Sendable, Identifiable {
    public var id: String { key }
    public let key: String
    public let size: Int64
    public let etag: String
    public let contentType: String
    public let uploadedAt: String
    public let publicUrl: String
    public let customMetadata: [String: String]?

    public init(
        key: String,
        size: Int64,
        etag: String,
        contentType: String,
        uploadedAt: String,
        publicUrl: String,
        customMetadata: [String: String]? = nil
    ) {
        self.key = key
        self.size = size
        self.etag = etag
        self.contentType = contentType
        self.uploadedAt = uploadedAt
        self.publicUrl = publicUrl
        self.customMetadata = customMetadata
    }
}

public struct AssetDetailsResponse: Codable, Sendable {
    public let success: Bool
    public let data: AssetMetadata

    public init(success: Bool, data: AssetMetadata) {
        self.success = success
        self.data = data
    }
}

public struct AssetDeleteData: Codable, Sendable {
    public let key: String
    public let deleted: Bool
}

public struct AssetDeleteResponse: Codable, Sendable {
    public let success: Bool
    public let data: AssetDeleteData
}

public struct AssetListData: Codable, Sendable {
    public let objects: [AssetMetadata]
    public let truncated: Bool
    public let cursor: String?
}

public struct AssetListResponse: Codable, Sendable {
    public let success: Bool
    public let data: AssetListData
}
