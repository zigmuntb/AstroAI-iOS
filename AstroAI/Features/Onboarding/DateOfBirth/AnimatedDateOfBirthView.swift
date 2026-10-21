//
//  AnimatedDateOfBirthView.swift
//  AstroAI
//

import SwiftUI

struct AnimatedDateOfBirthView: View {
    @State private var viewModel: DateOfBirthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var displayedAngle: Double
    @State private var skyFollowsSelection = false

    init(viewModel: DateOfBirthViewModel) {
        _viewModel = State(initialValue: viewModel)
        _displayedAngle = State(initialValue: viewModel.skyAngle)
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: Spacing.sm) {
                ScreenTitle(
                    eyebrow: "Celestial Anchor",
                    title: "When did your story begin?",
                    subtitle: "Your birth date is enough for a personal daily reading. Time and place can come later."
                )

                zodiac

                GeometryReader { wheelSpace in
                    BirthDateWheels(viewModel: viewModel, height: wheelSpace.size.height)
                }
                .frame(
                    minHeight: min(260, proxy.size.height * 0.48),
                    maxHeight: proxy.size.height * 0.74
                )
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingHeader(step: 1, onBack: viewModel.back)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "Continue", action: viewModel.continueTapped)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.md)
            .background(AppColor.surface.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) {
                Rectangle().fill(AppColor.hairline.opacity(0.12)).frame(height: 0.5)
            }
        }
        .background {
            StarfieldBackground(
                angle: displayedAngle,
                animatesRotation: skyFollowsSelection && !reduceMotion,
                twinkles: skyFollowsSelection && !reduceMotion
            )
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.refreshBounds()
            displayedAngle = viewModel.skyAngle
            skyFollowsSelection = true
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refreshBounds()
        }
        .onChange(of: viewModel.skyAngle) { _, new in
            guard skyFollowsSelection else {
                displayedAngle = new
                return
            }
            displayedAngle = ShortestTurn.approach(from: displayedAngle, to: new)
        }
    }

    private var zodiac: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Text(viewModel.sunSign.glyph)
                .font(.system(size: 32, design: .serif))
                .foregroundStyle(AppColor.champagne)
                .frame(width: 52, height: 52)
                .background(Circle().stroke(AppColor.champagne.opacity(0.4), lineWidth: 0.75))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.sunSign.name)
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
                    .contentTransition(.opacity)
                Text(viewModel.sunSign.qualities)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .contentTransition(.opacity)
                Text("Moon \(viewModel.illuminationText)")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .animation(.easeInOut(duration: 0.22), value: viewModel.sunSign)
    }
}
