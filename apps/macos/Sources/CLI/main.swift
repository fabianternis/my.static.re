import Foundation
import StaticReKit
import AppKit

func printUsage() {
    print("""
    static-re - Command Line Tool for my.static.re

    USAGE:
      static-re <command> [options]

    COMMANDS:
      upload <path> [--key <destination-key>]   Upload a file and copy URL to clipboard
      health                                    Check API & R2 status
      list [--limit <n>]                        List recent assets in bucket
      delete <key>                              Delete an asset by key
      config show                               Display current configuration
      config set-key <api-key>                  Save API key to ~/.static-re/config.json
      config set-url <api-url>                  Set custom API base URL

    EXAMPLES:
      static-re upload ~/Desktop/screenshot.png
      static-re upload ./banner.jpg --key images/banner.jpg
      static-re health
    """)
}

func copyToClipboard(text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

@MainActor
func run() async {
    let args = Array(CommandLine.arguments.dropFirst())

    guard let command = args.first else {
        printUsage()
        exit(0)
    }

    let configManager = ConfigManager.shared
    var config = configManager.loadConfig()
    let client = StaticReClient(config: config)

    switch command.lowercased() {
    case "health":
        print("Checking health of \(config.apiBaseUrl)...")
        do {
            let health = try await client.checkHealth()
            print("Status: \(health.status.uppercased())")
            print("Environment: \(health.environment)")
            print("R2 Bucket: \(health.services.r2Bucket)")
            print("Version: \(health.version)")
            print("Timestamp: \(health.timestamp)")
        } catch {
            print("Health check failed: \(error.localizedDescription)")
            exit(1)
        }

    case "upload":
        guard args.count >= 2 else {
            print("Error: Missing file path.")
            print("Usage: static-re upload <file-path> [--key <custom-key>]")
            exit(1)
        }

        let filePath = args[1]
        let fileUrl = URL(fileURLWithPath: filePath).standardizedFileURL

        var customKey: String? = nil
        if let keyIndex = args.firstIndex(of: "--key"), keyIndex + 1 < args.count {
            customKey = args[keyIndex + 1]
        }

        print("Uploading: \(fileUrl.lastPathComponent)...")

        do {
            let response = try await client.uploadFile(at: fileUrl, customKey: customKey)
            let publicUrl = response.data.publicUrl

            copyToClipboard(text: publicUrl)

            print("Upload Successful!")
            print("-----------------------------------------")
            print("Key:        \(response.data.key)")
            print("Public URL: \(publicUrl)")
            print("Expires At: \(response.data.expiresAt)")
            print("-----------------------------------------")
            print("(Public URL copied to clipboard)")
        } catch {
            print("Upload failed: \(error.localizedDescription)")
            exit(1)
        }

    case "list":
        var limit = 20
        if let limitIndex = args.firstIndex(of: "--limit"), limitIndex + 1 < args.count {
            limit = Int(args[limitIndex + 1]) ?? 20
        }

        print("Fetching assets from \(config.apiBaseUrl)...")
        do {
            let list = try await client.listAssets(limit: limit)
            print("Found \(list.data.objects.count) object(s):")
            print("-----------------------------------------")
            for obj in list.data.objects {
                let sizeKb = Double(obj.size) / 1024.0
                print(String(format: "- [%.1f KB] %@ -> %@", sizeKb, obj.key, obj.publicUrl))
            }
            print("-----------------------------------------")
        } catch {
            print("Failed to list assets: \(error.localizedDescription)")
            exit(1)
        }

    case "delete":
        guard args.count >= 2 else {
            print("Error: Missing asset key.")
            print("Usage: static-re delete <key>")
            exit(1)
        }
        let key = args[1]
        print("Deleting asset: \(key)...")
        do {
            let res = try await client.deleteAsset(key: key)
            print("Deleted: \(res.data.key) (success: \(res.data.deleted))")
        } catch {
            print("Failed to delete asset: \(error.localizedDescription)")
            exit(1)
        }

    case "config":
        guard args.count >= 2 else {
            printUsage()
            exit(1)
        }

        let subCommand = args[1]
        switch subCommand {
        case "show":
            print("Current Configuration:")
            print("  API Base URL:    \(config.apiBaseUrl)")
            print("  Public Base URL: \(config.publicBaseUrl)")
            let maskedKey = config.apiKey.isEmpty ? "(not set)" : "\(config.apiKey.prefix(4))...\(config.apiKey.suffix(4))"
            print("  API Key:         \(maskedKey)")

        case "set-key":
            guard args.count >= 3 else {
                print("Usage: static-re config set-key <api-key>")
                exit(1)
            }
            config.apiKey = args[2]
            do {
                try configManager.saveConfig(config)
                print("API key updated successfully.")
            } catch {
                print("Failed to save config: \(error)")
                exit(1)
            }

        case "set-url":
            guard args.count >= 3 else {
                print("Usage: static-re config set-url <api-url>")
                exit(1)
            }
            config.apiBaseUrl = args[2]
            do {
                try configManager.saveConfig(config)
                print("API Base URL updated successfully.")
            } catch {
                print("Failed to save config: \(error)")
                exit(1)
            }

        default:
            print("Unknown config command: \(subCommand)")
            printUsage()
            exit(1)
        }

    default:
        print("Unknown command: \(command)")
        printUsage()
        exit(1)
    }
}

// Entrypoint
await run()
