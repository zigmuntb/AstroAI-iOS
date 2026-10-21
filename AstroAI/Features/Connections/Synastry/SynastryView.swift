//
//  SynastryView.swift
//  AstroAI
//

import SwiftUI

struct SynastryView: View {
    @State private var viewModel: SynastryViewModel
    @Environment(\.isSanctuaryMember) private var isSanctuaryMember

    init(viewModel: SynastryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                recordHeader
                pairHeader

                if let report = viewModel.report {
                    if let guide = viewModel.guide {
                        compatibilitySection(guide.compatibility)
                        todaySection(guide.today)
                    }
                    if let week = viewModel.week {
                        weekSection(week)
                    }
                    personColumns
                    topology(report)
                    compositeSection(report)
                    dimensions(report)
                    inquiries(report)
                    artifact(report)
                } else if let error = viewModel.errorMessage {
                    errorState(error)
                } else {
                    ProgressView()
                        .tint(AppColor.primaryContainer)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refreshPhoto() }
        .task { await viewModel.load() }
    }

    // MARK: - Header

    private var recordHeader: some View {
        HStack {
            HStack(spacing: Spacing.xs) {
                Eyebrow(text: "The two of you")
            }
            Spacer()
            Button(action: viewModel.addConnection) {
                Label("Add Connection", systemImage: "plus")
                    .font(AppFont.labelLarge)
                    .foregroundStyle(AppColor.onSurface)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(AppColor.surfaceContainerLowest, in: .capsule)
                    .overlay(Capsule().stroke(AppColor.hairline.opacity(0.3), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, Spacing.sm)
    }

    private var pairHeader: some View {
        HStack(spacing: Spacing.md) {
            HStack(spacing: -12) {
                AvatarView(content: viewModel.userAvatar, size: 44)
                    .overlay(Circle().stroke(AppColor.surface, lineWidth: 2))
                PartnerInitial(name: viewModel.partnerName, size: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.title)
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
                    .lineLimit(1)
                Text(viewModel.pairSubtitle)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .card(.tinted, padding: 12)
    }

    private func compatibilitySection(_ compatibility: PairCompatibility) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Compatibility")
            HStack(alignment: .top, spacing: Spacing.sm) {
                ForEach(compatibility.counts) { count in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(count.value)")
                            .font(AppFont.headlineMedium)
                            .foregroundStyle(AppColor.onSurface)
                        Text(count.title)
                            .font(AppFont.labelSmall)
                            .foregroundStyle(AppColor.outline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            ForEach(compatibility.facts) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.title.uppercased())
                        .font(AppFont.labelSmall)
                        .tracking(0.6)
                        .foregroundStyle(AppColor.outline)
                    Text(fact.value)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = fact.detail {
                        Text(detail)
                            .font(AppFont.bodySmall)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
        .card(.tinted)
    }

    private func todaySection(_ today: PairToday) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Today", trailing: today.dateLabel)
            Text(today.skyLine)
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
            if let moonLine = today.moonLine {
                Text(moonLine)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !today.items.isEmpty {
                HairlineDivider()
                ForEach(today.items) { item in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        GlyphBadge(glyph: item.glyph, size: 40)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(item.title)
                                .font(AppFont.bodyMedium.weight(.medium))
                                .foregroundStyle(AppColor.onSurface)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.text)
                                .font(AppFont.bodySmall)
                                .foregroundStyle(AppColor.onSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                            AstrologyDisclosure(title: "Why this shows up", text: item.basis)
                        }
                    }
                }
            }
        }
        .card(.tinted)
    }

    private func weekSection(_ week: RelationshipWeek) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "This Week", trailing: week.rangeLabel)
            ForEach(week.beats) { beat in
                HStack(alignment: .top, spacing: Spacing.md) {
                    GlyphBadge(glyph: beat.glyph, size: 40)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(beat.title)
                                .font(AppFont.bodyMedium.weight(.medium))
                                .foregroundStyle(AppColor.onSurface)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: Spacing.sm)
                            Text(beat.when)
                                .font(AppFont.labelMedium)
                                .foregroundStyle(AppColor.outline)
                                .multilineTextAlignment(.trailing)
                        }
                        Text(beat.detail)
                            .font(AppFont.bodySmall)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Text("“\(week.question)”")
                .font(AppFont.quote)
                .foregroundStyle(AppColor.onSurface)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(.tinted)
    }

    private var personColumns: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            PersonColumn(person: viewModel.user)
            PersonColumn(person: viewModel.partner)
        }
    }

    // MARK: - Topology

