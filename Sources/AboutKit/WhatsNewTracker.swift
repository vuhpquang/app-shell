import AppShellCore
import Combine
import Foundation

/// Remembers the last version the user saw and offers "What's New" once after an update.
/// No version recorded yet (fresh install, or the first run after an app adopted app-shell)
/// → the current one is recorded silently.
@MainActor
public final class WhatsNewTracker: ObservableObject {
    public static let defaultKey = "appShell.lastSeenVersion"

    @Published public private(set) var pendingVersion: String?

    private let currentVersion: String
    private let defaults: UserDefaults
    private let key: String

    public init(currentVersion: String, defaults: UserDefaults = .standard, key: String = WhatsNewTracker.defaultKey) {
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.key = key
    }

    public convenience init(app: AppIdentity, defaults: UserDefaults = .standard) {
        self.init(currentVersion: app.version, defaults: defaults)
    }

    /// Call once at launch.
    public func evaluateLaunch() {
        guard let last = defaults.string(forKey: key) else {
            defaults.set(currentVersion, forKey: key)
            return
        }
        pendingVersion = Version.isVersion(currentVersion, newerThan: last) ? currentVersion : nil
    }

    /// The user opened What's New (or dismissed it).
    public func markSeen() {
        defaults.set(currentVersion, forKey: key)
        pendingVersion = nil
    }

    /// "What's New in 1.5.0" while there is something to show, for `.menuItem` apps.
    public var menuTitle: String? {
        pendingVersion.map { String(localized: "What's New in \($0)") }
    }
}
