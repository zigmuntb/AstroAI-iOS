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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                AppTopBar(title: "Today", onAvatarTap: viewModel.openProfile)
                    .padding(.horizontal, -Spacing.margin)

                if let reading = viewModel.reading {
                    greeting(reading)
                    tarot
                    luckyNumbers(reading)
                    balances(reading)
                    ephemeris(reading)
                    synthesis(reading)
                    tendencies(reading)
                    attunement(reading)
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
        .toolbarVisibility(.hidden, for: .navigationBar)
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

    private func greeting(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text(viewModel.dateLine)
                    .font(AppFont.labelLarge.weight(.medium))
                    .tracking(0.8)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                Circle().fill(AppColor.outlineVariant).frame(width: 4, height: 4)
                Text(viewModel.moonLine)
                    .font(AppFont.labelLarge.weight(.medium))
                    .foregroundStyle(AppColor.secondary)
            }

            Text(viewModel.greeting)
                .font(AppFont.displayMobile)
                .foregroundStyle(AppColor.onSurface)

            HStack(spacing: 6) {
                Circle().fill(AppColor.secondary).frame(width: 6, height: 6)
                Text("Atmosphere: \(reading.atmosphere)")
                    .font(AppFont.labelMedium)
                    .tracking(0.4)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColor.surfaceContainer, in: .capsule)
        }
    }

    private var tarot: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Eyebrow(text: "Tarot", icon: "sparkles")

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
        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: "Lucky Numbers")
                Spacer(minLength: Spacing.sm)
                Text("Personal day \(lucky.personalDay)")
                    .font(AppFont.labelMedium)
                    .tracking(0.4)
                    .foregroundStyle(AppColor.secondary)
            }

            HStack(spacing: Spacing.sm) {
                ForEach(Array(lucky.values.enumerated()), id: \.offset) { index, number in
                    Text("\(number)")
                        .font(AppFont.headlineSmall)
                        .monospacedDigit()
                        .foregroundStyle(index == 0 ? AppColor.onPrimary : AppColor.onSurface)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(index == 0 ? AppColor.primaryContainer : AppColor.surfaceContainerLowest, in: .circle)
                        .overlay {
                            if index > 0 {
                                Circle().stroke(AppColor.hairline.opacity(0.28), lineWidth: 0.5)
                            }
                        }
                        .accessibilityLabel(index == 0 ? "Personal day \(number)" : "\(number)")
                }
            }

            Text(lucky.note)
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(.tinted, padding: Spacing.md + 4)
        .accessibilityElement(children: .contain)
    }

    private func balances(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Eyebrow(text: "Today's Balance")
                Text("Each pair shares one scale, from 0 to 100.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(Array(reading.dials.enumerated()), id: \.element.id) { index, dial in
                    if index > 0 {
                        Rectangle()
                            .fill(AppColor.hairline.opacity(0.15))
                            .frame(height: 0.5)
                    }
                    let tints = dialTints(dial)
                    LifeDialMeter(dial: dial, leftTint: tints.0, rightTint: tints.1)
                }
            }
        }
        .card(.elevated, padding: Spacing.lg)
    }

    private func dialTints(_ dial: LifeDial) -> (Color, Color) {
        switch dial.id {
        case "bonds": (AppColor.dustyRose, AppColor.secondary)
        case "circle": (AppColor.sage, AppColor.primaryContainer)
        case "tempo": (AppColor.secondary, AppColor.primary)
        default: (AppColor.primaryContainer, AppColor.dustyRose)
        }
    }

    private func ephemeris(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Eyebrow(text: "Ephemeris Reading")
                    Text(reading.ephemerisTitle)
                        .font(AppFont.headlineMedium)
                        .foregroundStyle(AppColor.onSurface)
                    Text(reading.ephemerisText)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                VStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .stroke(AppColor.outline.opacity(0.35), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        Circle()
                            .stroke(AppColor.outline.opacity(0.25), lineWidth: 0.5)
                            .padding(8)
                        AspectChord()
                            .stroke(AppColor.secondary.opacity(0.8), lineWidth: 0.75)
                        MoonPhaseView(illumination: reading.moonIllumination)
                            .frame(width: 40, height: 40)
                    }
                    .frame(width: 92, height: 92)
                    Text("\(reading.moonIllumination)% Illum.")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.outline)
                }
            }

            Divider().overlay(AppColor.hairline.opacity(0.15))

            HStack {
                Label("Transit: \(reading.transitLine)", systemImage: "safari")
                Spacer()
                Text("Orb: \(reading.orb)")
            }
            .font(AppFont.labelMedium)
            .tracking(0.4)
            .foregroundStyle(AppColor.onSurfaceVariant)
        }
        .card(.tinted, padding: Spacing.md + 4)
    }

    private func synthesis(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Eyebrow(text: "The Daily Synthesis")
                Spacer()
                Image(systemName: "book")
                    .foregroundStyle(AppColor.outline)
            }

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
                            .foregroundStyle(AppColor.onPrimary)
                            .padding(Spacing.md)
                    }
                }
                .clipShape(.rect(cornerRadius: Radius.md))

            VStack(spacing: Spacing.sm) {
                ForEach(reading.areas) { area in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Image(systemName: area.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColor.primaryContainer)
                            .frame(width: 32, height: 32)
                            .background(AppColor.surfaceContainerLowest, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(area.title)
                                .font(AppFont.labelLarge)
                                .foregroundStyle(AppColor.onSurface)
                            Text(area.text)
                                .font(AppFont.bodyMedium)
                                .foregroundStyle(AppColor.onSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Spacing.md)
                    .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.md))
                }
            }
        }
        .card(.elevated, padding: Spacing.lg)
    }

    private func tendencies(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Eyebrow(text: "Somatic Tendencies")
                Spacer()
                Text("Self-Paced")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            ForEach(Array(reading.tendencies.enumerated()), id: \.element.id) { index, tendency in
                VStack(spacing: Spacing.sm) {
                    HStack {
                        Text(tendency.title)
                            .font(AppFont.bodyMedium.weight(.medium))
                            .foregroundStyle(AppColor.onSurface)
                        Spacer()
                        Text(tendency.value)
                            .font(AppFont.labelMedium)
                            .tracking(0.4)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                    }
                    LevelBar(value: tendency.level, color: index == 1 ? AppColor.secondary : AppColor.primary)
                }
            }
        }
        .card(.tinted, padding: Spacing.md + 4)
    }

    private func attunement(_ reading: DailyReading) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Eyebrow(text: "Morning Attunement")
                Spacer()
                Text(viewModel.isMoodRecorded ? "Recorded" : "Unrecorded")
                    .font(AppFont.labelMedium.weight(viewModel.isMoodRecorded ? .semibold : .medium))
                    .tracking(0.6)
                    .foregroundStyle(viewModel.isMoodRecorded ? AppColor.secondary : AppColor.outline)
            }
            Text("How is the day finding you?")
                .font(AppFont.headlineMedium)
                .foregroundStyle(AppColor.onSurface)
            Text("Acknowledge your emotional baseline to recalibrate today's transits.")
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)], spacing: Spacing.sm) {
                ForEach(reading.moods, id: \.self) { mood in
                    let isSelected = viewModel.selectedMood == mood
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { viewModel.selectMood(mood) }
                    } label: {
                        Text(mood)
                            .font(AppFont.bodyMedium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Eyebrow(text: "Consult the Oracle", icon: "questionmark.circle", color: AppColor.onSurfaceVariant)
                Spacer()
                Text("\(reading.moonSign.name) Transit Focus")
                    .font(AppFont.labelMedium.weight(.semibold))
                    .foregroundStyle(AppColor.secondary)
            }
            ForEach(reading.oracleQuestions, id: \.self) { question in
                Button {
                    viewModel.ask(question)
                } label: {
                    HStack(spacing: Spacing.md) {
                        Text(question)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(AppColor.onSurface)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(AppColor.outline)
                    }
                    .card(.elevated)
                }
                .buttonStyle(.plain)
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
                actionLabel(title: "Share Folio", icon: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            actionDivider
            actionButton(title: "Transit Map", icon: "calendar", action: viewModel.openTransitMap)
        }
        .padding(.vertical, Spacing.sm)
        .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.lg))
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

/// Mars–Saturn trine chord with endpoint dots, drawn around the moon disc.
private struct AspectChord: Shape {
    func path(in rect: CGRect) -> Path {
        let start = CGPoint(x: rect.width * 0.22, y: rect.height * 0.28)
        let end = CGPoint(x: rect.width * 0.78, y: rect.height * 0.72)
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        for point in [start, end] {
            path.addEllipse(in: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
        }
        return path
    }
}

/// A single 0...100 axis. The knob sits on today's lean: left score is the remainder.
private struct LifeDialMeter: View {
    let dial: LifeDial
    let leftTint: Color
    let rightTint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0.5

    private var shown: Int { Int((progress * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                pole(
                    icon: dial.leftIcon,
                    title: dial.left,
                    score: 100 - shown,
                    tint: leftTint,
                    emphasized: dial.value < 50
                )
                Spacer(minLength: Spacing.sm)
                pole(
                    icon: dial.rightIcon,
                    title: dial.right,
                    score: shown,
                    tint: rightTint,
                    emphasized: dial.value > 50,
                    leading: false
                )
            }

            meter

            Text(dial.note)
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dial.left) \(100 - dial.value) out of 100. \(dial.right) \(dial.value) out of 100. \(dial.note)")
        .onAppear {
            guard progress != lean else { return }
            if reduceMotion {
                progress = lean
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                    progress = lean
                }
            }
        }
    }

    private var lean: CGFloat { CGFloat(dial.value) / 100 }

    private var meter: some View {
        GeometryReader { geo in
            let knob: CGFloat = 14
            let width = geo.size.width
            let travel = max(width - knob, 0)
            let split = travel * progress + knob / 2
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(rightTint.opacity(0.72))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(leftTint.opacity(0.9))
                            .frame(width: max(split, 0))
                    }
                    .clipShape(Capsule())
                Circle()
                    .fill(AppColor.surfaceContainerLowest)
                    .overlay {
                        Circle().stroke(emphasizedTint, lineWidth: 1.5)
                    }
                    .shadow(color: AppColor.primary.opacity(0.14), radius: 2, y: 1)
                    .frame(width: knob, height: knob)
                    .offset(x: travel * progress)
            }
            .frame(width: width, height: knob, alignment: .leading)
        }
        .frame(height: 14)
    }

    private var emphasizedTint: Color {
        if dial.value < 50 { return leftTint }
        if dial.value > 50 { return rightTint }
        return AppColor.primaryContainer
    }

    private func pole(icon: String, title: String, score: Int, tint: Color, emphasized: Bool, leading: Bool = true) -> some View {
        HStack(spacing: 6) {
            if leading {
                iconView(icon, tint: tint, emphasized: emphasized)
                titleView(title, emphasized: emphasized)
                scoreView(score, tint: tint, emphasized: emphasized)
            } else {
                scoreView(score, tint: tint, emphasized: emphasized)
                titleView(title, emphasized: emphasized)
                iconView(icon, tint: tint, emphasized: emphasized)
            }
        }
    }

    private func iconView(_ name: String, tint: Color, emphasized: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(emphasized ? tint : AppColor.outline)
            .frame(width: 16, height: 16)
    }

    private func titleView(_ title: String, emphasized: Bool) -> some View {
        Text(title)
            .font(AppFont.labelLarge)
            .foregroundStyle(emphasized ? AppColor.onSurface : AppColor.onSurfaceVariant)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func scoreView(_ score: Int, tint: Color, emphasized: Bool) -> some View {
        Text("\(score)")
            .font(AppFont.headlineMedium)
            .foregroundStyle(emphasized ? tint : AppColor.outline)
            .monospacedDigit()
            .contentTransition(.numericText())
            .layoutPriority(1)
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
