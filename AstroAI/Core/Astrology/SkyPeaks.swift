//
//  SkyPeaks.swift
//  AstroAI
//

import Foundation

/// A natal or composite point a transiting planet can perfect an aspect to.
struct SkyTarget: Hashable {
    let planet: Planet
    let longitude: Double
    let phrase: String
}

/// The moment a transiting planet perfects a major aspect to a target.
struct SkyPeak: Hashable {
    let transiting: Planet
    let target: SkyTarget
    let kind: AspectKind
    let when: Date

    var id: String { "\(transiting.rawValue)-\(target.phrase)-\(kind.rawValue)-\(Int(when.timeIntervalSince1970))" }

    /// "Venus conjunct your Moon"
    var title: String { "\(transiting.name) \(SkyPeaks.word(kind)) \(target.phrase)" }
}

/// Finds the exact hits of transiting planets against fixed ecliptic points.
enum SkyPeaks {
    static func find(
        transiters: [Planet],
        targets: [SkyTarget],
        kinds: [AspectKind],
        from start: Date,
        until end: Date,
        options: ChartOptions,
        step: TimeInterval
    ) -> [SkyPeak] {
        guard end > start, step > 0 else { return [] }
        var dates: [Date] = []
        var cursor = start
        while cursor < end {
            dates.append(cursor)
            cursor = cursor.addingTimeInterval(step)
        }
        guard dates.count >= 2 else { return [] }

        let longitudes = Dictionary(uniqueKeysWithValues: transiters.map { planet in
            (planet, dates.map { longitude(of: planet, at: $0, options: options) })
        })

        var peaks: [SkyPeak] = []
        for transiter in transiters {
            guard let series = longitudes[transiter] else { continue }
            for target in targets {
                for kind in kinds {
                    for point in points(kind, natal: target.longitude) {
                        peaks.append(contentsOf: crossings(
                            transiter: transiter,
                            target: target,
                            kind: kind,
                            point: point,
                            dates: dates,
                            series: series,
                            options: options
                        ))
                    }
                }
            }
        }

        return dedupe(peaks.sorted { $0.when < $1.when })
    }

    static func word(_ kind: AspectKind) -> String {
        switch kind {
        case .conjunction: "conjunct"
        case .sextile: "sextile"
        case .square: "square"
        case .trine: "trine"
        case .opposition: "opposite"
        }
    }

    // MARK: - Search

    private static func crossings(
        transiter: Planet,
        target: SkyTarget,
        kind: AspectKind,
        point: Double,
        dates: [Date],
        series: [Double],
        options: ChartOptions
    ) -> [SkyPeak] {
        var found: [SkyPeak] = []
        var previous = Ephemeris.signedDifference(series[0], point)
        if abs(previous) < 0.05 {
            found.append(SkyPeak(transiting: transiter, target: target, kind: kind, when: dates[0]))
        }
        for index in 1..<dates.count {
            let next = Ephemeris.signedDifference(series[index], point)
            if previous * next < 0, abs(previous) < 15, abs(next) < 15 {
                let when = refine(
                    from: dates[index - 1],
                    to: dates[index],
                    point: point,
                    planet: transiter,
                    options: options,
                    startOffset: previous
                )
                if abs(Ephemeris.signedDifference(longitude(of: transiter, at: when, options: options), point)) < 0.2 {
                    found.append(SkyPeak(transiting: transiter, target: target, kind: kind, when: when))
                }
            }
            previous = next
        }
        return found
    }

    private static func refine(
        from start: Date,
        to end: Date,
        point: Double,
        planet: Planet,
        options: ChartOptions,
        startOffset: Double
    ) -> Date {
        var lo = start.timeIntervalSinceReferenceDate
        var hi = end.timeIntervalSinceReferenceDate
        for _ in 0..<20 {
            let mid = (lo + hi) / 2
            let sample = Ephemeris.signedDifference(longitude(of: planet, at: Date(timeIntervalSinceReferenceDate: mid), options: options), point)
            if startOffset * sample > 0 {
                lo = mid
            } else {
                hi = mid
            }
        }
        return Date(timeIntervalSinceReferenceDate: hi)
    }

    /// Drops a second detection of the same contact. A real repeat (Mercury retrograde) is days away.
    private static func dedupe(_ peaks: [SkyPeak]) -> [SkyPeak] {
        var kept: [SkyPeak] = []
        for peak in peaks {
            let repeatHit = kept.contains { previous in
                previous.transiting == peak.transiting
                    && previous.target.phrase == peak.target.phrase
                    && previous.kind == peak.kind
                    && abs(previous.when.timeIntervalSince(peak.when)) < 18 * 3_600
            }
            if !repeatHit { kept.append(peak) }
        }
        return kept
    }

    private static func points(_ kind: AspectKind, natal: Double) -> [Double] {
        switch kind {
        case .conjunction: [normalize(natal)]
        case .opposition: [normalize(natal + 180)]
        case .sextile: [normalize(natal + 60), normalize(natal - 60)]
        case .square: [normalize(natal + 90), normalize(natal - 90)]
        case .trine: [normalize(natal + 120), normalize(natal - 120)]
        }
    }

    static func longitude(of planet: Planet, at date: Date, options: ChartOptions) -> Double {
        let tropical = Ephemeris.tropicalLongitude(of: planet, at: date)
        let offset = options.isSidereal ? Ephemeris.ayanamsa(at: date) : 0
        return normalize(tropical - offset)
    }

    private static func normalize(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }
}
