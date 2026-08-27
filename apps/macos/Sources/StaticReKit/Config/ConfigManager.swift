import Foundation

public struct AppConfig: Codable, Sendable {
    public var apiKey: String
    public var apiBaseUrl: String
    public var publicBaseUrl: String

    public init(
        apiKey: String = "",
        apiBaseUrl: String = "https://my-api.static.re",
        publicBaseUrl: String = "https://my.static.re"
    ) {
        self.apiKey = apiKey
        self.apiBaseUrl = apiBaseUrl
        self.publicBaseUrl = publicBaseUrl
    }
}

public final class ConfigManager: @unchecked Sendable {
    public static let shared = ConfigManager()

    private let fileManager = FileManager.default
    private let configDirectory: URL
    private let configFile: URL

    private var cachedConfig: AppConfig?
    private let lock = NSLock()

    public init() {
        let homeDir = fileManager.homeDirectoryForCurrentUser
        self.configDirectory = homeDir.appendingPathComponent(".static-re", isDirectory: true)
        self.configFile = configDirectory.appendingPathComponent("config.json")
    }

    public func loadConfig() -> AppConfig {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedConfig {
            return cached
        }

        var config = AppConfig()

        // 1. Check config file
        if fileManager.fileExists(atPath: configFile.path) {
            do {
                let data = try Data(contentsOf: configFile)
                config = try JSONDecoder().decode(AppConfig.self, from: data)
            } catch {
                print("Warning: Failed to parse config file at \(configFile.path): \(error)")
            }
        }

        // 2. Override with environment variables if present
        if let envKey = ProcessInfo.processInfo.environment["STATIC_RE_API_KEY"], !envKey.isEmpty {
            config.apiKey = envKey
        }
        if let envApiUrl = ProcessInfo.processInfo.environment["STATIC_RE_API_URL"], !envApiUrl.isEmpty {
            config.apiBaseUrl = envApiUrl
        }
        if let envPublicUrl = ProcessInfo.processInfo.environment["STATIC_RE_PUBLIC_URL"], !envPublicUrl.isEmpty {
            config.publicBaseUrl = envPublicUrl
        }

        self.cachedConfig = config
        return config
    }

    public func saveConfig(_ config: AppConfig) throws {
        lock.lock()
        defer { lock.unlock() }

        if !fileManager.fileExists(atPath: configDirectory.path) {
            try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        try data.write(to: configFile, options: .atomic)

        self.cachedConfig = config
    }
}
