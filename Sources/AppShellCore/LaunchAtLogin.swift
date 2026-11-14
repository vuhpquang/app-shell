import ServiceManagement

/// "Open at login" through SMAppService (macOS 13+).
public enum LaunchAtLogin {
    @MainActor public static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message, or nil on success.
    @MainActor @discardableResult
    public static func set(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
