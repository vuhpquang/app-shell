import AppKit
import AppShellCore
import SwiftUI
import UpdaterKit

/// The About content every app shows, in a window (`AboutWindow`) or as a Settings pane.
///
///         [ icon ]
///         LaunchApp
///   The classic Launchpad, back on macOS 26+.
///      Version 1.4.2 (142)
///      ✓ LaunchApp is up to date       [Check for Updates]
///   [What's New] [Report Issue]
///   ───────────────────────────────
///   Made by Ha Phung Quang Vu
///   vuhpquang.com · GitHub · LinkedIn · Source code
///   © 2026 Ha Phung Quang Vu
public struct AboutView: View {
    let app: AppIdentity
    let updater: Updater?
    let onWhatsNew: (() -> Void)?

    @Environment(\.openURL) private var openURL

    /// `onWhatsNew` nil → opens `WhatsNewWindow` for the running version.
    public init(app: AppIdentity, updater: Updater?, onWhatsNew: (() -> Void)? = nil) {
        self.app = app
        self.updater = updater
        self.onWhatsNew = onWhatsNew
    }

    public var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: Self.icon(for: app))
                .resizable()
                .interpolation(.high)
                .frame(width: ShellTokens.Size.aboutIcon, height: ShellTokens.Size.aboutIcon)
                .accessibilityLabel(Text("\(app.name) icon", bundle: .module))

            VStack(spacing: ShellTokens.Spacing.xs) {
                Text(verbatim: app.name).font(.title.bold())
                Text(verbatim: app.tagline)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Version \(app.version) (\(app.build))", bundle: .module)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.top, ShellTokens.Spacing.xs)
            }
            .padding(.top, ShellTokens.Spacing.m)

            if let updater {
                HStack(spacing: ShellTokens.Spacing.m) {
                    UpdateStatusLabel(updater: updater)
                        .font(.callout)
                        .lineLimit(2)
                    UpdateActionButton(updater: updater)
                }
                .padding(.top, ShellTokens.Spacing.l)
            }

            HStack(spacing: ShellTokens.Spacing.s) {
                Button { whatsNew() } label: { Text("What's New", bundle: .module) }
                Button { openURL(app.newIssueURL) } label: { Text("Report Issue", bundle: .module) }
            }
            .padding(.top, ShellTokens.Spacing.l)

            Divider().padding(.vertical, ShellTokens.Spacing.l)

            AuthorFooter(app: app)
        }
        .padding(ShellTokens.Spacing.xl)
        .frame(maxWidth: ShellTokens.Size.aboutWidth)
        .tint(app.accent)
    }

    private func whatsNew() {
        if let onWhatsNew { onWhatsNew() } else { WhatsNewWindow.show(app: app, version: app.version) }
    }

    static func icon(for app: AppIdentity) -> NSImage {
        if app.bundleURL == Bundle.main.bundleURL { return NSApp?.applicationIconImage ?? NSWorkspace.shared.icon(forFile: app.bundleURL.path) }
        return NSWorkspace.shared.icon(forFile: app.bundleURL.path)
    }
}

/// "Made by …", the author's links, credits and the copyright line. Shared so a non-standard
/// About (Wisp keeps its own view) can still show exactly the same footer contents.
public struct AuthorFooter: View {
    let app: AppIdentity

    public init(app: AppIdentity) { self.app = app }

    public var body: some View {
        VStack(spacing: ShellTokens.Spacing.xs) {
            HStack(spacing: ShellTokens.Spacing.xs) {
                Text("Made by", bundle: .module).foregroundStyle(.secondary)
                Link(Author.name, destination: Author.website).fontWeight(.semibold)
            }
            HStack(spacing: ShellTokens.Spacing.s) {
                Link(destination: Author.website) { Text(verbatim: "vuhpquang.com") }
                Text(verbatim: "·").foregroundStyle(.tertiary)
                Link(destination: Author.github) { Text(verbatim: "GitHub") }
                Text(verbatim: "·").foregroundStyle(.tertiary)
                Link(destination: Author.linkedIn) { Text(verbatim: "LinkedIn") }
                Text(verbatim: "·").foregroundStyle(.tertiary)
                Link(destination: app.repoURL) { Text("Source code", bundle: .module) }
            }
            ForEach(app.credits, id: \.name) { credit in
                HStack(spacing: ShellTokens.Spacing.xs) {
                    Text(verbatim: credit.note).foregroundStyle(.secondary)
                    Link(credit.name, destination: credit.url)
                }
            }
            Text(verbatim: app.copyright)
                .foregroundStyle(.secondary)
                .padding(.top, ShellTokens.Spacing.xs)
        }
        .font(.callout)
    }
}
