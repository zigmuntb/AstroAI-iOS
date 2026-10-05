//
//  BirthTimeView.swift
//  AstroAI
//

import SwiftUI

struct BirthTimeView: View {
    @State private var viewModel: BirthTimeViewModel

    init(viewModel: BirthTimeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                stepRow
                titleBlock
                pickerCard
                unknownCard
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.md)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingHeader(step: 2, onBack: viewModel.back)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "CONTINUE", action: viewModel.continueTapped)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.md)
            .background(AppColor.surface)
        }
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isTimeUnknown)
    }

    private var stepRow: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Text("STEP 2 OF \(OnboardingCoordinator.steps.count)")
                    .font(AppFont.labelLarge.weight(.medium))
                    .tracking(1)
                    .foregroundStyle(AppColor.secondary)
            }
            Spacer()
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow(text: "Ascendant Degree", icon: "safari")
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColor.secondaryContainer, in: .capsule)
            ScreenTitle(
                title: "What time were you born?",
                subtitle: "Birth time sets your Rising sign and the houses of your chart. Without it, those stay approximate."
            )
        }
    }

    private var pickerCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Circle().fill(AppColor.secondary).frame(width: 6, height: 6)
                Text("SELECTED MERIDIAN TIME")
                    .font(AppFont.labelMedium)
                    .tracking(1)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                Spacer()
                Text(viewModel.displayTime)
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.primary)
                    .contentTransition(.numericText())
            }

            DatePicker("Birth time", selection: $viewModel.exactTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.md))
                .disabled(viewModel.isTimeUnknown)
                .opacity(viewModel.isTimeUnknown ? 0.4 : 1)

            HStack {
                Label("Exact birth minute", systemImage: "scope")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.onSurface)
            }
        }
        .card(.elevated, padding: Spacing.lg)
    }

    private var unknownCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Toggle(isOn: $viewModel.isTimeUnknown) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label("I don't know my exact birth time", systemImage: "questionmark.circle")
                        .font(AppFont.bodyLarge.weight(.medium))
                        .foregroundStyle(AppColor.onSurface)
                    Text("If the time is unknown, Rising sign and houses are estimated. Sun and most planet signs stay exact.")
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
            }
            .tint(AppColor.primaryContainer)

            if viewModel.isTimeUnknown {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Eyebrow(text: "Approximation Method", color: AppColor.onSurfaceVariant)
                    HStack(spacing: Spacing.sm) {
                        ForEach(BirthTimeViewModel.Approximation.allCases) { option in
                            approximationButton(option)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card(.tinted, padding: Spacing.lg)
    }

    private func approximationButton(_ option: BirthTimeViewModel.Approximation) -> some View {
        let isSelected = viewModel.approximation == option
        return Button {
            viewModel.select(option)
        } label: {
            VStack(spacing: 2) {
                Text(option.title)
                    .font(AppFont.bodySmall.weight(.medium))
                Text(viewModel.label(for: option))
                    .font(AppFont.labelMedium)
                    .foregroundStyle(isSelected ? AppColor.primaryFixed : AppColor.outline)
            }
            .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.onSurface)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isSelected ? AppColor.primaryContainer : AppColor.surface, in: .rect(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
    }
}
