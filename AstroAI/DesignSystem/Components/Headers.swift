//
//  Headers.swift
//  AstroAI
//

import SwiftUI

/// Avatar in the trailing toolbar. The bar supplies the 44 pt hit target.
struct ProfileToolbarButton: View {
    let action: () -> Void
    @Environment(\.userAvatar) private var avatar

    var body: some View {
        Button(action: action) {
            AvatarView(content: avatar, size: 28)
        }
        .accessibilityLabel("Profile")
    }
}

/// Onboarding header: back button, logo, segmented step progress and profile circle.
struct OnboardingHeader: View {
    /// 1-based step, `nil` hides the progress.
    let step: Int?
    var total = OnboardingCoordinator.steps.count
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            CelestialMark()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            Spacer(minLength: Spacing.sm)

            if let step {
                VStack(spacing: Spacing.xs) {
                    Text("Step \(step) of \(total)")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                    HStack(spacing: 3) {
                        ForEach(1...total, id: \.self) { index in
                            Capsule()
                                .fill(index <= step ? AppColor.primaryContainer : AppColor.outlineVariant)
                                .frame(width: 12, height: index == step ? 2 : 1.5)
                        }
                    }
                }
            }
        }
        .foregroundStyle(AppColor.onSurface)
        .padding(.horizontal, Spacing.margin)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColor.hairline.opacity(0.12)).frame(height: 0.5)
        }
    }
}

/// Eyebrow + serif headline + body subtitle used at the top of most screens.
struct ScreenTitle: View {
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: Spacing.sm) {
            if let eyebrow { Eyebrow(text: eyebrow) }
            Text(title)
                .font(AppFont.displayMobile)
                .foregroundStyle(AppColor.onSurface)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

/// Section title with optional trailing label.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.outline)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.secondary)
            }
        }
    }
}
