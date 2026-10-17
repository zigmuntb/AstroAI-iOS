//
//  Buttons.swift
//  AstroAI
//

import SwiftUI

/// Solid aubergine CTA, 50pt high. Use with `Label` or `Text`.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(AppColor.onPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppColor.primaryContainer.opacity(isEnabled ? 1 : 0.4), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Translucent aubergine tint with hairline border.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.labelLarge)
            .foregroundStyle(AppColor.primary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(AppColor.surfaceContainerHighest, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Borderless serif italic link with a trailing arrow.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.quote)
            .foregroundStyle(AppColor.secondary)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var astroPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var astroSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == GhostButtonStyle {
    static var astroGhost: GhostButtonStyle { GhostButtonStyle() }
}

/// "Continue →" primary button used at the bottom of most screens.
struct PrimaryButton: View {
    let title: String
    var icon: String? = "arrow.right"
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView().tint(AppColor.onPrimary)
                } else {
                    Text(title)
                    if let icon { Image(systemName: icon) }
                }
            }
        }
        .buttonStyle(.astroPrimary)
    }
}
