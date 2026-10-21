//
//  ProfileView.swift
//  AstroAI
//

import SwiftUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    identity
                    ForEach(viewModel.nudges) { nudge in
                        nudgeCard(nudge)
                    }
                    if !viewModel.isPremium {
                        sanctuaryCard
                    }
                    journalSection
                    preferencesSection
                    footer
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        // Runs on every appearance, so premium status and journal stay fresh after the paywall / journal.
        .task { await viewModel.load() }
    }

    // MARK: - Identity

    private var identity: some View {
        VStack(spacing: Spacing.md) {
            Button(action: viewModel.editProfile) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(content: viewModel.avatar, size: 112)
                        .padding(4)
                        .overlay(Circle().stroke(AppColor.champagne.opacity(0.5), lineWidth: 1))
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColor.primaryContainer)
                        .frame(width: 28, height: 28)
                        .background(AppColor.surfaceContainerLowest, in: .circle)
                        .overlay(Circle().stroke(AppColor.hairline.opacity(0.3), lineWidth: 0.5))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit profile")

            VStack(spacing: Spacing.sm) {
                Button(action: viewModel.editProfile) {
                    Text(viewModel.name)
                        .font(AppFont.displayMobile)
                        .foregroundStyle(AppColor.onSurface)
                }
                .buttonStyle(.plain)
                if !viewModel.birthLine.isEmpty {
                    Text(viewModel.birthLine)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
            }
            .multilineTextAlignment(.center)

            Pill(text: viewModel.membershipTitle, icon: viewModel.isPremium ? "checkmark.seal" : "checkmark.shield")

            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 88)
                } else {
                    ViewThatFits(in: .horizontal) {
                        bigThree(axis: .horizontal)
                        bigThree(axis: .vertical)
                    }
                }
            }
            .padding(.top, Spacing.sm)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.error)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func bigThree(axis: Axis) -> some View {
        let tiles = Array(viewModel.bigThree.enumerated())
        let row = ForEach(tiles, id: \.element.id) { index, tile in
            HStack(spacing: 0) {
                if axis == .horizontal, index > 0 {
                    Rectangle()
                        .fill(AppColor.hairline)
                        .frame(width: 0.5)
                        .padding(.vertical, Spacing.sm)
                }
                bigThreeTile(tile)
            }
        }
        return Group {
            if axis == .horizontal {
                HStack(spacing: 0) { row }
            } else {
                VStack(spacing: Spacing.md) { row }
            }
        }
    }

    private func bigThreeTile(_ tile: ProfileViewModel.BigThreeTile) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(tile.glyph)
                .font(AppFont.headlineMedium)
                .foregroundStyle(AppColor.primary)
            Text(tile.sign)
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
                .multilineTextAlignment(.center)
            Text(tile.label)
                .font(AppFont.labelMedium)
                .foregroundStyle(AppColor.secondary)
            Text(tile.detail)
                .font(AppFont.labelMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Nudges

    private func nudgeCard(_ nudge: ProfileViewModel.Nudge) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: nudge.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColor.secondary)
                .frame(width: 36, height: 36)
                .background(AppColor.secondaryContainer.opacity(0.5), in: .circle)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(nudge.title)
                    .font(AppFont.headlineSmall)
                    .foregroundStyle(AppColor.onSurface)
                Text(nudge.text)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle = nudge.actionTitle {
                    Button(actionTitle, action: viewModel.editProfile)
                        .font(AppFont.labelLarge)
                        .foregroundStyle(AppColor.primaryContainer)
                        .padding(.top, Spacing.xs)
                }
            }
            Spacer(minLength: 0)
        }
        .card(.tinted)
    }

    // MARK: - Sanctuary

    private var sanctuaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Eyebrow(text: "Membership", color: AppColor.onPrimary.opacity(0.7))
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundStyle(AppColor.onPrimary)
            }
            Text("Unlock StellarSage Sanctuary")
                .font(AppFont.headlineMedium)
                .foregroundStyle(AppColor.onPrimary)
            Text("Unlimited questions, a fuller reading of your chart, and more than one person.")
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onPrimary.opacity(0.75))
            Button(action: viewModel.exploreMembership) {
                HStack(spacing: Spacing.sm) {
                    Text("Explore Membership")
                    Image(systemName: "arrow.right")
                }
                .font(AppFont.bodyMedium.weight(.semibold))
                .foregroundStyle(AppColor.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(AppColor.surfaceContainerLowest, in: .rect(cornerRadius: Radius.md))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)
        }
        .card(.accent, padding: Spacing.lg)
        .overlay(alignment: .bottomTrailing) {
            ConstellationOrnament()
                .frame(width: 140, height: 140)
                .offset(x: 30, y: 30)
        }
        .clipShape(.rect(cornerRadius: Radius.lg))
    }

    // MARK: - Journal

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SectionHeader(
                title: "Journal",
                subtitle: "Private notes tied to today's sky",
                trailing: viewModel.folioCountTitle.uppercased()
            )

            promptCard

            ForEach(viewModel.recentEntries) { entry in
                RecentEntryCard(entry: entry)
            }

            Button(action: viewModel.openJournal) {
                HStack(spacing: Spacing.xs) {
                    Text(viewModel.viewAllTitle)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(AppFont.bodyMedium.weight(.medium))
                .foregroundStyle(AppColor.onSurface)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(AppColor.surfaceContainerHigh, in: .rect(cornerRadius: Radius.md))
            }
            .buttonStyle(.plain)
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Eyebrow(text: viewModel.prompt.context, icon: "calendar.badge.plus", color: AppColor.onSurfaceVariant)
            Text("\u{201C}\(viewModel.prompt.question)\u{201D}")
                .font(AppFont.quote)
                .foregroundStyle(AppColor.onSurface)
            Button(action: viewModel.openJournal) {
                HStack {
                    Text("Tap to write what this brings up")
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: Spacing.sm)
                    Image(systemName: "plus.circle")
                }
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.outline)
                .infoWell()
            }
            .buttonStyle(.plain)
        }
        .card(padding: Spacing.lg)
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Chart settings", subtitle: "How the chart is calculated, and reminders")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.preferenceRows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        HairlineDivider(leadingInset: 56)
                    }
                    Button(action: viewModel.openSettings) {
                        PreferenceRowView(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
            .card(padding: 0)
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            Text(viewModel.footerQuote)
                .font(AppFont.quote)
                .foregroundStyle(AppColor.secondary)
            Text(viewModel.versionLine.uppercased())
                .font(AppFont.labelSmall)
                .tracking(1.2)
                .foregroundStyle(AppColor.outline)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Subviews

private struct RecentEntryCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                Circle()
                    .fill(entry.kind == .oracle ? AppColor.champagne : AppColor.outlineVariant)
                    .frame(width: 5, height: 5)
                Text("\(entry.dayTitle) — \(entry.context)")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                if entry.kind == .oracle {
                    Label("AI Dialogue", systemImage: entry.kind.icon)
                        .font(AppFont.labelSmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(AppColor.hairline.opacity(0.3), lineWidth: 0.5))
                } else {
                    Image(systemName: entry.kind.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.outline)
                }
            }
            Text("\u{201C}\(entry.quote)\u{201D}")
                .font(AppFont.headlineSmall.weight(.regular))
                .foregroundStyle(AppColor.onSurface)
            Text([entry.timeTitle, entry.tags.first].compactMap { $0 }.joined(separator: " • "))
                .font(AppFont.labelSmall)
                .foregroundStyle(AppColor.outline)
        }
        .card(padding: Spacing.lg)
    }
}

