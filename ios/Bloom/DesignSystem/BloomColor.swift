import SwiftUI

/// Color tokens. The values (incl. dark mode variants) live in Assets.xcassets.
enum BloomColor {
    static let accent = Color("AccentColor")
    /// Logged and predicted period days.
    static let period = Color("Period")
    /// Fertile window.
    static let fertile = Color("Fertile")
    /// Estimated ovulation day.
    static let ovulation = Color("Ovulation")

    static let groupedBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let chipBackground = Color(.tertiarySystemFill)
}
