//
//  StarfieldBackground.swift
//  AstroAI
//
//  A fixed night sky. Date changes rotate it around the screen center;
//  it does not drift while the wheels are still.

import SwiftUI

struct StarfieldBackground: View {
    /// Unwrapped rotation in degrees. Year changes move this the most.
    var angle: Double
    var animatesRotation: Bool
    var twinkles: Bool

    var body: some View {
        GeometryReader { geo in
            let side = hypot(geo.size.width, geo.size.height) + 4
            ZStack {
                sky
                vignette

                layer(side: side, multiplier: 0.36) {
                    NebulaVeil()
                    MilkyBand()
                }
                layer(side: side, multiplier: 0.52) {
                    StarChart()
                    StarCanvas(stars: StarCatalog.distant)
                }
                layer(side: side, multiplier: 0.74) {
                    ConstellationLines()
                }
                layer(side: side, multiplier: 1) {
                    StarCanvas(stars: StarCatalog.primary)
                    if twinkles {
                        TwinklingStars(stars: StarCatalog.bright)
                    } else {
                        StarCanvas(stars: StarCatalog.bright)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func layer<Content: View>(side: CGFloat, multiplier: Double, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            content()
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(angle * multiplier))
        .animation(animatesRotation ? .smooth(duration: 0.42) : nil, value: angle)
    }

    private var sky: some View {
        LinearGradient(
            colors: [
                Color(hex: 0x070A14),
                Color(hex: 0x10182C),
                Color(hex: 0x0A0C18),
                Color(hex: 0x06070E)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var vignette: some View {
        ZStack {
            RadialGradient(
                colors: [.clear, Color(hex: 0x05060C).opacity(0.55)],
                center: .center,
                startRadius: 40,
                endRadius: 520
            )
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x070A14).opacity(0.72), location: 0),
                    .init(color: .clear, location: 0.22),
                    .init(color: .clear, location: 0.62),
                    .init(color: Color(hex: 0x070A14).opacity(0.82), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Stars

private struct StarPoint: Identifiable {
    let id: Int
    /// Position in the unit disk, −1...1.
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let alpha: Double
    let tint: StarTint
    let phase: Double
}

private enum StarTint {
    case white, champagne, rose

    var color: Color {
        switch self {
        case .white: Color(hex: 0xF7F4EE)
        case .champagne: Color(hex: 0xE4C992)
        case .rose: Color(hex: 0xE7B4B2)
        }
    }
}

private enum StarCatalog {
    static let distant = make(count: 240, seed: 11, radius: 0.35...0.85, alpha: 0.18...0.5)
    static let primary = make(count: 150, seed: 42, radius: 0.55...1.35, alpha: 0.4...0.95)
    static let bright = make(count: 22, seed: 88, radius: 1.15...1.9, alpha: 0.75...1)

    private static func make(
        count: Int,
        seed: UInt64,
        radius: ClosedRange<CGFloat>,
        alpha: ClosedRange<Double>
    ) -> [StarPoint] {
        var rng = SplitMix64(seed: seed)
        var stars: [StarPoint] = []
        var attempts = 0
        while stars.count < count && attempts < count * 30 {
            attempts += 1
            let x = CGFloat.random(in: -1...1, using: &rng)
            let y = CGFloat.random(in: -1...1, using: &rng)
            guard x * x + y * y <= 1 else { continue }
            let roll = Double.random(in: 0...1, using: &rng)
            let tint: StarTint = roll > 0.93 ? .champagne : (roll > 0.88 ? .rose : .white)
            stars.append(StarPoint(
                id: stars.count,
                x: x,
                y: y,
                radius: .random(in: radius, using: &rng),
                alpha: .random(in: alpha, using: &rng),
                tint: tint,
                phase: .random(in: 0...(2 * .pi), using: &rng)
            ))
        }
        return stars
    }
}

private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private struct StarCanvas: View {
    let stars: [StarPoint]

    var body: some View {
        Canvas { context, size in
            draw(stars, in: size, time: nil, context: &context)
        }
    }
}

private struct TwinklingStars: View {
    let stars: [StarPoint]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { timeline in
            Canvas { context, size in
                draw(stars, in: size, time: timeline.date.timeIntervalSinceReferenceDate, context: &context)
            }
        }
    }
}

private func draw(_ stars: [StarPoint], in size: CGSize, time: TimeInterval?, context: inout GraphicsContext) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let reach = size.width / 2
    for star in stars {
        let point = CGPoint(x: center.x + star.x * reach, y: center.y + star.y * reach)
        var alpha = star.alpha
        if let time {
            alpha *= 0.62 + 0.38 * (0.5 + 0.5 * sin(time * 1.15 + star.phase))
        }
        let color = star.tint.color.opacity(alpha)
        if star.radius >= 1.1 {
            let glow = star.radius * 5
            let glowRect = CGRect(x: point.x - glow, y: point.y - glow, width: glow * 2, height: glow * 2)
            context.fill(
                Path(ellipseIn: glowRect),
                with: .radialGradient(
                    Gradient(colors: [star.tint.color.opacity(alpha * 0.45), .clear]),
                    center: point,
                    startRadius: 0,
                    endRadius: glow
                )
            )
        }
        let rect = CGRect(
            x: point.x - star.radius,
            y: point.y - star.radius,
            width: star.radius * 2,
            height: star.radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }
}

// MARK: - Chart dressing

private struct StarChart: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2
            let ink = Color(hex: 0xF7F4EE).opacity(0.07)
            for factor in [0.28, 0.48, 0.7, 0.9] {
                let r = radius * factor
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(ink), lineWidth: 0.6)
            }
            for index in 0..<12 {
                let theta = Double(index) * .pi / 6
                var spoke = Path()
                spoke.move(to: center)
                spoke.addLine(to: CGPoint(
                    x: center.x + radius * 0.9 * CGFloat(cos(theta)),
                    y: center.y + radius * 0.9 * CGFloat(sin(theta))
                ))
                context.stroke(spoke, with: .color(ink.opacity(0.8)), lineWidth: 0.4)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ConstellationLines: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let reach = size.width / 2
            let ink = Color(hex: 0xE4C992).opacity(0.22)
            for figure in ConstellationFigures.all {
                var path = Path()
                for (index, point) in figure.enumerated() {
                    let placed = CGPoint(x: center.x + point.x * reach, y: center.y + point.y * reach)
                    if index == 0 {
                        path.move(to: placed)
                    } else {
                        path.addLine(to: placed)
                    }
                }
                context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 0.7, lineCap: .round, lineJoin: .round))
                for point in figure {
                    let placed = CGPoint(x: center.x + point.x * reach, y: center.y + point.y * reach)
                    let dot = CGRect(x: placed.x - 1.3, y: placed.y - 1.3, width: 2.6, height: 2.6)
                    context.fill(Path(ellipseIn: dot), with: .color(Color(hex: 0xF7F4EE).opacity(0.55)))
                }
            }
        }
    }
}

private enum ConstellationFigures {
    static let all: [[CGPoint]] = [
        [CGPoint(x: -0.62, y: -0.38), CGPoint(x: -0.48, y: -0.22), CGPoint(x: -0.3, y: -0.28), CGPoint(x: -0.18, y: -0.08), CGPoint(x: -0.34, y: 0.02)],
        [CGPoint(x: 0.22, y: -0.55), CGPoint(x: 0.34, y: -0.4), CGPoint(x: 0.5, y: -0.46), CGPoint(x: 0.58, y: -0.28)],
        [CGPoint(x: 0.42, y: 0.18), CGPoint(x: 0.28, y: 0.32), CGPoint(x: 0.12, y: 0.28), CGPoint(x: 0.02, y: 0.44), CGPoint(x: -0.12, y: 0.4), CGPoint(x: -0.08, y: 0.22), CGPoint(x: 0.1, y: 0.16)],
        [CGPoint(x: -0.55, y: 0.42), CGPoint(x: -0.4, y: 0.55), CGPoint(x: -0.22, y: 0.48), CGPoint(x: -0.16, y: 0.64)]
    ]
}

private struct NebulaVeil: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let reach = size.width / 2
            fill(
                context: &context,
                center: CGPoint(x: center.x - reach * 0.28, y: center.y - reach * 0.18),
                radius: reach * 0.42,
                color: Color(hex: 0x3A2E62)
            )
            fill(
                context: &context,
                center: CGPoint(x: center.x + reach * 0.34, y: center.y + reach * 0.16),
                radius: reach * 0.36,
                color: Color(hex: 0x1E3358)
            )
        }
    }

    private func fill(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [color.opacity(0.45), color.opacity(0.08), .clear]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }
}

private struct MilkyBand: View {
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.clear, Color(hex: 0xC9D0EA).opacity(0.14), Color(hex: 0xE4C992).opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .rotationEffect(.degrees(-32))
            .blur(radius: 22)
            .opacity(0.85)
    }
}
