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
            VStack(alignment: .leading, spacing: Spacing.block) {
                blueprintCard
                if let year = viewModel.filteredYear, viewModel.showsYear {
                    yearReading(year)
                }
                if viewModel.showsMonth {
                    monthSection
                }
                feed
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background {
            ZStack {
                AppColor.surface
                ExploreSkyBackdrop()
            }
            .ignoresSafeArea()
        }
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

    private var showsFeed: Bool {
        !viewModel.filteredWeek.isEmpty
            || !viewModel.filteredCycles.isEmpty
            || viewModel.showsLockedForecasts
            || viewModel.hasNoResults
    }

    @ViewBuilder
    private var feed: some View {
        if let library = viewModel.library {
            if showsFeed {
                VStack(alignment: .leading, spacing: Spacing.block) {
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
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else if let error = viewModel.errorMessage {
            VStack(spacing: Spacing.md) {
                Text(error)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again") { Task { await viewModel.retry() } }
                    .buttonStyle(.astroSecondary)
            }
            .frame(maxWidth: .infinity)
        } else {
            ProgressView()
                .tint(AppColor.primaryContainer)
                .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    // MARK: - Chart

    private var blueprintCard: some View {
        Button(action: viewModel.openBlueprint) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ViewThatFits(in: .horizontal) {
                    blueprintRow(stacked: false)
                    blueprintRow(stacked: true)
                }
                HairlineDivider()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func blueprintRow(stacked: Bool) -> some View {
        let copy = VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Your chart")
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
            Text(viewModel.blueprintLine ?? "What your birth details suggest, in plain language.")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }

        return Group {
            if stacked {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    chartWheel
                    HStack(alignment: .center, spacing: Spacing.md) {
                        copy
                        Spacer(minLength: 0)
                        chartChevron
                    }
                }
            } else {
                HStack(alignment: .center, spacing: Spacing.md) {
                    chartWheel
                    copy
                    Spacer(minLength: Spacing.sm)
                    chartChevron
                }
            }
        }
    }

    private var chartWheel: some View {
        NatalWheel(placements: viewModel.placements, showsSigns: false)
            .frame(width: 64, height: 64)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var chartChevron: some View {
        Image(systemName: "chevron.right")
            .font(.body.weight(.semibold))
            .foregroundStyle(AppColor.outline)
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)
    }

    // MARK: - Year

    private func yearReading(_ year: ExploreYearCard) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(year.eyebrow.uppercased())
                    .font(AppFont.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(AppColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.sm)
                Text(year.trailing)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(year.headline)
                .font(AppFont.headlineMedium)
                .foregroundStyle(AppColor.onSurface)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHeading(.h2)
            ExploreProseBlock(summary: year.summary)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Go carefully")
                    .font(AppFont.labelLarge)
                    .foregroundStyle(AppColor.secondary)
                Text(year.caution)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurface)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            AstrologyDisclosure(text: year.detail)
        }
    }

    // MARK: - Sections

    private var monthSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ExploreChapterHeader(
                title: "Your Month",
                trailing: viewModel.timeline?.rangeLabel ?? "",
                note: "What may ask for your attention, and a way to meet it."
            )
            if viewModel.filteredMonth.isEmpty {
                Text("Nothing exact lines up with your chart in this stretch.")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ExploreEntryList(cards: viewModel.filteredMonth, span: .month)
            }
        }
    }

    private func weekSection(range: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ExploreChapterHeader(
                title: "This Week",
                trailing: range,
                note: "How the mood shifts, and what to do with it."
            )
            ExploreEntryList(cards: viewModel.filteredWeek, span: .week)
        }
    }

    private var cyclesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ExploreChapterHeader(
                title: "Longer chapters",
                trailing: "Your chart",
                note: "Dates that can mark a longer theme. They do not decide what happens."
            )
            ExploreEntryList(cards: viewModel.filteredCycles, span: .chapter)
        }
    }

    private var lockedForecasts: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Sky forecasts", systemImage: "lock")
                .font(AppFont.labelLarge)
                .foregroundStyle(AppColor.secondary)
            Text("Longer cycles, in plain language.")
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
                .fixedSize(horizontal: false, vertical: true)
            Text("Membership shows upcoming dates that may matter, including eclipses and longer cycles. It does not predict what will happen.")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: viewModel.openPaywall) {
                Text("See longer forecasts")
            }
            .buttonStyle(.astroPrimary)
            .padding(.top, Spacing.xs)
        }
        .card(.tinted)
    }
}

// MARK: - Chapter header

