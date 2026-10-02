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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                stepRow
                titleBlock
                pickerCard
                unknownCard
                transparencyCard
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
                PrivacyFootnote(text: "Encrypted natal ephemeris calculation")
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
                Circle().fill(AppColor.outlineVariant).frame(width: 4, height: 4)
                Text("TEMPORAL AXIS")
                    .font(AppFont.labelMedium)
                    .tracking(1.2)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            Spacer()
            Label("UTC Ephemeris", systemImage: "clock")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColor.surfaceContainerHigh, in: .capsule)
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
                subtitle: "Your birth time helps us calculate your Ascendant (Rising sign) and precise astrological house cusps with celestial mathematical accuracy."
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
                Spacer()
                Text("TOLERANCE ±1m")
                    .font(AppFont.labelMedium)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.outline)
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
                    Text("Estimate or apply traditional solar baseline.")
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

    private var transparencyCard: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(AppColor.secondary)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Ephemeris Transparency")
                    .font(AppFont.bodyLarge.weight(.medium))
                    .tracking(0.4)
                    .foregroundStyle(AppColor.onSurface)
                Text("If exact time is unknown, we will use solar sunrise houses (06:00 AM). Your Sun and major planetary signs remain exact, while Rising sign and house boundaries will be gently approximated.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.lg))
    }
}
