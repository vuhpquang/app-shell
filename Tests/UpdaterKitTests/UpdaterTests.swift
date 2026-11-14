import AppShellCore
import Combine
import XCTest
@testable import UpdaterKit

private struct FakeTransport: UpdateTransport {
    var release: Release?
    var error: Error?

    func latestRelease(repo: String, userAgent: String) async throws -> Release {
        if let error { throw error }
        return release!
    }

    func release(repo: String, tag: String, userAgent: String) async throws -> Release {
        try await latestRelease(repo: repo, userAgent: userAgent)
    }

    func download(_ url: URL) async throws -> URL { URL(fileURLWithPath: "/tmp/fake-download") }
}

private final class FakeInstaller: Installing, @unchecked Sendable {
    var preflightError: Error?
    var staged = false
    var relaunched = false

    func preflight(target: URL, appName: String) throws { if let preflightError { throw preflightError } }
    func stage(_ file: URL, kind: AssetMatcher.Kind, bundleId: String?) throws -> URL {
        staged = true
        return URL(fileURLWithPath: "/tmp/Staged.app")
    }
    @MainActor func relaunch(replacing target: URL, with staged: URL, arguments: [String]) throws { relaunched = true }
}

@MainActor
private final class MemorySettings: UpdateSettingsStore {
    var autoCheck = true
    var autoInstall = false
    let subject = PassthroughSubject<Void, Never>()
    var changes: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }
}

@MainActor
final class UpdaterTests: XCTestCase {
    private let release = try! Release.decode(Data(ReleaseTests.json.utf8))
    private let app = AppInfo(name: "LaunchApp", tagline: "t", repo: "vuhpquang/launch-app", firstYear: 2026)

    private func updater(_ transport: FakeTransport, _ installer: FakeInstaller = FakeInstaller(),
                         settings: MemorySettings = MemorySettings()) -> Updater {
        let u = Updater(app: app, matcher: .dmg, settings: settings, transport: transport, installer: installer)
        u.currentVersionOverride = "1.4.2"
        return u
    }

    func testUserCheckFindsUpdate() async {
        let u = updater(FakeTransport(release: release))
        await u.checkNow(userInitiated: true)
        XCTAssertEqual(u.state, .available(version: "1.5.0"))
        XCTAssertEqual(u.releaseNotes, "- Faster search")
        XCTAssertNotNil(u.lastChecked)
    }

    func testUpToDate() async {
        let u = updater(FakeTransport(release: release))
        u.currentVersionOverride = "1.5.0"
        await u.checkNow(userInitiated: true)
        XCTAssertEqual(u.state, .upToDate)
    }

    func testNetworkErrorSaysWhatToDo() async {
        let u = updater(FakeTransport(error: URLError(.notConnectedToInternet)))
        await u.checkNow(userInitiated: true)
        XCTAssertEqual(u.state, .failed("Couldn't reach GitHub. Check your connection and try again"))
    }

    func testBackgroundCheckKeepsVisibleAvailable() async {
        var transport = FakeTransport(release: release)
        let u = updater(transport)
        await u.checkNow(userInitiated: true)
        transport.error = URLError(.timedOut)
        u.transport = transport
        await u.checkNow(userInitiated: false)
        XCTAssertEqual(u.state, .available(version: "1.5.0"))
    }

    func testBackgroundCheckKeepsVisibleFailure() async {
        let u = updater(FakeTransport(error: URLError(.timedOut)))
        await u.checkNow(userInitiated: true)
        u.transport = FakeTransport(release: release)
        await u.checkNow(userInitiated: false)
        XCTAssertEqual(u.state, .failed("Couldn't reach GitHub. Check your connection and try again"))
    }

    func testBackgroundCheckAutoInstalls() async {
        let installer = FakeInstaller()
        let settings = MemorySettings()
        settings.autoInstall = true
        let u = updater(FakeTransport(release: release), installer, settings: settings)
        u.terminate = {}
        await u.checkNow(userInitiated: false)
        XCTAssertTrue(installer.staged)
        XCTAssertTrue(installer.relaunched)
    }

    func testUserCheckDoesNotAutoInstall() async {
        let installer = FakeInstaller()
        let settings = MemorySettings()
        settings.autoInstall = true
        let u = updater(FakeTransport(release: release), installer, settings: settings)
        await u.checkNow(userInitiated: true)
        XCTAssertFalse(installer.staged)
    }

    func testPreflightFailureStopsBeforeDownload() async {
        let installer = FakeInstaller()
        installer.preflightError = UpdateError("Move LaunchApp to Applications and try again")
        let u = updater(FakeTransport(release: release), installer)
        await u.checkNow(userInitiated: true)
        await u.installNow()
        XCTAssertEqual(u.state, .failed("Move LaunchApp to Applications and try again"))
        XCTAssertFalse(installer.staged)
    }

    func testPreflightMessage() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ro-\(UUID())")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try! FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path) }
        XCTAssertThrowsError(try Installer().preflight(target: dir.appendingPathComponent("LaunchApp.app"),
                                                       appName: "LaunchApp")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Move LaunchApp to Applications and try again"))
        }
        XCTAssertThrowsError(try Installer().preflight(target: dir.appendingPathComponent("LaunchApp"),
                                                       appName: "LaunchApp"))
    }

    func testUserDefaultsSettingsReadExistingKey() {
        let defaults = UserDefaults(suiteName: "appshell-test-\(UUID())")!
        defaults.set(false, forKey: "updates.autoCheck")
        let s = UserDefaultsUpdateSettings(defaults: defaults, autoCheckKey: "updates.autoCheck", autoInstallKey: nil)
        XCTAssertFalse(s.autoCheck)
        s.autoInstall = true
        XCTAssertFalse(s.autoInstall, "no auto-install key → always off")
        XCTAssertFalse(s.supportsAutoInstall)
    }

    func testUserDefaultsSettingsDefaults() {
        let defaults = UserDefaults(suiteName: "appshell-test-\(UUID())")!
        let s = UserDefaultsUpdateSettings(defaults: defaults)
        XCTAssertTrue(s.autoCheck)
        XCTAssertFalse(s.autoInstall)
        s.autoInstall = true
        XCTAssertTrue(defaults.bool(forKey: "appShell.updates.autoInstall"))
    }
}
