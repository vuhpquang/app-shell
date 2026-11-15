import AppKit
import Foundation
import Security

/// How `ExternalInstaller.replace` talks to running apps (a fake in tests: tests never quit or open real apps).
@MainActor
public protocol AppProcessControlling {
    /// True while an app whose bundle is exactly `bundleURL` is running.
    func isRunning(bundleURL: URL) -> Bool
    /// Asks only the app(s) whose bundle is exactly `bundleURL` to quit.
    func terminate(bundleURL: URL)
    func open(_ app: URL, arguments: [String]?)
}

/// `NSWorkspace` implementation: matches running apps by their bundle path (`ExternalInstaller.isSameBundle`),
/// never by name or bundle id.
@MainActor
public struct WorkspaceAppProcessControl: AppProcessControlling {
    public init() {}

    private func matches(_ bundleURL: URL) -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { ExternalInstaller.isSameBundle($0.bundleURL, bundleURL) }
    }

    public func isRunning(bundleURL: URL) -> Bool {
        matches(bundleURL).contains { !$0.isTerminated }
    }

    public func terminate(bundleURL: URL) {
        matches(bundleURL).forEach { _ = $0.terminate() }
    }

    public func open(_ app: URL, arguments: [String]?) {
        let config = NSWorkspace.OpenConfiguration()
        if let arguments { config.arguments = arguments }
        NSWorkspace.shared.openApplication(at: app, configuration: config, completionHandler: nil)
    }
}

public enum ReplaceOutcome: Equatable, Sendable {
    case replaced(relaunched: Bool)
    /// The app is still running after the timeout; nothing was changed.
    case appRefusedToQuit
}

/// Installs or updates ANOTHER app (the App Depot's job): stage + verify a download, then swap it into place.
/// Unlike `Installer.relaunch` the swap happens in-process because this app keeps running.
public struct ExternalInstaller {
    private let process: AppProcessControlling?

    public init() { process = nil }

    /// Inject a fake in tests so they never quit or open real apps.
    public init(process: AppProcessControlling) { self.process = process }

    /// True only when `running` is the very bundle at `target` (symlinks resolved, `.`/`..` and trailing
    /// slashes removed). A copy with the same name or bundle id at another path never matches.
    public static func isSameBundle(_ running: URL?, _ target: URL) -> Bool {
        guard let running, running.isFileURL, target.isFileURL else { return false }
        func canonical(_ url: URL) -> String {
            url.resolvingSymlinksInPath().standardizedFileURL.path
        }
        return canonical(running) == canonical(target)
    }

    /// Unpacks the download and verifies the app inside: expected bundle id and
    /// `codesign --verify --deep --strict`. The caller then checks the catalog signer with `satisfies`.
    public func stage(_ file: URL, kind: AssetMatcher.Kind, bundleId: String) throws -> URL {
        try Installer().stage(file, kind: kind, bundleId: bundleId, requireOwnSigner: false)
    }

    /// Whether `candidate` is validly signed and satisfies the code requirement text (e.g. a catalog `signer`).
    public static func satisfies(_ candidate: URL, requirement: String) -> Bool {
        var req: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &req) == errSecSuccess, let req else {
            return false
        }
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(candidate as CFURL, [], &code) == errSecSuccess, let code else {
            return false
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate)
        return SecStaticCodeCheckValidity(code, flags, req) == errSecSuccess
    }

    /// The designated requirement of an installed app, as text (used to pin the signer of installed apps).
    public static func designatedRequirement(of app: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        var req: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(code, [], &req) == errSecSuccess, let req else { return nil }
        var text: CFString?
        guard SecRequirementCopyString(req, [], &text) == errSecSuccess else { return nil }
        return text as String?
    }

    /// Replaces `target` with `staged`. When `target` is running it is asked to quit (only that bundle,
    /// never another copy or app), the swap waits up to `quitTimeout`, then the new copy is reopened.
    @MainActor
    public func replace(target: URL, with staged: URL, relaunchArguments: [String]?,
                        quitTimeout: Duration) async throws -> ReplaceOutcome {
        let control: AppProcessControlling = process ?? WorkspaceAppProcessControl()
        let fm = FileManager.default
        let wasRunning = control.isRunning(bundleURL: target)

        if wasRunning {
            control.terminate(bundleURL: target)
            let deadline = ContinuousClock.now + quitTimeout
            while control.isRunning(bundleURL: target) {
                if ContinuousClock.now >= deadline { return .appRefusedToQuit }
                try await Task.sleep(for: .milliseconds(100))
            }
        }

        // Copy next to the target first so the final swap is a same-volume atomic replace.
        let parent = target.deletingLastPathComponent()
        let temp = parent.appendingPathComponent(".\(target.lastPathComponent).new-\(UUID().uuidString)")
        do {
            try Installer.run("/usr/bin/ditto", [staged.path, temp.path])
            _ = try? Installer.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", temp.path])
            if fm.fileExists(atPath: target.path) {
                _ = try fm.replaceItemAt(target, withItemAt: temp)
            } else {
                try fm.moveItem(at: temp, to: target)
            }
        } catch {
            try? fm.removeItem(at: temp)
            // The old copy was quit for the swap: bring it back so the user isn't left without it.
            if wasRunning, fm.fileExists(atPath: target.path) { control.open(target, arguments: relaunchArguments) }
            throw UpdateError("Couldn't replace \(target.lastPathComponent): \(error.localizedDescription)")
        }

        if wasRunning { control.open(target, arguments: relaunchArguments) }
        return .replaced(relaunched: wasRunning)
    }
}
