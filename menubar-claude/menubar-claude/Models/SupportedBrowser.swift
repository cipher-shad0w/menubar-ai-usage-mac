//
//  SupportedBrowser.swift
//  menubar-claude
//
//  Browser detection and management
//

import Foundation
import AppKit

/// Supported browsers for Claude authentication
enum SupportedBrowser: String, CaseIterable, Codable, Hashable {
    case chrome
    case firefox
    case brave
    case edge
    case opera
    case chromium
    case vivaldi
    case safari
    case comet

    /// Display name for the browser
    var displayName: String {
        switch self {
        case .chrome: return "Chrome"
        case .firefox: return "Firefox"
        case .brave: return "Brave"
        case .edge: return "Edge"
        case .opera: return "Opera"
        case .chromium: return "Chromium"
        case .vivaldi: return "Vivaldi"
        case .safari: return "Safari"
        case .comet: return "Comet"
        }
    }

    /// Bundle identifier for the browser application
    var bundleIdentifier: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .firefox: return "org.mozilla.firefox"
        case .brave: return "com.brave.Browser"
        case .edge: return "com.microsoft.edgemac"
        case .opera: return "com.operasoftware.Opera"
        case .chromium: return "org.chromium.Chromium"
        case .vivaldi: return "com.vivaldi.Vivaldi"
        case .safari: return "com.apple.Safari"
        case .comet: return "ai.perplexity.comet"
        }
    }

    /// Check if this browser is installed on the system
    var isInstalled: Bool {
        let workspace = NSWorkspace.shared
        let appURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
        return appURL != nil
    }

    /// Get URL for the browser's homepage (for downloading)
    var downloadURL: String {
        switch self {
        case .chrome: return "https://www.google.com/chrome/"
        case .firefox: return "https://www.mozilla.org/firefox/"
        case .brave: return "https://brave.com/download/"
        case .edge: return "https://www.microsoft.com/edge"
        case .opera: return "https://www.opera.com/download"
        case .chromium: return "https://www.chromium.org/getting-involved/download-chromium/"
        case .vivaldi: return "https://vivaldi.com/download/"
        case .safari: return "https://www.apple.com/safari/"
        case .comet: return "https://www.cometbrowser.com/"
        }
    }

    /// Get all installed browsers from a list of supported browsers
    static func getInstalledBrowsers(from browsers: [SupportedBrowser]) -> [SupportedBrowser] {
        return browsers.filter { $0.isInstalled }
    }

    /// Get all installed browsers from the system
    static func getAllInstalledBrowsers() -> [SupportedBrowser] {
        return SupportedBrowser.allCases.filter { $0.isInstalled }
    }

    /// Parse browser from string name (case-insensitive)
    static func parse(from string: String) -> SupportedBrowser? {
        return SupportedBrowser(rawValue: string.lowercased())
    }
}
