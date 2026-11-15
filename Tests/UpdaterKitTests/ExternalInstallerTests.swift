import XCTest
@testable import UpdaterKit

@MainActor
private final class FakeControl: AppProcessControlling {
    var running: Bool
    var quitsOnTerminate: Bool
    var terminated: [URL] = []
    var opened: [(URL, [String]?)] = []
    init(running: Bool, quitsOnTerminate: Bool = true) {
        self.running = running
        self.quitsOnTerminate = quitsOnTerminate
    }
    func isRunning(bundleURL: URL) -> Bool { running }
    func terminate(bundleURL: URL) {
        terminated.append(bundleURL)
        if quitsOnTerminate { running = false }
    }
    func open(_ app: URL, arguments: [String]?) { opened.append((app, arguments)) }
}

final class ExternalInstallerTests: XCTestCase {
    private let calculator = URL(fileURLWithPath: "/System/Applications/Calculator.app")

    func testSatisfiesAppleAnchor() {
        XCTAssertTrue(ExternalInstaller.satisfies(calculator, requirement: "anchor apple"))
    }

    func testDoesNotSatisfyWrongIdentifier() {
        XCTAssertFalse(ExternalInstaller.satisfies(calculator, requirement: "identifier \"x.y\" and anchor apple"))
    }

    func testInvalidRequirementTextIsFalse() {
        XCTAssertFalse(ExternalInstaller.satisfies(calculator, requirement: "this is not ((( a requirement"))
    }

    func testDesignatedRequirementOfCalculator() throws {
        let text = try XCTUnwrap(ExternalInstaller.designatedRequirement(of: calculator))
        XCTAssertTrue(text.contains("com.apple.calculator"))
        XCTAssertNil(ExternalInstaller.designatedRequirement(of: URL(fileURLWithPath: "/nonexistent.app")))
    }

    private func makeApp(_ dir: URL, _ name: String, marker: String) throws -> URL {
        let app = dir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try marker.write(to: app.appendingPathComponent("Contents/marker.txt"), atomically: true, encoding: .utf8)
        return app
    }

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ExtInstTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    @MainActor
    func testReplaceNotRunning() async throws {
        let dir = try tempDir()
        let target = try makeApp(dir, "Target.app", marker: "old")
        let staged = try makeApp(dir.appendingPathComponent("stage", isDirectory: true).deletingLastPathComponent(),
                                 "Staged.app", marker: "new")
        let control = FakeControl(running: false)
        let outcome = try await ExternalInstaller(process: control)
            .replace(target: target, with: staged, relaunchArguments: nil, quitTimeout: .seconds(1))
        XCTAssertEqual(outcome, .replaced(relaunched: false))
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("Contents/marker.txt"), encoding: .utf8), "new")
        XCTAssertTrue(control.terminated.isEmpty)
        XCTAssertTrue(control.opened.isEmpty)
        // No leftover temp copies next to the target.
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix(".") }, [])
    }

    @MainActor
    func testReplaceRunningQuitsReplacesAndReopens() async throws {
        let dir = try tempDir()
        let target = try makeApp(dir, "Target.app", marker: "old")
        let staged = try makeApp(dir, "Staged.app", marker: "new")
        let control = FakeControl(running: true)
        let outcome = try await ExternalInstaller(process: control)
            .replace(target: target, with: staged, relaunchArguments: ["--background"], quitTimeout: .seconds(1))
        XCTAssertEqual(outcome, .replaced(relaunched: true))
        XCTAssertEqual(control.terminated, [target])
        XCTAssertEqual(control.opened.first?.0, target)
        XCTAssertEqual(control.opened.first?.1, ["--background"])
    }

    @MainActor
    func testRefusedToQuitLeavesTargetUntouched() async throws {
        let dir = try tempDir()
        let target = try makeApp(dir, "Target.app", marker: "old")
        let staged = try makeApp(dir, "Staged.app", marker: "new")
        let control = FakeControl(running: true, quitsOnTerminate: false)
        let outcome = try await ExternalInstaller(process: control)
            .replace(target: target, with: staged, relaunchArguments: nil, quitTimeout: .milliseconds(300))
        XCTAssertEqual(outcome, .appRefusedToQuit)
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("Contents/marker.txt"), encoding: .utf8), "old")
        XCTAssertTrue(control.opened.isEmpty)
    }

    @MainActor
    func testReplaceFreshInstallWhenTargetMissing() async throws {
        let dir = try tempDir()
        let staged = try makeApp(dir, "Staged.app", marker: "new")
        let target = dir.appendingPathComponent("Fresh.app")
        let outcome = try await ExternalInstaller(process: FakeControl(running: false))
            .replace(target: target, with: staged, relaunchArguments: nil, quitTimeout: .seconds(1))
        XCTAssertEqual(outcome, .replaced(relaunched: false))
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.appendingPathComponent("Contents/marker.txt").path))
    }
}

