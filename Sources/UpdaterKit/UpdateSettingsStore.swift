import Combine
import Foundation

/// Where an app keeps "Check for updates automatically" / "Install updates automatically".
/// Apps with their own preferences model pass an adapter over it, so no stored key is renamed.
@MainActor
public protocol UpdateSettingsStore: AnyObject {
    var autoCheck: Bool { get set }
    var autoInstall: Bool { get set }
    /// False hides the "Install automatically" toggle.
    var supportsAutoInstall: Bool { get }
    /// Fires after either value changed.
    var changes: AnyPublisher<Void, Never> { get }
}

public extension UpdateSettingsStore {
    var supportsAutoInstall: Bool { true }
}

/// The two settings in UserDefaults. New apps use the default keys.
@MainActor
public final class UserDefaultsUpdateSettings: UpdateSettingsStore, ObservableObject {
    private let defaults: UserDefaults
    private let autoCheckKey: String
    private let autoInstallKey: String?
    private let subject = PassthroughSubject<Void, Never>()

    /// `autoInstallKey: nil` = the app has no auto-install option (always off).
    public init(defaults: UserDefaults = .standard,
                autoCheckKey: String = "appShell.updates.autoCheck",
                autoInstallKey: String? = "appShell.updates.autoInstall",
                autoCheckDefault: Bool = true) {
        self.defaults = defaults
        self.autoCheckKey = autoCheckKey
        self.autoInstallKey = autoInstallKey
        defaults.register(defaults: [autoCheckKey: autoCheckDefault])
    }

    public var autoCheck: Bool {
        get { defaults.bool(forKey: autoCheckKey) }
        set { objectWillChange.send(); defaults.set(newValue, forKey: autoCheckKey); subject.send() }
    }

    public var autoInstall: Bool {
        get { autoInstallKey.map { defaults.bool(forKey: $0) } ?? false }
        set {
            guard let autoInstallKey else { return }
            objectWillChange.send()
            defaults.set(newValue, forKey: autoInstallKey)
            subject.send()
        }
    }

    public var supportsAutoInstall: Bool { autoInstallKey != nil }
    public var changes: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }
}
