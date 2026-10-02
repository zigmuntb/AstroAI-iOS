//
//  TodayView.swift
//  AstroAI
//

import SwiftUI

struct TodayView: View {
    @State private var viewModel: TodayViewModel

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
