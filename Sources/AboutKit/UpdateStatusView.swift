import AppShellCore
import SwiftUI
import UpdaterKit

/// One line of update status: "LaunchApp is up to date", "Version 1.5.0 is available", errors.
public struct UpdateStatusLabel: View {
    @ObservedObject var updater: Updater

    public init(updater: Updater) { self.updater = updater }

    public var body: some View {
        switch updater.state {
        case .idle:
            Text("Not checked yet", bundle: .module).foregroundStyle(.secondary)
        case .checking:
            Text("Checking for updates…", bundle: .module).foregroundStyle(.secondary)
        case .upToDate:
            Label { Text("\(updater.app.name) is up to date", bundle: .module) }
                icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
        case .available(let version):
            Label { Text("Version \(version) is available", bundle: .module) }
                icon: { Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.accentColor) }
        case .downloading:
            Text("Downloading…", bundle: .module).foregroundStyle(.secondary)
        case .installing:
            Text("Installing…", bundle: .module).foregroundStyle(.secondary)
        case .failed(let message):
            Label { Text(message) }
                icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
        }
    }
}

/// The button that goes with the status: Check for Updates / Install Update / a spinner.
public struct UpdateActionButton: View {
    @ObservedObject var updater: Updater

    public init(updater: Updater) { self.updater = updater }

    public var body: some View {
        switch updater.state {
        case .available:
            Button { updater.install() } label: { Text("Install Update", bundle: .module) }
                .buttonStyle(.borderedProminent)
        case .checking, .downloading, .installing:
            ProgressView().controlSize(.small)
        default:
            Button { updater.check(userInitiated: true) } label: { Text("Check for Updates", bundle: .module) }
        }
    }
}
