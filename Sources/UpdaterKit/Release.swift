import AppShellCore
import Foundation

/// The parts of a GitHub release the updater reads (`GET /repos/{repo}/releases/latest`).
public struct Release: Decodable, Sendable, Equatable {
    public struct Asset: Decodable, Sendable, Equatable {
        public let name: String
        public let url: URL

        enum CodingKeys: String, CodingKey {
            case name
            case url = "browser_download_url"
        }
    }

    public let tagName: String
    public let body: String?
    public let publishedAt: Date?
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case publishedAt = "published_at"
        case assets
    }

    public static func decode(_ data: Data) throws -> Release {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Release.self, from: data)
    }
}

/// Which file of a release is this app's update.
public struct AssetMatcher: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case dmg, zip }

    public let kind: Kind
    /// Only assets whose name starts with this (e.g. "ZenTask-"); nil = any name.
    public let namePrefix: String?

    public init(kind: Kind, namePrefix: String? = nil) {
        self.kind = kind
        self.namePrefix = namePrefix
    }

    public static let dmg = AssetMatcher(kind: .dmg)
    public static func zip(prefix: String? = nil) -> AssetMatcher { AssetMatcher(kind: .zip, namePrefix: prefix) }

    public func pick(_ assets: [Release.Asset]) -> Release.Asset? {
        let suffix = kind == .dmg ? ".dmg" : ".zip"
        return assets.first { asset in
            let name = asset.name.lowercased()
            guard name.hasSuffix(suffix) else { return false }
            if let namePrefix { return asset.name.hasPrefix(namePrefix) }
            return true
        }
    }
}

/// What a check found.
public enum UpdateCheckResult: Equatable, Sendable {
    case upToDate
    case available(version: String, asset: URL, notes: String)

    /// Newer tag *and* an installable asset → available; anything else is up to date.
    public static func evaluate(_ release: Release, current: String, matcher: AssetMatcher) -> UpdateCheckResult {
        let remote = Version.normalize(tag: release.tagName)
        guard Version.isVersion(remote, newerThan: current), let asset = matcher.pick(release.assets) else {
            return .upToDate
        }
        return .available(version: remote, asset: asset.url, notes: release.body ?? "")
    }
}
