//
//  CelestialGraphics.swift
//  AstroAI
//

import SwiftUI

/// The AstroAI logo mark ("Celestial Mark" in the design).
struct CelestialMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            context.scaleBy(x: scale, y: scale)
            context.stroke(
                Path(ellipseIn: CGRect(x: 6, y: 6, width: 88, height: 88)),
                with: .color(AppColor.charcoal.opacity(0.4)),
                style: StrokeStyle(lineWidth: 1.2, dash: [2, 3])
            )

            var orbit = Path(ellipseIn: CGRect(x: 12, y: 34, width: 76, height: 32))
            orbit = orbit.applying(
                CGAffineTransform(translationX: -50, y: -50)
                    .concatenating(CGAffineTransform(rotationAngle: -25 * .pi / 180))
                    .concatenating(CGAffineTransform(translationX: 50, y: 50))
            )
            context.stroke(orbit, with: .color(AppColor.primaryContainer), lineWidth: 1.4)

            context.fill(Path(ellipseIn: CGRect(x: 36, y: 36, width: 28, height: 28)), with: .color(AppColor.midnight))
            context.fill(Path(ellipseIn: CGRect(x: 39, y: 39, width: 22, height: 22)), with: .color(AppColor.onPrimary))
            context.fill(Path(ellipseIn: CGRect(x: 46, y: 46, width: 8, height: 8)), with: .color(AppColor.primaryContainer))
            context.fill(Path(ellipseIn: CGRect(x: 74.5, y: 33.5, width: 7, height: 7)), with: .color(AppColor.champagne))
            context.fill(Path(ellipseIn: CGRect(x: 19.5, y: 60.5, width: 5, height: 5)), with: .color(AppColor.dustyRose))

            for (from, to) in [((50, 6), (50, 16)), ((50, 84), (50, 94)), ((6, 50), (16, 50)), ((84, 50), (94, 50))] {
                var tick = Path()
                tick.move(to: CGPoint(x: from.0, y: from.1))
                tick.addLine(to: CGPoint(x: to.0, y: to.1))
                context.stroke(tick, with: .color(AppColor.charcoal), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Hairline natal wheel: zodiac ring, house spokes, planets and aspect chords.
/// Used on Welcome, Chart Reveal, Natal Blueprint, Paywall and Synastry.
struct NatalWheel: View {
    var placements: [PlanetPlacement] = MockData.natalChart.placements
    var highlighted: Set<Planet> = [.sun, .moon, .ascendant]
    var selected: Planet? = nil
    var showsSigns = true
    var onSelect: ((Planet) -> Void)? = nil

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

                Canvas { context, _ in
                    drawRings(context: context, center: center, radius: radius)
                    drawAspects(context: context, center: center, radius: radius * 0.62)
                }

                // Glyph badges scale with the wheel so small previews stay readable.
                let scale = min(radius / 150, 1)

                ForEach(placements) { placement in
                    let isKey = highlighted.contains(placement.planet)
                    let badge = (isKey ? 34 : 24) * scale
                    let point = position(for: placement.longitude, center: center, radius: radius * (isKey ? 0.62 : 0.74))
                    Button {
                        onSelect?(placement.planet)
                    } label: {
                        Text(placement.planet == .ascendant ? "ASC" : placement.planet.glyph)
                            .font(.system(size: (isKey ? 14 : 11) * scale, design: .serif))
                            .foregroundStyle(placement.planet == selected ? AppColor.onPrimary : AppColor.primaryContainer)
                            .frame(width: badge, height: badge)
                            .background(
                                Circle().fill(placement.planet == selected ? AppColor.primaryContainer : AppColor.surfaceContainerLowest)
                            )
                            .overlay(Circle().stroke(AppColor.primaryContainer.opacity(0.4), lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                    .position(point)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func position(for longitude: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        // Ascendant-style orientation: 0° Aries on the left, counter-clockwise.
        let angle = CGFloat((180 - longitude) * .pi / 180)
        return CGPoint(x: center.x + radius * cos(angle), y: center.y - radius * sin(angle))
    }

    private func drawRings(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let line = AppColor.hairline.opacity(0.35)
        for factor in [0.98, 0.86] {
            let r = radius * factor
            context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(line), lineWidth: 0.75)
        }
        let inner = radius * 0.32
        context.stroke(
            Path(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2)),
            with: .color(line), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
        )

        for index in 0..<12 {
            let longitude = Double(index) * 30
            var spoke = Path()
            spoke.move(to: position(for: longitude, center: center, radius: inner))
            spoke.addLine(to: position(for: longitude, center: center, radius: radius * 0.98))
            context.stroke(spoke, with: .color(line.opacity(0.6)), lineWidth: 0.5)

            if showsSigns, let sign = ZodiacSign.allCases[safe: index] {
                let point = position(for: longitude + 15, center: center, radius: radius * 0.92)
                context.draw(
                    Text(sign.glyph).font(.system(size: radius * 0.07)).foregroundStyle(AppColor.outline),
                    at: point
                )
            }
        }
    }

    private func drawAspects(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let keys = placements.filter { highlighted.contains($0.planet) }
        guard keys.count > 1 else { return }
        for i in 0..<keys.count {
            for j in (i + 1)..<keys.count {
                var chord = Path()
                chord.move(to: position(for: keys[i].longitude, center: center, radius: radius))
                chord.addLine(to: position(for: keys[j].longitude, center: center, radius: radius))
                context.stroke(chord, with: .color(AppColor.champagne.opacity(0.8)), style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))
            }
        }
    }
}

/// Moon disc with illumination shading.
struct MoonPhaseView: View {
    /// 0...100
    let illumination: Int

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(AppColor.surfaceContainerLowest)
                Circle()
                    .fill(AppColor.primaryContainer)
                    .mask(
                        Circle()
                            .offset(x: -size * CGFloat(illumination) / 100)
                    )
                Circle().stroke(AppColor.primaryContainer.opacity(0.4), lineWidth: 0.75)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
