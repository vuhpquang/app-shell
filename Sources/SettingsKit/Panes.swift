import AboutKit
import AppShellCore
import Combine
import SwiftUI
import UpdaterKit

/// Settings → Updates: status, Check / Install, the notes of an available update and the two toggles.
public struct UpdatesPane: View {
    @ObservedObject var updater: Updater
    @State private var autoCheck = false
    @State private var autoInstall = false

    public init(updater: Updater) { self.updater = updater }

    public var body: some View {
        Form {
            Section {
                HStack {
                    UpdateStatusLabel(updater: updater)
                    Spacer()
                    UpdateActionButton(updater: updater)
                }
                if let checked = updater.lastChecked {
                    Text("Last checked \(checked.formatted(.relative(presentation: .named)))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if case .available = updater.state, !updater.releaseNotes.isEmpty {
                    ScrollView {
                        ReleaseNotesView(markdown: updater.releaseNotes)
                    }
                    .frame(maxHeight: ShellTokens.Size.notesMaxHeight)
                }
            }
            Section {
                Toggle(isOn: Binding(get: { autoCheck }, set: { autoCheck = $0; updater.settings.autoCheck = $0 })) {
                    Text("Check for updates automatically")
                }
                if updater.settings.supportsAutoInstall {
                    Toggle(isOn: Binding(get: { autoInstall }, set: { autoInstall = $0; updater.settings.autoInstall = $0 })) {
                        Text("Install updates automatically")
                    }
                    .disabled(!autoCheck)
                }
            } footer: {
                Text(updater.app.updateSourceDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: sync)
        .onReceive(updater.settings.changes) { sync() }
    }

    private func sync() {
        autoCheck = updater.settings.autoCheck
        autoInstall = updater.settings.autoInstall
    }
}

/// Settings → About: the shared About content, centred.
public struct AboutPane: View {
    let app: AppIdentity
    let updater: Updater?
    let onWhatsNew: (() -> Void)?

    public init(app: AppIdentity, updater: Updater?, onWhatsNew: (() -> Void)? = nil) {
        self.app = app
        self.updater = updater
        self.onWhatsNew = onWhatsNew
    }

    public var body: some View {
        ScrollView {
            AboutView(app: app, updater: updater, onWhatsNew: onWhatsNew)
                .frame(maxWidth: .infinity)
        }
    }
}

/// "Open <App> at login" for an app's General pane, with the error shown inline.
public struct LaunchAtLoginRow: View {
    let appName: String
    @State private var enabled = false
    @State private var error: String?

    public init(appName: String) { self.appName = appName }

    public var body: some View {
        Toggle(isOn: Binding(get: { enabled }, set: { on in
            error = LaunchAtLogin.set(on)
            enabled = LaunchAtLogin.isEnabled
        })) {
            Text("Open \(appName) at login")
            if let error {
                Text(error).foregroundStyle(.red)
            }
        }
        .onAppear { enabled = LaunchAtLogin.isEnabled }
    }
}