    private func topology(_ report: SynastryReport) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Eyebrow(text: "Aspect Topology")
                Spacer()
                Text(report.harmony)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
            }

            SynastryWheel(user: viewModel.userChart, partner: viewModel.partnerChart, aspects: viewModel.aspects)
                .frame(height: 280)
                .padding(.vertical, Spacing.sm)

            HStack(spacing: Spacing.lg) {
                wheelKey(color: AppColor.primaryContainer, name: viewModel.userName, ring: "Inner")
                wheelKey(color: AppColor.secondary, name: viewModel.partnerName, ring: "Outer")
            }

            VStack(spacing: Spacing.sm) {
                Text(report.title.uppercased())
                    .font(AppFont.labelMedium)
                    .tracking(1.2)
                    .foregroundStyle(AppColor.outline)
                Text("“\(report.quote)”")
                    .font(.system(size: 26, design: .serif).italic())
                    .foregroundStyle(AppColor.onSurface)
                Text(report.summary)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .padding(.top, Spacing.xs)
            }
            .multilineTextAlignment(.center)
        }
        .card(.tinted, padding: Spacing.lg)
    }

    private func wheelKey(color: Color, name: String, ring: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(name)
                .font(AppFont.labelMedium)
                .foregroundStyle(AppColor.onSurface)
                .lineLimit(1)
            Text(ring)
                .font(AppFont.labelSmall)
                .tracking(0.4)
                .foregroundStyle(AppColor.outline)
        }
    }

    // MARK: - Composite

    @ViewBuilder
    private func compositeSection(_ report: SynastryReport) -> some View {
        if isSanctuaryMember, let composite = report.composite {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "Composite Chart", trailing: composite.harmony)
                Text(composite.summary)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineSpacing(3)
                VStack(spacing: 0) {
                    ForEach(Array(composite.points.enumerated()), id: \.element.id) { index, point in
                        if index > 0 { HairlineDivider() }
                        HStack(spacing: Spacing.md) {
                            Text(point.glyph)
                                .font(.system(size: 16, design: .serif))
                                .foregroundStyle(AppColor.primary)
                                .frame(width: 24)
                            Text(point.name)
                                .font(AppFont.bodyMedium.weight(.medium))
                                .foregroundStyle(AppColor.onSurface)
                            Spacer(minLength: Spacing.sm)
                            Text(point.placement)
                                .font(AppFont.bodySmall)
                                .foregroundStyle(AppColor.onSurfaceVariant)
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
            .card(.elevated)
        } else if !isSanctuaryMember {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Composite Chart", systemImage: "lock")
                    .font(AppFont.labelLarge)
                    .foregroundStyle(AppColor.secondary)
                Text("A reading of the relationship itself.")
                    .font(AppFont.headlineSmall)
                    .foregroundStyle(AppColor.onSurface)
                Text("Membership adds a combined view of the two of you, separate from either person's chart.")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                Button(action: viewModel.openPaywall) {
                    Text("See the relationship")
                }
                .buttonStyle(.astroPrimary)
                .padding(.top, Spacing.xs)
            }
            .card(.tinted)
        }
    }

    // MARK: - Dimensions

    private func dimensions(_ report: SynastryReport) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SectionHeader(title: "How you get along", trailing: "\(report.dimensions.count)")
                .padding(.top, Spacing.sm)
            ForEach(Array(report.dimensions.enumerated()), id: \.element.id) { index, dimension in
                DimensionCard(dimension: dimension, badgeColor: badgeColor(at: index))
            }
        }
    }

    private func badgeColor(at index: Int) -> Color {
        switch index % 4 {
        case 0, 2: AppColor.secondaryContainer
        case 3: AppColor.dustyRose.opacity(0.35)
        default: AppColor.surfaceContainerHigh
        }
    }

    // MARK: - Inquiries

    private func inquiries(_ report: SynastryReport) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(AppColor.secondary)
                Text("Questions to sit with")
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
            }

            ForEach(viewModel.questions) { question in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    Text("\(question.number)")
                        .font(.system(size: 17, design: .serif))
                        .foregroundStyle(AppColor.outlineVariant)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("“\(question.text)”")
                            .font(.system(size: 22, design: .serif))
                            .foregroundStyle(AppColor.onSurface)
                        Text(question.prompt)
                            .font(AppFont.labelMedium)
                            .tracking(0.4)
                            .foregroundStyle(AppColor.outline)
                    }
                }
                .card(.elevated, padding: Spacing.md + 4)
            }
        }
        .card(.tinted, padding: Spacing.md + 4)
    }

    // MARK: - Artifact

    private func artifact(_ report: SynastryReport) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share this reading")
                        .font(AppFont.headlineMedium)
                        .foregroundStyle(AppColor.onSurface)
                }
                Spacer()
                Button(action: viewModel.toggleDegrees) {
                    Label(viewModel.hidesDegrees ? "Show Degrees" : "Hide Degrees",
                          systemImage: viewModel.hidesDegrees ? "eye.slash" : "eye")
                        .font(AppFont.labelLarge)
                        .foregroundStyle(AppColor.onSurface)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(AppColor.surfaceContainerHigh, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, Spacing.sm)

            storyCard(report)
                .padding(Spacing.md)
                .background(AppColor.surfaceContainerHigh, in: .rect(cornerRadius: Radius.lg))

            ShareLink(item: viewModel.shareText) {
                Label("Share Compatibility Card", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.astroPrimary)
        }
    }

    private func storyCard(_ report: SynastryReport) -> some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Label("StellarSage", systemImage: "sparkles")
                    .font(AppFont.labelMedium)
                    .tracking(1.2)
                    .textCase(.uppercase)
            }
            .foregroundStyle(AppColor.onSurface)

            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    GlyphBadge(glyph: viewModel.userGlyph, size: 52, background: AppColor.surfaceContainerLow)
                    Image(systemName: "infinity")
                        .foregroundStyle(AppColor.secondary)
                    GlyphBadge(glyph: viewModel.partnerGlyph, size: 52, foreground: AppColor.secondary, background: AppColor.surfaceContainerLow)
                }
                Text(viewModel.title)
                    .font(AppFont.headlineLarge)
                    .foregroundStyle(AppColor.onSurface)
                Text(viewModel.cardSubtitle.uppercased())
                    .font(AppFont.labelMedium)
                    .tracking(1)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .contentTransition(.opacity)
                Rectangle()
                    .fill(AppColor.hairline.opacity(0.3))
                    .frame(width: 40, height: 0.5)
                Text("“\(report.quote)”")
                    .font(.system(size: 24, design: .serif).italic())
                    .foregroundStyle(AppColor.onSurface)
                Text(report.harmony)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(AppColor.secondaryContainer, in: .capsule)
            }
        }
        .padding(Spacing.lg)
        .background {
            ZStack {
                AppColor.surfaceContainerLowest
                Circle()
                    .stroke(AppColor.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .padding(Spacing.lg)
                Circle()
                    .stroke(AppColor.primaryContainer.opacity(0.15), lineWidth: 0.5)
                    .padding(64)
            }
        }
        .clipShape(.rect(cornerRadius: Radius.lg))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .animation(.easeInOut(duration: 0.2), value: viewModel.hidesDegrees)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Text(message)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.astroSecondary)
        }
        .card(.tinted, padding: Spacing.lg)
    }
}

