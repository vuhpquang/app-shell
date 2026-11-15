import AppKit
import Foundation
import Security

/// File-system side of an update (a fake in tests).
public protocol Installing: Sendable {
    /// Throws a user-facing error when this copy can't be replaced in place.
    func preflight(target: URL, appName: String) throws
    /// Unpacks the download, verifies the app inside and returns a staged copy.
    func stage(_ file: URL, kind: AssetMatcher.Kind, bundleId: String?) throws -> URL
    /// Starts the detached swap script; the caller terminates the app right after.
    @MainActor func relaunch(replacing target: URL, with staged: URL, arguments: [String]) throws
}

/// The real installer. Verification: same bundle id, valid signature
/// (`codesign --verify --deep --strict`) and — when this copy is signed with a certificate —
/// the update satisfies this copy's designated requirement (same signer).
public struct Installer: Installing {
    public init() {}

    public func preflight(target: URL, appName: String) throws {
        guard target.pathExtension == "app" else {
            throw UpdateError("\(appName) isn't running from an app bundle. Move \(appName) to Applications and try again")
        }
        guard FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
            throw UpdateError("No permission to replace \(target.path). Move \(appName) to Applications and try again")
        }
    }

    public func stage(_ file: URL, kind: AssetMatcher.Kind, bundleId: String?) throws -> URL {
        try stage(file, kind: kind, bundleId: bundleId, requireOwnSigner: true)
    }

    /// `requireOwnSigner: false` is for installing OTHER apps (`ExternalInstaller`): their signer is
    /// checked against the catalog's requirement instead of this copy's designated requirement.
    func stage(_ file: URL, kind: AssetMatcher.Kind, bundleId: String?, requireOwnSigner: Bool) throws -> URL {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("AppShellUpdate-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        do {
            return try stage(file, kind: kind, bundleId: bundleId, requireOwnSigner: requireOwnSigner, in: work)
        } catch {
            // A refused or broken download leaves nothing behind (the disk image is already detached).
            try? fm.removeItem(at: work)
            throw error
        }
    }

    private func stage(_ file: URL, kind: AssetMatcher.Kind, bundleId: String?, requireOwnSigner: Bool,
                       in work: URL) throws -> URL {
        let fm = FileManager.default
        let source: URL
        var detach: URL?
        switch kind {
        case .dmg:
            let dmg = work.appendingPathComponent("update.dmg")
            try fm.moveItem(at: file, to: dmg)
            let mount = work.appendingPathComponent("mnt")
            try fm.createDirectory(at: mount, withIntermediateDirectories: true)
            try Self.run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen",
                                               "-mountpoint", mount.path])
            detach = mount
            source = mount
        case .zip:
            let zip = work.appendingPathComponent("update.zip")
            try fm.moveItem(at: file, to: zip)
            let unpacked = work.appendingPathComponent("unpacked")
            try Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])
            source = unpacked
        }
        defer { if let detach { _ = try? Self.run("/usr/bin/hdiutil", ["detach", detach.path, "-force"]) } }

        guard let appName = try fm.contentsOfDirectory(atPath: source.path).first(where: { $0.hasSuffix(".app") }) else {
            throw UpdateError("The update contains no app")
        }
        let newApp = source.appendingPathComponent(appName)
        guard Bundle(url: newApp)?.bundleIdentifier == bundleId else {
            throw UpdateError("The update is for a different app")
        }
        do {
            try Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path])
        } catch {
            throw UpdateError("The update's signature is invalid")
        }
        guard !requireOwnSigner || Self.satisfiesOwnSigner(newApp) else {
            throw UpdateError("The update isn't signed by the same developer")
        }

        let staged = work.appendingPathComponent("staged").appendingPathComponent(appName)
        try fm.createDirectory(at: staged.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.run("/usr/bin/ditto", [newApp.path, staged.path])
        return staged
    }

    /// Ad-hoc / unsigned builds have no signer to pin, so they pass; a certificate-signed copy
    /// only accepts an update that satisfies its own designated requirement.
    public static func satisfiesOwnSigner(_ candidate: URL) -> Bool {
        var me: SecCode?
        guard SecCodeCopySelf([], &me) == errSecSuccess, let me else { return true }
        var staticMe: SecStaticCode?
        guard SecCodeCopyStaticCode(me, [], &staticMe) == errSecSuccess, let staticMe else { return true }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticMe, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
                == errSecSuccess,
              let certs = (info as? [String: Any])?[kSecCodeInfoCertificates as String] as? [Any],
              !certs.isEmpty else {
            return true
        }

        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(staticMe, [], &requirement) == errSecSuccess,
              let requirement else { return false }
        var other: SecStaticCode?
        guard SecStaticCodeCreateWithPath(candidate as CFURL, [], &other) == errSecSuccess,
              let other else { return false }
        return SecStaticCodeCheckValidity(other, SecCSFlags(rawValue: kSecCSCheckAllArchitectures),
                                          requirement) == errSecSuccess
    }

    /// A detached shell script waits for this process to exit, swaps the bundle,
    /// clears quarantine and opens the new copy (with `arguments`).
    @MainActor
    public func relaunch(replacing target: URL, with staged: URL, arguments: [String]) throws {
        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf "$1" && /usr/bin/ditto "$2" "$1" && /usr/bin/xattr -dr com.apple.quarantine "$1" 2>/dev/null
        rm -rf "$(dirname "$(dirname "$2")")"
        shift 2
        if [ $# -gt 0 ]; then /usr/bin/open "$0" --args "$@"; else /usr/bin/open "$0"; fi
        """
        // $0 is the target again so `shift 2` leaves only the app arguments.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script, target.path, target.path, staged.path] + arguments
        do {
            try task.run()
        } catch {
            throw UpdateError("Couldn't start the installer: \(error.localizedDescription)")
        }
    }

    @discardableResult
    static func run(_ tool: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let out = String(data: data, encoding: .utf8) ?? ""
        guard p.terminationStatus == 0 else { throw UpdateError("\((tool as NSString).lastPathComponent) failed: \(out)") }
        return out
    }
}
