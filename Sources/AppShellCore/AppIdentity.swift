import AppKit
import SwiftUI

/// How an app offers "What's New" after it was updated.
public enum WhatsNewMode: Sendable, Equatable {
    /// Opens a window by itself on the first launch of a new version (apps with a main window).
    case automatic
    /// Shows a "What's New in X" menu item until opened once (background / menu-bar apps,
    /// which start at login and may be relaunched by auto-install with nobody watching).
    case menuItem
}

/// Someone else's work an app builds on (forks name their upstream here).
public struct Credit: Sendable, Equatable {
    public var name: String
    public var url: URL
    public var note: String

    public init(name: String, url: URL, note: String) {
        self.name = name
        self.url = url
        self.note = note
    }
}

/// Everything the shared shell needs to know about one app. Filled once per app.
public struct AppIdentity: Sendable {
    public var name: String
    /// One line in the app's own words.
    public var tagline: String
    /// GitHub "owner/name", e.g. "vuhpquang/launch-app".
    public var repo: String
    /// Year of the first release, for the copyright line.
    public var firstYear: Int
    /// The app's accent colour; nil = system accent.
    public var accent: Color?
    public var credits: [Credit]
    public var whatsNew: WhatsNewMode
    /// The bundle to read version and icon from (the app's main bundle).
    public var bundleURL: URL

    public init(name: String, tagline: String, repo: String, firstYear: Int, accent: Color? = nil,
                credits: [Credit] = [], whatsNew: WhatsNewMode = .menuItem, bundleURL: URL = Bundle.main.bundleURL) {
        self.name = name
        self.tagline = tagline
        self.repo = repo
        self.firstYear = firstYear
        self.accent = accent
        self.credits = credits
        self.whatsNew = whatsNew
        self.bundleURL = bundleURL
    }

    private var info: [String: Any] { Bundle(url: bundleURL)?.infoDictionary ?? [:] }

    /// CFBundleShortVersionString ("0.0.0" outside an app bundle).
    public var version: String { info["CFBundleShortVersionString"] as? String ?? "0.0.0" }
    /// CFBundleVersion ("0" outside an app bundle).
    public var build: String { info["CFBundleVersion"] as? String ?? "0" }
    public var bundleIdentifier: String? { Bundle(url: bundleURL)?.bundleIdentifier }

    public var repoURL: URL { URL(string: "https://github.com/\(repo)")! }
    public var releasesURL: URL { repoURL.appendingPathComponent("releases") }
    public var newIssueURL: URL { repoURL.appendingPathComponent("issues/new") }
    public func releaseURL(tag: String) -> URL { releasesURL.appendingPathComponent("tag/\(tag)") }

    public var copyright: String { Author.copyright(since: firstYear) }
}
