//
//  NameView.swift
//  AstroAI
//

import SwiftUI

struct NameView: View {
    @State private var viewModel: NameViewModel
    @FocusState private var isFieldFocused: Bool

    init(viewModel: NameViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                stepRow

                ScreenTitle(
                    eyebrow: "Personal Signature",
                    title: "What should we call you?",
                    subtitle: "Your name personalizes your daily synthesis and conversations with the AI Oracle."
                )

                nameField
                previewCard
                mechanicsCard
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.md)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingHeader(step: 7, onBack: viewModel.back)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "Continue", action: viewModel.continueTapped)
                    .disabled(!viewModel.canContinue)
                PrivacyFootnote(text: "Stored privately on your device")
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.md)
            .background(AppColor.surface)
        }
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onAppear { isFieldFocused = true }
    }

    private var stepRow: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Text("STEP 7 OF \(OnboardingCoordinator.steps.count)")
                    .font(AppFont.labelLarge.weight(.regular))
                    .tracking(1)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                Circle().fill(AppColor.secondary).frame(width: 5, height: 5)
            }
            Spacer()
            Eyebrow(text: "Identity", icon: "signature")
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColor.surfaceContainerHigh, in: .capsule)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label("FULL OR CHOSEN NAME", systemImage: "person.text.rectangle")
                    .font(AppFont.labelLarge)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.onSurface)
                Spacer()
                Text(viewModel.counterText)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
                    .monospacedDigit()
            }

            HStack(spacing: Spacing.md) {
                TextField("e.g. Elena", text: $viewModel.name)
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused($isFieldFocused)
                    .onSubmit(viewModel.continueTapped)

                if !viewModel.name.isEmpty {
                    Button { viewModel.name = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColor.onSurfaceVariant)
                            .frame(width: 28, height: 28)
                            .background(AppColor.surfaceContainerHigh, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear name")
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: 56)
            .background(AppColor.surfaceContainerLowest, in: .rect(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isFieldFocused ? AppColor.champagne : AppColor.outlineVariant, lineWidth: isFieldFocused ? 1.5 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFieldFocused)
        }
        .card(.elevated, padding: Spacing.md)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow(text: "Morning Preview", icon: "sun.horizon")
            Text(viewModel.greetingPreview)
                .font(AppFont.headlineLarge)
                .foregroundStyle(AppColor.onSurface)
                .contentTransition(.opacity)
                .animation(.easeInOut, value: viewModel.greetingPreview)
            Text("This is how your daily reading will greet you.")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
        .card(.elevated)
    }

    private var mechanicsCard: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            IconBadge(
                systemName: "lock",
                size: 28,
                foreground: AppColor.secondary,
                background: AppColor.secondaryContainer
            )
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Eyebrow(text: "Context Anonymization")
                Text("Your name stays on this device. AI Oracle queries strip names and identity markers before synthesis.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
        }
        .card(.tinted)
    }
}
