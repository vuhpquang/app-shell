import XCTest
@testable import UpdaterKit

final class CatalogTransportTests: XCTestCase {
    private let fixture = """
    {"data":{"generatedAt":"2026-11-15T11:05:47.749Z","apps":[
     {"slug":"launch-app","name":"LaunchApp","platform":"macos","appId":"com.vuhpquang.launchapp",
      "latest":{"version":"1.5.1","build":null,"notes":"## Fixes\\n- Crash fixed\\n","assetName":"LaunchApp.dmg",
      "downloadUrl":"https://github.com/vuhpquang/launch-app/releases/download/v1.5.1/LaunchApp.dmg",
      "sha256":"x","size":1,"publishedAt":"2026-11-14T07:16:55.000Z","minOs":null}},
     {"slug":"fresh","name":"Fresh","platform":"macos","appId":"a.b","latest":null}],
     "x":1},"error":null,"status":200}
    """.data(using: .utf8)!

    func testMapsLatestToRelease() throws {
        let release = try CatalogTransport.release(fromCatalog: fixture, slug: "launch-app")
        XCTAssertEqual(release.tagName, "v1.5.1")
        XCTAssertEqual(release.body, "## Fixes\n- Crash fixed\n")
        XCTAssertEqual(release.assets.map(\.name), ["LaunchApp.dmg"])
        XCTAssertEqual(release.assets.first?.url.absoluteString,
                       "https://github.com/vuhpquang/launch-app/releases/download/v1.5.1/LaunchApp.dmg")
        XCTAssertNotNil(release.publishedAt)
        XCTAssertEqual(AssetMatcher.dmg.pick(release.assets)?.name, "LaunchApp.dmg")
    }

    func testNullLatestThrowsNoReleaseYet() {
        XCTAssertThrowsError(try CatalogTransport.release(fromCatalog: fixture, slug: "fresh")) {
            XCTAssertEqual($0 as? UpdateError, UpdateError("No release yet"))
        }
    }

    func testUnknownSlugThrows() {
        XCTAssertThrowsError(try CatalogTransport.release(fromCatalog: fixture, slug: "nope")) {
            XCTAssertEqual($0 as? UpdateError, UpdateError("This app isn't in the catalog"))
        }
    }
}