private struct ExploreChapterHeader: View {
    let title: String
    var trailing: String = ""
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                headerLine(stacked: false)
                headerLine(stacked: true)
            }
            Capsule()
                .fill(AppColor.secondary)
                .frame(width: 28, height: 2)
                .accessibilityHidden(true)
            Text(note)
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func headerLine(stacked: Bool) -> some View {
        let titleText = Text(title)
            .font(AppFont.headlineSmall)
            .foregroundStyle(AppColor.onSurface)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHeading(.h2)
        let range = Text(trailing)
            .font(AppFont.labelMedium)
            .foregroundStyle(AppColor.outline)
            .multilineTextAlignment(stacked ? .leading : .trailing)
            .fixedSize(horizontal: false, vertical: true)

        return Group {
            if stacked {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    titleText
                    if !trailing.isEmpty { range }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    titleText
                    Spacer(minLength: Spacing.md)
                    if !trailing.isEmpty { range }
                }
            }
        }
    }
}

// MARK: - Entries

private extension String {
    /// Zodiac signs default to a color emoji. The selector keeps them in the same ink as the type.
    var astroInk: String { self + "\u{FE0E}" }
}

private enum ExploreSpan {
    case week
    case month
    case chapter

    var verticalPadding: CGFloat {
        switch self {
        case .week: 12
        case .month: 18
        case .chapter: 26
        }
    }

    /// Longer chapters use a slightly larger margin glyph. The glyph itself is the type marker.
    var glyphScale: CGFloat {
        switch self {
        case .week, .month: 1
        case .chapter: 1.18
        }
    }
}

private struct ExploreEntryList: View {
    let cards: [ExploreCard]
    let span: ExploreSpan
    var expandsDetail = false

    @ScaledMetric(relativeTo: .headline) private var glyphColumn: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                if index > 0 {
                    HairlineDivider(leadingInset: glyphColumn + Spacing.md)
                }
                ExploreEntry(card: card, span: span, expandsDetail: expandsDetail)
            }
        }
    }
}

private struct ExploreEntry: View {
    let card: ExploreCard
    let span: ExploreSpan
    var expandsDetail = false

    @ScaledMetric(relativeTo: .headline) private var glyphSize: CGFloat = 22
    @ScaledMetric(relativeTo: .headline) private var glyphColumn: CGFloat = 36

    private var prominentPhase: Bool {
        span == .week && card.glyph == "☽"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(card.glyph.astroInk)
                .font(.system(size: glyphSize * span.glyphScale * (prominentPhase ? 1.12 : 1), weight: .medium, design: .serif))
                .foregroundStyle(AppColor.primary)
                .frame(width: glyphColumn, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(card.headline)
                        .font(AppFont.headlineSmall)
                        .foregroundStyle(AppColor.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHeading(.h3)
                    if !card.when.isEmpty {
                        Text(card.when)
                            .font(AppFont.labelMedium)
                            .foregroundStyle(AppColor.outline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !card.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ExploreProseBlock(summary: card.summary)
                        .padding(.top, Spacing.xs)
                }
                AstrologyDisclosure(text: card.detail, initiallyExpanded: expandsDetail)
            }
        }
        .padding(.vertical, span.verticalPadding)
    }
}

// MARK: - Prose

/// Splits a recommendation into the practical point and the lines that support it.
private enum ExploreProse {
    static func sentences(in text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var result: [String] = []
        var start = trimmed.startIndex
        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let character = trimmed[index]
            if ".!?".contains(character) {
                let next = trimmed.index(after: index)
                let boundary = next == trimmed.endIndex || trimmed[next].isWhitespace
                if boundary {
                    let sentence = trimmed[start...index].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sentence.isEmpty {
                        result.append(sentence)
                    }
                    start = next
                }
            }
            index = trimmed.index(after: index)
        }
        let tail = trimmed[start...].trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            result.append(tail)
        }
        return result
    }

    static func isCareful(_ sentence: String) -> Bool {
        let lowered = sentence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowered.hasPrefix("don't") || lowered.hasPrefix("don’t") || lowered.hasPrefix("do not")
    }
}

private struct ExploreProseBlock: View {
    let summary: String

    var body: some View {
        let sentences = ExploreProse.sentences(in: summary)
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let lead = sentences.first {
                Text(lead)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(AppColor.onSurface)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if sentences.count > 1 {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(Array(sentences.dropFirst().enumerated()), id: \.offset) { _, line in
                        ExploreSupportLine(text: line)
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
    }
}

private struct ExploreSupportLine: View {
    let text: String

    private var careful: Bool { ExploreProse.isCareful(text) }

    var body: some View {
        Text(text)
            .font(AppFont.bodyMedium)
            .foregroundStyle(careful ? AppColor.onSurface : AppColor.onSurfaceVariant)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, careful ? 12 : 0)
            .background(alignment: .leading) {
                if careful {
                    Rectangle()
                        .fill(AppColor.secondary)
                        .frame(width: 2)
                        .padding(.vertical, 2)
                        .accessibilityHidden(true)
                }
            }
            .padding(.top, careful ? Spacing.xs : 0)
    }
}

#Preview("Night") {
    NavigationStack {
        ExploreLayoutPreview()
    }
    .preferredColorScheme(.dark)
}

#Preview("Day") {
    NavigationStack {
        ExploreLayoutPreview()
    }
    .preferredColorScheme(.light)
}

