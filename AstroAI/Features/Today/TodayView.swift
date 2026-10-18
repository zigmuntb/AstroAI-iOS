//
//  TodayView.swift
//  AstroAI
//

import ImagePlayground
import SwiftUI

struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @FocusState private var isTarotFieldFocused: Bool

    init(viewModel: TodayViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                if let reading = viewModel.reading {
                    masthead(reading)
                    if let motion = viewModel.moonMotion {
                        moonMotionCard(motion)
                    }
                    synthesis(reading)
                    balances(reading)
                    luckyNumbers(reading)
                    attunement(reading)
                    tarot
                    oracle(reading)
                    actions
                } else if viewModel.isLoading {
                    ProgressView()
                        .tint(AppColor.primaryContainer)
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let message = viewModel.errorMessage {
                    errorState(message)
                }
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.bottom, Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProfileToolbarButton(action: viewModel.openProfile)
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.isTarotComposerPresented, onDismiss: viewModel.tarotComposerDismissed) {
            tarotComposer
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .imagePlaygroundSheet(
            isPresented: $viewModel.isTarotPlaygroundPresented,
            concepts: [.text(viewModel.tarotConcept)],
            onCompletion: { url in viewModel.saveTarotCard(from: url) }
        )
        .imagePlaygroundGenerationStyle(.illustration, in: [.illustration])
        .tarotPlaygroundOptions()
    }

    // MARK: - Sections

    private func masthead(_ reading: DailyReading) -> some View {
        ViewThatFits(in: .horizontal) {
            mastheadRow(reading, axis: .horizontal)
            mastheadRow(reading, axis: .vertical)
        }
    }

    private func mastheadRow(_ reading: DailyReading, axis: Axis) -> some View {
        let stack = (axis == .horizontal)
        return Group {
            if stack {
                HStack(alignment: .center, spacing: Spacing.md) {
                    moon(reading)
                    mastheadText(reading)
                }
            } else {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    moon(reading)
                    mastheadText(reading)
                }
            }
        }
    }

    private func moon(_ reading: DailyReading) -> some View {
        MoonPhaseView(illumination: reading.moonIllumination)
            .frame(width: 64, height: 64)
            .accessibilityLabel("\(reading.moonPhase), \(reading.moonIllumination) percent illuminated")
    }

    private func mastheadText(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(viewModel.dateLine)
                .font(AppFont.labelLarge)
                .foregroundStyle(AppColor.secondary)
            Text(viewModel.greeting)
                .font(AppFont.displayMobile)
                .foregroundStyle(AppColor.onSurface)
            Text("\(reading.moonPhase) in \(reading.moonSign.name) · \(reading.atmosphere)")
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func moonMotionCard(_ motion: MoonMotion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(motion.line)
                .font(AppFont.bodyMedium.weight(.medium))
                .foregroundStyle(AppColor.onSurface)
                .fixedSize(horizontal: false, vertical: true)
            if motion.isVoid {
                Text("Nothing new needs a decision until the Moon changes sign.")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(.tinted)
    }

    private var tarot: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Tarot")
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)

            if let data = viewModel.tarotImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: Radius.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(AppColor.champagne.opacity(0.8), lineWidth: 1)
                    }
                    .accessibilityLabel("Tarot card")

                if !viewModel.tarotDescription.isEmpty {
                    Text(viewModel.tarotDescription)
                        .font(AppFont.quote)
                        .foregroundStyle(AppColor.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Draw a card from a description")
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
                Text("Name a feeling, a question, or a scene. Image Playground illustrates it as a tarot card, and the picture stays here.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let tarotError = viewModel.tarotError {
                Text(tarotError)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.error)
            }

            if supportsImagePlayground {
                if viewModel.tarotImageData == nil {
                    Button("Describe a card", action: viewModel.beginTarot)
                        .buttonStyle(.astroPrimary)
                } else {
                    Button("Draw another", action: viewModel.beginTarot)
                        .buttonStyle(.astroSecondary)
                }
            } else if viewModel.tarotImageData == nil {
                Text("Image Playground isn't available on this iPhone.")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.outline)
            }
        }
        .card(.elevated, padding: Spacing.lg)
    }

    private var tarotComposer: some View {
        let draft = Binding(
            get: { viewModel.tarotDraft },
            set: { viewModel.tarotDraft = String($0.prefix(TarotCardStore.descriptionLimit)) }
        )
        return NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("What should the card show?")
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
                Text("A mood, a question, or a scene. The picture is an illustration, not a prediction.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    TextField("A moonlit path between two towers", text: draft, axis: .vertical)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurface)
                        .lineLimit(3...6)
                        .focused($isTarotFieldFocused)
                        .padding(Spacing.md)
                        .background(AppColor.surfaceContainer, in: .rect(cornerRadius: Radius.md))
                    Text("\(draft.wrappedValue.count)/\(TarotCardStore.descriptionLimit)")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.outline)
                        .monospacedDigit()
                }

                PrivacyFootnote(
                    text: "Write the scene in English. Image Playground doesn't draw Russian yet.",
                    icon: "sparkles"
                )

                Spacer(minLength: 0)

                PrimaryButton(title: "Draw the card", icon: "sparkles", action: viewModel.drawTarotCard)
                    .disabled(!viewModel.canDrawTarot)
            }
            .padding(Spacing.margin)
            .screenBackground()
            .navigationTitle("Tarot")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { isTarotFieldFocused = true }
        }
    }

    private func luckyNumbers(_ reading: DailyReading) -> some View {
        let lucky = reading.luckyNumbers
        let companions = lucky.values.dropFirst().map(String.init).joined(separator: "   ")
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Lucky numbers")
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                Text("\(lucky.personalDay)")
                    .font(AppFont.displayMobile)
                    .monospacedDigit()
                    .foregroundStyle(AppColor.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal day")
                        .font(AppFont.labelLarge)
                        .foregroundStyle(AppColor.secondary)
                    if !companions.isEmpty {
                        Text(companions)
                            .font(AppFont.headlineSmall)
                            .monospacedDigit()
                            .foregroundStyle(AppColor.onSurface)
                    }
                }
            }

            Text(lucky.note)
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func balances(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Today's balance")
                    .font(AppFont.headlineSmall)
                    .foregroundStyle(AppColor.onSurface)
                Text("Swipe the deck. Each card is one place to put the day.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            BalanceDeck(dials: reading.dials)
        }
    }

    private func synthesis(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(reading.synthesisTitle)
                    .font(AppFont.headlineLarge)
                    .foregroundStyle(AppColor.onSurface)
                Text(reading.synthesisText)
                    .font(AppFont.bodyLarge)
                    .lineSpacing(4)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            .fixedSize(horizontal: false, vertical: true)

            BannerImage(name: "TodayContemplation", height: 200)
                .overlay(alignment: .bottomLeading) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [.clear, AppColor.midnight.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                        Text(reading.imageCaption)
                            .font(AppFont.labelMedium)
                            .foregroundStyle(AppColor.ivory)
                            .padding(Spacing.md)
                    }
                }
                .clipShape(.rect(cornerRadius: Radius.md))
        }
    }

    private func attunement(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(viewModel.isMoodRecorded ? "Recorded" : "Not recorded")
                    .font(AppFont.labelMedium.weight(viewModel.isMoodRecorded ? .semibold : .medium))
                    .foregroundStyle(viewModel.isMoodRecorded ? AppColor.secondary : AppColor.outline)
                Spacer()
            }
            Text("How are you feeling today?")
                .font(AppFont.headlineMedium)
                .foregroundStyle(AppColor.onSurface)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)], spacing: Spacing.sm) {
                ForEach(reading.moods, id: \.self) { mood in
                    let isSelected = viewModel.selectedMood == mood
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { viewModel.selectMood(mood) }
                    } label: {
                        Text(mood)
                            .font(AppFont.bodyMedium)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.onSurface)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(isSelected ? AppColor.primary : AppColor.surfaceContainerLowest, in: .rect(cornerRadius: Radius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Spacing.sm)
        }
        .card(.tinted, padding: Spacing.md + 4)
    }

    private func oracle(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Ask the Oracle")
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
            Text("\(reading.moonSign.name) is the focus")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.secondary)

            VStack(spacing: 0) {
                ForEach(Array(reading.oracleQuestions.enumerated()), id: \.element) { index, question in
                    if index > 0 { HairlineDivider() }
                    Button {
                        viewModel.ask(question)
                    } label: {
                        HStack(spacing: Spacing.md) {
                            Text(question)
                                .font(AppFont.bodyLarge)
                                .foregroundStyle(AppColor.onSurface)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppColor.outline)
                        }
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 0) {
            actionButton(
                title: viewModel.isSaved ? "Saved" : "Save Reading",
                icon: viewModel.isSaved ? "bookmark.fill" : "bookmark",
                action: viewModel.toggleSave
            )
            actionDivider
            ShareLink(item: viewModel.shareText) {
                actionLabel(title: "Share", icon: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            actionDivider
            actionButton(title: "Transit Map", icon: "calendar", action: viewModel.openTransitMap)
        }
        .padding(.vertical, Spacing.sm)
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionLabel(title: title, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(title: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(title)
                .font(AppFont.labelMedium)
                .tracking(0.6)
        }
        .foregroundStyle(AppColor.onSurfaceVariant)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(.rect)
    }

    private var actionDivider: some View {
        Rectangle()
            .fill(AppColor.hairline.opacity(0.2))
            .frame(width: 0.5, height: 32)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Text(message)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.astroSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

extension View {
    /// Portrait card on iOS 27, and no photos of the user mixed into the illustration.
    @ViewBuilder
    func tarotPlaygroundOptions() -> some View {
        if #available(iOS 26.4, *) {
            imagePlaygroundOptions(TarotPlaygroundOptions.make())
        } else {
            imagePlaygroundPersonalizationPolicy(.disabled)
        }
    }
}

@available(iOS 26.4, *)
private enum TarotPlaygroundOptions {
    static func make() -> ImagePlaygroundOptions {
        var options = ImagePlaygroundOptions()
        options.personalization = .disabled
        if #available(iOS 27, *) {
            options.sizeSpecification = .closest(to: CGSize(width: 768, height: 1152))
        }
        return options
    }
}
