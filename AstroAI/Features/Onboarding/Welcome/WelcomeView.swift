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
            VStack(alignment: .leading, spacing: Spacing.block) {
                header

                ScreenTitle(
                    eyebrow: "Precision Celestial Intelligence",
                    title: "The stars, interpreted for you.",
                    subtitle: "Discover what your birth chart reveals about your patterns, relationships, and personal journey."
                )

                wheel
                promise
                actions
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

    private var promise: some View {
        Text("A birth chart, the day’s sky, and the people in it. Calculated on this iPhone.")
            .font(AppFont.bodyLarge)
            .foregroundStyle(AppColor.onSurfaceVariant)
            .fixedSize(horizontal: false, vertical: true)
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
