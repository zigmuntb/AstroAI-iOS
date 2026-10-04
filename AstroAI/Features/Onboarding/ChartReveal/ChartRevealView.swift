//
//  ChartRevealView.swift
//  AstroAI
//

import SwiftUI

struct ChartRevealView: View {
    @State private var viewModel: ChartRevealViewModel

    init(viewModel: ChartRevealViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                titleBlock
                wheel
                VStack(spacing: Spacing.sm + 4) {
                    ForEach(viewModel.bigThree) { placement in
                        BigThreeCard(placement: placement, isSelected: viewModel.selectedPlanet == placement.planet) {
                            viewModel.select(placement.planet)
                        }
                    }
                }
                synthesisCard
                archetypeCard
                actions
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingHeader(step: 8, onBack: viewModel.back)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: Spacing.sm + 4) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("YOUR NATAL ARCHITECTURE")
                    .tracking(1)
            }
            .font(AppFont.labelMedium)
            .foregroundStyle(AppColor.onSurfaceVariant)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(AppColor.surfaceContainerHigh, in: .capsule)

            Text("A first glimpse of your cosmic blueprint.")
                .font(AppFont.displayMobile)
                .foregroundStyle(AppColor.onSurface)
                .multilineTextAlignment(.center)

            Text(viewModel.calculatedFor)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var wheel: some View {
        VStack(spacing: Spacing.sm) {
            NatalWheel(
                placements: viewModel.chart.placements,
                selected: viewModel.selectedPlanet,
                showsSigns: false
            ) { viewModel.select($0) }
            HStack(spacing: 6) {
                Circle().fill(AppColor.secondary).frame(width: 5, height: 5)
                Text("TAP TRINITY GLYPHS TO INSPECT")
                    .tracking(0.8)
            }
            .font(AppFont.labelMedium)
            .foregroundStyle(AppColor.onSurfaceVariant)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(AppColor.surfaceContainerLowest, in: .capsule)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    private var synthesisCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Eyebrow(text: "AI Synthesis & Primary Tension", icon: "brain.head.profile")
            Text(viewModel.synthesis)
                .font(.system(size: 22, design: .serif).italic())
                .lineSpacing(6)
                .foregroundStyle(AppColor.onSurface)
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(AppColor.secondary).frame(width: 5, height: 5)
                    Text(viewModel.accuracyText.uppercased())
                        .tracking(0.6)
                }
                .font(AppFont.labelMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                Spacer()
                Text("Ephemeris DE441")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
        }
        .card(.tinted, padding: Spacing.lg)
    }

    private var archetypeCard: some View {
        BannerImage(name: "ExploreArchway", height: 160)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ATMOSPHERIC ARCHETYPE")
                        .font(AppFont.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(AppColor.onPrimary.opacity(0.75))
                    Text(viewModel.archetype)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(AppColor.onPrimary)
                }
                .padding(Spacing.md + 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.clear, AppColor.midnight.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                )
            }
            .clipShape(.rect(cornerRadius: Radius.lg))
            .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: Spacing.md) {
            PrimaryButton(title: "Explore my chart", action: viewModel.explore)
            Button(action: viewModel.toggleExplanation) {
                HStack(spacing: Spacing.xs) {
                    Text("See how it works")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15))
                }
            }
            .buttonStyle(.astroGhost)

            if viewModel.showsExplanation {
                Text("Your chart is computed from the exact positions of the planets at your birth moment and place. The Sun, Moon and Ascendant form your Big Three; AstroAI then synthesizes how they interact into a personal reading.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, Spacing.sm)
        .animation(.easeOut(duration: 0.2), value: viewModel.showsExplanation)
    }
}

private struct BigThreeCard: View {
    let placement: ChartRevealViewModel.KeyPlacement
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.sm + 4) {
                GlyphBadge(
                    glyph: placement.glyph,
                    size: 40,
                    foreground: AppColor.primaryContainer,
                    background: badgeBackground
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(placement.label.uppercased())
                            .font(AppFont.labelMedium)
                            .tracking(0.8)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                        Text("· \(placement.location)")
                            .font(AppFont.bodySmall.weight(.medium))
                            .foregroundStyle(AppColor.secondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text(placement.sign)
                            .font(AppFont.headlineMedium.weight(.regular))
                            .foregroundStyle(AppColor.onSurface)
                        Text(placement.degree)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                    }
                    Text(placement.quote)
                        .font(AppFont.bodyMedium.italic())
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .padding(.top, Spacing.sm)
            }
            .card(.elevated)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(AppColor.primaryContainer.opacity(isSelected ? 0.5 : 0), lineWidth: 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var badgeBackground: Color {
        switch placement.planet {
        case .sun: AppColor.primaryFixed
        case .moon: AppColor.surfaceContainerHigh
        default: AppColor.secondaryContainer
        }
    }
}
