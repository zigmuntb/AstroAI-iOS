//
//  MoonMotion.swift
//  AstroAI
//

import Foundation

/// Where the Moon is now, when it changes sign, and whether it is void of course before that.
struct MoonMotion: Hashable {
    let sign: ZodiacSign
    let phaseName: String
    let ingress: Date
    let nextSign: ZodiacSign
    /// When the last major aspect before the ingress perfects. Nil when the Moon keeps making aspects up to the sign change.
    let voidBegins: Date?
    let nextPhaseName: String?
    let nextPhase: Date?

    var isVoid: Bool {
        guard let voidBegins else { return false }
        return voidBegins <= Date()
    }

    /// One line for Today: the sign change, and the void when the gap is long enough to matter.
    var line: String {
        let enters = "the Moon enters \(nextSign.name) at \(Self.clock(ingress))"
        guard let voidBegins, ingress.timeIntervalSince(voidBegins) > 45 * 60 else {
            return "Moon enters \(nextSign.name) at \(Self.clock(ingress))"
        }
        if voidBegins <= Date() {
            return "Void of course until \(enters)"
        }
        return "Void of course after \(Self.clock(voidBegins)), until \(enters)"
    }

    private static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}

enum MoonMotionCalculator {
    private static let aspected: [Planet] = [.sun, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]
    private static let kinds: [AspectKind] = [.conjunction, .sextile, .square, .trine, .opposition]
    private static let phases: [(name: String, elongation: Double)] = [
        ("New Moon", 0),
        ("First Quarter", 90),
        ("Full Moon", 180),
        ("Last Quarter", 270)
    ]

    static func make(at date: Date = .now, options: ChartOptions) -> MoonMotion {
        let sign = ZodiacSign.containing(SkyPeaks.longitude(of: .moon, at: date, options: options))
        let phase = TransitCalculator.moonPhase(at: date)
        let ingress = nextIngress(after: date, leaving: sign, options: options)
        let nextSign = ZodiacSign.containing(SkyPeaks.longitude(of: .moon, at: ingress.addingTimeInterval(60), options: options))
        let phaseHit = nextPhase(after: date, options: options)
        return MoonMotion(
            sign: sign,
            phaseName: phase.name,
            ingress: ingress,
            nextSign: nextSign,
            voidBegins: voidBegins(from: date, until: ingress, options: options),
            nextPhaseName: phaseHit?.name,
            nextPhase: phaseHit?.date
        )
    }

    // MARK: - Ingress

    /// The next time the Moon settles into a new sign. Falls back to two and a half days when the search misses.
    private static func nextIngress(after start: Date, leaving: ZodiacSign, options: ChartOptions) -> Date {
        let horizon = start.addingTimeInterval(4 * 86_400)
        let step: TimeInterval = 3 * 3_600
        var cursor = start
        while cursor < horizon {
            let next = min(cursor.addingTimeInterval(step), horizon)
            let sign = ZodiacSign.containing(SkyPeaks.longitude(of: .moon, at: next, options: options))
            if sign != leaving {
                return refineIngress(from: cursor, to: next, entered: sign, options: options)
            }
            cursor = next
        }
        return start.addingTimeInterval(2.5 * 86_400)
    }

    private static func refineIngress(from start: Date, to end: Date, entered: ZodiacSign, options: ChartOptions) -> Date {
        var lo = start.timeIntervalSinceReferenceDate
        var hi = end.timeIntervalSinceReferenceDate
        for _ in 0..<18 {
            let mid = (lo + hi) / 2
            let sign = ZodiacSign.containing(SkyPeaks.longitude(of: .moon, at: Date(timeIntervalSinceReferenceDate: mid), options: options))
            if sign == entered {
                hi = mid
            } else {
                lo = mid
            }
        }
        return Date(timeIntervalSinceReferenceDate: hi)
    }

    // MARK: - Void of course

