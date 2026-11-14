// swift-tools-version:6.0
// app-shell — the shared updater, About and Settings shell for vuhpquang's macOS apps.
// Consumed by each app as a git submodule at Vendor/app-shell (`.package(path:)`).
// Tools 6.0 is only this package's own floor; apps with older manifests (Padlet: 5.9) can depend on it.

import PackageDescription

let package = Package(
    name: "AppShell",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AppShellCore", targets: ["AppShellCore"]),
        .library(name: "UpdaterKit", targets: ["UpdaterKit"]),
        .library(name: "AboutKit", targets: ["AboutKit"]),
        .library(name: "SettingsKit", targets: ["SettingsKit"]),
    ],
    targets: [
        .target(name: "AppShellCore"),
        .target(name: "UpdaterKit", dependencies: ["AppShellCore"]),
        .target(name: "AboutKit", dependencies: ["AppShellCore", "UpdaterKit"]),
        .target(name: "SettingsKit", dependencies: ["AppShellCore", "UpdaterKit", "AboutKit"]),
        .testTarget(name: "AppShellCoreTests", dependencies: ["AppShellCore"]),
        .testTarget(name: "UpdaterKitTests", dependencies: ["UpdaterKit"]),
        .testTarget(name: "AboutKitTests", dependencies: ["AboutKit"]),
        .testTarget(name: "SettingsKitTests", dependencies: ["SettingsKit"]),
    ],
    swiftLanguageModes: [.v6]
)
