import AppShellCore
import Combine
import SwiftUI
import UpdaterKit
import XCTest
@testable import SettingsKit

@MainActor
final class SettingsShellTests: XCTestCase {
    private let app = AppIdentity(name: "Demo", tagline: "t", repo: "vuhpquang/demo", firstYear: 2026)

    private func panes() -> [SettingsPane] {
        [SettingsPane(id: "general", title: "General", systemImage: "gearshape") { Text(verbatim: "g") },
         SettingsPane(id: "apps", title: "Apps", systemImage: "square.grid.3x3") { Text(verbatim: "a") }]
    }

    func testSharedPanesComeLast() {
        let updater = Updater(app: app, matcher: .dmg, settings: UserDefaultsUpdateSettings(
            defaults: UserDefaults(suiteName: "appshell-settings-\(UUID())")!))
        let shell = SettingsShell(app: app, updater: updater, panes: panes(), selection: .constant("general"))
        XCTAssertEqual(shell.allPanes.map(\.id), ["general", "apps", "updates", "about"])
    }

    func testNoUpdaterNoUpdatesPane() {
        let shell = SettingsShell(app: app, updater: nil, panes: panes(), selection: .constant("general"))
        XCTAssertEqual(shell.allPanes.map(\.id), ["general", "apps", "about"])
    }

    func testUnknownSelectionFallsBackToFirst() {
        let shell = SettingsShell(app: app, updater: nil, panes: panes(), selection: .constant("gone"))
        XCTAssertEqual(shell.current.id, "general")
    }

    func testStandardStyleIsStock() {
        let s = SettingsShellStyle.standard
        XCTAssertNil(s.sidebarIconTint)
        XCTAssertNil(s.detailBackground)
        XCTAssertNil(s.windowSize)
        XCTAssertNil(s.sidebarRow)
    }
}