private struct PreferenceRowView: View {
    let row: ProfileViewModel.PreferenceRow

    var body: some View {
        HStack(spacing: Spacing.md) {
            IconBadge(systemName: row.icon, size: 28, background: AppColor.surfaceContainer)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(AppColor.onSurface)
                Text(row.subtitle)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            Spacer(minLength: Spacing.sm)
            trailing
        }
        .padding(Spacing.md)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var trailing: some View {
        switch row.trailing {
        case .icon(let name):
            Image(systemName: name)
                .foregroundStyle(AppColor.onSurfaceVariant)
        case .picker(let value):
            HStack(spacing: Spacing.xs) {
                Text(value)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
            }
            .font(AppFont.bodySmall.weight(.medium))
            .foregroundStyle(AppColor.onSurface)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColor.surfaceContainer, in: .rect(cornerRadius: Radius.sm))
        case .verified:
            Label("VERIFIED", systemImage: "checkmark.circle")
                .font(AppFont.labelSmall)
                .tracking(0.8)
                .foregroundStyle(AppColor.secondary)
        case .button(let title):
            Text(title)
                .font(AppFont.bodySmall.weight(.medium))
                .foregroundStyle(AppColor.onSurface)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColor.surfaceContainer, in: .rect(cornerRadius: Radius.sm))
        }
    }
}

/// Faint concentric circles + cross used behind the Sanctuary card.
private struct ConstellationOrnament: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let color = GraphicsContext.Shading.color(AppColor.onPrimary.opacity(0.15))
            context.stroke(Path(ellipseIn: rect.insetBy(dx: size.width * 0.05, dy: size.height * 0.05)),
                           with: color, style: StrokeStyle(lineWidth: 0.75, dash: [2, 2]))
            context.stroke(Path(ellipseIn: rect.insetBy(dx: size.width * 0.22, dy: size.height * 0.22)),
                           with: color, lineWidth: 0.5)
            var cross = Path()
            cross.move(to: CGPoint(x: size.width * 0.1, y: size.height / 2))
            cross.addLine(to: CGPoint(x: size.width * 0.9, y: size.height / 2))
            cross.move(to: CGPoint(x: size.width / 2, y: size.height * 0.1))
            cross.addLine(to: CGPoint(x: size.width / 2, y: size.height * 0.9))
            context.stroke(cross, with: color, lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