// MARK: - Pieces

/// The partner has no stored photo: the first letter of their name on a warm ground.
private struct PartnerInitial: View {
    let name: String
    var size: CGFloat = 44

    private var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? ""
    }

    var body: some View {
        ZStack {
            AppColor.secondaryContainer
            if initial.isEmpty {
                Image(systemName: "person")
                    .font(.system(size: size * 0.4, weight: .medium))
            } else {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .regular, design: .serif))
            }
        }
        .foregroundStyle(AppColor.secondary)
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay(Circle().stroke(AppColor.surface, lineWidth: 2))
        .accessibilityLabel(name.isEmpty ? "Partner" : name)
    }
}

private struct PersonColumn: View {
    let person: SynastryViewModel.Person

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(person.name)
                    .font(AppFont.labelLarge)
                    .foregroundStyle(AppColor.onSurface)
                    .lineLimit(1)
            }
            ForEach(person.placements) { placement in
                HStack(spacing: Spacing.xs) {
                    Text("\(placement.glyph) \(placement.label)")
                        .font(AppFont.labelSmall)
                        .tracking(0.6)
                        .foregroundStyle(AppColor.outline)
                        .frame(width: 52, alignment: .leading)
                    Text(placement.value)
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .card(.elevated, padding: 12)
    }
}

private struct DimensionCard: View {
    let dimension: SynastryDimension
    let badgeColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: dimension.icon)
                .font(.system(size: 16))
                .foregroundStyle(AppColor.primaryContainer)
                .frame(width: 32, height: 32)
                .background(AppColor.surfaceContainerHigh, in: .rect(cornerRadius: Radius.sm))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(dimension.title)
                        .font(AppFont.labelLarge)
                        .foregroundStyle(AppColor.onSurface)
                    Spacer(minLength: Spacing.xs)
                    Text(dimension.badge)
                        .font(AppFont.labelSmall)
                        .tracking(0.4)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor, in: .capsule)
                }
                Text(dimension.text)
                    .font(AppFont.bodyMedium)
                    .lineSpacing(3)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
        }
        .card(.elevated, padding: Spacing.md + 4)
    }
}
