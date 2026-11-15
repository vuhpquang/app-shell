# Changelog

## 0.2.0 — 2026-11-15

- `CatalogTransport`: an `UpdateTransport` that reads the latest release of one app from the
  vuhpquang.com catalog (`/api/depot/catalog`) by slug (used by the App Depot to update itself).
- `ExternalInstaller`: install or update OTHER apps — `stage` (bundle id + `codesign --strict`),
  `satisfies(_:requirement:)`, `designatedRequirement(of:)` and an in-process `replace` that quits only
  the exact running bundle (`AppProcessControlling`, injectable), swaps it and reopens it.
- `Release` has a public memberwise init; `Installer.stage` got an internal `requireOwnSigner` switch
  (default behaviour unchanged).

## 0.1.1 — 2026-11-14

- No resource bundles any more: SwiftPM-built apps (LaunchApp, Padlet) don't ship them, so
  `Bundle.module` would crash once the build folder was gone; Xcode apps (ZenTask) failed to sign them.

## 0.1.0 — 2026-11-14

First version, adopted by LaunchApp, Padlet and ZenTask.

- `AppShellCore`: `Author`, `AppIdentity`, `Version`, `LaunchAtLogin`, `ShellTokens`.
- `UpdaterKit`: self-update from GitHub Releases (DMG or zip asset), consolidated from the apps' copies.
- `AboutKit`: About window, author footer, What's New (offered once per new version).
- `SettingsKit`: Settings shell with shared Updates and About panes, optional styling for themed apps.
