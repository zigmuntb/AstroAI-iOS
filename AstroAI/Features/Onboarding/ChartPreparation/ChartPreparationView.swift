//
//  ChartPreparationView.swift
//  AstroAI
//

import SwiftUI

struct ChartPreparationView: View {
    @State private var viewModel: ChartPreparationViewModel

    init(viewModel: ChartPreparationViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Label("SWISS EPHEMERIS DE431 CALCULATION", systemImage: "gearshape.2")
                    .font(AppFont.labelMedium.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 10)
                    .background(AppColor.surfaceContainerHigh, in: .capsule)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)

                OrbitGraphic(nodes: viewModel.nodes, progress: viewModel.progress)
                    .frame(maxWidth: 320)

                VStack(spacing: Spacing.sm) {
                    Text("Connecting the pieces of your chart.")
                        .font(AppFont.headlineLarge)
                        .foregroundStyle(AppColor.onSurface)
                    Text(viewModel.subtitle)
                        .font(AppFont.bodyLarge)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
                .multilineTextAlignment(.center)

                checklist

                if let error = viewModel.errorMessage {
                    VStack(spacing: Spacing.md) {
                        Text(error)
                            .font(AppFont.bodyMedium)
                            .foregroundStyle(AppColor.error)
                            .multilineTextAlignment(.center)
                        Button("Try again") {
                            Task { await viewModel.retry() }
                        }
                        .buttonStyle(.astroSecondary)
                    }
                }

                PrivacyFootnote(text: "ALL MATHEMATICAL COMPUTATIONS EXECUTE SECURELY ON-DEVICE.")
                    .tracking(0.8)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.md)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.35), value: viewModel.progress)
        .task { await viewModel.load() }
    }

    private var checklist: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.steps) { step in
                if step.id > 0 {
                    Rectangle()
                        .fill(AppColor.outlineVariant.opacity(0.6))
                        .frame(height: 0.5)
                        .padding(.vertical, Spacing.md)
                }
                StepRow(step: step)
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.lg))
        .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
    }
}

private struct StepRow: View {
    let step: ChartPreparationViewModel.Step

    var body: some View {
        HStack(spacing: Spacing.md) {
            indicator
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(AppFont.bodyLarge.weight(.medium))
                    .tracking(0.4)
                    .foregroundStyle(step.state == .active ? AppColor.primaryContainer : AppColor.onSurface)
                Text(step.detail)
                    .font(AppFont.labelMedium)
                    .tracking(0.8)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .opacity(step.state == .pending ? 0.45 : 1)
    }

    @ViewBuilder
    private var indicator: some View {
        switch step.state {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColor.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColor.surfaceContainerHighest, in: .circle)
                .transition(.scale.combined(with: .opacity))
        case .active:
            ZStack {
                Circle().stroke(AppColor.outline.opacity(0.6), lineWidth: 1)
                Circle().fill(AppColor.surfaceContainerHigh).padding(1)
                Circle().fill(AppColor.primaryContainer).frame(width: 10, height: 10)
                    .phaseAnimator([1.0, 0.55]) { dot, scale in
                        dot.opacity(scale)
                    } animation: { _ in .easeInOut(duration: 1.1) }
            }
        case .pending:
            Circle().stroke(AppColor.outlineVariant, lineWidth: 1)
        }
    }
}

/// Concentric orbit rings with a slowly rotating dashed halo and chords
/// that draw in as the preparation progresses.
private struct OrbitGraphic: View {
    let nodes: [ChartPreparationViewModel.OrbitNode]
    let progress: Double

    // Node positions on the inner orbit, in degrees from the top, clockwise.
    private let angles: [Double] = [22, 222, 112]
    private let cardinals = [("00°", ZodiacSign.aries), ("90°", .cancer), ("180°", .libra), ("270°", .capricorn)]

    @State private var rotation = 0.0

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [AppColor.secondaryContainer.opacity(0.25), .clear],
                        center: .center, startRadius: 0, endRadius: radius
                    ))

                Circle()
                    .stroke(AppColor.hairline.opacity(0.35), style: StrokeStyle(lineWidth: 0.75, dash: [2, 4]))
                    .frame(width: size * 0.98, height: size * 0.98)
                    .rotationEffect(.degrees(rotation))

                Canvas { context, _ in
                    let line = AppColor.hairline.opacity(0.3)
                    for factor in [0.88, 0.66, 0.42, 0.2] {
                        let r = radius * factor
                        context.stroke(
                            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                            with: .color(line), lineWidth: factor == 0.42 ? 1 : 0.5
                        )
                    }
                    var cross = Path()
                    cross.move(to: CGPoint(x: center.x, y: center.y - radius * 0.88))
                    cross.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.88))
                    cross.move(to: CGPoint(x: center.x - radius * 0.88, y: center.y))
                    cross.addLine(to: CGPoint(x: center.x + radius * 0.88, y: center.y))
                    context.stroke(cross, with: .color(line.opacity(0.5)), lineWidth: 0.5)
                }

                chords(center: center, radius: radius * 0.66)
                    .trim(from: 0, to: progress)
                    .stroke(AppColor.champagne.opacity(0.8), style: StrokeStyle(lineWidth: 1, lineCap: .round))

                ForEach(Array(cardinals.enumerated()), id: \.offset) { index, item in
                    Text("\(item.0) \(item.1.glyph)")
                        .font(AppFont.labelSmall)
                        .foregroundStyle(AppColor.outline)
                        .position(point(angle: Double(index) * 90, center: center, radius: radius * 0.94))
                }

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    let angle = angles[index % angles.count]
                    Circle()
                        .fill(index == 0 ? AppColor.secondaryContainer : AppColor.surfaceContainerLowest)
                        .overlay(Circle().stroke(AppColor.secondary, lineWidth: 1))
                        .frame(width: index == 0 ? 16 : 12, height: index == 0 ? 16 : 12)
                        .position(point(angle: angle, center: center, radius: radius * 0.66))
                    Text("\(node.glyph) \(node.label)")
                        .font(AppFont.labelMedium)
                        .foregroundStyle(AppColor.secondary)
                        .position(point(angle: angle, center: center, radius: radius * 0.8))
                        .transition(.opacity)
                }

                Circle()
                    .fill(AppColor.primaryContainer.opacity(0.8))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().fill(AppColor.onPrimary).frame(width: 8, height: 8))
                    .phaseAnimator([1.0, 1.15]) { core, scale in
                        core.scaleEffect(scale)
                    } animation: { _ in .easeInOut(duration: 1.4) }
                    .position(center)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.linear(duration: 48).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    private func chords(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: center)
        for angle in [angles[0], angles[2], angles[1]] {
            path.addLine(to: point(angle: angle, center: center, radius: radius))
        }
        path.addLine(to: center)
        return path
    }

    private func point(angle: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let radians = CGFloat((angle - 90) * .pi / 180)
        return CGPoint(x: center.x + radius * cos(radians), y: center.y + radius * sin(radians))
    }
}
