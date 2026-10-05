//
//  JournalView.swift
//  AstroAI
//

import SwiftUI

struct JournalView: View {
    @State private var viewModel: JournalViewModel
    @FocusState private var isComposing: Bool

    init(viewModel: JournalViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                header
                searchField
                filters
                promptCard
                timeline
                vaultFooter
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.reload() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Eyebrow(text: "Folio Archive · Vol. III", color: AppColor.onSurfaceVariant)
                Spacer()
                Label("Zero-Knowledge", systemImage: "lock")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.secondary)
            }
            Text("Personal Journal & Musings")
                .font(AppFont.displayMobile)
                .foregroundStyle(AppColor.onSurface)
            Text("A contemplative repository of transit observations, nocturnal thoughts, and dialogues with the celestial oracle.")
                .font(AppFont.bodyLarge)
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.outline)
            TextField("Search reflections by keyword, planet, or transit...", text: $viewModel.searchText)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurface)
                .submitLabel(.search)
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(AppColor.outline)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 48)
        .background(AppColor.surfaceContainerLowest, in: panelShape(Radius.md))
        .cardEdge(radius: Radius.md, shadowOpacity: 0)
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.sm) {
                ForEach(viewModel.filters) { filter in
                    Chip(title: viewModel.title(for: filter), isSelected: viewModel.selectedFilter == filter) {
                        viewModel.select(filter)
                    }
                }
            }
            .padding(.horizontal, Spacing.margin)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Spacing.margin)
    }

    // MARK: - Prompt

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                Eyebrow(text: viewModel.prompt.context, icon: "infinity")
                Spacer(minLength: Spacing.sm)
                Text(viewModel.promptBadge)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
            }
            Text("\u{201C}\(viewModel.prompt.question)\u{201D}")
                .font(AppFont.headlineMedium.weight(.regular).italic())
                .foregroundStyle(AppColor.onSurface)
            Text(viewModel.prompt.note)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)

            composer
        }
        .card(padding: Spacing.lg)
    }

    private var composer: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: "pencil.line")
                .font(.system(size: 15))
                .foregroundStyle(AppColor.onPrimary)
                .frame(width: 36, height: 36)
                .background(AppColor.primaryContainer, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                TextField("Record private reflection...", text: $viewModel.draft, axis: .vertical)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(AppColor.onSurface)
                    .lineLimit(1...6)
                    .focused($isComposing)
                    .submitLabel(.done)
                    .onSubmit(submit)
                if !isComposing && viewModel.draft.isEmpty {
                    Text("Tap to transcribe voice or write prose")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.outline)
                }
            }
            Spacer(minLength: 0)
            Button(action: submit) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewModel.canSubmit ? AppColor.primaryContainer : AppColor.outline)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSubmit)
        }
        .infoWell()
    }

    private func submit() {
        viewModel.submitReflection()
        isComposing = false
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Eyebrow(text: "Chronological Folios", color: AppColor.onSurfaceVariant)
                Spacer()
                Text(viewModel.seasonTitle)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
            }
            .padding(.horizontal, Spacing.xs)

            if viewModel.visibleEntries.isEmpty {
                Text("No reflections match this view yet.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.outline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
            } else {
                ForEach(viewModel.visibleEntries) { entry in
                    JournalEntryCard(entry: entry)
                }
            }
        }
    }

    private var vaultFooter: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 18))
                .foregroundStyle(AppColor.onSurfaceVariant)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Cryptographic Device Vault")
                    .font(AppFont.bodyMedium.weight(.medium))
                    .foregroundStyle(AppColor.onSurface)
                Text("All personal journal folios are encrypted on-device. No telemetry or LLM training.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
        }
        .card(.tinted, padding: Spacing.lg)
    }
}

// MARK: - Entry card

private struct JournalEntryCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                Text(entry.dayTitle)
                    .font(AppFont.bodyLarge.weight(.medium))
                    .foregroundStyle(AppColor.onSurface)
                Circle()
                    .fill(AppColor.outline)
                    .frame(width: 4, height: 4)
                Text("\(entry.context) · \(entry.timeTitle)")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                badge
            }

            Text("\u{201C}\(entry.quote)\u{201D}")
                .font(AppFont.headlineMedium.weight(.regular).italic())
                .foregroundStyle(AppColor.onSurface)

            if !entry.body.isEmpty {
                Text(entry.body)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineLimit(3)
            }

            if !entry.tags.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(Array(entry.tags.enumerated()), id: \.offset) { index, tag in
                            Pill(text: tag, icon: index == 0 ? tagIcon : nil)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .card(padding: Spacing.lg)
    }

    @ViewBuilder
    private var badge: some View {
        if entry.kind == .oracle {
            Label("Linked Oracle", systemImage: entry.kind.icon)
                .font(AppFont.labelMedium)
                .foregroundStyle(AppColor.primaryContainer)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 3)
                .background(AppColor.primaryFixed, in: .capsule)
        } else {
            Image(systemName: entry.kind.icon)
                .font(.system(size: 16))
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
    }

    private var tagIcon: String {
        switch entry.kind {
        case .oracle: "triangle"
        case .bookmark: "safari"
        case .reflection: "book"
        }
    }
}
