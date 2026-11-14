import XCTest
@testable import UpdaterKit

final class ReleaseTests: XCTestCase {
    static let json = """
    {"tag_name":"v1.5.0","body":"- Faster search","published_at":"2026-11-10T08:00:00Z",
     "assets":[
       {"name":"ZenTask-1.5.0.apk","browser_download_url":"https://example.com/ZenTask-1.5.0.apk"},
       {"name":"ZenTask-1.5.0.zip","browser_download_url":"https://example.com/ZenTask-1.5.0.zip"},
       {"name":"LaunchApp.dmg","browser_download_url":"https://example.com/LaunchApp.dmg"}]}
    """

    func release(_ json: String = json) throws -> Release {
        try Release.decode(Data(json.utf8))
    }

    func testDecode() throws {
        let r = try release()
        XCTAssertEqual(r.tagName, "v1.5.0")
        XCTAssertEqual(r.body, "- Faster search")
        XCTAssertNotNil(r.publishedAt)
        XCTAssertEqual(r.assets.count, 3)
    }

    func testPickDMG() throws {
        XCTAssertEqual(AssetMatcher.dmg.pick(try release().assets)?.name, "LaunchApp.dmg")
    }

    func testPickZipIgnoresAPK() throws {
        XCTAssertEqual(AssetMatcher.zip(prefix: "ZenTask-").pick(try release().assets)?.name, "ZenTask-1.5.0.zip")
    }

    func testAvailable() throws {
        let result = UpdateCheckResult.evaluate(try release(), current: "1.4.2", matcher: .dmg)
        XCTAssertEqual(result, .available(version: "1.5.0", asset: URL(string: "https://example.com/LaunchApp.dmg")!,
                                          notes: "- Faster search"))
    }

    func testNoMatchingAssetIsUpToDate() throws {
        let onlyAPK = """
        {"tag_name":"v2.0.0","body":null,"published_at":null,
         "assets":[{"name":"ZenTask-2.0.0.apk","browser_download_url":"https://example.com/a.apk"}]}
        """
        XCTAssertEqual(UpdateCheckResult.evaluate(try release(onlyAPK), current: "1.0.0",
                                                  matcher: .zip(prefix: "ZenTask-")), .upToDate)
    }

    func testSameOrOlderIsUpToDate() throws {
        XCTAssertEqual(UpdateCheckResult.evaluate(try release(), current: "1.5.0", matcher: .dmg), .upToDate)
        XCTAssertEqual(UpdateCheckResult.evaluate(try release(), current: "1.6", matcher: .dmg), .upToDate)
    }
}
