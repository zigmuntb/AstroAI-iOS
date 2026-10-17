//
//  ExploreView.swift
//  AstroAI
//

import SwiftUI

struct ExploreView: View {
    @State private var viewModel: ExploreViewModel

    init(viewModel: ExploreViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    blueprintCard
                    content
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xl)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .screenBackground()
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileToolbarButton(action: viewModel.openProfile)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search this week's sky")
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let library = viewModel.library {
            if !viewModel.transits.isEmpty {
                transitsSection(range: library.weekRange)
            }
            if viewModel.hasNoResults {
                Text("No sky events match “\(viewModel.searchText)”.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.outline)
                    .frame(maxWidth: .infinity)
            }
        } else if let error = viewModel.errorMessage {
            VStack(spacing: Spacing.md) {
                Text(error)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await viewModel.retry() } }
                    .buttonStyle(.astroSecondary)
            }
        } else {
            ProgressView()
                .tint(AppColor.primaryContainer)
                .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    // MARK: - Cosmic Blueprint entry

    private var blueprintCard: some View {
        Button(action: viewModel.openBlueprint) {
            HStack(spacing: Spacing.md) {
                NatalWheel(placements: viewModel.placements, showsSigns: false)
                    .frame(width: 64, height: 64)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Your chart")
                        .font(AppFont.headlineSmall)
                        .foregroundStyle(AppColor.onSurface)
                    Text(viewModel.blueprintLine ?? "Big Three, elemental balance and every placement.")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColor.outline)
            }
            .padding(.vertical, Spacing.sm)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Ephemeris

    private func transitsSection(range: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("This Week", icon: "clock.arrow.circlepath", trailing: range, trailingColor: AppColor.outline)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.transits.enumerated()), id: \.element.id) { index, transit in
                    if index > 0 { HairlineDivider() }
                    transitRow(transit, tone: TransitTone.allCases[index % TransitTone.allCases.count])
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    private func transitRow(_ transit: Transit, tone: TransitTone) -> some View {
        HStack(spacing: Spacing.md) {
            GlyphBadge(glyph: transit.glyph, size: 40, foreground: tone.foreground, background: tone.background)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(transit.kind)
                        .font(AppFont.labelLarge)
                        .foregroundStyle(tone.foreground)
                    Spacer()
                    Text(transit.date)
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.outline)
                }
                Text(transit.title)
                    .font(AppFont.bodyMedium.weight(.medium))
                    .foregroundStyle(AppColor.onSurface)
                    .lineLimit(1)
                Text(transit.detail)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func sectionTitle(_ title: String, icon: String, trailing: String, trailingColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppColor.primary)
            Text(title)
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
            Spacer()
            if !trailing.isEmpty {
                Text(trailing)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(trailingColor)
            }
        }
    }
}

/// Rotating badge tints for the weekly transit rows.
private enum TransitTone: CaseIterable {
    case champagne, lilac, rose

    var background: Color {
        switch self {
        case .champagne: AppColor.secondaryContainer
        case .lilac: AppColor.primaryFixed
        case .rose: AppColor.dustyRose.opacity(0.3)
        }
    }

    var foreground: Color {
        switch self {
        case .champagne: AppColor.secondary
        case .lilac: AppColor.primary
        case .rose: AppColor.dustyRose
        }
    }
}
