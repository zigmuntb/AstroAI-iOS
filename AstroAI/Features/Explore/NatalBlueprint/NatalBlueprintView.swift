//
//  NatalBlueprintView.swift
//  AstroAI
//

import SwiftUI

struct NatalBlueprintView: View {
    @State private var viewModel: NatalBlueprintViewModel
    @Environment(\.isSanctuaryMember) private var isSanctuaryMember

    init(viewModel: NatalBlueprintViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                masthead
                modePicker

                if let chart = viewModel.chart {
                    wheelCard(chart)
                    bigThree(chart)
                    distribution(chart)
                    placements(chart)
                    if viewModel.mode == .deep {
                        deepDive
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    disclaimer
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: Spacing.md) {
                        Text(error)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                        Button("Try again") { Task { await viewModel.retry() } }
                            .buttonStyle(.astroSecondary)
                    }
                } else {
                    ProgressView()
                        .tint(AppColor.primaryContainer)
                        .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.bottom, Spacing.xl)
            .animation(.easeInOut(duration: 0.25), value: viewModel.mode)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.isInspectorPresented, onDismiss: viewModel.closeInspector) {
            CoordinatesInspector(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var masthead: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(viewModel.eyebrow.uppercased())
                    .font(AppFont.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(AppColor.secondary)
                Spacer()
                Text(viewModel.houseSystem)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text("Cosmic Blueprint")
                    .font(AppFont.displayMobile)
                    .foregroundStyle(AppColor.onSurface)
                Spacer(minLength: 0)
                Text(viewModel.birthLine)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
        }
        .padding(.top, Spacing.sm)
    }

    private var modePicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(NatalBlueprintViewModel.Mode.allCases) { mode in
                let isSelected = viewModel.mode == mode
                Button {
                    viewModel.mode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(AppFont.bodySmall.weight(.medium))
                        .foregroundStyle(isSelected ? AppColor.onSurface : AppColor.onSurfaceVariant)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: Radius.sm)
                                    .fill(AppColor.surfaceContainerLowest)
                                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xs)
        .background(AppColor.surfaceContainerHigh, in: .rect(cornerRadius: Radius.md))
    }

    // MARK: - Wheel

