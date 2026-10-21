//
//  ConstellationBackdrop.swift
//  AstroAI
//
//  The user's Sun constellation, drawn as a quiet plate behind Today.
//  It fades before the reading, and only a few of its stars swell and settle.

import SwiftUI

struct ConstellationBackdrop: View {
    let sign: ZodiacSign

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ink = Ink.make(scheme: colorScheme, increasedContrast: contrast == .increased)
        ZStack {
            RadialGradient(
                colors: [ink.veil, .clear],
                center: UnitPoint(x: 0.56, y: 0.18),
                startRadius: 12,
                endRadius: 380
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.65), location: 0),
                        .init(color: .black, location: 0.18),
                        .init(color: .black.opacity(0.4), location: 0.5),
                        .init(color: .clear, location: 0.68)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
                Canvas { context, size in
                    let time = reduceMotion ? nil : timeline.date.timeIntervalSinceReferenceDate
                    draw(ink: ink, in: size, time: time, context: &context)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(ink: Ink, in size: CGSize, time: TimeInterval?, context: inout GraphicsContext) {
        let figure = ZodiacConstellation.figure(for: sign)
        let plot = plotRect(in: size)
        let quiet = contrast == .increased ? 0.62 : 1.0

        for mote in DustField.motes(for: sign) {
            let point = CGPoint(x: plot.minX + mote.x * plot.width, y: plot.minY + mote.y * plot.height)
            let alpha = mote.alpha * visibility(of: point, in: size) * quiet
            guard alpha > 0.01 else { continue }
            let rect = CGRect(x: point.x - mote.radius, y: point.y - mote.radius, width: mote.radius * 2, height: mote.radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(ink.star.opacity(alpha)))
        }

        for link in figure.links {
            guard figure.stars.indices.contains(link.0), figure.stars.indices.contains(link.1) else { continue }
            let start = placed(figure.stars[link.0], in: plot)
            let end = placed(figure.stars[link.1], in: plot)
            let alpha = min(visibility(of: start, in: size), visibility(of: end, in: size)) * quiet
            guard alpha > 0.02 else { continue }
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(
                path,
                with: .color(ink.line.opacity(alpha)),
                style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round)
            )
        }

        for (index, star) in figure.stars.enumerated() {
            let point = placed(star, in: plot)
            let veil = visibility(of: point, in: size)
            guard veil > 0.02 else { continue }
            let pulse = star.twinkles ? twinkle(at: time, index: index) : 0
            let tint = star.magnitude >= 0.9 ? ink.warm : ink.star
            let radius = 1.05 + star.magnitude * 1.2 + CGFloat(pulse) * 0.35
            let core = (ink.starBase + ink.starSpan * Double(star.magnitude) + ink.pulseGain * pulse) * veil * quiet

            if star.magnitude >= 0.8 || pulse > 0.04 {
                let glow = radius * (5.2 + CGFloat(pulse) * 4.5)
                let glowRect = CGRect(x: point.x - glow, y: point.y - glow, width: glow * 2, height: glow * 2)
                let glowAlpha = (0.05 + 0.08 * Double(star.magnitude) + 0.28 * pulse) * veil * quiet
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(colors: [tint.opacity(glowAlpha), .clear]),
                        center: point,
                        startRadius: radius,
                        endRadius: glow
                    )
                )
            }

            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(min(core, 0.72))))
        }
    }

    private func plotRect(in size: CGSize) -> CGRect {
        let width = min(size.width * 0.88, 460)
        let height = min(size.height * 0.44, width * 0.96)
        return CGRect(
            x: (size.width - width) * 0.58,
            y: size.height * 0.075,
            width: width,
            height: height
        )
    }

    private func placed(_ star: ZodiacConstellation.Star, in plot: CGRect) -> CGPoint {
        CGPoint(x: plot.minX + star.x * plot.width, y: plot.minY + star.y * plot.height)
    }

    /// Strongest behind the greeting, gone before the body of the reading.
    private func visibility(of point: CGPoint, in size: CGSize) -> Double {
        let y = point.y / max(size.height, 1)
        let x = point.x / max(size.width, 1)
        let vertical: Double
        if y < 0.05 {
            vertical = 0.4
        } else if y < 0.12 {
            vertical = 0.4 + (y - 0.05) / 0.07 * 0.6
        } else if y < 0.46 {
            vertical = 1
        } else if y < 0.64 {
            vertical = max(0, 1 - (y - 0.46) / 0.18)
        } else {
            vertical = 0
        }
        let horizontal = 0.78 + 0.22 * x
        return vertical * horizontal
    }

    /// A short swell every 9–15 seconds. Steady the rest of the time.
    private func twinkle(at time: TimeInterval?, index: Int) -> Double {
        guard let time else { return 0 }
        let period = 9.0 + Double(index % 5) * 1.5
        let phase = Double((index * 47) % 100) / 100
        let cycle = (time / period + phase).truncatingRemainder(dividingBy: 1)
        let t = max(0, 1 - abs(cycle - 0.22) / 0.08)
        return t * t * (3 - 2 * t)
    }
}

