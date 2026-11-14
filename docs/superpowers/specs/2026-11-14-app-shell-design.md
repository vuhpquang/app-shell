# app-shell — shared app "shell" for the hub's macOS apps

Date: 2026-11-14 · Status: draft for review

## Intent

The owner's own macOS apps (Padlet, LaunchApp, ZenTask, and later any new one) should feel like one
family in the parts that aren't the product itself: how they update, what their About says, how their
Settings window is laid out. Today each app carries its own copy of that code and the copies drift:

- `UpdateManager.swift` in Padlet and LaunchApp are the same 325 lines with names swapped; ZenTask's
  `Updater.swift` is a third variant (zip asset, async/`@Observable`).
- The author shows up as "Ha Phung Quang Vu" (Padlet Settings), "Vu Ha" (Padlet/LaunchApp Info.plist,
  Wisp About), "vuhpquang" (ZenTask). The portfolio (vuhpquang.com) uses **Ha Phung Quang Vu**.

Goal: one place to fix an updater bug, one place that says who made the app, one layout for Settings —
plus a hub rule that makes every current and future app follow it.

## Goals

1. **UpdaterKit** — one self-updater from GitHub Releases used by LaunchApp, Padlet, ZenTask.
2. **AboutKit** — one About view + What's New sheet, fed by per-app metadata; one `Author` record.
3. **SettingsKit** — the Settings *shell* (window, sidebar, fixed order of shared panes) and the shared
   panes (Updates, About, Launch at login).
4. **Hub rule** `.claude/rules/app-shell.md` — detailed, so new apps adopt the kit from day one and
   existing apps stay consistent (including the non-Swift ones by convention).

## Non-goals

- Wisp code: Wisp keeps Sparkle and its own About/Settings (upstream Ghostty merges must stay clean).
  Wisp only copies the shared **content** (author name, links, copyright line) into `WispAboutView`.
- Quickcast: not migrated now. Its updater/Settings come from Tinycast and are the most complete; they
  are a reference for the kit, and Quickcast may adopt the kit later only if the upstream diff stays small.
- DevKit (Tauri), Portfolio (web), ZenTask Android: no shared code, only the conventions in the rule.
- App-specific Settings panes (Padlet gestures, LaunchApp layout, ZenTask accounts…) stay in each app.
- Sparkle / appcasts / EdDSA keys (decided against, see Approaches).

## Anti-goals (failure even if it works)

- Apps that look like clones of each other: icon, accent colour, tagline and copy stay per app
  (`.claude/rules/design.md`). The kit supplies layout, not identity.
- A kit full of `if app == …` branches. Per-app differences come in as configuration, never as switches
  on app identity.
- A change in the kit silently changing a shipped app: apps move to a new kit version only on purpose.
- Losing a user's existing update preferences (auto-check / auto-install) during migration.
- Weakening update verification compared to today.

## Constraints

- **Deployment target macOS 13** (Padlet). So: no `@Observable` (macOS 14) — use `ObservableObject`;
  Liquid Glass / macOS 26 APIs only behind `if #available`.
- **Swift 6 language mode clean** (Quickcast/ZenTask build with strict concurrency). Kit compiles under
  Swift 6 mode; consumers on Swift 5.9/5.10 tools (Padlet `swift-tools-version:5.9`, LaunchApp 5.10)
  must still be able to depend on it → package manifest `swift-tools-version:5.9`, Swift 6 mode set via
  `swiftLanguageVersions`/settings where the toolchain allows. (Builder: verify with the installed
  toolchain which form works for both.)
- **Works offline / at the office**: GitHub pushes are blocked at the office, so consuming a new kit
  version must not require pushing anything.
- Persisted keys are never renamed (project rule). Existing keys: Padlet `Preferences.general
  .autoCheckUpdates/.autoInstallUpdates`, LaunchApp `Preferences.settings.autoCheckUpdates/
  .autoInstallUpdates`, ZenTask `UserDefaults "updates.autoCheck"`.
- Release assets differ: Padlet `Padlet.dmg`, LaunchApp `LaunchApp.dmg`, ZenTask `ZenTask-X.Y.Z.zip`
  (plus APKs in the same release, which must be ignored).
- Builds are self-signed / ad-hoc; verification = same bundle id + `codesign --verify --deep --strict`
  + satisfies this copy's designated requirement when this copy has a certificate (current behaviour).
