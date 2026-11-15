import CoreGraphics
import Foundation

/// Design tokens of the shared shell (spacing on the 2/4/8 scale, sizes, durations).
/// Views in AboutKit / SettingsKit use these, never literals.
public enum ShellTokens {
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Size {
        public static let aboutIcon: CGFloat = 112
        public static let paneIcon: CGFloat = 72
        public static let authorLogo: CGFloat = 32
        public static let aboutWidth: CGFloat = 420
        public static let whatsNewWidth: CGFloat = 480
        public static let whatsNewHeight: CGFloat = 420
        public static let notesMaxHeight: CGFloat = 160
        public static let settingsWidth: CGFloat = 720
        public static let settingsHeight: CGFloat = 500
        public static let sidebarWidth: CGFloat = 200
    }

    public enum Radius {
        public static let card: CGFloat = 10
    }
}