private struct Ink {
    var line: Color
    var star: Color
    var warm: Color
    var veil: Color
    var starBase: Double
    var starSpan: Double
    var pulseGain: Double

    static func make(scheme: ColorScheme, increasedContrast: Bool) -> Ink {
        if scheme == .dark {
            return Ink(
                line: Color(hex: 0xE4C992, opacity: increasedContrast ? 0.10 : 0.20),
                star: Color(hex: 0xF7F3EA),
                warm: Color(hex: 0xE4C992),
                veil: Color(hex: 0x243044, opacity: increasedContrast ? 0.18 : 0.42),
                starBase: increasedContrast ? 0.12 : 0.20,
                starSpan: increasedContrast ? 0.14 : 0.26,
                pulseGain: increasedContrast ? 0.12 : 0.30
            )
        }
        return Ink(
            line: Color(hex: 0x3E3047, opacity: increasedContrast ? 0.08 : 0.18),
            star: Color(hex: 0x2C261E),
            warm: Color(hex: 0x6A5124),
            veil: Color(hex: 0xE6D5C4, opacity: increasedContrast ? 0.16 : 0.5),
            starBase: increasedContrast ? 0.10 : 0.18,
            starSpan: increasedContrast ? 0.10 : 0.22,
            pulseGain: increasedContrast ? 0.08 : 0.24
        )
    }
}

// MARK: - Figures

/// Stick figures of the twelve zodiac constellations, in a unit square.
/// They follow the familiar asterisms (the sickle, the teapot, the hook), not a star atlas.
private struct ZodiacConstellation {
    struct Star {
        var x: CGFloat
        var y: CGFloat
        var magnitude: CGFloat
        var twinkles: Bool
    }

    let stars: [Star]
    let links: [(Int, Int)]

    static func figure(for sign: ZodiacSign) -> ZodiacConstellation {
        switch sign {
        case .aries: aries
        case .taurus: taurus
        case .gemini: gemini
        case .cancer: cancer
        case .leo: leo
        case .virgo: virgo
        case .libra: libra
        case .scorpio: scorpio
        case .sagittarius: sagittarius
        case .capricorn: capricorn
        case .aquarius: aquarius
        case .pisces: pisces
        }
    }

    private static func s(_ x: CGFloat, _ y: CGFloat, _ magnitude: CGFloat, twinkles: Bool = false) -> Star {
        Star(x: x, y: y, magnitude: magnitude, twinkles: twinkles)
    }

    private static let aries = ZodiacConstellation(
        stars: [
            s(0.78, 0.30, 1.0, twinkles: true),
            s(0.58, 0.44, 0.62),
            s(0.42, 0.60, 0.55, twinkles: true),
            s(0.28, 0.48, 0.34),
            s(0.16, 0.66, 0.42)
        ],
        links: [(0, 1), (1, 2), (2, 3), (3, 4)]
    )

