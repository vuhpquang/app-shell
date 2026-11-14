import XCTest
@testable import UpdaterKit

/// Real GitHub + real installer staging (no swap). Opt-in:
/// `APPSHELL_LIVE=vuhpquang/launch-app:dmg:com.vuhpquang.launchapp swift test --filter LiveTests`
/// (kind = dmg | zip:<prefix>).
final class LiveTests: XCTestCase {
    func testStageLatestRelease() async throws {
        guard let spec = ProcessInfo.processInfo.environment["APPSHELL_LIVE"] else {
            throw XCTSkip("set APPSHELL_LIVE=owner/repo:kind:bundle.id")
        }
        let parts = spec.split(separator: ":").map(String.init)
        let repo = parts[0], bundleId = parts.last!
        let matcher: AssetMatcher = parts[1] == "dmg" ? .dmg : .zip(prefix: parts.count > 3 ? parts[2] : nil)
        let transport = URLSessionTransport()
        let release = try await transport.latestRelease(repo: repo, userAgent: "app-shell-tests")
        guard case let .available(version, asset, _) = UpdateCheckResult.evaluate(release, current: "0.0.1", matcher: matcher) else {
            return XCTFail("no installable asset in \(release.tagName)")
        }
        let file = try await transport.download(asset)
        let staged = try Installer().stage(file, kind: matcher.kind, bundleId: bundleId)
        print("LIVE: \(repo) \(version) staged OK at \(staged.path)")
        XCTAssertEqual(Bundle(url: staged)?.bundleIdentifier, bundleId)
    }
}