- English UI strings; the kit localizes nothing today but strings go through `String(localized:)` with
  `bundle: .module` so a consumer that localizes (Quickcast later) can.

## Approaches

### How apps consume the kit — **chosen: B**

- A. Remote SwiftPM dependency pinned to a tag on `github.com/vuhpquang/app-shell`. Standard and tidy,
  but a kit change made at the office can't be tagged on GitHub, so apps can't ship it until home.
- **B. Git submodule per app at `Vendor/app-shell`, referenced by local path** (`.package(path:)` in
  SwiftPM apps, `packages: AppShell: path: …` in xcodegen apps). Pinned by submodule commit; works fully
  offline: commit kit → bump submodule in the app → `PUBLISH=0` release; `ship-check` pushes later.
  Cost: nested submodules, and release/build scripts must `git submodule update --init` first.
- C. Copy files into each app with a hub sync script. No dependency mechanism, but drift returns.

Picked B by the owner because releases at the office are frequent.

### Updater engine — **chosen: A**

- **A. Own updater, consolidated from Padlet/LaunchApp** (proven in three apps), supporting DMG and zip,
  borrowing a few ideas from Quickcast (quarantine handling, architecture check).
- B. Sparkle (as Wisp): standard, has UI, but needs EdDSA keys, an appcast to generate and host, and
  changes to every release script — infrastructure for a problem the apps don't have.

Picked A by the owner.

## Design

### Repo and package

- New GitHub repo `vuhpquang/app-shell` (branch `main`), added to the hub as `projects/app-shell` via the
  `add-project` skill (so the hub tracks it like the apps), **and** as `Vendor/app-shell` submodule inside
  each consuming app.
- One package `AppShell`, library products:
  - `AppShellCore` — `Author`, `AppInfo` (per-app metadata), version comparison, small helpers.
  - `UpdaterKit` — depends on Core.
  - `AboutKit` — depends on Core + UpdaterKit (shows update status/button).
  - `SettingsKit` — depends on Core + UpdaterKit + AboutKit.
- Tests: `swift test` in the kit (pure logic: version compare, release parsing/asset selection,
  state machine with a fake transport, settings-store adapters).
- Kit has its own `CLAUDE.md` (how to change it, how apps bump it) and `CHANGELOG.md`; versions tagged
  `vX.Y.Z` on the kit repo for humans, even though apps pin by submodule commit.

### AppShellCore

```swift
public enum Author {           // the only place these live
    public static let name = "Ha Phung Quang Vu"
    public static let website = URL("https://vuhpquang.com")
    public static let github = URL("https://github.com/vuhpquang")
    public static let linkedIn = URL("https://www.linkedin.com/in/vuhpquang/")
    public static func copyright(since: Int) -> String   // "© 2025–2026 Ha Phung Quang Vu" / "© 2026 …"
}

public struct AppInfo {         // filled once per app
    var name: String            // "LaunchApp"
    var tagline: String         // one line, the app's own copy
    var repo: String            // "vuhpquang/launch-app"
    var firstYear: Int          // for the copyright line
    var icon: NSImage           // default NSApp.applicationIconImage
    var accent: Color?          // nil = system accent
    var credits: [Credit]       // e.g. upstream for forks; empty for own apps
    // derived: version, build (Info.plist), repoURL, releasesURL, newIssueURL
}
```

### UpdaterKit

Behaviour = today's Padlet/LaunchApp updater, generalised:

- `Updater(app: AppInfo, asset: AssetMatcher, settings: UpdateSettingsStore)` — an `ObservableObject`,
  `@MainActor`. `State`: `idle, checking, upToDate, available(version), downloading(progress?),
  installing, failed(message)` (same cases as today; add optional progress).
- `check(userInitiated:)`: `GET api.github.com/repos/{repo}/releases/latest`, tag `vX.Y.Z` vs
  `CFBundleShortVersionString` (dotted numeric compare, pre-release suffix ignored, as today). Keeps the
  release notes (`body`) and the release's published date for What's New.
- `AssetMatcher`: `.dmg` or `.zip` plus a name predicate (ZenTask: `ZenTask-*.zip`, ignoring `.apk`).
- `install()`: download → stage (mount DMG read-only / unzip with `ditto -x -k`) → verify (same bundle
  id, `codesign --verify --deep --strict`, same signer when this copy has a certificate) → hand off to the
  detached shell script that waits for the PID to exit, swaps the bundle, strips quarantine, reopens →
  terminate. Same safety checks as today; none removed.