    private static let taurus = ZodiacConstellation(
        stars: [
            s(0.18, 0.14, 0.72, twinkles: true),
            s(0.32, 0.30, 0.40),
            s(0.44, 0.42, 0.50),
            s(0.52, 0.60, 1.0, twinkles: true),
            s(0.64, 0.40, 0.46),
            s(0.74, 0.26, 0.38),
            s(0.86, 0.12, 0.74),
            s(0.40, 0.52, 0.32),
            s(0.08, 0.36, 0.34, twinkles: true),
            s(0.14, 0.28, 0.24),
            s(0.16, 0.38, 0.28),
            s(0.10, 0.42, 0.20),
            s(0.18, 0.32, 0.22)
        ],
        links: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (2, 7), (7, 3)]
    )

    private static let gemini = ZodiacConstellation(
        stars: [
            s(0.28, 0.10, 0.86, twinkles: true),
            s(0.28, 0.28, 0.40),
            s(0.28, 0.46, 0.44),
            s(0.12, 0.32, 0.32),
            s(0.42, 0.34, 0.38),
            s(0.18, 0.70, 0.40),
            s(0.38, 0.72, 0.34),
            s(0.70, 0.08, 1.0, twinkles: true),
            s(0.70, 0.26, 0.42),
            s(0.70, 0.44, 0.44),
            s(0.56, 0.32, 0.36),
            s(0.86, 0.30, 0.34, twinkles: true),
            s(0.60, 0.68, 0.38),
            s(0.80, 0.70, 0.34)
        ],
        links: [
            (0, 1), (1, 2), (1, 3), (1, 4), (2, 5), (2, 6),
            (7, 8), (8, 9), (8, 10), (8, 11), (9, 12), (9, 13),
            (4, 10)
        ]
    )

    private static let cancer = ZodiacConstellation(
        stars: [
            s(0.48, 0.18, 0.50),
            s(0.48, 0.38, 0.34),
            s(0.26, 0.58, 0.70, twinkles: true),
            s(0.72, 0.54, 0.64),
            s(0.46, 0.76, 0.86, twinkles: true),
            s(0.40, 0.46, 0.30, twinkles: true),
            s(0.46, 0.42, 0.22),
            s(0.44, 0.52, 0.20),
            s(0.52, 0.48, 0.24),
            s(0.36, 0.52, 0.18)
        ],
        links: [(0, 1), (1, 2), (1, 3), (1, 4)]
    )

    private static let leo = ZodiacConstellation(
        stars: [
            s(0.54, 0.24, 0.50),
            s(0.40, 0.12, 0.72, twinkles: true),
            s(0.26, 0.26, 0.44),
            s(0.20, 0.44, 0.40),
            s(0.30, 0.60, 0.46),
            s(0.34, 0.78, 1.0, twinkles: true),
            s(0.64, 0.36, 0.60),
            s(0.84, 0.26, 0.90, twinkles: true),
            s(0.70, 0.56, 0.46)
        ],
        links: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 8), (8, 6), (6, 7), (7, 8)]
    )

    private static let virgo = ZodiacConstellation(
        stars: [
            s(0.22, 0.16, 0.76, twinkles: true),
            s(0.40, 0.34, 0.44),
            s(0.60, 0.22, 0.56),
            s(0.48, 0.50, 0.40),
            s(0.54, 0.66, 0.50),
            s(0.62, 0.86, 1.0, twinkles: true)
        ],
        links: [(0, 1), (1, 3), (3, 4), (4, 5), (1, 2)]
    )

    private static let libra = ZodiacConstellation(
        stars: [
            s(0.30, 0.28, 0.90, twinkles: true),
            s(0.70, 0.20, 1.0, twinkles: true),
            s(0.12, 0.50, 0.40),
            s(0.22, 0.68, 0.46),
            s(0.40, 0.56, 0.34),
            s(0.62, 0.46, 0.40),
            s(0.82, 0.54, 0.52, twinkles: true),
            s(0.72, 0.72, 0.40)
        ],
        links: [(0, 1), (0, 2), (2, 3), (3, 4), (4, 0), (1, 5), (5, 6), (6, 7), (7, 1)]
    )

    private static let scorpio = ZodiacConstellation(
        stars: [
            s(0.08, 0.18, 0.44),
            s(0.22, 0.26, 0.50),
            s(0.14, 0.38, 0.38),
            s(0.32, 0.32, 0.55),
            s(0.44, 0.42, 1.0, twinkles: true),
            s(0.50, 0.54, 0.40),
            s(0.44, 0.66, 0.50),
            s(0.56, 0.78, 0.56),
            s(0.70, 0.72, 0.62, twinkles: true),
            s(0.82, 0.54, 0.92, twinkles: true),
            s(0.90, 0.68, 0.48)
        ],
        links: [(0, 1), (1, 3), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8), (8, 9), (9, 10)]
    )

    private static let sagittarius = ZodiacConstellation(
        stars: [
            s(0.46, 0.14, 0.76, twinkles: true),
            s(0.30, 0.32, 0.50),
            s(0.08, 0.44, 0.64),
            s(0.32, 0.64, 1.0, twinkles: true),
            s(0.56, 0.66, 0.54),
            s(0.78, 0.48, 0.86, twinkles: true),
            s(0.64, 0.28, 0.50)
        ],
        links: [(0, 1), (0, 6), (1, 2), (2, 3), (1, 3), (3, 4), (4, 5), (5, 6)]
    )

    private static let capricorn = ZodiacConstellation(
        stars: [
            s(0.20, 0.36, 0.55),
            s(0.40, 0.20, 0.78, twinkles: true),
            s(0.52, 0.42, 0.46),
            s(0.30, 0.54, 0.40),
            s(0.60, 0.56, 0.36),
            s(0.70, 0.70, 0.44),
            s(0.82, 0.52, 0.96, twinkles: true),
            s(0.90, 0.66, 0.40, twinkles: true)
        ],
        links: [(0, 1), (1, 2), (2, 3), (3, 0), (2, 4), (4, 5), (5, 6), (6, 7)]
    )

    private static let aquarius = ZodiacConstellation(
        stars: [
            s(0.28, 0.12, 0.86, twinkles: true),
            s(0.48, 0.10, 0.92, twinkles: true),
            s(0.38, 0.28, 0.40),
            s(0.22, 0.34, 0.30),
            s(0.54, 0.32, 0.40),
            s(0.44, 0.46, 0.38),
            s(0.62, 0.54, 0.34),
            s(0.42, 0.66, 0.52, twinkles: true),
            s(0.64, 0.76, 0.42),
            s(0.44, 0.88, 0.56)
        ],
        links: [(0, 2), (1, 2), (2, 3), (2, 4), (4, 5), (5, 6), (6, 7), (7, 8), (8, 9)]
    )

    private static let pisces = ZodiacConstellation(
        stars: [
            s(0.24, 0.16, 0.46),
            s(0.36, 0.22, 0.40),
            s(0.38, 0.36, 0.44),
            s(0.26, 0.46, 0.40),
            s(0.14, 0.38, 0.52, twinkles: true),
            s(0.12, 0.22, 0.34),
            s(0.46, 0.50, 0.34),
            s(0.58, 0.62, 1.0, twinkles: true),
            s(0.68, 0.48, 0.40),
            s(0.74, 0.38, 0.44),
            s(0.86, 0.26, 0.72, twinkles: true),
            s(0.94, 0.42, 0.40),
            s(0.84, 0.54, 0.46),
            s(0.72, 0.50, 0.34)
        ],
        links: [
            (0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0),
            (2, 6), (6, 7), (7, 8), (8, 9),
            (9, 10), (10, 11), (11, 12), (12, 13), (13, 9)
        ]
    )
}

