//
//  IntentionsView.swift
//  AstroAI
//

import SwiftUI

struct IntentionsView: View {
    @State private var viewModel: IntentionsViewModel

    init(viewModel: IntentionsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                titleBlock
                calibrationBar
                VStack(spacing: Spacing.lg) {
                    ForEach(viewModel.options) { intention in
                        IntentionRow(intention: intention, isSelected: viewModel.isSelected(intention)) {
                            viewModel.toggle(intention)
                        }
                    }
                }
                note
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingHeader(step: 5, onBack: viewModel.back)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(AppColor.secondary).frame(width: 5, height: 5)
                    Text("STEP 5 OF \(OnboardingCoordinator.steps.count)")
                        .font(AppFont.labelMedium)
                        .tracking(1.2)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
                Spacer()
                Text("ORIENTATION")
                    .font(AppFont.labelMedium)
                    .tracking(1.2)
                    .foregroundStyle(AppColor.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColor.secondaryContainer.opacity(0.5), in: .capsule)
            }
            ScreenTitle(
                title: "What are you looking for right now?",
                subtitle: "A single focus or several paths to guide your daily synthesis."
            )
        }
    }

    private var calibrationBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(AppColor.primaryContainer)
            Text("AI Calibration Active")
                .font(AppFont.bodySmall.weight(.medium))
                .tracking(0.4)
                .foregroundStyle(AppColor.onSurface)
            Spacer()
            Text(viewModel.selectedCountText)
                .font(AppFont.bodySmall.weight(.medium))
                .tracking(0.4)
                .foregroundStyle(AppColor.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 4)
        .background(AppColor.surfaceContainer, in: panelShape(Radius.md))
        .cardEdge(radius: Radius.md, shadowOpacity: 0)
    }

    private var note: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(AppColor.secondary)
            Text("Your intentions shape the focus of your daily briefing and can be revisited at any moment.")
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
        .card(.elevated)
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: "Continue", action: viewModel.next)
                .disabled(!viewModel.canContinue)
            PrivacyFootnote(text: "Encrypted & private to your device")
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.surface)
    }
}

private struct IntentionRow: View {
    let intention: Intention
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.md) {
                checkmark
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(intention.title)
                            .font(AppFont.headlineMedium.weight(.regular))
                            .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.onSurface)
                        Spacer(minLength: Spacing.sm)
                        Image(systemName: intention.symbol)
                            .font(.system(size: 14))
                            .foregroundStyle(isSelected ? AppColor.onPrimary.opacity(0.7) : AppColor.onSurfaceVariant)
                    }
                    Text(intention.subtitle)
                        .font(AppFont.bodyMedium)
                        .lineSpacing(3)
                        .foregroundStyle(isSelected ? AppColor.onPrimary.opacity(0.8) : AppColor.onSurfaceVariant)
                }
                .multilineTextAlignment(.leading)
            }
            .padding(Spacing.md + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppColor.primary : AppColor.surfaceContainerLowest, in: panelShape())
            .cardEdge(border: isSelected ? .clear : AppColor.outlineVariant, shadowOpacity: isSelected ? 0 : 0.06)
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
                .foregroundStyle(AppColor.primary)
                .frame(width: 24, height: 24)
                .background(AppColor.surfaceContainerLowest, in: .circle)
        } else {
            Circle()
                .fill(AppColor.surfaceContainerHigh)
                .frame(width: 24, height: 24)
        }
    }
}
