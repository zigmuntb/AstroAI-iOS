//
//  Headers.swift
//  AstroAI
//

import SwiftUI

/// Top bar of main tab screens: "✦ Title   ∞  (avatar)".
struct AppTopBar: View {
    let title: String
    var onAvatarTap: (() -> Void)? = nil

    @Environment(\.userAvatar) private var avatar

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 18))
            Text(title)
                .font(AppFont.headlineMedium)
            Spacer()
            Image(systemName: "infinity")
                .font(.system(size: 18))
                .padding(.trailing, Spacing.sm)
            Button {
                onAvatarTap?()
            } label: {
                AvatarView(content: avatar, size: 32)
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(AppColor.onSurface)
        .padding(.horizontal, Spacing.margin)
        .padding(.vertical, Spacing.sm)
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
                        .frame(width: 32, height: 44)
                }
                .buttonStyle(.plain)
            }
            CelestialMark()
                .frame(width: 30, height: 30)
            Text("AstroAI")
                .font(AppFont.headlineMedium)

            Spacer(minLength: Spacing.sm)

            if let step {
                VStack(spacing: Spacing.xs) {
                    Text("STEP \(step) OF \(total)")
                        .font(AppFont.labelMedium)
                        .tracking(1)
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

            Image(systemName: "person")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColor.onPrimary)
                .frame(width: 32, height: 32)
                .background(AppColor.primary, in: .circle)
                .padding(.leading, Spacing.xs)
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