final class ExternalInstallerHardeningTests: XCTestCase {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ExtInstHard-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    func testBundleMatchSamePath() {
        let target = URL(fileURLWithPath: "/Applications/Padlet.app")
        XCTAssertTrue(ExternalInstaller.isSameBundle(URL(fileURLWithPath: "/Applications/Padlet.app/"), target))
        XCTAssertTrue(ExternalInstaller.isSameBundle(URL(fileURLWithPath: "/Applications/./Padlet.app"), target))
    }

    func testSameNameElsewhereDoesNotMatch() {
        let target = URL(fileURLWithPath: "/tmp/root/Padlet.app")
        XCTAssertFalse(ExternalInstaller.isSameBundle(URL(fileURLWithPath: "/Applications/Padlet.app"), target))
        XCTAssertFalse(ExternalInstaller.isSameBundle(URL(fileURLWithPath: "/tmp/root/Padlet 2.app"), target))
        XCTAssertFalse(ExternalInstaller.isSameBundle(nil, target))
    }

    func testSymlinkedPathMatches() throws {
        let dir = try tempDir()
        let real = dir.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: real.appendingPathComponent("A.app"), withIntermediateDirectories: true)
        let link = dir.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        XCTAssertTrue(ExternalInstaller.isSameBundle(link.appendingPathComponent("A.app"), real.appendingPathComponent("A.app")))
        XCTAssertTrue(ExternalInstaller.isSameBundle(real.appendingPathComponent("A.app"), link.appendingPathComponent("A.app")))
    }

    @MainActor
    func testFailedSwapAfterQuitReopensTheOldApp() async throws {
        let dir = try tempDir()
        let target = dir.appendingPathComponent("Target.app")
        try FileManager.default.createDirectory(at: target.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let missingStaged = dir.appendingPathComponent("Missing.app")   // ditto fails → swap fails
        let control = FakeControl(running: true)
        do {
            _ = try await ExternalInstaller(process: control)
                .replace(target: target, with: missingStaged, relaunchArguments: ["--background"], quitTimeout: .seconds(1))
            XCTFail("expected a throw")
        } catch {}
        XCTAssertEqual(control.terminated, [target])
        XCTAssertEqual(control.opened.first?.0, target, "the old copy is reopened")
        XCTAssertEqual(control.opened.first?.1, ["--background"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
    }

    @MainActor
    func testFailedSwapWhenNotRunningOpensNothing() async throws {
        let dir = try tempDir()
        let target = dir.appendingPathComponent("Target.app")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let control = FakeControl(running: false)
        do {
            _ = try await ExternalInstaller(process: control)
                .replace(target: target, with: dir.appendingPathComponent("Missing.app"), relaunchArguments: nil, quitTimeout: .seconds(1))
            XCTFail("expected a throw")
        } catch {}
        XCTAssertTrue(control.opened.isEmpty)
    }
}

final class StageCleanupTests: XCTestCase {
    private func workDirs() -> Set<String> {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path)) ?? []
        return Set(items.filter { $0.hasPrefix("AppShellUpdate-") })
    }

    func testRefusedStageLeavesNoWorkFolder() throws {
        let bogus = FileManager.default.temporaryDirectory.appendingPathComponent("bogus-\(UUID().uuidString).zip")
        try Data("not a zip".utf8).write(to: bogus)
        defer { try? FileManager.default.removeItem(at: bogus) }
        let before = workDirs()
        XCTAssertThrowsError(try ExternalInstaller().stage(bogus, kind: .zip, bundleId: "x.y"))
        XCTAssertEqual(workDirs().subtracting(before), [], "a refused download leaves nothing in the temp folder")
    }
}