private struct ExploreLayoutPreview: View {
    var expandsDetail = false
    var scrolls = true

    var body: some View {
        Group {
            if scrolls {
                ScrollView { column }
            } else {
                column
            }
        }
        .background {
            ZStack {
                AppColor.surface
                ExploreSkyBackdrop()
            }
            .ignoresSafeArea()
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("YEAR AHEAD")
                            .font(AppFont.labelSmall)
                            .tracking(1.2)
                            .foregroundStyle(AppColor.secondary)
                        Spacer()
                        Text("Until Mar 21")
                            .font(AppFont.labelMedium)
                            .foregroundStyle(AppColor.outline)
                    }
                    Text("A year for one close relationship")
                        .font(AppFont.headlineMedium)
                        .foregroundStyle(AppColor.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                    ExploreProseBlock(summary: "Put the effort into one close relationship. Ask for a specific change, and leave the rest of the history for later. The pace comes from conversations and decisions. Write the agreement down before you accept it.")
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Go carefully")
                            .font(AppFont.labelLarge)
                            .foregroundStyle(AppColor.secondary)
                        Text("Don't try to settle the whole relationship in one conversation.")
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(AppColor.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    AstrologyDisclosure(
                        text: "Astrologers count each year of life as one area of the chart. This year that area is the 7th house. This is an interpretation of the year, not a promise about what will happen.",
                        initiallyExpanded: expandsDetail
                    )
                }
                ExploreChapterHeader(
                    title: "Your Month",
                    trailing: "Oct 25 — Nov 24",
                    note: "What may ask for your attention, and a way to meet it."
                )
                ExploreEntryList(cards: ExploreLayoutPreview.samples, span: .month, expandsDetail: expandsDetail)
                ExploreChapterHeader(
                    title: "This Week",
                    trailing: "Oct 25 — Oct 31",
                    note: "How the mood shifts, and what to do with it."
                )
                ExploreEntryList(cards: [ExploreLayoutPreview.phase, ExploreLayoutPreview.ingress], span: .week)
                ExploreChapterHeader(
                    title: "Longer chapters",
                    trailing: "Your chart",
                    note: "Dates that can mark a longer theme. They do not decide what happens."
                )
                ExploreEntryList(cards: [ExploreLayoutPreview.chapter], span: .chapter)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.lg)
    }

    static let samples: [ExploreCard] = [
        ExploreCard(
            id: "short",
            glyph: "♀",
            when: "Mon, Oct 27, 9:40 AM",
            headline: "An easier warmth in closeness",
            summary: "Warmth is a little easier to offer and to receive. Plan one ordinary hour together, and leave the rest of the week alone.",
            detail: "Venus in the sky trines your Moon. Venus is associated with affection. This is an interpretation, not a prediction."
        ),
        ExploreCard(
            id: "long",
            glyph: "♂",
            when: "Friday, October 31, 2:14 PM",
            headline: "Extra heat in a close relationship that has already been on your mind",
            summary: "Closeness may feel more sensitive than the facts deserve. Ask one plain question before you decide what a silence means. Ask for one thing that would feel better, without making it a test of the relationship. With someone close, ask one question. Do not try to settle the relationship in a single talk. Don't treat a quiet mood as proof that a relationship is failing.",
            detail: "Mars in the sky squares your Venus around Friday, October 31. Mars is associated with drive and heat. The contact falls in the part of life about a close relationship. This describes a mood to work with. It does not decide what the other person will do."
        )
    ]

    static let phase = ExploreCard(
        id: "phase",
        glyph: "☽",
        when: "Wed, Oct 28",
        headline: "A quieter point in the month",
        summary: "Feelings may be easier to notice than to explain. Pay special attention to home and the people you come from. Don't make a lasting decision from a passing feeling.",
        detail: "Full Moon in Taurus around Wednesday. This describes the mood of the month. It does not decide an outcome."
    )

    static let ingress = ExploreCard(
        id: "ingress",
        glyph: "♏",
        when: "Thu, Oct 29",
        headline: "A more private mood",
        summary: "You may want fewer people around and a clearer sense of what is yours. This is most likely to color conversations and learning.",
        detail: "The Moon enters Scorpio. That is read as a shift in tone, not as something that has to happen."
    )

    static let chapter = ExploreCard(
        id: "chapter",
        glyph: "☉",
        when: "Feb 17, 2027",
        headline: "A turning point worth noticing",
        summary: "A rare quiet point in the month can mark a turning point around the work other people can see. Use it to finish one visible piece, not to announce a new direction. Don't quit a responsibility on the strength of the feeling alone.",
        detail: "A solar eclipse is a new moon aligned so that the Moon passes in front of the Sun. An eclipse highlights a theme. It does not force an ending or a beginning."
    )
}
