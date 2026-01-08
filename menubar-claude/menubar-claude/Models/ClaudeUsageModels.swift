//
//  ClaudeUsageModels.swift
//  menubar-claude
//
//  Data models for Claude usage information
//

import Foundation

/// Response from claude.py script
struct ClaudeUsageResponse: Codable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

/// Usage information for a specific time window
struct UsageWindow: Codable {
    let utilization: Double
    let limit: Int?
    let used: Int?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case limit
        case used
        case resetsAt = "resets_at"
    }

    /// Parse reset time as Date
    var resetDate: Date? {
        guard let resetsAt = resetsAt else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: resetsAt) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }

    /// Time remaining until reset
    var timeUntilReset: TimeInterval? {
        guard let resetDate = resetDate else { return nil }
        return resetDate.timeIntervalSinceNow
    }

    /// Formatted time until reset (e.g., "2h 34m", "1d 5h")
    var formattedTimeUntilReset: String {
        guard let interval = timeUntilReset, interval > 0 else {
            return "Reset now"
        }

        let seconds = Int(interval)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Usage status for display
enum UsageStatus {
    case ready          // Not started or 0%
    case low           // < 50%
    case medium        // 50-79%
    case high          // 80-99%
    case exhausted     // 100%

    init(utilization: Double) {
        switch utilization {
        case 0:
            self = .ready
        case 0..<50:
            self = .low
        case 50..<80:
            self = .medium
        case 80..<100:
            self = .high
        default:
            self = .exhausted
        }
    }

    var color: String {
        switch self {
        case .ready: return "green"
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .exhausted: return "red"
        }
    }

    var description: String {
        switch self {
        case .ready: return "Ready"
        case .low: return "Low Usage"
        case .medium: return "Moderate Usage"
        case .high: return "High Usage"
        case .exhausted: return "Limit Reached"
        }
    }
}

/// Structured error types for Claude usage fetching
enum ClaudeUsageError: Error {
    case cookieAuthenticationFailed(installedBrowsers: [SupportedBrowser], allSupportedBrowsers: [SupportedBrowser])
    case uvNotFound
    case networkError(message: String)
    case forbidden
    case scriptExecutionFailed(message: String)
    case parseError(message: String)
    case unknown(message: String)

    /// User-friendly title for the error
    var title: String {
        switch self {
        case .cookieAuthenticationFailed:
            return "Authentication Required"
        case .uvNotFound:
            return "UV Not Installed"
        case .networkError:
            return "Network Error"
        case .forbidden:
            return "Access Forbidden"
        case .scriptExecutionFailed:
            return "Script Error"
        case .parseError:
            return "Data Error"
        case .unknown:
            return "Unknown Error"
        }
    }

    /// Detailed user-friendly message explaining the error
    var message: String {
        switch self {
        case .cookieAuthenticationFailed(let installedBrowsers, let allSupportedBrowsers):
            if installedBrowsers.isEmpty {
                // No supported browsers installed
                let browserNames = allSupportedBrowsers.map { $0.displayName }.joined(separator: ", ")
                return "Could not find valid Claude session cookies.\n\nNo supported browsers are installed. Please install one of:\n\(browserNames)"
            } else {
                // Show only installed browsers
                let browserNames = installedBrowsers.map { $0.displayName }.joined(separator: ", ")
                if installedBrowsers.count == 1 {
                    return "Could not find valid Claude session cookies.\n\nPlease sign in to Claude.ai in \(browserNames)."
                } else {
                    return "Could not find valid Claude session cookies.\n\nPlease sign in to Claude.ai in one of these installed browsers:\n\(browserNames)"
                }
            }
        case .uvNotFound:
            return "The 'uv' package manager is not installed.\n\nPlease install it from:\nhttps://docs.astral.sh/uv/getting-started/installation/"
        case .networkError(let msg):
            return "Failed to connect to Claude servers.\n\n\(msg)"
        case .forbidden:
            return "Access was denied by Claude servers.\n\nTry refreshing the Claude.ai page in your browser or switching organizations."
        case .scriptExecutionFailed(let msg):
            return "The Python script encountered an error:\n\n\(msg)"
        case .parseError(let msg):
            return "Failed to parse the response data:\n\n\(msg)"
        case .unknown(let msg):
            return "An unexpected error occurred:\n\n\(msg)"
        }
    }

    /// Icon name for the error
    var iconName: String {
        switch self {
        case .cookieAuthenticationFailed:
            return "key.slash.fill"
        case .uvNotFound:
            return "exclamationmark.triangle.fill"
        case .networkError:
            return "wifi.exclamationmark"
        case .forbidden:
            return "hand.raised.fill"
        case .scriptExecutionFailed, .parseError:
            return "exclamationmark.octagon.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    /// Suggested action for the user
    var suggestedAction: String? {
        switch self {
        case .cookieAuthenticationFailed(let installedBrowsers, _):
            if installedBrowsers.isEmpty {
                return "Install a supported browser"
            } else if installedBrowsers.count == 1 {
                return "Open \(installedBrowsers[0].displayName) and sign in"
            } else {
                return "Open your browser and sign in to Claude.ai"
            }
        case .uvNotFound:
            return "Install UV package manager"
        case .networkError:
            return "Check your internet connection"
        case .forbidden:
            return "Refresh Claude.ai in your browser"
        case .scriptExecutionFailed, .parseError, .unknown:
            return nil
        }
    }

    /// Get installed browsers for this error (if applicable)
    var installedBrowsers: [SupportedBrowser]? {
        switch self {
        case .cookieAuthenticationFailed(let installed, _):
            return installed
        default:
            return nil
        }
    }

    /// Parse error from stderr output
    static func parse(from stderr: String) -> ClaudeUsageError {
        // Try to parse JSON error data first (new format)
        let lines = stderr.components(separatedBy: "\n")
        if let jsonLine = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("{") }),
           let jsonData = jsonLine.data(using: .utf8),
           let errorDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let errorMessage = errorDict["error"] as? String {

            // Extract supported browsers from JSON
            var supportedBrowsers: [SupportedBrowser] = []
            if let browserNames = errorDict["supported_browsers"] as? [String] {
                supportedBrowsers = browserNames.compactMap { SupportedBrowser.parse(from: $0) }
            }

            // Determine error type from message
            if errorMessage.contains("Failed to read cookies") || errorMessage.contains("No valid cookies found") {
                // Check which browsers are actually installed
                let installedBrowsers = SupportedBrowser.getInstalledBrowsers(from: supportedBrowsers)
                return .cookieAuthenticationFailed(installedBrowsers: installedBrowsers, allSupportedBrowsers: supportedBrowsers)
            } else if errorMessage.contains("403 Forbidden") {
                return .forbidden
            } else if errorMessage.contains("Request failed") || errorMessage.contains("Connection") || errorMessage.contains("timeout") {
                return .networkError(message: errorMessage)
            } else if errorMessage.contains("Missing 'lastActiveOrg'") {
                return .forbidden
            } else {
                return .scriptExecutionFailed(message: errorMessage)
            }
        }

        // Fallback to old parsing method
        let errorLine = lines.first { $0.contains("[!] Critical Error:") } ?? stderr
        let cleanError = errorLine.replacingOccurrences(of: "[!] Critical Error:", with: "").trimmingCharacters(in: .whitespaces)

        // Check for specific error patterns
        if cleanError.contains("Failed to read cookies") || cleanError.contains("No valid cookies found") {
            // Use default browser list as fallback
            let defaultBrowsers: [SupportedBrowser] = [.chrome, .firefox, .brave, .edge, .safari]
            let installedBrowsers = SupportedBrowser.getInstalledBrowsers(from: defaultBrowsers)
            return .cookieAuthenticationFailed(installedBrowsers: installedBrowsers, allSupportedBrowsers: defaultBrowsers)
        } else if cleanError.contains("Could not find uv executable") {
            return .uvNotFound
        } else if cleanError.contains("403 Forbidden") || stderr.contains("403") {
            return .forbidden
        } else if cleanError.contains("Request failed") || cleanError.contains("Connection") || cleanError.contains("timeout") {
            return .networkError(message: cleanError)
        } else if cleanError.contains("Missing 'lastActiveOrg'") {
            return .forbidden
        } else if !cleanError.isEmpty {
            return .scriptExecutionFailed(message: cleanError)
        } else {
            return .unknown(message: stderr)
        }
    }
}