    private func wheelCard(_ chart: NatalChart) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Spacer()
                Button(action: viewModel.inspectDegrees) {
                    Label("Inspect Degrees", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.onSurface)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColor.surfaceContainer, in: .capsule)
                }
                .buttonStyle(.plain)
            }

            ZStack(alignment: .bottom) {
                NatalWheel(placements: chart.placements, selected: viewModel.selectedPlanet) { viewModel.select($0) }
                Label("Tap glyphs to inspect aspects", systemImage: "hand.tap")
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColor.surfaceContainer, in: .capsule)
                    .allowsHitTesting(false)
            }

            HStack(spacing: Spacing.md) {
                legendItem("Trine (120°)", color: AppColor.secondary, dash: [])
                legendItem("Opposition (180°)", color: AppColor.onSurfaceVariant, dash: [2, 2])
                legendItem("Sextile (60°)", color: AppColor.champagne, dash: [])
            }
        }
        .card(.elevated)
    }

    private func legendItem(_ title: String, color: Color, dash: [CGFloat]) -> some View {
        HStack(spacing: 6) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 1))
                path.addLine(to: CGPoint(x: 14, y: 1))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: dash))
            .frame(width: 14, height: 2)
            Text(title)
                .font(AppFont.labelSmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
    }

    // MARK: - Big Three

    private func bigThree(_ chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            sectionHeader("The Big Three", trailing: "")

            ForEach(chart.bigThree) { placement in
                let isMoon = placement.planet == .moon
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Text(placement.planet.glyph)
                            .font(.system(size: 18, design: .serif))
                            .foregroundStyle(AppColor.primary)
                        Text(viewModel.headline(for: placement))
                            .font(AppFont.bodyMedium.weight(.semibold))
                            .foregroundStyle(AppColor.onSurface)
                        Spacer(minLength: Spacing.xs)
                        Text(viewModel.position(for: placement))
                            .font(AppFont.labelMedium)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 3)
                            .background(AppColor.surfaceContainerHigh, in: .capsule)
                    }
                    Text("“\(placement.title)”")
                        .font(AppFont.quote)
                        .foregroundStyle(isMoon ? AppColor.secondary : AppColor.onSurface)
                    Text(placement.summary)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .lineSpacing(3)
                }
                .card(isMoon ? .tinted : .elevated)
            }
        }
    }

    // MARK: - Elements & modalities

    private func distribution(_ chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Elements")
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
                Spacer()
                Text(viewModel.dominantElement)
                    .font(AppFont.labelSmall)
                    .foregroundStyle(AppColor.secondary)
            }

            ShareBar(shares: chart.elements, colors: Self.elementColors, height: 8)

            HStack(alignment: .top) {
                ForEach(Array(chart.elements.enumerated()), id: \.element.id) { index, share in
                    VStack(spacing: 2) {
                        Text("\(share.percent)% \(share.name)")
                            .font(AppFont.labelMedium.weight(.semibold))
                            .foregroundStyle(Self.elementColors[index % Self.elementColors.count])
                        Text(share.keyword)
                            .font(AppFont.labelSmall)
                            .foregroundStyle(AppColor.outline)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HairlineDivider()

            HStack {
                Text("Modalities".uppercased())
                    .font(AppFont.labelMedium.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(AppColor.onSurface)
                Spacer()
                Text(viewModel.dominantModality)
                    .font(AppFont.labelSmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }

            ShareBar(shares: chart.modalities, colors: Self.modalityColors, height: 4)

            HStack(alignment: .top) {
                ForEach(chart.modalities) { share in
                    Text("\(share.name) (\(share.percent)%) • \(share.keyword)")
                        .font(AppFont.labelSmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .card(.elevated)
    }

    private static let elementColors = [AppColor.primary, AppColor.secondary, AppColor.dustyRose, AppColor.outline]
    private static let modalityColors = [AppColor.primaryContainer, AppColor.champagne, AppColor.outlineVariant]

    // MARK: - Placements

    private func placements(_ chart: NatalChart) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            sectionHeader("Planetary Placements", trailing: "")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("“\(chart.tension)”")
                    .font(.system(size: 22, design: .serif).italic())
                    .foregroundStyle(AppColor.onSurface)
                Text(chart.synthesis)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineSpacing(2)
            }
            .card(.tinted, padding: Spacing.lg)

            ForEach(chart.otherPlacements) { placement in
                placementRow(placement)
            }
        }
    }

    private func placementRow(_ placement: PlanetPlacement) -> some View {
        let isExpanded = viewModel.isExpanded(placement.planet)
        return VStack(alignment: .leading, spacing: Spacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggle(placement.planet) }
            } label: {
                HStack(spacing: Spacing.md) {
                    GlyphBadge(glyph: placement.planet.glyph, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                            Text(viewModel.headline(for: placement))
                                .font(AppFont.bodyMedium.weight(.semibold))
                                .foregroundStyle(AppColor.onSurface)
                            Text(placement.degree)
                                .font(AppFont.labelSmall)
                                .foregroundStyle(AppColor.onSurfaceVariant)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColor.surfaceContainerHigh, in: .capsule)
                        }
                        Text(viewModel.houseLine(for: placement))
                            .font(AppFont.labelMedium)
                            .tracking(0.4)
                            .foregroundStyle(AppColor.secondary)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColor.outline)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(placement.summary)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .lineSpacing(3)
                    if !placement.detail.isEmpty {
                        Text(placement.detail)
                            .font(AppFont.bodySmall)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                            .lineSpacing(2)
                    }
                    if !placement.aspectNote.isEmpty {
                        Label(placement.aspectNote, systemImage: "infinity")
                            .font(AppFont.bodySmall)
                            .foregroundStyle(AppColor.primary)
                            .infoWell(padding: Spacing.sm + 2)
                    }
                }
                .transition(.opacity)
            }
        }
        .card(.elevated)
    }

    // MARK: - Deep dive

    private var deepDive: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            if isSanctuaryMember {
                houseRulerships
                dignities
                if let path = viewModel.nodalPath {
                    nodalPath(path)
                }
            } else {
                blueprintLock
            }
            declinations
        }
    }

    private var blueprintLock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Complete Natal Blueprint", systemImage: "lock")
                .font(AppFont.labelLarge)
                .foregroundStyle(AppColor.secondary)
            Text("House rulerships, essential dignities and the nodal path.")
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onSurface)
            Text("Sanctuary opens the traditional ruler of every house, where each planet stands in dignity, and the axis from South Node to North Node.")
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)
            Button(action: viewModel.openPaywall) {
                Text("Unlock Blueprint")
            }
            .buttonStyle(.astroPrimary)
            .padding(.top, Spacing.xs)
        }
        .card(.tinted)
    }

    private var houseRulerships: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("House Rulerships", trailing: "")
            Text(viewModel.houseNote)
                .font(AppFont.bodySmall)
                .foregroundStyle(AppColor.onSurfaceVariant)

            VStack(spacing: 0) {
                ForEach(viewModel.houseRules) { rule in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(rule.label)
                                .font(AppFont.bodyMedium.weight(.semibold))
                                .foregroundStyle(AppColor.onSurface)
                            Spacer()
                            Text(rule.cusp)
                                .font(AppFont.labelMedium)
                                .foregroundStyle(AppColor.secondary)
                        }
                        Text(rule.ruler)
                            .font(AppFont.bodySmall)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { HairlineDivider() }
                }
            }
            .card(.elevated)
        }
    }

    private var dignities: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Essential Dignities", trailing: "")
            VStack(spacing: 0) {
                ForEach(viewModel.dignities) { line in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(line.planet.glyph) \(line.planet.name)")
                                .font(AppFont.bodyMedium.weight(.semibold))
                                .foregroundStyle(AppColor.onSurface)
                            Spacer(minLength: Spacing.sm)
                            Text(line.status)
                                .font(AppFont.labelSmall)
                                .foregroundStyle(AppColor.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColor.secondaryContainer, in: .capsule)
                        }
                        Text(line.text)
                            .font(AppFont.bodySmall)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                            .lineSpacing(2)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { HairlineDivider() }
                }
            }
            .card(.elevated)
        }
    }

    private func nodalPath(_ path: NatalBlueprintViewModel.NodalPath) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("Nodal Path", trailing: path.axis)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("North Node")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                    Spacer()
                    Text(path.north)
                        .font(AppFont.bodySmall.weight(.medium))
                        .foregroundStyle(AppColor.onSurface)
                }
                HStack {
                    Text("South Node")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                    Spacer()
                    Text(path.south)
                        .font(AppFont.bodySmall.weight(.medium))
                        .foregroundStyle(AppColor.onSurface)
                }
                Text(path.text)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineSpacing(3)
                    .padding(.top, Spacing.xs)
            }
            .card(.tinted)
        }
    }

    private var declinations: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Planetary Declinations & Bounds")
                .font(AppFont.headlineSmall)
                .foregroundStyle(AppColor.onPrimary)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Eyebrow(text: viewModel.outOfBounds.label, color: AppColor.onPrimary)
                Text(viewModel.outOfBounds.value)
                    .font(AppFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(AppColor.onPrimary)
                Text(viewModel.outOfBounds.caption)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onPrimary.opacity(0.75))
                    .lineSpacing(2)
            }

            HStack(spacing: Spacing.sm) {
                ForEach(viewModel.rulers) { ruler in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ruler.label.uppercased())
                            .font(AppFont.labelSmall)
                            .tracking(0.8)
                            .foregroundStyle(AppColor.onPrimary.opacity(0.6))
                        Text(ruler.value)
                            .font(AppFont.headlineSmall)
                            .foregroundStyle(AppColor.onPrimary)
                        Text(ruler.caption)
                            .font(AppFont.labelMedium)
                            .foregroundStyle(AppColor.onPrimary.opacity(0.75))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.onPrimary.opacity(0.08), in: .rect(cornerRadius: Radius.sm))
                }
            }
        }
        .card(.accent, padding: Spacing.lg)
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("What This Chart Can & Cannot Tell You", systemImage: "book")
                .font(AppFont.bodyMedium.weight(.semibold))
                .foregroundStyle(AppColor.onSurface)
            Text(viewModel.disclaimer)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .lineSpacing(3)
        }
        .card(.tinted)
    }

    private func sectionHeader(_ title: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.headlineMedium)
                .foregroundStyle(AppColor.onSurface)
            if !trailing.isEmpty {
                Spacer()
                Text(trailing.uppercased())
                    .font(AppFont.labelSmall)
                    .tracking(1)
                    .foregroundStyle(AppColor.secondary)
            }
        }
        .padding(.top, Spacing.sm)
    }
}

