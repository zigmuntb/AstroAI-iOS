//
//  ExploreSkyBackdrop.swift
//  AstroAI
//
//  A quiet astronomical plate behind Explore: a few orbital arcs,
//  a sparse star field, and two small figures. It is not the user's
//  constellation — that plate belongs to Today.
//

import SwiftUI

struct ExploreSkyBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let ink = Plate.make(scheme: colorScheme, increasedContrast: contrast == .increased)
        let quiet = contrast == .increased
        ZStack {
            if !reduceTransparency && !quiet {
                RadialGradient(
                    colors: [ink.wash, .clear],
                    center: UnitPoint(x: 0.92, y: 0.02),
                    startRadius: 10,
                    endRadius: 460
                )
            }

            Canvas { context, size in
                draw(ink: ink, quiet: quiet, in: size, context: &context)
            }
        }
        .mask(verticalFade)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Stronger near the top and bottom edges, quieter through the reading band.
    private var verticalFade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.85), location: 0),
                .init(color: .black.opacity(0.45), location: 0.22),
                .init(color: .black.opacity(0.28), location: 0.55),
                .init(color: .black.opacity(0.5), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func draw(ink: Plate, quiet: Bool, in size: CGSize, context: inout GraphicsContext) {
        let gain = quiet ? 0.45 : 1.0
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        for curve in Plate.orbits {
            var path = Path()
            path.move(to: point(curve.start, width: width, height: height))
            path.addQuadCurve(
                to: point(curve.end, width: width, height: height),
                control: point(curve.control, width: width, height: height)
            )
            context.stroke(
                path,
                with: .color(ink.line.opacity(curve.alpha * gain)),
                style: StrokeStyle(lineWidth: curve.width, lineCap: .round)
            )
        }

        for figure in Plate.figures {
            for link in figure.links {
                guard figure.stars.indices.contains(link.0), figure.stars.indices.contains(link.1) else { continue }
                var path = Path()
                path.move(to: point(figure.stars[link.0], width: width, height: height))
                path.addLine(to: point(figure.stars[link.1], width: width, height: height))
                context.stroke(
                    path,
                    with: .color(ink.line.opacity(0.22 * gain)),
                    style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
                )
            }
        }

        let marks = Plate.figures.flatMap(\.stars) + Plate.dust
        for star in marks {
            let origin = point(star, width: width, height: height)
            let tint = star.warm ? ink.warm : ink.star
            let radius = star.radius
            let rect = CGRect(x: origin.x - radius, y: origin.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(min(star.alpha * gain, 0.55))))
        }
    }

    private func point(_ mark: Plate.Mark, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: mark.x * width, y: mark.y * height)
    }
}

private struct Plate {
    var line: Color
    var star: Color
    var warm: Color
    var wash: Color

    struct Mark {
        var x: CGFloat
        var y: CGFloat
        var radius: CGFloat = 1.1
        var alpha: Double = 0.34
        var warm: Bool = false
    }

    struct Orbit {
        var start: Mark
        var control: Mark
        var end: Mark
        var alpha: Double
        var width: CGFloat
    }

    struct Figure {
        var stars: [Mark]
        var links: [(Int, Int)]
    }

    static func make(scheme: ColorScheme, increasedContrast: Bool) -> Plate {
        if scheme == .dark {
            return Plate(
                line: Color(hex: 0xE4C992, opacity: increasedContrast ? 0.16 : 0.55),
                star: Color(hex: 0xF7F3EA),
                warm: Color(hex: 0xE4C992),
                wash: Color(hex: 0x243044, opacity: increasedContrast ? 0.12 : 0.55)
            )
        }
        return Plate(
            line: Color(hex: 0x3E3047, opacity: increasedContrast ? 0.14 : 0.45),
            star: Color(hex: 0x2C261E),
            warm: Color(hex: 0x6A5124),
            wash: Color(hex: 0xE6D5C4, opacity: increasedContrast ? 0.12 : 0.7)
        )
    }

    static let orbits: [Orbit] = [
        Orbit(
            start: Mark(x: -0.08, y: 0.20),
            control: Mark(x: 0.46, y: 0.01),
            end: Mark(x: 1.06, y: 0.16),
            alpha: 0.20,
            width: 0.7
        ),
        Orbit(
            start: Mark(x: 0.62, y: -0.04),
            control: Mark(x: 0.98, y: 0.22),
            end: Mark(x: 1.12, y: 0.58),
            alpha: 0.14,
            width: 0.6
        ),
        Orbit(
            start: Mark(x: -0.06, y: 0.64),
            control: Mark(x: 0.08, y: 0.92),
            end: Mark(x: 0.48, y: 1.02),
            alpha: 0.12,
            width: 0.6
        )
    ]

    static let figures: [Figure] = [
        Figure(
            stars: [
                Mark(x: 0.76, y: 0.07, radius: 1.35, alpha: 0.42, warm: true),
                Mark(x: 0.84, y: 0.12, radius: 0.9, alpha: 0.28),
                Mark(x: 0.93, y: 0.08, radius: 1.15, alpha: 0.36),
                Mark(x: 0.87, y: 0.18, radius: 0.85, alpha: 0.24)
            ],
            links: [(0, 1), (1, 2), (1, 3)]
        ),
        Figure(
            stars: [
                Mark(x: 0.07, y: 0.76, radius: 1.05, alpha: 0.30),
                Mark(x: 0.15, y: 0.82, radius: 1.3, alpha: 0.38, warm: true),
                Mark(x: 0.09, y: 0.90, radius: 0.8, alpha: 0.22),
                Mark(x: 0.22, y: 0.87, radius: 0.95, alpha: 0.26)
            ],
            links: [(0, 1), (1, 2), (1, 3)]
        )
    ]

    /// A handful of field stars, kept out of a dense cluster.
    static let dust: [Mark] = [
        Mark(x: 0.12, y: 0.11, radius: 0.7, alpha: 0.16),
        Mark(x: 0.28, y: 0.06, radius: 0.55, alpha: 0.12),
        Mark(x: 0.48, y: 0.14, radius: 0.8, alpha: 0.18),
        Mark(x: 0.18, y: 0.28, radius: 0.5, alpha: 0.10),
        Mark(x: 0.90, y: 0.30, radius: 0.65, alpha: 0.14),
        Mark(x: 0.08, y: 0.46, radius: 0.6, alpha: 0.12),
        Mark(x: 0.94, y: 0.48, radius: 0.75, alpha: 0.16),
        Mark(x: 0.72, y: 0.62, radius: 0.55, alpha: 0.11),
        Mark(x: 0.36, y: 0.78, radius: 0.7, alpha: 0.13),
        Mark(x: 0.58, y: 0.88, radius: 0.6, alpha: 0.12),
        Mark(x: 0.84, y: 0.80, radius: 0.9, alpha: 0.18, warm: true),
        Mark(x: 0.30, y: 0.94, radius: 0.5, alpha: 0.10)
    ]
}

#Preview("Night") {
    ExploreSkyBackdrop()
        .background(AppColor.surface)
        .preferredColorScheme(.dark)
}

#Preview("Day") {
    ExploreSkyBackdrop()
        .background(AppColor.surface)
        .preferredColorScheme(.light)
}
