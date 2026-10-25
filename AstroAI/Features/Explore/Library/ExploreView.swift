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
                    if let year = viewModel.filteredYear, viewModel.showsYear {
                        yearCard(year)
                    }
                    if viewModel.showsMonth {
                        monthSection
                    }
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
        .searchable(text: $viewModel.searchText, prompt: "Search your sky")
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let library = viewModel.library {
            if !viewModel.filteredWeek.isEmpty {
                weekSection(range: library.weekRange)
            }
            if !viewModel.filteredCycles.isEmpty {
                cyclesSection
            } else if viewModel.showsLockedForecasts {
                lockedForecasts
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
                    Text(viewModel.blueprintLine ?? "What your birth details suggest, in plain language.")
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

    // MARK: - Year and month

    private func yearCard(_ year: ExploreYearCard) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(year.eyebrow.uppercased())
                    .font(AppFont.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(AppColor.secondary)
                Spacer()
                Text(year.trailing)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
            }
            Text(year.headline)
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
                .fixedSize(horizontal: false, vertical: true)
            Text(year.summary)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Go carefully")
                    .font(AppFont.labelLarge)
                    .foregroundStyle(AppColor.secondary)
                Text(year.caution)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
            }
            AstrologyDisclosure(text: year.detail)
        }
        .card(.tinted)
    }

    private var monthSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle(
                "Your Month",
                icon: "calendar",
                trailing: viewModel.timeline?.rangeLabel ?? "",
                trailingColor: AppColor.outline
            )
            Text("What may ask for your attention, and a way to meet it.")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
            if viewModel.filteredMonth.isEmpty {
                Text("Nothing exact lines up with your chart in this stretch.")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .padding(.top, Spacing.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.filteredMonth.enumerated()), id: \.element.id) { index, card in
                        if index > 0 { HairlineDivider() }
                        recommendation(card)
                    }
                }
                .padding(.top, Spacing.sm)
            }
        }
    }

    private func weekSection(range: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("This Week", icon: "clock.arrow.circlepath", trailing: range, trailingColor: AppColor.outline)
            Text("How the mood shifts, and what to do with it.")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.filteredWeek.enumerated()), id: \.element.id) { index, card in
                    if index > 0 { HairlineDivider() }
                    recommendation(card)
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    private func recommendation(_ card: ExploreCard) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            GlyphBadge(glyph: card.glyph, size: 40)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.headline)
                        .font(AppFont.bodyMedium.weight(.medium))
                        .foregroundStyle(AppColor.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Spacing.sm)
                    Text(card.when)
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.outline)
                        .multilineTextAlignment(.trailing)
                }
                Text(card.summary)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
                AstrologyDisclosure(text: card.detail)
            }
        }
        .padding(.vertical, 12)
    }

    private var cyclesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Longer chapters", icon: "clock.arrow.circlepath", trailing: "Your chart", trailingColor: AppColor.secondary)
            Text("Dates that can mark a longer theme. They do not decide what happens.")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.filteredCycles.enumerated()), id: \.element.id) { index, card in
                    if index > 0 { HairlineDivider() }
                    recommendation(card)
                }
            }
            .padding(.top, Spacing.sm)
        }
        .padding(.top, Spacing.xl)
    }

    private var lockedForecasts: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Sky forecasts", systemImage: "lock")
                .font(AppFont.labelLarge)
                .foregroundStyle(AppColor.secondary)
            Text("Longer cycles, in plain language.")
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
            Text("Membership shows upcoming dates that may matter, including eclipses and longer cycles. It does not predict what will happen.")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
            Button(action: viewModel.openPaywall) {
                Text("See longer forecasts")
            }
            .buttonStyle(.astroPrimary)
            .padding(.top, Spacing.xs)
        }
        .card(.tinted)
        .padding(.top, Spacing.xl)
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