    /// The last time the Moon perfects a major aspect before leaving the sign.
    /// Nil when an aspect is still closing as the sign changes, so there is no real void.
    private static func voidBegins(from start: Date, until ingress: Date, options: ChartOptions) -> Date? {
        guard ingress > start else { return nil }
        let step: TimeInterval = 30 * 60
        var cursor = start
        var previous = orbs(at: cursor, options: options)
        var falling = Dictionary(uniqueKeysWithValues: aspected.map { ($0, false) })
        var lastExact: Date?
        while cursor < ingress {
            let nextDate = min(cursor.addingTimeInterval(step), ingress)
            let next = orbs(at: nextDate, options: options)
            for planet in aspected {
                guard let before = previous[planet], let after = next[planet] else { continue }
                if after > before, before < 0.8, falling[planet] == true {
                    let when = refineOrb(from: cursor, to: nextDate, planet: planet, options: options)
                    if when < ingress { lastExact = max(lastExact ?? when, when) }
                }
                falling[planet] = after < before
            }
            previous = next
            cursor = nextDate
        }
        guard let lastExact else { return start }
        guard ingress.timeIntervalSince(lastExact) > 45 * 60 else { return nil }
        return lastExact
    }

    private static func orbs(at date: Date, options: ChartOptions) -> [Planet: Double] {
        let moon = SkyPeaks.longitude(of: .moon, at: date, options: options)
        var result: [Planet: Double] = [:]
        for planet in aspected {
            let longitude = SkyPeaks.longitude(of: planet, at: date, options: options)
            let separation = Ephemeris.separation(moon, longitude)
            let orb = kinds.map { abs(separation - Double($0.degrees)) }.min() ?? 180
            result[planet] = orb
        }
        return result
    }

    private static func refineOrb(from start: Date, to end: Date, planet: Planet, options: ChartOptions) -> Date {
        var lo = start.timeIntervalSinceReferenceDate
        var hi = end.timeIntervalSinceReferenceDate
        for _ in 0..<12 {
            let left = (2 * lo + hi) / 3
            let right = (lo + 2 * hi) / 3
            let leftOrb = orbs(at: Date(timeIntervalSinceReferenceDate: left), options: options)[planet] ?? 180
            let rightOrb = orbs(at: Date(timeIntervalSinceReferenceDate: right), options: options)[planet] ?? 180
            if leftOrb < rightOrb {
                hi = right
            } else {
                lo = left
            }
        }
        return Date(timeIntervalSinceReferenceDate: (lo + hi) / 2)
    }

    // MARK: - Phase

    private static func nextPhase(after start: Date, options: ChartOptions) -> (name: String, date: Date)? {
        let horizon = start.addingTimeInterval(32 * 86_400)
        let step: TimeInterval = 6 * 3_600
        var cursor = start
        var previous = elongation(at: cursor, options: options)
        var best: (name: String, date: Date)?
        while cursor < horizon {
            let nextDate = min(cursor.addingTimeInterval(step), horizon)
            let next = elongation(at: nextDate, options: options)
            let traveled = forward(from: previous, to: next)
            if traveled < 180 {
                for phase in phases {
                    let until = forward(from: previous, to: phase.elongation)
                    guard until > 1e-4, until <= traveled + 1e-4 else { continue }
                    let when = refinePhase(from: cursor, to: nextDate, elongation: phase.elongation, options: options)
                    guard when > start else { continue }
                    if best == nil || when < best!.date {
                        best = (phase.name, when)
                    }
                }
            }
            if let found = best, found.date < cursor {
                break
            }
            previous = next
            cursor = nextDate
        }
        return best
    }

    private static func refinePhase(from start: Date, to end: Date, elongation target: Double, options: ChartOptions) -> Date {
        var lo = start.timeIntervalSinceReferenceDate
        var hi = end.timeIntervalSinceReferenceDate
        for _ in 0..<18 {
            let mid = (lo + hi) / 2
            let remaining = forward(from: elongation(at: Date(timeIntervalSinceReferenceDate: mid), options: options), to: target)
            if remaining > 180 {
                hi = mid
            } else {
                lo = mid
            }
        }
        return Date(timeIntervalSinceReferenceDate: hi)
    }

    private static func elongation(at date: Date, options: ChartOptions) -> Double {
        forward(
            from: SkyPeaks.longitude(of: .sun, at: date, options: options),
            to: SkyPeaks.longitude(of: .moon, at: date, options: options)
        )
    }

    private static func forward(from start: Double, to end: Double) -> Double {
        let value = (end - start).truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
}
