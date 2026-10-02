//
//  SynastryView.swift
//  AstroAI
//

import SwiftUI

struct SynastryView: View {
    @State private var viewModel: SynastryViewModel

    init(viewModel: SynastryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                recordHeader
                pairSwitcher
                personColumns

                if let report = viewModel.report {
                    topology(report)
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
        .task { await viewModel.load() }
    }

    // MARK: - Header

    private var recordHeader: some View {
        HStack {
            HStack(spacing: Spacing.xs) {
                Eyebrow(text: "Synastry Record")
                Circle().fill(AppColor.champagne).frame(width: 4, height: 4)
                Text("Vol. IV")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
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

    private var pairSwitcher: some View {
        HStack(spacing: Spacing.md) {
            HStack(spacing: -12) {
                portrait(viewModel.user.portrait, size: 44)
                portrait(viewModel.partner.portrait, size: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(viewModel.title)
                        .font(AppFont.headlineMedium)
                        .foregroundStyle(AppColor.onSurface)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColor.outline)
                }
                Text("\(viewModel.relationLabel) • Synced")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Pill(text: "Aligned", icon: "infinity")
        }
        .card(.tinted, padding: 12)
    }

    private var personColumns: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            PersonColumn(person: viewModel.user, badgeColor: AppColor.secondaryContainer)
            PersonColumn(person: viewModel.partner, badgeColor: AppColor.primaryFixed)
        }
    }

    private func portrait(_ name: String, size: CGFloat) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(.circle)
            .overlay(Circle().stroke(AppColor.surface, lineWidth: 2))
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

            NatalWheel(showsSigns: false)
                .frame(height: 220)
                .padding(.vertical, Spacing.sm)

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

    // MARK: - Dimensions

    private func dimensions(_ report: SynastryReport) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Dimensional Architecture", trailing: "\(report.dimensions.count) Dimensions")
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
                Text("Introspective Inquiries")
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
            }
            Text("Curated questions derived from the current lunar cycle to unlock unspoken spaces between you.")
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)

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
                    Text("Relational Artifact")
                        .font(AppFont.headlineMedium)
                        .foregroundStyle(AppColor.onSurface)
                    Text("Formatted for story sharing or keepsakes")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
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

            Text("Saves high-resolution portrait graphic directly to your camera roll or Instagram stories.")
                .font(AppFont.labelMedium)
                .foregroundStyle(AppColor.outline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func storyCard(_ report: SynastryReport) -> some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Label("AstroAI Synastry", systemImage: "sparkles")
                    .font(AppFont.labelMedium)
                    .tracking(1.2)
                    .textCase(.uppercase)
                Spacer()
                Text("EP. 28")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
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
            .multilineTextAlignment(.center)
            .padding(.vertical, Spacing.lg)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Celestial Blueprint")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.outline)
                    Text("astroai.com/synastry")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.onSurface)
                }
                Spacer()
                Image(systemName: "qrcode")
                    .font(.system(size: 26))
                    .foregroundStyle(AppColor.onSurface)
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

private struct PersonColumn: View {
    let person: SynastryViewModel.Person
    let badgeColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(person.name)
                    .font(AppFont.labelLarge)
                    .foregroundStyle(AppColor.onSurface)
                    .lineLimit(1)
                Spacer(minLength: Spacing.xs)
                Text(person.role)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(badgeColor, in: .capsule)
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
