import SwiftUI

extension Color {
    /// Color from a 0xRRGGBB value, as the Android theme declares them.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Alivia palette, taken from the technician app designs (same values as Android `core/ui/theme/Color.kt`).
enum AliviaColor {
    static let navy = Color(hex: 0x0F1D4D)
    static let navyButton = Color(hex: 0x14286B)
    static let navySoft = Color(hex: 0xE8ECF8)
    static let teal = Color(hex: 0x8DEEDF)
    static let tealSoft = Color(hex: 0xDDF8F3)
    static let tealDark = Color(hex: 0x1F6F62)
    static let background = Color(hex: 0xF7F8FD)
    static let surface = Color(hex: 0xFFFFFF)
    static let surfaceMuted = Color(hex: 0xEFF2FB)
    static let ink = Color(hex: 0x111A3A)
    static let inkMuted = Color(hex: 0x5B6382)
    static let outline = Color(hex: 0xE2E6F2)
    static let danger = Color(hex: 0xC62828)
    static let dangerSoft = Color(hex: 0xFDECEA)
    static let warning = Color(hex: 0xE6A23C)
    static let warningSoft = Color(hex: 0xFFF4E0)

    // Service types, as the orders list colors them.
    static let evaluation = navy
    static let installation = Color(hex: 0x2E7D6B)
    static let incident = danger

    /// Teal of the Alivia mark.
    static let logoTeal = Color(hex: 0x29C3B5)
}
