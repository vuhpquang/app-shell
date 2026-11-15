# app-shell — notes for Claude

The shared "shell" of the owner's own macOS apps: self-update from GitHub Releases, About + What's New,
the Settings window shell. Repo `vuhpquang/app-shell` (public), branch `main` (push freely).
Swift package `AppShell`, macOS 13+ (Padlet's floor), Swift 6 language mode, `swift-tools-version:6.0`
(consumers with older manifests can still depend on it).

Used by LaunchApp, Padlet, ZenTask (macOS) as a git submodule at `Vendor/app-shell` + `.package(path:)`
(xcodegen: `packages: AppShell: path:`). Not used by Wisp / Quickcast (forks: upstream merges stay clean)
nor DevKit / Portfolio / Android (other stacks) — they follow the conventions in the hub rule
`.claude/rules/app-shell.md` instead. Spec + plan: `docs/superpowers/`.

## Commands

```bash
swift build && swift test
swift run AppShellPreview /tmp/appshell-shots     # About, What's New, Settings panes → PNG, light + dark
APPSHELL_LIVE=vuhpquang/launch-app:dmg:com.vuhpquang.launchapp swift test --filter LiveTests
APPSHELL_LIVE=vuhpquang/zentask:zip:ZenTask-:com.vuhpquang.zentask swift test --filter LiveTests
#   real GitHub release → download → stage + verify (no swap)
```

In an app's DEBUG build, `APPSHELL_PRETEND_VERSION=0.0.1` makes the updater see an update.

## Layout

- `AppShellCore` — `Author` (the ONLY place the author's name, links and copyright format live),
  `AppIdentity` (per-app values: name, tagline, repo, first year, accent, credits, What's New mode),
  `Version`, `LaunchAtLogin`, `ShellTokens` (spacing/sizes; views use these, never literals).
- `UpdaterKit` — `Release` + `AssetMatcher` (pure), `Updater` (`ObservableObject`, `@MainActor` state
  machine), `Installer` (stage DMG/zip, verify bundle id + `codesign --strict` + own designated
  requirement, detached swap script), `UpdateTransport` (URLSession; fakes in tests),
  `UpdateSettingsStore` (apps adapt their own storage so keys never change; `UserDefaultsUpdateSettings`
  for new apps: `appShell.updates.autoCheck/autoInstall`).
- `UpdaterKit` also has `CatalogTransport(catalogURL:slug:)` (update source = the vuhpquang.com catalog
  instead of GitHub) and `ExternalInstaller` (install/replace OTHER apps: `stage`, static
  `satisfies(_:requirement:)` / `designatedRequirement(of:)`, `@MainActor replace(target:with:relaunchArguments:quitTimeout:)`;
  it quits only a running app whose `bundleURL` equals the target, via the injectable
  `AppProcessControlling`, so tests never touch real apps).
- `AboutKit` — `AboutView`, `AuthorFooter`, `AboutWindow`, `UpdateStatusLabel`/`UpdateActionButton`,
  `WhatsNewTracker` (`appShell.lastSeenVersion`; silent first run), `WhatsNewView`/`WhatsNewWindow`,
  `ReleaseNotes` (Markdown → blocks).
- `SettingsKit` — `SettingsShell` (app panes, then Updates + About), `SettingsShellStyle` (optional
  general styling for themed apps), `UpdatesPane`, `AboutPane`, `LaunchAtLoginRow`.
- `AppShellPreview` — dev-only renderer, not a product.

## Rules

- Per-app differences come in as values (`AppIdentity`, `AssetMatcher`, `UpdateSettingsStore`,
  `SettingsShellStyle`). Never branch on which app is running.
- `ObservableObject`, not `@Observable` (macOS 13). macOS 14+/26 APIs only behind `if #available`.
- **No resources in the package** (no `resources:`, no `Bundle.module`). LaunchApp and Padlet copy only the
  executable into their `.app`, so a SwiftPM resource bundle would be missing at runtime (`Bundle.module`
  then crashes once `.build` is gone), and Xcode apps fail to sign the bundles with a named identity.
  Strings are plain English literals; images come from SF Symbols or the app's own bundle.
- Never weaken update verification. Changing `Installer` means re-running the live tests for a DMG app and
  the zip app.
- A change here ships nowhere until an app bumps its submodule: commit + push here (tag `vX.Y.Z` for
  notable changes, note it in `CHANGELOG.md`), then in each app `git -C Vendor/app-shell pull`,
  build + test, commit `chore: bump app-shell`, release.

GitNexus can't parse Swift; don't run `npx gitnexus analyze` in this repo.
In the hub, bump the pointer with `git add projects/app-shell` and commit `chore: bump app-shell submodule`.
