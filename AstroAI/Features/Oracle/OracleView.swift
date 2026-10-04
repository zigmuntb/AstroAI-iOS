//
//  OracleView.swift
//  AstroAI
//

import SwiftUI

struct OracleView: View {
    @State private var viewModel: OracleViewModel
    @FocusState private var isInputFocused: Bool

    private let typingID = "typing"

    init(viewModel: OracleViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    AppTopBar(title: "AI Astrologer", onAvatarTap: viewModel.openProfile)
                        .padding(.horizontal, -Spacing.margin)

                    if viewModel.isOffline {
                        OracleOfflineView(
                            isRetrying: viewModel.isRetrying,
                            onRetry: viewModel.retry,
                            onContinue: viewModel.continueOffline
                        )
                    } else {
                        contextBar
                        transcript
                        suggestions
                        quota
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
        .toolbarVisibility(.hidden, for: .navigationBar)
        .task { await viewModel.loadSky() }
    }

    // MARK: - Context

    private var contextBar: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: 6) {
                        Circle().fill(AppColor.secondary).frame(width: 6, height: 6)
                        Eyebrow(text: "Sanctuary Chamber")
                    }
                    Text("AstroAI Sanctuary")
                        .font(AppFont.headlineMedium)
                        .foregroundStyle(AppColor.onSurface)
                    Text(viewModel.syncLine)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
                Spacer()
                HStack(spacing: Spacing.sm) {
                    squareButton(icon: "book", action: viewModel.openJournal)
                    squareButton(icon: "arrow.clockwise") {
                        withAnimation { viewModel.resetSession() }
                    }
                }
            }

            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(AppColor.onSurfaceVariant)
                Text(viewModel.transitLine)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                Spacer(minLength: 0)
                Text(viewModel.transitBadge)
                    .font(AppFont.labelSmall)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColor.secondaryContainer.opacity(0.6), in: .capsule)
            }
            .padding(Spacing.sm + 4)
            .background(AppColor.surfaceContainerHigh.opacity(0.6), in: .rect(cornerRadius: Radius.md))
        }
        .card(.tinted, padding: Spacing.md + 4)
    }

    private func squareButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppColor.onSurface)
                .frame(width: 40, height: 40)
                .background(AppColor.surfaceContainerHighest, in: .rect(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
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
            Image(systemName: "hurricane")
                .font(.system(size: 11))
                .foregroundStyle(AppColor.onPrimary)
                .frame(width: 22, height: 22)
                .background(AppColor.primary, in: .circle)
            Text("AstroAI Guide • Hermetic Reading")
                .font(AppFont.bodySmall.weight(.medium))
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
    }

    private func readingCard(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            oracleHeader

            VStack(alignment: .leading, spacing: Spacing.md) {
                if let note = message.transitNote {
                    Label(note, systemImage: "circle.dashed")
                        .font(AppFont.labelMedium)
                        .tracking(0.4)
                        .foregroundStyle(AppColor.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppColor.secondaryContainer.opacity(0.45), in: .capsule)
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
            Divider().overlay(AppColor.hairline.opacity(0.2))

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
                Text("Consulting the ephemeris…")
                    .font(AppFont.quote)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            .card(.elevated)
        }
    }

    // MARK: - Suggestions & quota

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Eyebrow(text: "Suggested Contemplations", color: AppColor.onSurfaceVariant)
                Spacer()
                Image(systemName: "lightbulb")
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                Button {
                    viewModel.ask(suggestion)
                } label: {
                    HStack(spacing: Spacing.md) {
                        Text(suggestion)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(AppColor.onSurface)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(AppColor.outlineVariant)
                    }
                    .card(.elevated)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isTyping)
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
            Button("Unlimited Dialogue", action: viewModel.openPaywall)
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
                TextField("Ask about your chart, current transits, or patterns...", text: $viewModel.draft)
                    .font(AppFont.bodyMedium)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit(viewModel.send)
                Button(action: viewModel.send) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.onPrimary)
                        .frame(width: 40, height: 40)
                        .background(AppColor.primary.opacity(viewModel.canSend ? 1 : 0.5), in: .rect(cornerRadius: Radius.sm))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSend)
            }
            .padding(Spacing.sm)
            .background(AppColor.surfaceContainerLowest, in: .rect(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppColor.hairline.opacity(0.2), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

            PrivacyFootnote(text: "Private Ephemeris Engine • Encrypted Chart Sanctuary")
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.surface.opacity(0.95))
    }
}