- Pre-flight errors stay explicit and actionable ("Move <App> to Applications and try again").
- Scheduling: first check 10 s after launch, then every 6 h, only while auto-check is on; a background
  result never replaces a visible `available`/`failed` state (ZenTask's rule, adopted for all). Auto-install
  only on background checks with auto-install on (today's behaviour).
- `UpdateSettingsStore` protocol (`autoCheck`, `autoInstall`, change publisher). Each app supplies an
  adapter over **its existing storage**, so no key is renamed. The kit ships a `UserDefaultsUpdateSettings
  (autoCheckKey:autoInstallKey:)` for apps (ZenTask, new apps) that keep them in UserDefaults; new apps
  use keys `appShell.updates.autoCheck` / `appShell.updates.autoInstall`.
- Relaunch hook: `onWillRelaunch` closure so an app can save state first; LaunchApp needs the relaunched
  copy started with `--background` (builder: confirm from LaunchApp's AppDelegate/release flow).
- Debug: `dryRun()` (check → download → stage, no swap) and a `PRETEND_VERSION` env override in DEBUG,
  replacing the per-app `debugDryRun` / `ZENTASK_PRETEND_VERSION`.
- `LaunchAtLogin` (SMAppService wrapper) lives in Core (it sits in Padlet's updater file today).

### AboutKit

- `AboutView(app:updater:)` — layout from the sketch below, modelled on Wisp's `WispAboutView` and
  Padlet's About: icon, name, tagline, "Version X (build)" (selectable), update status + button,
  buttons **Check for Updates / What's New / Report Issue**, then "Made by **Ha Phung Quang Vu**",
  links **vuhpquang.com · GitHub · LinkedIn · Source code**, credits (forks), copyright line.
- Usable two ways: as a Settings pane (`SettingsKit`) and as a standalone About window
  (`AboutWindow.show(app:updater:)`) for the app menu's "About <App>" item.
- `WhatsNewSheet`: offered once per new version (key `appShell.lastSeenVersion`). *How* it is offered is
  per app via `AppInfo.whatsNew: .automatic | .menuItem` (my call):
  - `.automatic` (window apps — ZenTask): the sheet opens over the main window on the first launch of a
    newer version.
  - `.menuItem` (background / `LSUIElement` apps — LaunchApp, Padlet, which start at login or with
    `--background` and may be relaunched by auto-install with nobody watching): no window opens by
    itself; the app / menu-bar menu shows "What's New in X.Y" until opened once.
  - First run with no `lastSeenVersion` recorded (fresh install, or first run after migrating to the
    kit): record the current version silently, show nothing (my call).
  Content = the GitHub release notes for the running version
  (fetched by tag `releases/tags/vX.Y.Z`; offline → a link to the releases page). Markdown rendered with
  `AttributedString(markdown:)`. Also opened from the About button.
- Design: system fonts and semantic colours only, light + dark, accent from `AppInfo.accent`.

```
        [ icon ]
        LaunchApp
  The classic Launchpad, back on macOS 26+.
     Version 1.4.2 (142)  · ✓ Up to date
  [Check for Updates] [What's New] [Report Issue]
  ───────────────────────────────
  Made by Ha Phung Quang Vu
  vuhpquang.com · GitHub · LinkedIn · Source code
  © 2026 Ha Phung Quang Vu
```

### SettingsKit

- `AppSettingsWindow` / `SettingsShell(panes:)`: stock titled window, sidebar (`NavigationSplitView`)
  + `Form { }.formStyle(.grouped)` detail, ⌘, opens, Esc/⌘W closes, remembers last pane (key provided
  by the app so existing ones aren't renamed).
- Pane order: **app panes first (General first), then the shared ones: Updates, About.**
  The app passes its own panes (id, title, SF Symbol, view); the shell appends the shared ones.
- Shared panes: `UpdatesPane` (status, Check/Install, release notes when available, the two toggles),
  `AboutPane` (AboutView), and a `LaunchAtLoginRow` for an app's General pane.
- **Style hook (owner's decision):** `SettingsShellStyle` with optional `sidebarIconTint: Color?`,
  `sidebarBackground` / `detailBackground: AnyShapeStyle?` (hides the grouped-form grey when set),
  `windowSize: CGSize?`, and an optional sidebar-row selection modifier. Default = stock everywhere.
  ZenTask passes its theme values (today's `SidebarSelect`, theme backgrounds, `Theme.Size`), so its
  Settings keep their current look. The hook is general styling only — nothing in it names an app.
  Native controls inside forms are never restyled (design.md).
- **Padlet (owner's decision): restyled to the shared shell.** Its cards / icon badges / custom switches
  in Settings are replaced by stock grouped forms (optionally a light style hook for its accent); its
  `Author` enum and About section are replaced by AboutKit. This is a visible UI change and gets its own
  `design-check` (light + dark) before release.

### Migration per app (each one commit series in that app + hub pointer bump)

1. LaunchApp: add submodule, depend on UpdaterKit; delete `Update/UpdateManager.swift`; adapter over
   `Preferences.settings`; AppDelegate/Settings call sites switched; release script inits submodules.
2. Padlet: same (adapter over `Preferences.general`, DMG), Homebrew-tap step untouched.
3. ZenTask macOS: xcodegen `packages:` local path; zip matcher; UserDefaults adapter on
   `updates.autoCheck` (no auto-install toggle today → keep it off by default; builder decides whether to
   expose it, see calls).
4. Then AboutKit + What's New into all three; replace their About code; Info.plist copyright → shared
   line. Wisp: change `authorName` to "Ha Phung Quang Vu", add website + LinkedIn links, copyright line.
5. Then SettingsKit shell into LaunchApp (already sidebar + grouped forms → default style), ZenTask
   (themed → style hook keeps its look), Padlet (restyle to stock forms, own design-check).
6. Hub rule `app-shell.md` + updates to `add-project`, `release-project`, `ship-check`, `sync-project`
   skills (submodule init, kit bumps).

Each app is verified with its own build + tests, a `dryRun()` against its real latest release, and
`design-check` (light + dark) for About/Settings.

### Hub rule `.claude/rules/app-shell.md` (outline)

- What the kit is, where it lives, which apps use it, which don't and why (Wisp, Quickcast, DevKit,
  Portfolio, Android).
- **Identity content**: author name exactly "Ha Phung Quang Vu", links (website, GitHub, LinkedIn), the
  copyright format; applies to every app's About, Info.plist `NSHumanReadableCopyright`, README footer,
  DevKit About, Wisp About, Portfolio. Source of truth = `AppShellCore.Author`; anything else copies it.
- **Every app has**: About (window + pane) with the fixed contents above; Check for Updates in the app/
  menu-bar menu; What's New after an update; Report Issue → `github.com/<repo>/issues/new`; Settings with
  General first and Updates, About last; Launch at login in General where the app runs in the background.
- **Updates**: GitHub Releases `vX.Y.Z` is the feed for every app (Tauri updater for DevKit points at the
  same releases); release notes are user-facing (they are shown in-app).
- **Changing the kit**: change in `projects/app-shell`, test, commit, tag; then bump `Vendor/app-shell` in
  each app *one at a time*, build + test each, release; never let an app's submodule float.
- **Adding a new app**: `add-project` adds the submodule and the three products from the start.
- Menu standard: About <App>, Check for Updates…, Settings… ⌘,, Quit ⌘Q.

## Left to the builder (calls to make, state in the plan)

- Exact Swift-version/manifest setup that satisfies Swift 6 mode and the 5.9 tools consumers.
- Whether `downloading` shows progress (URLSession delegate) or stays indeterminate.
- How the submodule path is wired in each release script (one `git submodule update --init --recursive`
  line at the top is the expected form).
- Test seams (protocol for HTTP + process runner) to unit-test the updater without network.

- Repo visibility: **public** (my call) — the app repos are public, so a private submodule would break
  anyone cloning an app with `--recursive`. The repo must be created and first pushed **from home**
  (GitHub pushes are blocked at the office).

## Decisions log

- Consumption: submodule + local path (owner).
- Updater: own code, not Sparkle (owner).
- About content: name "Ha Phung Quang Vu", vuhpquang.com, GitHub, LinkedIn (owner).
- ZenTask Settings keep their theme via a general style hook (owner).
- Padlet Settings restyled to the shared shell (owner).
- What's New automatic vs menu item per app; silent first run (my call).
- Kit repo public (my call).
