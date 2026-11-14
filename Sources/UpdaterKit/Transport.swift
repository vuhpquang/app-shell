import Foundation

/// Network seam of the updater (a fake in tests).
public protocol UpdateTransport: Sendable {
    /// `GET /repos/{repo}/releases/latest` (GitHub leaves pre-releases out).
    func latestRelease(repo: String, userAgent: String) async throws -> Release
    /// `GET /repos/{repo}/releases/tags/{tag}` — used by What's New.
    func release(repo: String, tag: String, userAgent: String) async throws -> Release
    /// Downloads to a temporary file and returns its location.
    func download(_ url: URL) async throws -> URL
}

public struct URLSessionTransport: UpdateTransport {
    public init() {}

    public func latestRelease(repo: String, userAgent: String) async throws -> Release {
        try await fetch("https://api.github.com/repos/\(repo)/releases/latest", userAgent: userAgent)
    }

    public func release(repo: String, tag: String, userAgent: String) async throws -> Release {
        try await fetch("https://api.github.com/repos/\(repo)/releases/tags/\(tag)", userAgent: userAgent)
    }

    private func fetch(_ url: String, userAgent: String) async throws -> Release {
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try Release.decode(data)
    }

    public func download(_ url: URL) async throws -> URL {
        let (location, response) = try await URLSession.shared.download(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw UpdateError("The download failed. Try again later")
        }
        // URLSession deletes `location` when this returns; move it somewhere we own.
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent("AppShellDownload-\(UUID().uuidString)")
        try FileManager.default.moveItem(at: location, to: kept)
        return kept
    }
}

/// An updater error whose message is shown to the user as is.
public struct UpdateError: LocalizedError, Equatable {
    public let errorDescription: String?
    public init(_ message: String) { errorDescription = message }
}
