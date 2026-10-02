//
//  Theme.swift
//  AstroAI
//
//  Tokens from the Stitch "AstroAI Design System".
//  Newsreader → system serif (New York), Inter → system sans (SF Pro).
//

import SwiftUI

enum AppColor {
    static let surface = Color(hex: 0xFCF8FC)
    static let surfaceContainerLowest = Color.white
    static let surfaceContainerLow = Color(hex: 0xF7F2F6)
    static let surfaceContainer = Color(hex: 0xF1EDF0)
    static let surfaceContainerHigh = Color(hex: 0xEBE7EB)
    static let surfaceContainerHighest = Color(hex: 0xE5E1E5)

    static let onSurface = Color(hex: 0x1C1B1E)
    static let onSurfaceVariant = Color(hex: 0x4A454C)
    static let outline = Color(hex: 0x7B757C)
    static let outlineVariant = Color(hex: 0xCCC4CC)
    static let hairline = Color(hex: 0x89847F)

    static let primary = Color(hex: 0x3E3047)
    static let primaryContainer = Color(hex: 0x55465F)   // Aubergine
    static let onPrimary = Color(hex: 0xF5F1E9)          // Warm Ivory
    static let primaryFixed = Color(hex: 0xF0DBFA)

    static let secondary = Color(hex: 0x725B33)
    static let secondaryContainer = Color(hex: 0xFBDBA9)
    static let champagne = Color(hex: 0xC4A779)          // Antique Champagne
    static let sage = Color(hex: 0xA7B4A0)
    static let dustyRose = Color(hex: 0xC99B9A)
    static let midnight = Color(hex: 0x171A2B)
    static let charcoal = Color(hex: 0x29282B)

    static let error = Color(hex: 0xBA1A1A)
}

enum AppFont {
    static let displayLarge = Font.system(size: 40, weight: .regular, design: .serif)
    static let displayMobile = Font.system(size: 32, weight: .regular, design: .serif)
    static let headlineLarge = Font.system(size: 28, weight: .regular, design: .serif)
    static let headlineMedium = Font.system(size: 22, weight: .medium, design: .serif)
    static let headlineSmall = Font.system(size: 19, weight: .medium, design: .serif)
    static let quote = Font.system(size: 19, weight: .regular, design: .serif).italic()

    static let bodyLarge = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)

    static let labelLarge = Font.system(size: 13, weight: .semibold)
    static let labelMedium = Font.system(size: 11, weight: .medium)
    static let labelSmall = Font.system(size: 9, weight: .semibold)
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 36
    /// Horizontal screen margin.
    static let margin: CGFloat = 20
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
