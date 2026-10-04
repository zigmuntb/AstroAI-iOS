//
//  AboutYouView.swift
//  AstroAI
//

import SwiftUI

struct AboutYouView: View {
    @State private var viewModel: AboutYouViewModel

    init(viewModel: AboutYouViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                titleBlock
                PersonalContextForm(context: $viewModel.context)
                note
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingHeader(step: 6, onBack: viewModel.back)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(AppColor.secondary).frame(width: 5, height: 5)
                    Text("STEP 6 OF \(OnboardingCoordinator.steps.count)")
                        .font(AppFont.labelMedium)
                        .tracking(1.2)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
                Spacer()
                Text(viewModel.answeredCountText.uppercased())
                    .font(AppFont.labelMedium)
                    .tracking(1.2)
                    .foregroundStyle(AppColor.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColor.secondaryContainer.opacity(0.5), in: .capsule)
            }
            ScreenTitle(
                title: "Where are you in life right now?",
                subtitle: "Optional. The more the Oracle knows about your situation, the more personal its answers become."
            )
        }
    }

    private var note: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "lock")
                .foregroundStyle(AppColor.secondary)
            Text("Everything you share stays on this device and is only used by the on-device Oracle. You can change it anytime in your profile.")
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
        .card(.elevated)
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryButton(title: viewModel.continueTitle, action: viewModel.next)
            PrivacyFootnote(text: "Every question is optional")
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.surface)
    }
}
