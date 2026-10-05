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
                AppTopBar(title: "Explore", onAvatarTap: viewModel.openProfile)

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        searchField
                        topicRail
                    }

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
        .toolbarVisibility(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let library = viewModel.library {
            if viewModel.showsFeatured {
                featuredCard(library.featured)
            }
            if !viewModel.transits.isEmpty {
                transitsSection(range: library.weekRange)
            }
            if !viewModel.tomes.isEmpty {
                compendiumSection
            }
            if viewModel.hasNoResults {
                Text("No entries match “\(viewModel.searchText)”.")
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

    // MARK: - Search & filter

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
            TextField("Search planets, houses, transits, or synastry...", text: $viewModel.searchText)
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurface)
                .submitLabel(.search)
                .autocorrectionDisabled()
        }
        .foregroundStyle(AppColor.outline)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(AppColor.surfaceContainerLowest, in: .rect(cornerRadius: Radius.sm))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private var topicRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                ForEach(ExploreViewModel.Topic.allCases) { topic in
                    Chip(title: topic.rawValue, isSelected: viewModel.selectedTopic == topic) {
                        viewModel.select(topic)
                    }
                }
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.xs)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Spacing.margin)
    }

    // MARK: - Cosmic Blueprint entry

    private var blueprintCard: some View {
        Button(action: viewModel.openBlueprint) {
            HStack(spacing: Spacing.md) {
                NatalWheel(showsSigns: false)
                    .frame(width: 64, height: 64)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Eyebrow(text: "Natal Synthesis", icon: "sparkles")
                    Text("Your Cosmic Blueprint")
                        .font(AppFont.headlineSmall)
                        .foregroundStyle(AppColor.onSurface)
                    Text("Big Three, elemental balance and every placement.")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColor.outline)
            }
            .card(.elevated)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Featured

    private func featuredCard(_ article: Article) -> some View {
        Button(action: viewModel.openFeatured) {
            VStack(alignment: .leading, spacing: 0) {
                BannerImage(name: "ExploreArchway", height: 192)
                    .overlay {
                        LinearGradient(
                            colors: [.clear, AppColor.surfaceContainerLowest.opacity(0.3), AppColor.surfaceContainerLowest],
                            startPoint: .top, endPoint: .bottom
                        )
                    }
                    .overlay(alignment: .top) {
                        HStack {
                            HStack(spacing: 6) {
                                Text(article.glyph)
                                Text(article.eyebrow.uppercased())
                            }
                            .font(AppFont.labelSmall)
                            .tracking(1.4)
                            .foregroundStyle(AppColor.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppColor.surfaceContainerLowest.opacity(0.9), in: .capsule)

                            Spacer()

                            Label(article.meta, systemImage: "clock")
                                .font(AppFont.labelSmall)
                                .foregroundStyle(AppColor.secondary)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, 3)
                                .background(AppColor.secondaryContainer.opacity(0.9), in: .capsule)
                        }
                        .padding(12)
                    }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(article.title)
                        .font(AppFont.headlineMedium)
                        .foregroundStyle(AppColor.onSurface)
                        .multilineTextAlignment(.leading)
                    Text(article.summary)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Spacer()
                        HStack(spacing: 2) {
                            Text("Read")
                            Image(systemName: "arrow.right")
                        }
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, Spacing.sm)
                    .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.sm))
                    .padding(.top, Spacing.sm)
                }
                .padding([.horizontal, .bottom], Spacing.md)
                .padding(.top, Spacing.xs)
            }
            .background(AppColor.surfaceContainerLowest, in: panelShape(Radius.md))
            .clipShape(panelShape(Radius.md))
            .cardEdge(radius: Radius.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Ephemeris

    private func transitsSection(range: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("This Week", icon: "clock.arrow.circlepath", trailing: range, trailingColor: AppColor.outline)

            VStack(spacing: Spacing.md) {
                ForEach(Array(viewModel.transits.enumerated()), id: \.element.id) { index, transit in
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
                    Text(transit.kind.uppercased())
                        .font(AppFont.labelSmall)
                        .tracking(1)
                        .foregroundStyle(tone.foreground)
                    Spacer()
                    Text(transit.date)
                        .font(AppFont.labelSmall)
                        .foregroundStyle(tone == .rose ? tone.foreground : AppColor.outline)
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

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColor.outline)
        }
        .card(.elevated, padding: 14)
    }

    // MARK: - Knowledge Compendium

    private var compendiumSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Library", icon: "book", trailing: "", trailingColor: AppColor.secondary)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.tomes.enumerated()), id: \.element.id) { index, tome in
                    if index > 0 {
                        HairlineDivider(inset: Spacing.md)
                    }
                    tomeRow(tome, accent: index.isMultiple(of: 2) ? AppColor.primary : AppColor.secondary)
                }
            }
            .card(.elevated, padding: 0)
            .padding(.top, Spacing.sm)
        }
    }

    private func tomeRow(_ tome: Article, accent: Color) -> some View {
        Button {
            viewModel.open(tome)
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                Text(tome.glyph)
                    .font(.system(size: 22, design: .serif).italic())
                    .foregroundStyle(accent)
                    .frame(width: 48, height: 48)
                    .background(AppColor.surfaceContainer, in: .rect(cornerRadius: Radius.sm))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(tome.eyebrow.uppercased())
                            .tracking(0.8)
                        Spacer(minLength: Spacing.sm)
                        Text(tome.meta)
                    }
                    .font(AppFont.labelSmall)
                    .foregroundStyle(AppColor.outline)

                    Text(tome.title)
                        .font(AppFont.headlineSmall)
                        .foregroundStyle(AppColor.onSurface)
                    Text(tome.summary)
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .lineSpacing(3)
                }
                .multilineTextAlignment(.leading)
            }
            .padding(Spacing.md)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

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

