// Renders the shared views to PNGs, light and dark, for design checks:
//   swift run AppShellPreview /tmp/appshell-shots
// Not a product: apps never build it.

import AboutKit
import AppKit
import AppShellCore
import Combine
import SettingsKit
import SwiftUI
import UpdaterKit

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/tmp/appshell-shots")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let app = AppIdentity(name: "LaunchApp", tagline: "The classic Launchpad, back on macOS 26+.",
                      repo: "vuhpquang/launch-app", firstYear: 2026,
                      credits: [Credit(name: "Ghostty", url: URL(string: "https://ghostty.org")!, note: "Built on")])

struct OfflineTransport: UpdateTransport {
    func latestRelease(repo: String, userAgent: String) async throws -> Release {
        try Release.decode(Data("""
        {"tag_name":"v1.5.0","body":"## Added\\n- Faster **search**\\n- Folders remember their page","published_at":null,
         "assets":[{"name":"LaunchApp.dmg","browser_download_url":"https://example.com/LaunchApp.dmg"}]}
        """.utf8))
    }
    func release(repo: String, tag: String, userAgent: String) async throws -> Release {
        try await latestRelease(repo: repo, userAgent: userAgent)
    }
    func download(_ url: URL) async throws -> URL { throw URLError(.cancelled) }
}

@MainActor
func render<V: View>(_ name: String, size: CGSize, _ view: V) {
    for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        let host = NSHostingView(rootView: view
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, suffix == "dark" ? .dark : .light))
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
        host.cacheDisplay(in: host.bounds, to: rep)
        let file = out.appendingPathComponent("\(name)-\(suffix).png")
        try? rep.representation(using: .png, properties: [:])?.write(to: file)
        print(file.path)
    }
}

MainActor.assumeIsolated {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    let settings = UserDefaultsUpdateSettings(defaults: UserDefaults(suiteName: "appshell-preview")!)
    let updater = Updater(app: app, matcher: .dmg, settings: settings, transport: OfflineTransport())
    Task { @MainActor in
        await updater.checkNow(userInitiated: true)
        render("about", size: CGSize(width: 440, height: 520), AboutView(app: app, updater: updater))
        render("whatsnew", size: CGSize(width: 480, height: 420),
               WhatsNewView(app: app, version: "1.5.0", transport: OfflineTransport()))
        let panes = [SettingsPane(id: "general", title: "General", systemImage: "gearshape") {
            Form { Section { LaunchAtLoginRow(appName: "LaunchApp"); Toggle("Show in Dock", isOn: .constant(true)) } }
                .formStyle(.grouped)
        }]
        render("settings-updates", size: CGSize(width: 760, height: 520),
               SettingsShell(app: app, updater: updater, panes: panes, selection: .constant("updates")))
        render("settings-about", size: CGSize(width: 760, height: 560),
               SettingsShell(app: app, updater: updater, panes: panes, selection: .constant("about")))
        let themed = SettingsShellStyle(sidebarIconTint: .purple, detailBackground: Color(nsColor: .systemPurple).opacity(0.08))
        render("settings-themed", size: CGSize(width: 760, height: 520),
               SettingsShell(app: app, updater: updater, panes: panes, selection: .constant("general"), style: themed))
        exit(0)
    }
}
RunLoop.main.run()
