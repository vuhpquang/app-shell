# Changelog

## 0.2.7 — 2026-11-15

- Fix: the About window could collapse to ~170 pt wide (text wrapping per character) once the logo was added.
  The content now has a fixed `aboutWidth`; the author footer is a centered column (logo, "Made by …", links)
  whose lines never wrap. `AppShellPreview` renders About at its fitting size and fails unless it is exactly
  `aboutWidth` wide (`about-natural-*.png`).

## 0.2.6 — 2026-11-15

- The author logo in the footer is the small circle variant ("{VU} HA" without the tiny "HAHA", larger lettering),
  which reads at 32 pt. Same `Author.logoPNG` API, new embedded PNG.

## 0.2.5 — 2026-11-15

- The author footer (About window and Settings → About) shows the author's circle logo ("{VU} HA") at
  32 pt left of "Made by …"; it links to vuhpquang.com. The PNG is embedded as base64 in
  `AppShellCore/AuthorLogo.swift` (`Author.logoPNG`), not a bundle resource, so the package still ships
  no resources. New public view `AuthorLogo`, token `ShellTokens.Size.authorLogo`.

## 0.2.4 — 2026-11-15

- `AppIdentity.updateSourceDescription`: the footer of Settings → Updates is a value. The default is
  unchanged ("Updates come from the app's GitHub releases."); App Depot sets its own.

## 0.2.3 — 2026-11-15

- `AppIdentity.tagPrefix` (default "v") and `releaseURL(version:)`: What's New's "View on GitHub" and its
  notes lookup use `<tagPrefix><version>`, so a repo with several apps (App Depot: `macos-v`) links right.
- `WhatsNewWindow.show(…, transport:)`: catalog apps load the notes from their `CatalogTransport`, which now
  matches a tag by its version part (`macos-v0.1.0` ↔ catalog `v0.1.0`).

## 0.2.2 — 2026-11-15

- `Installer.stage` (and so `ExternalInstaller.stage`) removes its work folder when it refuses or fails,
  so a damaged or wrongly signed download leaves nothing in the temporary folder.

## 0.2.1 — 2026-11-15

- `ExternalInstaller.replace`: when the swap fails after the running app was quit, the old copy is
  reopened (with the relaunch arguments) before the error is thrown.
- Running-app matching is one pure function, `ExternalInstaller.isSameBundle(_:_:)`: both sides are
  compared with `resolvingSymlinksInPath().standardizedFileURL`; a copy with the same name elsewhere never
  matches. `ExternalInstaller(process:)` is public so apps can test with a fake controller.
- `Updater.unreachableMessage`: the error for a failed user check (catalog apps name their server
  instead of GitHub). Default unchanged.

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
