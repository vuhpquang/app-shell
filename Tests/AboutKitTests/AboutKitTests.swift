import AppShellCore
import XCTest
@testable import AboutKit

@MainActor
final class WhatsNewTrackerTests: XCTestCase {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "appshell-about-\(UUID())")! }

    func testFirstRunRecordsSilently() {
        let d = defaults()
        let t = WhatsNewTracker(currentVersion: "1.5.0", defaults: d)
        t.evaluateLaunch()
        XCTAssertNil(t.pendingVersion)
        XCTAssertEqual(d.string(forKey: "appShell.lastSeenVersion"), "1.5.0")
    }

    func testNewerVersionIsOfferedOnce() {
        let d = defaults()
        d.set("1.4.0", forKey: "appShell.lastSeenVersion")
        let t = WhatsNewTracker(currentVersion: "1.5.0", defaults: d)
        t.evaluateLaunch()
        XCTAssertEqual(t.pendingVersion, "1.5.0")
        XCTAssertEqual(t.menuTitle, "What's New in 1.5.0")
        t.markSeen()
        XCTAssertNil(t.pendingVersion)
        XCTAssertNil(t.menuTitle)
        let again = WhatsNewTracker(currentVersion: "1.5.0", defaults: d)
        again.evaluateLaunch()
        XCTAssertNil(again.pendingVersion)
    }

    func testSameVersionNotOffered() {
        let d = defaults()
        d.set("1.5.0", forKey: "appShell.lastSeenVersion")
        let t = WhatsNewTracker(currentVersion: "1.5.0", defaults: d)
        t.evaluateLaunch()
        XCTAssertNil(t.pendingVersion)
    }
}

final class ReleaseNotesTests: XCTestCase {
    func testBlocks() {
        let notes = """
        ## Added
        - Faster **search**
        * Folders

        Plain line
        """
        XCTAssertEqual(ReleaseNotes.blocks(from: notes), [
            .heading("Added"),
            .bullet("Faster **search**"),
            .bullet("Folders"),
            .paragraph("Plain line"),
        ])
    }

    func testEmpty() {
        XCTAssertEqual(ReleaseNotes.blocks(from: "  \n\n"), [])
    }
}
