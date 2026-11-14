import AppKit
import AppShellCore
import SwiftUI
import UpdaterKit

/// Small helper: one reusable titled window per kind, brought to front on every show.
@MainActor
final class ShellWindow {
    private var window: NSWindow?

    func show<Content: View>(title: String, @ViewBuilder content: () -> Content) {
        let hosting = NSHostingController(rootView: content())
        if let window {
            window.contentViewController = hosting
            window.title = title
        } else {
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.title = title
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// The app menu's "About <App>" window.
@MainActor
public enum AboutWindow {
    private static let host = ShellWindow()

    public static func show(app: AppIdentity, updater: Updater?, onWhatsNew: (() -> Void)? = nil) {
        host.show(title: String(localized: "About \(app.name)")) {
            AboutView(app: app, updater: updater, onWhatsNew: onWhatsNew)
        }
    }
}

/// The release notes of one version, fetched from GitHub (`releases/tags/v<version>`).
public struct WhatsNewView: View {
    let app: AppIdentity
    let version: String
    let transport: UpdateTransport

    enum Load: Equatable { case loading, loaded(String), failed }
    @State private var load: Load = .loading
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    public init(app: AppIdentity, version: String, transport: UpdateTransport = URLSessionTransport()) {
        self.app = app
        self.version = version
        self.transport = transport
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's New in \(app.name) \(version)")
                .font(.title2.bold())
                .padding(.bottom, ShellTokens.Spacing.m)
            ScrollView {
                Group {
                    switch load {
                    case .loading:
                        ProgressView().frame(maxWidth: .infinity)
                    case .loaded(let notes) where !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
                        ReleaseNotesView(markdown: notes)
                    case .loaded:
                        Text("This version has no release notes.").foregroundStyle(.secondary)
                    case .failed:
                        Text("Couldn't load the release notes. Check your connection, or read them on GitHub.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, ShellTokens.Spacing.xs)
            }
            HStack {
                Button { openURL(app.releaseURL(tag: "v\(version)")) } label: { Text("View on GitHub") }
                Spacer()
                Button { dismiss(); NSApp.keyWindow?.performClose(nil) } label: { Text("Done") }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, ShellTokens.Spacing.m)
        }
        .padding(ShellTokens.Spacing.xl)
        .frame(width: ShellTokens.Size.whatsNewWidth, height: ShellTokens.Size.whatsNewHeight)
        .tint(app.accent)
        .task {
            do {
                let release = try await transport.release(repo: app.repo, tag: "v\(version)", userAgent: "\(app.name)/\(app.version)")
                load = .loaded(release.body ?? "")
            } catch {
                load = .failed
            }
        }
    }
}

/// "What's New" in its own window (menu item, About button, or automatically after an update).
@MainActor
public enum WhatsNewWindow {
    private static let host = ShellWindow()

    public static func show(app: AppIdentity, version: String, tracker: WhatsNewTracker? = nil) {
        tracker?.markSeen()
        host.show(title: String(localized: "What's New")) {
            WhatsNewView(app: app, version: version)
        }
    }
}
