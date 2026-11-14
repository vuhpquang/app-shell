import Foundation

/// Who makes the apps. The only place these values live: every About, Info.plist copyright,
/// README footer and the portfolio copy them from here (`.claude/rules/app-shell.md` in the hub).
public enum Author {
    public static let name = "Ha Phung Quang Vu"
    public static let website = URL(string: "https://vuhpquang.com")!
    public static let github = URL(string: "https://github.com/vuhpquang")!
    public static let linkedIn = URL(string: "https://www.linkedin.com/in/vuhpquang/")!

    /// "© 2026 Ha Phung Quang Vu", or "© 2025–2026 Ha Phung Quang Vu" for an app first released earlier.
    public static func copyright(since firstYear: Int, now: Date = Date()) -> String {
        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        let span = firstYear < year ? "\(firstYear)–\(year)" : "\(year)"
        return "© \(span) \(name)"
    }
}
