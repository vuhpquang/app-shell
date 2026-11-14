import Foundation

/// Release version helpers. Tags are `vX.Y.Z`; bundles carry `X.Y.Z`.
public enum Version {
    /// Numeric dotted comparison; missing parts count as 0, anything after "-" is ignored.
    public static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = parts(a), pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// "v1.2.3" → "1.2.3".
    public static func normalize(tag: String) -> String {
        tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private static func parts(_ v: String) -> [Int] {
        let core = normalize(tag: v).split(separator: "-").first ?? ""
        return core.split(separator: ".").map { Int($0) ?? 0 }
    }
}