/// Proportional stacked bar for element / modality shares.
private struct ShareBar: View {
    let shares: [ChartShare]
    let colors: [Color]
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let total = max(shares.reduce(0) { $0 + $1.percent }, 1)
            let spacing: CGFloat = 2
            let available = proxy.size.width - spacing * CGFloat(max(shares.count - 1, 0))
            HStack(spacing: spacing) {
                ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                    Rectangle()
                        .fill(colors[index % colors.count])
                        .frame(width: available * CGFloat(share.percent) / CGFloat(total))
                }
            }
        }
        .frame(height: height)
        .clipShape(.capsule)
    }
}

/// "Exact Ephemeris Coordinates" sheet listing every placement.
private struct CoordinatesInspector: View {
    let viewModel: NatalBlueprintViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label("Exact Ephemeris Coordinates", systemImage: "camera.filters")
                    .font(AppFont.headlineSmall)
                    .foregroundStyle(AppColor.onSurface)
                Spacer()
                Button(action: viewModel.closeInspector) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .frame(width: 32, height: 32)
                        .background(AppColor.surfaceContainerHigh, in: .circle)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.coordinates) { row in
                        let isSelected = row.planet == viewModel.selectedPlanet
                        HStack {
                            Text(row.title)
                                .font(AppFont.bodyMedium.weight(.medium))
                                .foregroundStyle(AppColor.onSurface)
                            Spacer()
                            Text(row.value)
                                .font(AppFont.bodySmall.monospacedDigit())
                                .foregroundStyle(AppColor.onSurfaceVariant)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 12)
                        .background(isSelected ? AppColor.primaryFixed.opacity(0.6) : .clear, in: .rect(cornerRadius: Radius.sm))
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(AppColor.surfaceContainerHigh).frame(height: 0.5)
                        }
                    }
                }

                Text(viewModel.inspectorNote)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
                    .padding(.top, Spacing.md)
            }
            .scrollIndicators(.hidden)

            Button("Done Inspecting", action: viewModel.closeInspector)
                .buttonStyle(.astroPrimary)
        }
        .padding(Spacing.margin)
        .padding(.top, Spacing.sm)
        .background(AppColor.surface.ignoresSafeArea())
    }
}
