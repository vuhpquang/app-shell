import AboutKit
import AppShellCore
import SwiftUI
import UpdaterKit

/// One page of the Settings sidebar.
public struct SettingsPane: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    let content: AnyView

    /// `content` is the whole page; use `Form { … }.formStyle(.grouped)` like the shared panes.
    public init<Content: View>(id: String, title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.content = AnyView(content())
    }
}

/// Optional styling for apps with a themed window (ZenTask). Default = stock macOS everywhere.
/// General styling only: nothing here may name an app. Native controls inside the forms are never restyled.
public struct SettingsShellStyle {
    /// Colour of the sidebar icons; nil = system.
    public var sidebarIconTint: Color?
    /// Background behind the detail page; set → the grouped-form grey is hidden so it shows through.
    public var detailBackground: Color?
    /// Applied to the sidebar list (themed list background, …).
    public var decorateSidebar: ((AnyView) -> AnyView)?
    /// Draws a sidebar row with its own selection look instead of the List's
    /// (label, selected, select action).
    public var sidebarRow: ((AnyView, Bool, @escaping () -> Void) -> AnyView)?
    /// Fixed window size; nil = resizable with the shell's minimum.
    public var windowSize: CGSize?
    public var sidebarWidth: CGFloat

    public init(sidebarIconTint: Color? = nil, detailBackground: Color? = nil,
                decorateSidebar: ((AnyView) -> AnyView)? = nil,
                sidebarRow: ((AnyView, Bool, @escaping () -> Void) -> AnyView)? = nil,
                windowSize: CGSize? = nil, sidebarWidth: CGFloat = ShellTokens.Size.sidebarWidth) {
        self.sidebarIconTint = sidebarIconTint
        self.detailBackground = detailBackground
        self.decorateSidebar = decorateSidebar
        self.sidebarRow = sidebarRow
        self.windowSize = windowSize
        self.sidebarWidth = sidebarWidth
    }

    public static var standard: SettingsShellStyle { SettingsShellStyle() }
}

/// The Settings window content every app shares: a sidebar with the app's own panes first
/// (General first), then Updates and About; each page a grouped form.
public struct SettingsShell: View {
    public static let updatesPaneID = "updates"
    public static let aboutPaneID = "about"

    let app: AppIdentity
    let updater: Updater?
    let panes: [SettingsPane]
    @Binding var selection: String
    let style: SettingsShellStyle
    let onWhatsNew: (() -> Void)?

    /// `selection` is a pane id; keep it in the app's existing storage so the last pane is remembered.
    public init(app: AppIdentity, updater: Updater?, panes: [SettingsPane], selection: Binding<String>,
                style: SettingsShellStyle = .standard, onWhatsNew: (() -> Void)? = nil) {
        self.app = app
        self.updater = updater
        self.panes = panes
        self._selection = selection
        self.style = style
        self.onWhatsNew = onWhatsNew
    }

    var allPanes: [SettingsPane] {
        var all = panes
        if let updater {
            all.append(SettingsPane(id: Self.updatesPaneID, title: String(localized: "Updates"),
                                    systemImage: "arrow.down.circle") { UpdatesPane(updater: updater) })
        }
        all.append(SettingsPane(id: Self.aboutPaneID, title: String(localized: "About"),
                                systemImage: "info.circle") {
            AboutPane(app: app, updater: updater, onWhatsNew: onWhatsNew)
        })
        return all
    }

    var current: SettingsPane {
        let all = allPanes
        return all.first { $0.id == selection } ?? all[0]
    }

    public var body: some View {
        let all = allPanes
        let current = current
        NavigationSplitView {
            sidebar(all, current: current)
                .navigationSplitViewColumnWidth(style.sidebarWidth)
                .modifier(NoSidebarToggle())
        } detail: {
            current.content
                .scrollContentBackground(style.detailBackground == nil ? .automatic : .hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(style.detailBackground ?? .clear)
                .navigationTitle(current.title)
        }
        .modifier(WindowSizing(size: style.windowSize))
        .tint(app.accent)
    }

    private func sidebar(_ all: [SettingsPane], current: SettingsPane) -> AnyView {
        let list: AnyView
        if let row = style.sidebarRow {
            list = AnyView(List(all) { pane in
                row(AnyView(label(pane)), pane.id == current.id) { selection = pane.id }
            })
        } else {
            list = AnyView(List(all, selection: Binding<String?>(get: { current.id }, set: { if let id = $0 { selection = id } })) { pane in
                label(pane).tag(pane.id)
            })
        }
        return style.decorateSidebar?(list) ?? list
    }

    private func label(_ pane: SettingsPane) -> some View {
        Label {
            Text(verbatim: pane.title)
        } icon: {
            if let tint = style.sidebarIconTint {
                Image(systemName: pane.systemImage).foregroundStyle(tint)
            } else {
                Image(systemName: pane.systemImage)
            }
        }
    }
}

/// A Settings sidebar is always shown: no collapse button (macOS 14+ API).
private struct NoSidebarToggle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.toolbar(removing: .sidebarToggle)
        } else {
            content
        }
    }
}

private struct WindowSizing: ViewModifier {
    let size: CGSize?

    func body(content: Content) -> some View {
        if let size {
            content.frame(width: size.width, height: size.height)
        } else {
            content.frame(minWidth: ShellTokens.Size.settingsWidth, minHeight: ShellTokens.Size.settingsHeight)
        }
    }
}
