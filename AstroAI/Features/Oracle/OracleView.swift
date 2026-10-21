//
//  OracleView.swift
//  AstroAI
//

import SwiftUI

struct OracleView: View {
    @State private var viewModel: OracleViewModel
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isInputFocused: Bool

    private let typingID = "typing"

    init(viewModel: OracleViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.block) {
                    if viewModel.isOffline {
                        OracleOfflineView(
                            isRetrying: viewModel.isRetrying,
                            onRetry: viewModel.retry,
                            onContinue: viewModel.continueOffline
                        )
                    } else {
                        contextBar
                        transcript
                        if let install = viewModel.modelInstall {
                            modelInstallCard(install)
                        } else {
                            suggestions
                        }
                        if viewModel.showsFreeQuota {
                            quota
                        }
                    }
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.bottom, Spacing.lg)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                guard let last = viewModel.messages.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .top) }
            }
            .onChange(of: viewModel.isTyping) { _, isTyping in
                guard isTyping else { return }
                withAnimation { proxy.scrollTo(typingID, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.isOffline { inputBar }
        }
        .screenBackground()
        .navigationTitle("Oracle")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.openJournal) {
                    Image(systemName: "book")
                }
                .accessibilityLabel("Journal")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { viewModel.resetSession() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("New conversation")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ProfileToolbarButton(action: viewModel.openProfile)
            }
        }
        .task { await viewModel.loadSky() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.loadSky() }
        }
    }

    // MARK: - Context

    private var contextBar: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(viewModel.syncLine)
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
                .fixedSize(horizontal: false, vertical: true)
            Text(viewModel.transitLine)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
            Text("Answers use your chart when it helps. They are not forecasts, and they cannot tell you what someone else feels.")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
            AstrologyDisclosure(text: viewModel.astrologyDetail)
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach(viewModel.messages) { message in
                Group {
                    switch message.role {
                    case .user: userBubble(message)
                    case .oracle: readingCard(message)
                    }
                }
                .id(message.id)
            }
            if viewModel.showsTypingIndicator {
                typingIndicator.id(typingID)
            }
        }
    }

    private func userBubble(_ message: ChatMessage) -> some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text("\(viewModel.userName) • \(viewModel.timestamp(for: message))")
                    .font(AppFont.labelMedium)
                    .tracking(0.4)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                Text(viewModel.userInitial)
                    .font(AppFont.labelMedium.weight(.semibold))
                    .foregroundStyle(AppColor.secondary)
                    .frame(width: 22, height: 22)
                    .background(AppColor.secondaryContainer, in: .circle)
            }
            Text(message.text)
                .font(AppFont.bodyLarge)
                .lineSpacing(4)
                .foregroundStyle(AppColor.onSurface)
                .padding(Spacing.md)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Radius.lg, bottomLeadingRadius: Radius.lg,
                        bottomTrailingRadius: Radius.lg, topTrailingRadius: Radius.sm / 2
                    )
                    .fill(AppColor.surfaceContainerHigh)
                )
                .padding(.leading, Spacing.xl)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var oracleHeader: some View {
        HStack(spacing: Spacing.sm) {
            Text("☽")
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.primary)
                .accessibilityHidden(true)
            Text("Oracle")
                .font(AppFont.bodySmall.weight(.medium))
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
    }

    private func readingCard(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            oracleHeader

            VStack(alignment: .leading, spacing: Spacing.md) {
                if let note = message.transitNote {
                    AstrologyDisclosure(text: note)
                }
                if let title = message.title {
                    Text(title)
                        .font(AppFont.headlineLarge)
                        .foregroundStyle(AppColor.primary)
                }
                Text(message.text)
                    .font(AppFont.bodyLarge)
                    .lineSpacing(5)
                    .foregroundStyle(AppColor.onSurface)
                    .fixedSize(horizontal: false, vertical: true)

                if viewModel.streamingMessageID != message.id {
                    messageActions(message)
                }
            }
            .card(.elevated, padding: Spacing.md + 4)
        }
    }

    private func messageActions(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HairlineDivider()

            HStack(spacing: Spacing.lg) {
                let isSaved = viewModel.savedMessageIDs.contains(message.id)
                Button {
                    viewModel.save(message)
                } label: {
                    Label(isSaved ? "Saved to Journal" : "Save to Journal", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                }
                Button {
                    UIPasteboard.general.string = [message.title, message.text].compactMap { $0 }.joined(separator: "\n\n")
                    viewModel.markCopied(message)
                } label: {
                    Label(viewModel.copiedMessageID == message.id ? "Copied" : "Copy", systemImage: "doc.on.doc")
                }
                Spacer()
                ShareLink(item: message.text) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .font(AppFont.labelMedium)
            .tracking(0.4)
            .foregroundStyle(AppColor.onSurfaceVariant)
            .buttonStyle(.plain)
        }
    }

    private var typingIndicator: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            oracleHeader
            HStack(spacing: Spacing.sm) {
                ProgressView().tint(AppColor.primaryContainer)
                Text("Thinking this through…")
                    .font(AppFont.quote)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            .card(.elevated)
        }
    }

    // MARK: - Suggestions & quota

    private func modelInstallCard(_ install: OracleModelInstall) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Eyebrow(text: "On this phone")
            Text("Install the Oracle")
                .font(AppFont.headlineMedium)
                .foregroundStyle(AppColor.onSurface)
            Text("Apple Intelligence isn't available here, so the Oracle uses a free open model. It downloads once (\(install.sizeDescription)) and then answers stay on this phone, without a server.")
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
            if let progress = viewModel.installProgress {
                ProgressView(value: progress) {
                    Text(progress > 0 && progress < 1 ? "Downloading…" : "Preparing the Oracle…")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
                .tint(AppColor.primary)
            } else {
                Button(action: viewModel.installModel) {
                    Text("Download the Oracle")
                }
                .buttonStyle(.astroPrimary)
            }
            if let installError = viewModel.installError {
                Text(installError)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.error)
            }
        }
        .card(.tinted, padding: Spacing.md + 4)
    }

    @ViewBuilder
    private var suggestions: some View {
        if !viewModel.suggestions.isEmpty {
            suggestionsList
        }
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("You could ask")
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    AskPromptButton(question: suggestion, isEnabled: !viewModel.isTyping) {
                        viewModel.ask(suggestion)
                    }
                }
            }
        }
    }

    private var quota: some View {
        HStack(spacing: Spacing.md) {
            Circle().fill(AppColor.secondary).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.quotaText)
                    .font(AppFont.labelLarge.weight(.medium))
                    .foregroundStyle(AppColor.onSurface)
                Text("Resets tonight at 12:00 AM")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            Spacer(minLength: Spacing.sm)
            Button("Unlimited questions", action: viewModel.openPaywall)
                .font(AppFont.labelMedium.weight(.semibold))
                .underline()
                .foregroundStyle(AppColor.primary)
                .buttonStyle(.plain)
        }
        .card(.tinted)
    }

    // MARK: - Input

    private var inputBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "square.on.square")
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .padding(.leading, Spacing.xs)
                TextField("Ask about your day, a relationship, or a decision", text: $viewModel.draft)
                    .font(AppFont.bodyMedium)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit(viewModel.send)
                Button(action: viewModel.send) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.onPrimary)
                        .frame(width: 44, height: 44)
                        .background(AppColor.primary.opacity(viewModel.canSend ? 1 : 0.5), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSend)
            }
            .padding(Spacing.sm)
            .background(AppColor.surfaceContainerLowest, in: panelShape(Radius.md))
            .cardEdge(radius: Radius.md)
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.surface.opacity(0.95))
    }
}