// MARK: - Dust

private struct DustMote {
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var alpha: Double
}

private enum DustField {
    private static let stored: [ZodiacSign: [DustMote]] = {
        Dictionary(uniqueKeysWithValues: ZodiacSign.allCases.map { ($0, make($0)) })
    }()

    static func motes(for sign: ZodiacSign) -> [DustMote] {
        stored[sign] ?? []
    }

    private static func make(_ sign: ZodiacSign) -> [DustMote] {
        let figure = ZodiacConstellation.figure(for: sign)
        var rng = SplitMix64(seed: 1_700 + UInt64(ZodiacSign.allCases.firstIndex(of: sign) ?? 0))
        var motes: [DustMote] = []
        var attempts = 0
        while motes.count < 16 && attempts < 80 {
            attempts += 1
            let x = CGFloat.random(in: 0.02...0.98, using: &rng)
            let y = CGFloat.random(in: 0.02...0.96, using: &rng)
            let crowded = figure.stars.contains { hypot($0.x - x, $0.y - y) < 0.07 }
            if crowded { continue }
            motes.append(DustMote(
                x: x,
                y: y,
                radius: .random(in: 0.45...0.85, using: &rng),
                alpha: .random(in: 0.08...0.18, using: &rng)
            ))
        }
        return motes
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

#Preview("Night") {
    ConstellationBackdrop(sign: .scorpio)
        .background(AppColor.surface)
        .preferredColorScheme(.dark)
}

#Preview("Day") {
    ConstellationBackdrop(sign: .leo)
        .background(AppColor.surface)
        .preferredColorScheme(.light)
}
