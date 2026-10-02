//
//  Cards.swift
//  AstroAI
//

import SwiftUI

enum CardStyle {
    /// White card with hairline border (Layer 1).
    case elevated
    /// Tinted surface container, no border.
    case tinted
    /// Solid aubergine, ivory text.
    case accent
}

struct CardModifier: ViewModifier {
    let style: CardStyle
    var padding: CGFloat = Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: .rect(cornerRadius: Radius.lg))
            .overlay {
                if style == .elevated {
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .stroke(AppColor.hairline.opacity(0.18), lineWidth: 0.5)
                }
            }
    }

    private var background: Color {
        switch style {
        case .elevated: AppColor.surfaceContainerLowest
        case .tinted: AppColor.surfaceContainer
        case .accent: AppColor.primaryContainer
        }
    }
}

extension View {
    func card(_ style: CardStyle = .elevated, padding: CGFloat = Spacing.md) -> some View {
        modifier(CardModifier(style: style, padding: padding))
    }

    /// Standard screen background + horizontal margin for scroll content.
    func screenBackground() -> some View {
        background(AppColor.surface.ignoresSafeArea())
    }
}

/// Uppercase tracked label, e.g. "EPHEMERIS READING".
struct Eyebrow: View {
    let text: String
    var icon: String? = nil
    var color: Color = AppColor.secondary

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon { Image(systemName: icon) }
            Text(text.uppercased())
        }
        .font(AppFont.labelMedium)
        .tracking(1.2)
        .foregroundStyle(color)
    }
}

/// Small rounded tag, e.g. "Step 4 of 6" or "4 selected".
struct Pill: View {
    let text: String
    var icon: String? = nil
    var isFilled = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(AppFont.labelMedium)
        .tracking(0.6)
        .foregroundStyle(isFilled ? AppColor.onPrimary : AppColor.onSurfaceVariant)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isFilled ? AppColor.primaryContainer : AppColor.surfaceContainerHigh, in: .capsule)
    }
}

/// Fully rounded filter chip, 32pt.
struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.bodySmall.weight(.medium))
                .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.outline)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(isSelected ? AppColor.primaryContainer : AppColor.surfaceContainerLowest, in: .capsule)
                .overlay(Capsule().stroke(AppColor.hairline.opacity(isSelected ? 0 : 0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

/// Lock icon + small caption at the bottom of screens.
struct PrivacyFootnote: View {
    let text: String
    var icon = "lock"

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
            Text(text)
        }
        .font(AppFont.labelMedium)
        .foregroundStyle(AppColor.outline)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

/// Horizontal level bar used in "Somatic tendencies" and chart distributions.
struct LevelBar: View {
    let value: Double
    var color: Color = AppColor.primaryContainer

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColor.surfaceContainerHighest)
                Capsule().fill(color).frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
    }
}

/// Circular icon badge used as a leading element of rows.
struct IconBadge: View {
    let systemName: String
    var size: CGFloat = 40
    var foreground: Color = AppColor.primaryContainer
    var background: Color = AppColor.surfaceContainerHigh

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: .circle)
    }
}

/// Astrological glyph inside a circle (☉, ☽, ASC…).
struct GlyphBadge: View {
    let glyph: String
    var size: CGFloat = 40
    var foreground: Color = AppColor.primaryContainer
    var background: Color = AppColor.surfaceContainerHigh

    var body: some View {
        Text(glyph)
            .font(.system(size: size * 0.45, design: .serif))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: .circle)
    }
}

/// Full-width image cropped to a fixed height. Unlike `scaledToFill()` + `frame`,
/// it never makes the parent wider than the screen.
struct BannerImage: View {
    let name: String
    let height: CGFloat

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                Image(name)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
    }
}
