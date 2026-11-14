# app-shell

The shared "shell" of [vuhpquang](https://github.com/vuhpquang)'s macOS apps (LaunchApp, Padlet, ZenTask):
one self-updater from GitHub Releases, one About window and What's New, one Settings window shell.

| Product | What it gives an app |
|---|---|
| `AppShellCore` | `Author`, `AppIdentity`, version compare, `LaunchAtLogin` |
| `UpdaterKit` | `Updater`: check GitHub Releases, download DMG/zip, verify, swap, relaunch |
| `AboutKit` | `AboutView`, `AboutWindow`, `WhatsNewTracker`, `WhatsNewWindow` |
| `SettingsKit` | `SettingsShell` (sidebar + grouped forms, Updates + About panes), `LaunchAtLoginRow` |

Apps include it as a git submodule at `Vendor/app-shell` and depend on it by path:

```swift
.package(path: "Vendor/app-shell")
```

macOS 13+. Swift 6 language mode. `swift test` runs the tests.

© 2026 Ha Phung Quang Vu · [vuhpquang.com](https://vuhpquang.com)
