//
//  DateOfBirthView.swift
//  AstroAI
//

import SwiftUI

struct DateOfBirthView: View {
    @State private var viewModel: DateOfBirthViewModel

    init(viewModel: DateOfBirthViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                stepRow

                ScreenTitle(
                    eyebrow: "Celestial Anchor",
                    title: "When did your story begin?",
                    subtitle: "Your birth date helps us build the foundation of your personal chart."
                )

                pickerCard
                mechanicsCard
                insightCards
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.md)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingHeader(step: 1, onBack: viewModel.back)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "Continue", action: viewModel.continueTapped)
                PrivacyFootnote(text: "EPHEMERIS DATA PROCESSED ON-DEVICE")
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.md)
            .background(AppColor.surface)
        }
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var stepRow: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Text("STEP 1 OF \(OnboardingCoordinator.steps.count)")
                    .font(AppFont.labelLarge.weight(.regular))
                    .tracking(1)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                Circle().fill(AppColor.secondary).frame(width: 5, height: 5)
            }
            Spacer()
            Eyebrow(text: "Initiation", icon: "sparkles")
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColor.surfaceContainerHigh, in: .capsule)
        }
    }

    private var pickerCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Label("NATAL INSCRIPTION", systemImage: "calendar")
                    .font(AppFont.labelLarge)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.onSurface)
                Spacer()
                signPill
            }

            DatePicker(
                "Birth date",
                selection: $viewModel.birthDate,
                in: ...viewModel.latestDate,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .background(AppColor.surfaceContainerLowest, in: .rect(cornerRadius: Radius.sm))

            HStack {
                Circle().fill(AppColor.champagne).frame(width: 6, height: 6)
                Text("Solar Alignment")
                    .font(AppFont.bodySmall)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                Spacer()
                Text("\(viewModel.sunSign.glyph) \(viewModel.sunSign.name)")
                    .font(AppFont.bodySmall.weight(.medium))
                    .foregroundStyle(AppColor.onSurface)
            }
            .padding(.horizontal, Spacing.xs)
        }
        .card(.elevated, padding: Spacing.md)
    }

    private var signPill: some View {
        HStack(spacing: Spacing.xs) {
            Text(viewModel.sunSign.glyph)
            Text(viewModel.sunSign.name.uppercased())
                .tracking(0.8)
        }
        .font(AppFont.labelLarge.weight(.medium))
        .foregroundStyle(AppColor.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppColor.surfaceContainerLow, in: .capsule)
        .contentTransition(.opacity)
        .animation(.easeInOut, value: viewModel.sunSign)
    }

    private var mechanicsCard: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            IconBadge(
                systemName: "info.circle",
                size: 28,
                foreground: AppColor.secondary,
                background: AppColor.secondaryContainer
            )
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Eyebrow(text: "Cosmic Mechanics")
                Text("Determines the exact solar degree, lunar phase, and foundational planetary alignments of your birth.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
        }
        .card(.tinted)
    }

    private var insightCards: some View {
        HStack(spacing: Spacing.sm) {
            insightCard(
                icon: "moon",
                label: "Moon Phase",
                title: viewModel.moonPhase.name,
                caption: viewModel.illuminationText
            )
            insightCard(
                icon: "safari",
                label: "Solar House",
                title: viewModel.sunSign.solarHouseName,
                caption: viewModel.sunSign.solarHouseTheme
            )
        }
    }

    private func insightCard(icon: String, label: String, title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow(text: label, icon: icon, color: AppColor.onSurfaceVariant)
            Text(title)
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(caption)
                .font(AppFont.labelMedium)
                .tracking(0.6)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(.tinted, padding: Spacing.md)
    }
}
