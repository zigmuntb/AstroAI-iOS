//
//  SynastryWheel.swift
//  AstroAI
//

import SwiftUI

/// Bi-wheel for one pair: the user's planets on the inner ring, the partner's on the outer,
/// with the cross-chart aspects drawn between them.
struct SynastryWheel: View {
    let user: [PlanetPlacement]
    let partner: [PlanetPlacement]
    let aspects: [SynastryAspect]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let inner = marks(user, center: center, base: radius * 0.46)
            let outer = marks(partner, center: center, base: radius * 0.68)
            let glyph = max(16, radius * 0.13)

            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [AppColor.secondaryContainer.opacity(0.22), .clear],
                        center: .center, startRadius: 0, endRadius: radius
                    ))

                Canvas { context, _ in
                    drawZodiac(context: context, center: center, radius: radius)
                    drawAspects(context: context, inner: inner, outer: outer)
                }

                ForEach(inner) { mark in
                    WheelGlyph(placement: mark.placement, isPartner: false, size: glyph)
                        .position(mark.point)
                }
                ForEach(outer) { mark in
                    WheelGlyph(placement: mark.placement, isPartner: true, size: glyph)
                        .position(mark.point)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Synastry wheel")
    }

    // MARK: - Layout

    private struct Mark: Identifiable {
        var id: Planet { placement.planet }
        let placement: PlanetPlacement
        let point: CGPoint
    }

    /// Places planets on a ring and nudges neighbors apart so glyphs do not sit on each other.
    private func marks(_ placements: [PlanetPlacement], center: CGPoint, base: CGFloat) -> [Mark] {
        let sorted = placements.sorted { $0.longitude < $1.longitude }
        var occupied: [(longitude: Double, radius: CGFloat)] = []
        return sorted.map { placement in
            var ring = base
            var attempt = 0
            while occupied.contains(where: { angularGap($0.longitude, placement.longitude) < 13 && abs($0.radius - ring) < base * 0.07 }),
                  attempt < 4 {
                let step = CGFloat((attempt / 2) + 1)
                let direction: CGFloat = attempt.isMultiple(of: 2) ? -1 : 1
                ring = base + direction * step * base * 0.1
                attempt += 1
            }
            occupied.append((placement.longitude, ring))
            return Mark(placement: placement, point: position(placement.longitude, center: center, radius: ring))
        }
    }

    private func angularGap(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }

    /// 0° Aries on the left, counter-clockwise — the same orientation as the natal wheel.
    private func position(_ longitude: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = CGFloat((180 - longitude) * .pi / 180)
        return CGPoint(x: center.x + radius * cos(angle), y: center.y - radius * sin(angle))
    }

    // MARK: - Drawing

    private func drawZodiac(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let line = AppColor.hairline.opacity(0.4)
        for factor in [0.98, 0.84] {
            strokeCircle(context: context, center: center, radius: radius * factor, color: line, width: 0.75)
        }
        strokeCircle(context: context, center: center, radius: radius * 0.68, color: AppColor.secondary.opacity(0.28), width: 0.6)
        strokeCircle(context: context, center: center, radius: radius * 0.46, color: AppColor.primaryContainer.opacity(0.28), width: 0.6)

        for index in 0..<12 {
            let longitude = Double(index) * 30
            var spoke = Path()
            spoke.move(to: position(longitude, center: center, radius: radius * 0.84))
            spoke.addLine(to: position(longitude, center: center, radius: radius * 0.98))
            context.stroke(spoke, with: .color(line.opacity(0.7)), lineWidth: 0.5)

            if let sign = ZodiacSign.allCases[safe: index] {
                let point = position(longitude + 15, center: center, radius: radius * 0.91)
                context.draw(
                    Text(sign.glyph).font(.system(size: radius * 0.065)).foregroundStyle(AppColor.outline),
                    at: point
                )
            }
        }
    }

    private func drawAspects(context: GraphicsContext, inner: [Mark], outer: [Mark]) {
        for aspect in aspects {
            guard let partner = outer.first(where: { $0.placement.planet == aspect.partnerPlanet }),
                  let user = inner.first(where: { $0.placement.planet == aspect.userPlanet }) else { continue }
            var chord = Path()
            chord.move(to: partner.point)
            chord.addLine(to: user.point)
            let width: CGFloat = aspect.orb < 1.5 ? 1.15 : 0.65
            context.stroke(
                chord,
                with: .color(lineColor(aspect.kind).opacity(0.85)),
                style: StrokeStyle(lineWidth: width, lineCap: .round)
            )
        }
    }

    private func strokeCircle(context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, width: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: width)
    }

    private func lineColor(_ kind: AspectKind) -> Color {
        switch kind {
        case .conjunction: AppColor.champagne
        case .trine, .sextile: AppColor.sage
        case .square, .opposition: AppColor.dustyRose
        }
    }
}

private struct WheelGlyph: View {
    let placement: PlanetPlacement
    let isPartner: Bool
    var size: CGFloat

    var body: some View {
        Text(placement.planet == .ascendant ? "ASC" : placement.planet.glyph)
            .font(.system(size: placement.planet == .ascendant ? size * 0.32 : size * 0.46, design: .serif))
            .foregroundStyle(isPartner ? AppColor.secondary : AppColor.primaryContainer)
            .frame(width: size, height: size)
            .background(isPartner ? AppColor.secondaryContainer : AppColor.surfaceContainerLowest, in: .circle)
            .overlay(Circle().stroke((isPartner ? AppColor.secondary : AppColor.primaryContainer).opacity(0.45), lineWidth: 0.75))
    }
}
