//
//  WelcomeView.swift
//  AstroAI
//

import SwiftUI

struct WelcomeView: View {
    @State private var viewModel: WelcomeViewModel

    init(viewModel: WelcomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header

                ScreenTitle(
                    eyebrow: "Precision Celestial Intelligence",
                    title: "The stars, interpreted for you.",
                    subtitle: "Discover what your birth chart reveals about your patterns, relationships, and personal journey."
                )

                wheel
                features
                actions

                PrivacyFootnote(text: "Encrypted on-device • Zero-knowledge astrological ephemeris")
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.bottom, Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            CelestialMark().frame(width: 30, height: 30)
            Text("ASTROAI")
                .font(AppFont.labelLarge)
                .tracking(2)
            Spacer()
            Pill(text: "● EPHEMERIS 4.2")
        }
        .padding(.top, Spacing.sm)
    }

    private var wheel: some View {
        VStack(spacing: -Spacing.md) {
            NatalWheel(selected: viewModel.selectedPlanet, showsSigns: false) { viewModel.select($0) }
                .padding(.horizontal, Spacing.lg)
            Text("● Tap to inspect celestial geometry")
                .font(AppFont.labelMedium)
                .tracking(0.6)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColor.surfaceContainerLowest, in: .capsule)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    private var features: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(viewModel.features) { feature in
                VStack(spacing: Spacing.xs) {
                    Eyebrow(text: feature.eyebrow)
                    Text(feature.title)
                        .font(AppFont.headlineMedium)
                        .foregroundStyle(AppColor.onSurface)
                    Text(feature.caption)
                        .font(AppFont.labelMedium)
                        .tracking(0.6)
                        .foregroundStyle(AppColor.outline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.md))
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.md) {
            PrimaryButton(title: "Begin your journey", action: viewModel.begin)
            Button("I already have an account", action: viewModel.signIn)
                .font(AppFont.bodyLarge.weight(.medium))
                .foregroundStyle(AppColor.primary)
        }
    }
}
