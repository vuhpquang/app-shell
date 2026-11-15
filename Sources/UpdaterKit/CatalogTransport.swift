import Foundation

/// Update source for an app that is published in the vuhpquang.com catalog
/// (`/api/depot/catalog?platform=macos`) instead of straight from GitHub Releases.
/// `repo` / `userAgent` arguments of `UpdateTransport` are ignored: the catalog `slug` picks the app.
public struct CatalogTransport: UpdateTransport {
    public let catalogURL: URL
    public let slug: String

    public init(catalogURL: URL, slug: String) {
        self.catalogURL = catalogURL
        self.slug = slug
    }

    public func latestRelease(repo: String, userAgent: String) async throws -> Release {
        try await fetch(userAgent: userAgent)
    }

    /// What's New asks for the running version's notes: the catalog only knows the latest one.
    public func release(repo: String, tag: String, userAgent: String) async throws -> Release {
        let latest = try await fetch(userAgent: userAgent)
        guard Self.matches(tag: tag, latest) else { throw UpdateError("No release notes for \(tag)") }
        return latest
    }

    /// The catalog's release is `v<version>`; the app may ask with its own tag prefix (`macos-v0.1.0`).
    static func matches(tag: String, _ release: Release) -> Bool {
        func version(_ t: String) -> Substring { t.drop { !$0.isNumber } }
        return version(tag) == version(release.tagName)
    }

    public func download(_ url: URL) async throws -> URL {
        try await URLSessionTransport().download(url)
    }

    private func fetch(userAgent: String) async throws -> Release {
        var request = URLRequest(url: catalogURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try Self.release(fromCatalog: data, slug: slug)
    }

    /// Pure mapping, kept separate for tests.
    static func release(fromCatalog data: Data, slug: String) throws -> Release {
        let catalog = try JSONDecoder().decode(Envelope.self, from: data)
        guard let app = catalog.data.apps.first(where: { $0.slug == slug }) else {
            throw UpdateError("This app isn't in the catalog")
        }
        guard let latest = app.latest else { throw UpdateError("No release yet") }
        guard let url = URL(string: latest.downloadUrl) else { throw UpdateError("The catalog has a bad download link") }
        return Release(tagName: "v" + latest.version,
                       body: latest.notes,
                       publishedAt: latest.publishedAt.flatMap(Self.parseDate),
                       assets: [.init(name: latest.assetName, url: url)])
    }

    private static func parseDate(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? plain.date(from: text)
    }

    private struct Envelope: Decodable {
        struct Payload: Decodable { let apps: [App] }
        struct App: Decodable {
            let slug: String
            let latest: Latest?
        }
        struct Latest: Decodable {
            let version: String
            let notes: String?
            let assetName: String
            let downloadUrl: String
            let publishedAt: String?
        }
        let data: Payload
    }
}
