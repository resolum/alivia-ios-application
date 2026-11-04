import SwiftUI

/// Type scale of the app (same sizes and weights as Android `core/ui/theme/Type.kt`).
enum AliviaFont {
    static let headlineMedium = Font.system(size: 26, weight: .bold)
    static let headlineSmall = Font.system(size: 22, weight: .bold)
    static let titleLarge = Font.system(size: 20, weight: .semibold)
    static let titleMedium = Font.system(size: 17, weight: .semibold)
    static let titleSmall = Font.system(size: 15, weight: .semibold)
    static let bodyLarge = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 14, weight: .regular)
    static let bodySmall = Font.system(size: 12, weight: .regular)
    static let labelLarge = Font.system(size: 16, weight: .semibold)
    static let labelMedium = Font.system(size: 13, weight: .semibold)
    static let labelSmall = Font.system(size: 11, weight: .semibold)
}
