//
//  Theme.swift
//  AstroAI
//
//  Almanac ink. The page is warm paper by day and night sky after dark.
//  Aubergine (day) and champagne (night) are the one action color.
//  Gold is only for marginal notes. Serif is for the reading, not the chrome.
//

import SwiftUI
import UIKit

enum AppColor {
    static let surface = adaptive(light: 0xF3EFE6, dark: 0x12141A)
    static let surfaceContainerLowest = adaptive(light: 0xFFFCF7, dark: 0x1C1E27)
    static let surfaceContainerLow = adaptive(light: 0xEFEBE2, dark: 0x181A22)
    static let surfaceContainer = adaptive(light: 0xE8E3D8, dark: 0x23262F)
    static let surfaceContainerHigh = adaptive(light: 0xE0DACE, dark: 0x2A2E38)
    static let surfaceContainerHighest = adaptive(light: 0xD6CFC2, dark: 0x343844)

    static let onSurface = adaptive(light: 0x1C1914, dark: 0xEDE6D8)
    static let onSurfaceVariant = adaptive(light: 0x514C45, dark: 0xC8BFAF, lightHigh: 0x3A342C, darkHigh: 0xE4DCCE)
    static let outline = adaptive(light: 0x6E675E, dark: 0xB3A89A, lightHigh: 0x3A342C, darkHigh: 0xE4DCCE)
    /// Rules and separators. Light 3.3:1 on the page, dark 3.8:1.
    static let outlineVariant = adaptive(light: 0x8A8174, dark: 0x6A7180)
    static let hairline = outlineVariant

    /// Symbols and links. Dark value is champagne so it stays visible on the night page.
    static let primary = adaptive(light: 0x3E3047, dark: 0xE4C992)
    /// Filled actions. Ivory text by day, ink text by night.
    static let primaryContainer = adaptive(light: 0x3E3047, dark: 0xE4C992)
    static let onPrimary = adaptive(light: 0xF7F3EA, dark: 0x1C1914)
    /// Text and marks that sit on the midnight surface, in both appearances.
    static let ivory = Color(hex: 0xF7F3EA)
    static let primaryFixed = adaptive(light: 0xE7DCEB, dark: 0x3A3228)

    /// Marginal notes. 6.5:1 on the day page, 11.5:1 at night.
    static let secondary = adaptive(light: 0x6A5124, dark: 0xE4C992, lightHigh: 0x4A3814)
    static let secondaryContainer = adaptive(light: 0xF3E2C4, dark: 0x3A3224)
    /// Ornament only. Too light to use as small text in the day appearance.
    static let champagne = adaptive(light: 0xC4A779, dark: 0xE4C992)
    static let sage = adaptive(light: 0x4E5C48, dark: 0xC5D2BE)
    static let dustyRose = adaptive(light: 0x8A4544, dark: 0xE7B4B2)
    static let midnight = adaptive(light: 0x171A2B, dark: 0x0C0E14)
    static let charcoal = adaptive(light: 0x29282B, dark: 0xEDE6D8)

    static let error = adaptive(light: 0x9B1C1C, dark: 0xFFB4AB)

    /// The moon stays a lit disc in both appearances.
    static let moonLit = adaptive(light: 0xFFFCF7, dark: 0xEDE6D8)
    static let moonShade = adaptive(light: 0x3E3047, dark: 0x2C2836)
}

enum AppFont {
    static let displayLarge = Font.system(.largeTitle, design: .serif, weight: .regular)
    static let displayMobile = Font.system(.title, design: .serif, weight: .regular)
    static let headlineLarge = Font.system(.title2, design: .serif, weight: .regular)
    static let headlineMedium = Font.system(.title3, design: .serif, weight: .medium)
    static let headlineSmall = Font.system(.headline, design: .serif, weight: .medium)
    static let quote = Font.system(.title3, design: .serif, weight: .regular).italic()

    static let bodyLarge = Font.body
    static let bodyMedium = Font.subheadline
    static let bodySmall = Font.footnote

    static let labelLarge = Font.subheadline.weight(.semibold)
    static let labelMedium = Font.caption
    /// caption2 is 11 pt at the default size, the iOS minimum, and it scales.
    static let labelSmall = Font.caption2.weight(.semibold)
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 36
    /// Gap between neighboring information blocks on a screen.
    static let block: CGFloat = 32
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

private func adaptive(light: UInt32, dark: UInt32, lightHigh: UInt32? = nil, darkHigh: UInt32? = nil) -> Color {
    Color(uiColor: UIColor { traits in
        let high = traits.accessibilityContrast == .high
        let hex: UInt32
        if traits.userInterfaceStyle == .dark {
            hex = high ? (darkHigh ?? dark) : dark
        } else {
            hex = high ? (lightHigh ?? light) : light
        }
        return UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    })
}
