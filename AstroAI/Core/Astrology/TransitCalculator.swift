//
//  TransitCalculator.swift
//  AstroAI
//

import Foundation

/// A planet in today's sky aspecting a point of the natal chart.
struct NatalTransit: Hashable {
    let transiting: Planet
    let natal: Planet
    let kind: AspectKind
    let orb: Double
    /// `true` while the aspect is still getting tighter.
    let isApplying: Bool

    var title: String { "\(transiting.name) \(kind.name.lowercased()) natal \(natal.name)" }
    var glyphLine: String { "\(transiting.glyph) \(kind.glyph) \(natal.glyph)" }
}

/// The sky at a moment, optionally related to a natal chart.
struct SkySnapshot {
    let date: Date
    let positions: [Ephemeris.Position]
    let moonPhase: MoonPhase
    /// Sorted by tightness.
    let transits: [NatalTransit]
    /// Natal house each transiting planet is passing through.
    let houses: [Planet: Int]

    func position(of planet: Planet) -> Ephemeris.Position? {
        positions.first { $0.planet == planet }
    }

    var retrogrades: [Planet] {
        positions.filter { $0.isRetrograde && $0.planet != .northNode && $0.planet != .moon && $0.planet != .sun }.map(\.planet)
    }
}

enum TransitCalculator {
    static func sky(at date: Date, natal: NatalChart?, options: ChartOptions = ChartOptions()) -> SkySnapshot {
        let positions = NatalChartCalculator.positions(at: date, options: options)
        let tomorrow = NatalChartCalculator.positions(at: date.addingTimeInterval(86_400), options: options)
        guard let natal else {
            return SkySnapshot(date: date, positions: positions, moonPhase: moonPhase(positions), transits: [], houses: [:])
        }

        var transits: [NatalTransit] = []
        for (now, next) in zip(positions, tomorrow) where now.planet != .northNode {
            for target in natal.placements where target.planet != .northNode {
                for kind in [AspectKind.conjunction, .sextile, .square, .trine, .opposition] {
                    let orb = abs(Ephemeris.separation(now.longitude, target.longitude) - Double(kind.degrees))
                    guard orb <= orbLimit(now.planet) else { continue }
                    let nextOrb = abs(Ephemeris.separation(next.longitude, target.longitude) - Double(kind.degrees))
                    transits.append(NatalTransit(transiting: now.planet, natal: target.planet, kind: kind, orb: orb, isApplying: nextOrb < orb))
                }
            }
        }

        var houses: [Planet: Int] = [:]
        for position in positions where position.planet != .northNode {
            houses[position.planet] = natal.house(for: position.longitude)
        }
        return SkySnapshot(
            date: date,
            positions: positions,
            moonPhase: moonPhase(positions),
            transits: transits.sorted { $0.orb < $1.orb },
            houses: houses
        )
    }

    static func moonPhase(at date: Date) -> MoonPhase {
        moonPhase(Ephemeris.positions(at: date))
    }

    /// Tighter orbs for fast movers so only events of the day show up.
    private static func orbLimit(_ planet: Planet) -> Double {
        switch planet {
        case .moon: 3
        case .sun, .mercury, .venus, .mars: 2
        case .jupiter, .saturn: 2
        default: 1.5
        }
    }

    private static func moonPhase(_ positions: [Ephemeris.Position]) -> MoonPhase {
        guard let sun = positions.first(where: { $0.planet == .sun }),
              let moon = positions.first(where: { $0.planet == .moon }) else {
            return MoonPhase(name: "New Moon", illumination: 0)
        }
        var elongation = (moon.longitude - sun.longitude).truncatingRemainder(dividingBy: 360)
        if elongation < 0 { elongation += 360 }
        let illumination = Int(((1 - cos(elongation * .pi / 180)) / 2 * 100).rounded())

        let name: String = switch elongation {
        case ..<10, 350...: "New Moon"
        case ..<80: "Waxing Crescent"
        case ..<100: "First Quarter"
        case ..<170: "Waxing Gibbous"
        case ..<190: "Full Moon"
        case ..<260: "Waning Gibbous"
        case ..<280: "Last Quarter"
        default: "Waning Crescent"
        }
        return MoonPhase(name: name, illumination: illumination)
    }
}

extension NatalChart {
    func house(for longitude: Double) -> Int {
        Self.house(for: longitude, cusps: cusps, sunLongitude: placement(.sun)?.longitude ?? 0)
    }

    /// House of a zodiac longitude: by cusps, or solar whole-sign houses when there are none.
    static func house(for longitude: Double, cusps: [Double], sunLongitude: Double) -> Int {
        guard cusps.count == 12 else {
            let first = ZodiacSign.containing(sunLongitude)
            return (ZodiacSign.containing(longitude).index - first.index + 12) % 12 + 1
        }
        for index in 0..<12 {
            let start = cusps[index]
            let width = (cusps[(index + 1) % 12] - start + 360).truncatingRemainder(dividingBy: 360)
            let offset = (longitude - start + 360).truncatingRemainder(dividingBy: 360)
            if offset < width { return index + 1 }
        }
        return 1
    }
}
