import Foundation

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public enum StaticReError: LocalizedError, Sendable {
    case missingApiKey
    case invalidURL(String)
    case httpError(statusCode: Int, message: String)
    case fileNotFound(String)
    case uploadFailed(String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "API Key is not configured. Please set your API Key in Settings or ~/.static-re/config.json."
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let statusCode, let message):
            return "HTTP Error \(statusCode): \(message)"
        case .fileNotFound(let path):
            return "File not found at: \(path)"
        case .uploadFailed(let msg):
            return "Direct upload to storage failed: \(msg)"
        case .decodingError(let msg):
            return "Failed to decode response: \(msg)"
        }
    }
}

public final class StaticReClient: @unchecked Sendable {
    public let config: AppConfig
    private let urlSession: URLSession

    public init(config: AppConfig? = nil, urlSession: URLSession = .shared) {
        self.config = config ?? ConfigManager.shared.loadConfig()
        self.urlSession = urlSession
    }

    // MARK: - Health Check

    public func checkHealth() async throws -> HealthResponse {
        guard let url = URL(string: "\(config.apiBaseUrl)/health") else {
            throw StaticReError.invalidURL("\(config.apiBaseUrl)/health")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StaticReError.httpError(statusCode: 0, message: "Non-HTTP response received")
        }

        if httpResponse.statusCode != 200 && httpResponse.statusCode != 503 {
            throw try parseError(from: data, statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(HealthResponse.self, from: data)
        } catch {
            throw StaticReError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Presign Upload Request

    public func requestPresignedUrl(
        fileName: String,
        contentType: String,
        key: String? = nil,
        contentLength: Int64? = nil,
        customMetadata: [String: String]? = nil,
        expiresInSeconds: Int? = nil
    ) async throws -> PresignedUrlResponse {
        guard !config.apiKey.isEmpty else {
            throw StaticReError.missingApiKey
        }

        guard let url = URL(string: "\(config.apiBaseUrl)/upload/presign") else {
            throw StaticReError.invalidURL("\(config.apiBaseUrl)/upload/presign")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")

        let payload = PresignUploadRequest(
            fileName: fileName,
            contentType: contentType,
            key: key,
            contentLength: contentLength,
            customMetadata: customMetadata,
            expiresInSeconds: expiresInSeconds
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StaticReError.httpError(statusCode: 0, message: "Non-HTTP response received")
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw try parseError(from: data, statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(PresignedUrlResponse.self, from: data)
        } catch {
            throw StaticReError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Direct Binary Upload to Presigned R2 URL

    public func uploadData(
        _ data: Data,
        to uploadUrlString: String,
        contentType: String,
        headers: [String: String] = [:]
    ) async throws {
        guard let uploadUrl = URL(string: uploadUrlString) else {
            throw StaticReError.invalidURL(uploadUrlString)
        }

        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        for (headerKey, headerVal) in headers {
            request.setValue(headerVal, forHTTPHeaderField: headerKey)
        }

        let (respData, response) = try await urlSession.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StaticReError.uploadFailed("Non-HTTP response received from storage")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: respData, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw StaticReError.uploadFailed("Storage upload returned \(httpResponse.statusCode): \(errorText)")
        }
    }

    // MARK: - High-Level File Upload

    public func uploadFile(
        at fileUrl: URL,
        customKey: String? = nil,
        customMetadata: [String: String]? = nil
    ) async throws -> PresignedUrlResponse {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileUrl.path) else {
            throw StaticReError.fileNotFound(fileUrl.path)
        }

        let fileData = try Data(contentsOf: fileUrl)
        let fileName = fileUrl.lastPathComponent
        let contentType = detectContentType(for: fileUrl)
        let fileSize = Int64(fileData.count)

        // 1. Request presigned URL from API
        let presignResponse = try await requestPresignedUrl(
            fileName: fileName,
            contentType: contentType,
            key: customKey,
            contentLength: fileSize,
            customMetadata: customMetadata
        )

        // 2. Perform direct binary upload to R2
        try await uploadData(
            fileData,
            to: presignResponse.data.uploadUrl,
            contentType: contentType,
            headers: presignResponse.data.headers
        )

        return presignResponse
    }

    // MARK: - Asset Management

    public func listAssets(prefix: String? = nil, limit: Int = 50) async throws -> AssetListResponse {
        guard !config.apiKey.isEmpty else {
            throw StaticReError.missingApiKey
        }

        var components = URLComponents(string: "\(config.apiBaseUrl)/assets")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let prefix = prefix, !prefix.isEmpty {
            queryItems.append(URLQueryItem(name: "prefix", value: prefix))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw StaticReError.invalidURL("\(config.apiBaseUrl)/assets")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StaticReError.httpError(statusCode: 0, message: "Non-HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            throw try parseError(from: data, statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(AssetListResponse.self, from: data)
    }

    public func deleteAsset(key: String) async throws -> AssetDeleteResponse {
        guard !config.apiKey.isEmpty else {
            throw StaticReError.missingApiKey
        }

        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        guard let url = URL(string: "\(config.apiBaseUrl)/assets/\(encodedKey)") else {
            throw StaticReError.invalidURL("\(config.apiBaseUrl)/assets/\(encodedKey)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StaticReError.httpError(statusCode: 0, message: "Non-HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            throw try parseError(from: data, statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(AssetDeleteResponse.self, from: data)
    }

    // MARK: - Helpers

    public func detectContentType(for url: URL) -> String {
        if #available(macOS 11.0, *),
           let uti = UTType(filenameExtension: url.pathExtension),
           let mime = uti.preferredMIMEType {
            return mime
        }

        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "pdf": return "application/pdf"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "json": return "application/json"
        case "txt": return "text/plain"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }

    private func parseError(from data: Data, statusCode: Int) throws -> Error {
        if let apiError = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) {
            return apiError
        }
        let rawMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        return StaticReError.httpError(statusCode: statusCode, message: rawMessage)
    }
}
