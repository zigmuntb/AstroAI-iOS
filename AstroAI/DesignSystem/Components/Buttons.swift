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

/// A suggested question. The filled row and send mark show that a tap posts it into the Oracle chat.
struct AskPromptButton: View {
    let question: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Spacing.md) {
                Text(question)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(AppColor.onSurface)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.onPrimary)
                    .frame(width: 32, height: 32)
                    .background(AppColor.primaryContainer, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.leading, Spacing.md)
            .padding(.trailing, Spacing.xs)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(AppColor.surfaceContainerLowest, in: panelShape(Radius.md))
            .overlay {
                panelShape(Radius.md).strokeBorder(AppColor.outlineVariant.opacity(0.55), lineWidth: 1)
            }
        }
        .buttonStyle(AskPromptButtonStyle())
        .disabled(!isEnabled)
        .accessibilityHint("Sends this question to the Oracle")
    }
}

private struct AskPromptButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(!isEnabled ? 0.45 : (configuration.isPressed ? 0.72 : 1))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
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
