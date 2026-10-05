//
//  InterestsView.swift
//  AstroAI
//

import SwiftUI

struct InterestsView: View {
    @State private var viewModel: InterestsViewModel

    init(viewModel: InterestsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                titleBlock
                resonanceCard
                options
                quote
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingHeader(step: 4, onBack: viewModel.back)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Eyebrow(text: "Attunement")
                Spacer()
                Pill(text: "Step 4 of \(OnboardingCoordinator.steps.count)")
            }
            ScreenTitle(
                title: "What would you like clarity about?",
                subtitle: "Your experience should reflect what matters to you. Choose as many as you wish."
            )
        }
    }

    private var resonanceCard: some View {
        HStack(spacing: Spacing.md) {
            IconBadge(systemName: "sparkles", size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("ALGORITHMIC RESONANCE")
                    .font(AppFont.labelMedium)
                    .tracking(1)
                    .foregroundStyle(AppColor.onSurface)
                Text("Fine-tuning natal ephemeris & transit priorities")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineLimit(1)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.surfaceContainerLow, AppColor.secondaryContainer.opacity(0.25)],
                startPoint: .leading, endPoint: .trailing
            ),
            in: .rect(cornerRadius: Radius.lg)
        )
        .cardEdge()
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("AREAS OF INQUEST")
                    .font(AppFont.labelMedium)
                    .tracking(1.2)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                Spacer()
                Pill(text: viewModel.selectedCountText, isFilled: true)
            }
            .padding(.bottom, Spacing.xs)

            VStack(spacing: Spacing.lg) {
                ForEach(viewModel.options) { interest in
                    InterestRow(interest: interest, isSelected: viewModel.isSelected(interest)) {
                        viewModel.toggle(interest)
                    }
                }
            }
        }
    }

    private var quote: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "camera.macro")
                .foregroundStyle(AppColor.secondary)
                .padding(.top, 4)
            Text("“The stars do not compel; they merely incline. Your intent shapes the mirror.”")
                .font(AppFont.quote)
                .foregroundStyle(AppColor.secondary)
        }
        .card(.tinted, padding: Spacing.lg)
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: "Continue", action: viewModel.next)
                .disabled(!viewModel.canContinue)
            Text("You can reconfigure your attunement focus at any moment in Settings.")
                .font(AppFont.labelMedium)
                .tracking(0.6)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(AppColor.surface)
    }
}

private struct InterestRow: View {
    let interest: Interest
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                IconBadge(
                    systemName: interest.symbol,
                    size: 44,
                    foreground: isSelected ? AppColor.onPrimary : AppColor.primaryContainer,
                    background: isSelected ? AppColor.onPrimary.opacity(0.15) : AppColor.surfaceContainerHigh
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(interest.title)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.onSurface)
                    Text(interest.subtitle)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(isSelected ? AppColor.onPrimary.opacity(0.8) : AppColor.onSurfaceVariant)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: Spacing.sm)
                checkmark
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? AppColor.primaryContainer : AppColor.surfaceContainerLowest,
                in: panelShape(Radius.md)
            )
            .cardEdge(radius: Radius.md, border: isSelected ? .clear : AppColor.outlineVariant, shadowOpacity: isSelected ? 0 : 0.06)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var checkmark: some View {
        if isSelected {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColor.primaryContainer)
                .frame(width: 30, height: 30)
                .background(AppColor.surfaceContainerLowest, in: .circle)
        } else {
            Circle()
                .fill(AppColor.surfaceContainerHigh)
                .frame(width: 30, height: 30)
        }
    }
}
