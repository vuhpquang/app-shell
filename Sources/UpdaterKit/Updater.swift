import AppKit
import AppShellCore
import Combine
import Foundation

/// Self-update from GitHub Releases.
///
/// 1. `check` reads `/releases/latest`, compares its tag (`v1.2.3`) with the bundle version and picks
///    the release's asset for this app (`AssetMatcher`).
/// 2. `install` downloads it, stages and verifies the app inside (`Installer`), then a detached script
///    waits for the app to quit, swaps the bundle in place and opens the new copy.
///
/// Automatic checks run 10 s after `startAutomaticChecks()` and every 6 hours while auto-check is on.
/// A background check never replaces an "available" or "failed" state the user hasn't acted on.
/// With auto-install on, an update found by a background check is installed without asking.
///
/// `ObservableObject` (not `@Observable`) because Padlet still supports macOS 13.
@MainActor
public final class Updater: ObservableObject {
    public enum State: Equatable, Sendable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading
        case installing
        case failed(String)

        public var isBusy: Bool {
            switch self {
            case .checking, .downloading, .installing: return true
            default: return false
            }
        }
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var lastChecked: Date?
    @Published public private(set) var releaseNotes = ""

    public let app: AppIdentity
    public let matcher: AssetMatcher
    public let settings: UpdateSettingsStore

    /// Runs just before the app quits to be replaced (save state here).
    public var onWillRelaunch: (@MainActor () -> Void)?
    /// Arguments the new copy is opened with (LaunchApp: `["--background"]` when it was started so).
    public var relaunchArguments: [String] = []
    /// Shown when a check the user asked for can't reach the update source (catalog apps name their server).
    public var unreachableMessage = "Couldn't reach GitHub. Check your connection and try again"

    var transport: UpdateTransport
    let installer: Installing
    var terminate: @MainActor () -> Void = { NSApp.terminate(nil) }
    var currentVersionOverride: String?

    private var assetURL: URL?
    private var timer: Timer?
    private var startTask: Task<Void, Never>?
    private var settingsSubscription: AnyCancellable?

    public init(app: AppIdentity, matcher: AssetMatcher, settings: UpdateSettingsStore,
                transport: UpdateTransport = URLSessionTransport(), installer: Installing = Installer()) {
        self.app = app
        self.matcher = matcher
        self.settings = settings
        self.transport = transport
        self.installer = installer
    }

    /// The running version. DEBUG builds honour `APPSHELL_PRETEND_VERSION` to test an update.
    public var currentVersion: String {
        if let currentVersionOverride { return currentVersionOverride }
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment["APPSHELL_PRETEND_VERSION"], !v.isEmpty { return v }
        #endif
        return app.version
    }

    private var userAgent: String { "\(app.name)/\(currentVersion)" }

    // MARK: - Scheduling

    /// Call once at launch. Follows the auto-check setting as it changes.
    public func startAutomaticChecks() {
        settingsSubscription = settings.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in MainActor.assumeIsolated { self?.reschedule() } }
        reschedule()
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        startTask?.cancel()
        startTask = nil
        guard settings.autoCheck else { return }
        startTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            self?.check(userInitiated: false)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check(userInitiated: false) }
        }
    }

    // MARK: - Check

    /// Fire-and-forget check (menus, buttons).
    public func check(userInitiated: Bool) {
        Task { await checkNow(userInitiated: userInitiated) }
    }

    public func checkNow(userInitiated: Bool) async {
        guard !state.isBusy else { return }
        if !userInitiated {
            guard settings.autoCheck else { return }
            switch state {
            case .available, .failed: return   // the user hasn't acted on it yet
            default: break
            }
        }
        let previous = state
        state = .checking
        do {
            let release = try await transport.latestRelease(repo: app.repo, userAgent: userAgent)
            lastChecked = Date()
            switch UpdateCheckResult.evaluate(release, current: currentVersion, matcher: matcher) {
            case .upToDate:
                state = .upToDate
            case let .available(version, asset, notes):
                assetURL = asset
                releaseNotes = notes
                state = .available(version: version)
                if !userInitiated && settings.autoInstall && settings.supportsAutoInstall {
                    await installNow()
                }
            }
        } catch {
            lastChecked = Date()
            // A failed background check stays quiet; the user only sees errors they asked for.
            state = userInitiated ? .failed(unreachableMessage) : previous
        }
    }

    // MARK: - Install

    /// Fire-and-forget install of the update found by the last check.
    public func install() {
        Task { await installNow() }
    }

    public func installNow() async {
        guard case .available = state, let url = assetURL else { return }
        let target = app.bundleURL
        do {
            try installer.preflight(target: target, appName: app.name)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        state = .downloading
        do {
            let file = try await transport.download(url)
            let installer = installer, kind = matcher.kind, bundleId = app.bundleIdentifier
            let staged = try await Task.detached { try installer.stage(file, kind: kind, bundleId: bundleId) }.value
            state = .installing
            onWillRelaunch?()
            try installer.relaunch(replacing: target, with: staged, arguments: relaunchArguments)
            terminate()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Debug

    /// Check → download → stage (verify) without replacing anything. For a DEBUG menu / snapshot run.
    public func dryRun() async -> String {
        await checkNow(userInitiated: true)
        guard case let .available(version) = state, let url = assetURL else { return "state: \(state)" }
        do {
            let file = try await transport.download(url)
            let installer = installer, kind = matcher.kind, bundleId = app.bundleIdentifier
            let staged = try await Task.detached { try installer.stage(file, kind: kind, bundleId: bundleId) }.value
            return "available \(version); staged OK at \(staged.path)"
        } catch {
            return "available \(version); stage failed: \(error.localizedDescription)"
        }
    }
}
