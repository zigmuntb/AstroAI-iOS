//
//  Cards.swift
//  AstroAI
//

import SwiftUI

enum CardStyle {
    /// White card, cool border, lifted off the page.
    case elevated
    /// Gray well with a warm border, sitting in the page.
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
            .background(background, in: panelShape())
            .cardEdge(border: border, shadowOpacity: shadowOpacity)
    }

    private var background: Color {
        switch style {
        case .elevated: AppColor.surfaceContainerLowest
        case .tinted: AppColor.surfaceContainerHigh
        case .accent: AppColor.primaryContainer
        }
    }

    private var border: Color {
        switch style {
        case .elevated, .tinted: .clear
        case .accent: AppColor.champagne.opacity(0.55)
        }
    }

    /// Groups separate by fill, the way an inset list does. Shadows read as a widget stack.
    private var shadowOpacity: Double { 0 }
}

/// Visible edge shared by cards and custom panels.
struct CardEdgeModifier: ViewModifier {
    var radius: CGFloat = Radius.lg
    var border: Color = AppColor.outlineVariant
    var shadowOpacity: Double = 0.08

    func body(content: Content) -> some View {
        content
            .overlay {
                panelShape(radius).strokeBorder(border, lineWidth: 1)
            }
            .shadow(color: AppColor.primary.opacity(shadowOpacity), radius: shadowOpacity > 0 ? 12 : 0, y: shadowOpacity > 0 ? 4 : 0)
    }
}

func panelShape(_ radius: CGFloat = Radius.lg) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
}

/// Full-width rule that separates rows inside a block.
struct HairlineDivider: View {
    var inset: CGFloat = 0
    var leadingInset: CGFloat? = nil

    var body: some View {
        Rectangle()
            .fill(AppColor.outlineVariant)
            .frame(height: 1)
            .padding(.leading, leadingInset ?? inset)
            .padding(.trailing, leadingInset == nil ? inset : 0)
    }
}

extension View {
    func card(_ style: CardStyle = .elevated, padding: CGFloat = Spacing.md) -> some View {
        modifier(CardModifier(style: style, padding: padding))
    }

    func cardEdge(radius: CGFloat = Radius.lg, border: Color = AppColor.outlineVariant, shadowOpacity: Double = 0.08) -> some View {
        modifier(CardEdgeModifier(radius: radius, border: border, shadowOpacity: shadowOpacity))
    }

    /// Nested copy that should read as its own block inside a card.
    func infoWell(padding: CGFloat = Spacing.md) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surfaceContainerHigh, in: panelShape(Radius.md))
    }

    /// Standard screen background + horizontal margin for scroll content.
    func screenBackground() -> some View {
        background(AppColor.surface.ignoresSafeArea())
    }
}

/// A marginal note. Sentence case, so it reads as a caption rather than a stamped label.
struct Eyebrow: View {
    let text: String
    var icon: String? = nil
    var color: Color = AppColor.secondary

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(AppFont.labelMedium)
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
        .background(isFilled ? AppColor.primaryContainer : AppColor.surfaceContainerLowest, in: .capsule)
        .overlay {
            if !isFilled {
                Capsule().strokeBorder(AppColor.outlineVariant, lineWidth: 1)
            }
        }
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
                .font(AppFont.bodyMedium.weight(.medium))
                .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.onSurface)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(isSelected ? AppColor.primaryContainer : AppColor.surfaceContainerLowest, in: .capsule)
                .overlay(Capsule().stroke(AppColor.hairline.opacity(isSelected ? 0 : 1), lineWidth: 0.5))
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
