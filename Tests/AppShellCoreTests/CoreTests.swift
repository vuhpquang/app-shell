import XCTest
@testable import AppShellCore

final class AuthorTests: XCTestCase {
    private func date(_ year: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: 6, day: 1))!
    }

    func testCopyrightSingleYear() {
        XCTAssertEqual(Author.copyright(since: 2026, now: date(2026)), "© 2026 Ha Phung Quang Vu")
    }

    func testCopyrightRange() {
        XCTAssertEqual(Author.copyright(since: 2025, now: date(2026)), "© 2025–2026 Ha Phung Quang Vu")
    }

    func testLinks() {
        XCTAssertEqual(Author.name, "Ha Phung Quang Vu")
        XCTAssertEqual(Author.website.absoluteString, "https://vuhpquang.com")
        XCTAssertEqual(Author.github.absoluteString, "https://github.com/vuhpquang")
        XCTAssertEqual(Author.linkedIn.absoluteString, "https://www.linkedin.com/in/vuhpquang/")
    }
}

final class VersionTests: XCTestCase {
    func testNewer() {
        XCTAssertTrue(Version.isVersion("1.4.3", newerThan: "1.4.2"))
        XCTAssertTrue(Version.isVersion("1.10", newerThan: "1.9"))
        XCTAssertTrue(Version.isVersion("1.5.0-beta", newerThan: "1.4.2"))
    }

    func testNotNewer() {
        XCTAssertFalse(Version.isVersion("1.4", newerThan: "1.4.0"))
        XCTAssertFalse(Version.isVersion("1.4.2", newerThan: "1.4.2"))
        XCTAssertFalse(Version.isVersion("1.3.9", newerThan: "1.4.2"))
    }

    func testNormalize() {
        XCTAssertEqual(Version.normalize(tag: "v1.2"), "1.2")
        XCTAssertEqual(Version.normalize(tag: "V2.0.1"), "2.0.1")
        XCTAssertEqual(Version.normalize(tag: "3.0"), "3.0")
    }
}

final class AppIdentityTests: XCTestCase {
    func testURLs() {
        let app = AppIdentity(name: "LaunchApp", tagline: "t", repo: "vuhpquang/launch-app", firstYear: 2026)
        XCTAssertEqual(app.repoURL.absoluteString, "https://github.com/vuhpquang/launch-app")
        XCTAssertEqual(app.releasesURL.absoluteString, "https://github.com/vuhpquang/launch-app/releases")
        XCTAssertEqual(app.newIssueURL.absoluteString, "https://github.com/vuhpquang/launch-app/issues/new")
        XCTAssertEqual(app.releaseURL(tag: "v1.2.0").absoluteString,
                       "https://github.com/vuhpquang/launch-app/releases/tag/v1.2.0")
        XCTAssertEqual(app.whatsNew, .menuItem)
    }
}
