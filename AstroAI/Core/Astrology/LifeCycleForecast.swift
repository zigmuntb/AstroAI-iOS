//
//  LifeCycleForecast.swift
//  AstroAI
//

import Foundation

/// Upcoming Saturn returns, solar eclipses and nodal sign changes, read against a natal chart.
enum LifeCycleForecast {
    private static let locale = Locale(identifier: "en_US_POSIX")
    private static let calendar = Calendar(identifier: .gregorian)

    static func events(for chart: NatalChart, born: Date?, options: ChartOptions, now: Date = .now) -> [Transit] {
        let saturn = saturnReturns(chart: chart, born: born, options: options, now: now)
        let eclipses = solarEclipses(chart: chart, born: born, options: options, now: now)
        let nodes = nodalShifts(chart: chart, born: born, options: options, now: now)
        return (saturn + eclipses + nodes).sorted { $0.date < $1.date }.map(\.transit)
    }

    // MARK: - Saturn return

    /// Exact conjunctions of the next Saturn return. A return can be exact up to three times.
    private static func saturnReturns(chart: NatalChart, born: Date?, options: ChartOptions, now: Date) -> [DatedTransit] {
        guard let natal = chart.placement(.saturn) else { return [] }
        let target = natal.longitude
        let horizon = calendar.date(byAdding: .year, value: 32, to: now) ?? now.addingTimeInterval(32 * 365.25 * 86_400)
        let hits = conjunctions(of: .saturn, with: target, from: now, until: horizon, options: options, clusterDays: 400, limit: 3)
        let house = lifeHouse(chart, longitude: target)
        let degree = natal.degree
        let reliableHouse = house

        return hits.enumerated().map { index, date in
            let retrograde = isRetrograde(.saturn, at: date, options: options)
            let exact: String = switch (index, hits.count) {
            case (0, 1): "Exact"
            case (0, _): "First exact"
            case (hits.count - 1, _): "Final exact"
            default: "Middle exact"
            }
            let motion = retrograde ? " Saturn is retrograde." : ""
            let place = reliableHouse.map {
                "your natal Saturn at \(degree) \(natal.sign.glyph), in your \(AstrologyLexicon.ordinal($0)) house: \(AstrologyLexicon.houseTheme($0))"
            } ?? "your natal Saturn at \(degree) \(natal.sign.glyph)"
            return DatedTransit(
                date: date,
                transit: Transit(
                    glyph: Planet.saturn.glyph,
                    kind: "Saturn Return",
                    date: stamp(date),
                    title: "\(exact) at \(degree) \(natal.sign.name)",
                    detail: "Saturn in the sky meets \(place).\(motion)\(agePhrase(born: born, on: date))",
                    fact: .saturnReturn(
                        sign: natal.sign,
                        degree: degree,
                        house: reliableHouse,
                        age: age(born: born, on: date),
                        index: index,
                        count: hits.count,
                        retrograde: retrograde
                    )
                )
            )
        }
    }

    // MARK: - Solar eclipses

    private static func solarEclipses(chart: NatalChart, born: Date?, options: ChartOptions, now: Date) -> [DatedTransit] {
        Ephemeris.upcomingSolarEclipses(from: now, count: 4).map { eclipse in
            let sun = longitude(of: .sun, at: eclipse.date, options: options)
            let sign = ZodiacSign.containing(sun)
            let degree = NatalChartCalculator.formatDegrees(sun.truncatingRemainder(dividingBy: 30))
            let house = lifeHouse(chart, longitude: sun)
            return DatedTransit(
                date: eclipse.date,
                transit: Transit(
                    glyph: Planet.sun.glyph,
                    kind: "Solar Eclipse",
                    date: stamp(eclipse.date),
                    title: "\(eclipse.kind) in \(sign.name)",
                    detail: "\(degree) \(sign.glyph).\(house.map { " It falls in your \(AstrologyLexicon.ordinal($0)) house: \(AstrologyLexicon.houseTheme($0))." } ?? "")\(agePhrase(born: born, on: eclipse.date))",
                    fact: .solarEclipse(
                        kind: eclipse.kind,
                        sign: sign,
                        degree: degree,
                        house: house,
                        age: age(born: born, on: eclipse.date)
                    )
                )
            )
        }
    }

    // MARK: - Nodal shifts

    /// The next two times the chosen lunar node settles into a new sign.
    private static func nodalShifts(chart: NatalChart, born: Date?, options: ChartOptions, now: Date) -> [DatedTransit] {
        var cursor = now
        var leaving = sign(of: .northNode, at: cursor, options: options)
        var found: [DatedTransit] = []
        while found.count < 2, let ingress = nextStableIngress(after: cursor, leaving: leaving, options: options) {
            let longitude = self.longitude(of: .northNode, at: ingress.date, options: options)
            let house = lifeHouse(chart, longitude: longitude)
            found.append(DatedTransit(
                date: ingress.date,
                transit: Transit(
                    glyph: Planet.northNode.glyph,
                    kind: "Nodal Shift",
                    date: stamp(ingress.date),
                    title: "North Node enters \(ingress.sign.name)",
                    detail: "It leaves \(leaving.name).\(house.map { " It enters your \(AstrologyLexicon.ordinal($0)) house: \(AstrologyLexicon.houseTheme($0))." } ?? "") The node stays in one sign for about 18 months.\(agePhrase(born: born, on: ingress.date))",
                    fact: .nodalShift(
                        entering: ingress.sign,
                        leaving: leaving,
                        house: house,
                        age: age(born: born, on: ingress.date)
                    )
                )
            ))
            cursor = ingress.date.addingTimeInterval(86_400)
            leaving = ingress.sign
        }
        return found
    }

    /// First moment the node is in a new sign and still there two months later, so a true-node wobble does not count.
    private static func nextStableIngress(after start: Date, leaving: ZodiacSign, options: ChartOptions) -> (date: Date, sign: ZodiacSign)? {
        let horizon = start.addingTimeInterval(1_100 * 86_400)
        let step: TimeInterval = 5 * 86_400
        var cursor = start
        var previous = leaving
        while cursor < horizon {
            let nextDate = min(cursor.addingTimeInterval(step), horizon)
            let next = sign(of: .northNode, at: nextDate, options: options)
            if next != previous {
                let crossing = refineIngress(from: cursor, to: nextDate, entered: next, options: options)
                let later = sign(of: .northNode, at: crossing.addingTimeInterval(60 * 86_400), options: options)
                if later != leaving {
                    return (crossing, later)
                }
            }
            previous = next
            cursor = nextDate
        }
        return nil
    }

    // MARK: - Search

    private struct DatedTransit {
        let date: Date
        let transit: Transit
    }

    /// Times `planet` conjoins `target`, keeping only the cluster that begins with the first hit.
    private static func conjunctions(
        of planet: Planet,
        with target: Double,
        from start: Date,
        until end: Date,
        options: ChartOptions,
        clusterDays: Double,
        limit: Int
    ) -> [Date] {
        let step: TimeInterval = 15 * 86_400
        var hits: [Date] = []
        var cursor = start
        var previousOffset = offset(of: planet, from: target, at: start, options: options)

        if abs(previousOffset) < 0.05 {
            hits.append(start)
            cursor = start.addingTimeInterval(40 * 86_400)
            previousOffset = offset(of: planet, from: target, at: cursor, options: options)
        }

        while cursor < end, hits.count < limit {
            if let first = hits.first, cursor.timeIntervalSince(first) > clusterDays * 86_400 { break }
            let nextDate = min(cursor.addingTimeInterval(step), end)
            let nextOffset = offset(of: planet, from: target, at: nextDate, options: options)
            if previousOffset * nextOffset < 0 {
                let hit = refineCrossing(from: cursor, to: nextDate, target: target, planet: planet, options: options, startOffset: previousOffset)
                if hit >= start.addingTimeInterval(-3_600) {
                    hits.append(hit)
                }
            }
            previousOffset = nextOffset
            cursor = nextDate
        }
        return hits
    }

    private static func refineCrossing(
        from start: Date,
        to end: Date,
        target: Double,
        planet: Planet,
        options: ChartOptions,
        startOffset: Double
    ) -> Date {
        var lo = start.timeIntervalSinceReferenceDate
        var hi = end.timeIntervalSinceReferenceDate
        for _ in 0..<24 {
            let mid = (lo + hi) / 2
            let sample = offset(of: planet, from: target, at: Date(timeIntervalSinceReferenceDate: mid), options: options)
            if startOffset * sample > 0 {
                lo = mid
            } else {
                hi = mid
            }
        }
        return Date(timeIntervalSinceReferenceDate: hi)
    }

    private static func refineIngress(from start: Date, to end: Date, entered: ZodiacSign, options: ChartOptions) -> Date {
        var lo = start.timeIntervalSinceReferenceDate
        var hi = end.timeIntervalSinceReferenceDate
        for _ in 0..<20 {
            let mid = (lo + hi) / 2
            if sign(of: .northNode, at: Date(timeIntervalSinceReferenceDate: mid), options: options) == entered {
                hi = mid
            } else {
                lo = mid
            }
        }
        return Date(timeIntervalSinceReferenceDate: hi)
    }

    private static func offset(of planet: Planet, from target: Double, at date: Date, options: ChartOptions) -> Double {
        Ephemeris.signedDifference(longitude(of: planet, at: date, options: options), target)
    }

    private static func longitude(of planet: Planet, at date: Date, options: ChartOptions) -> Double {
        let tropical = planet == .northNode && options.usesTrueNode
            ? Ephemeris.trueNode(at: date)
            : Ephemeris.tropicalLongitude(of: planet, at: date)
        let offset = options.isSidereal ? Ephemeris.ayanamsa(at: date) : 0
        var value = tropical - offset
        value.formTruncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }

    private static func sign(of planet: Planet, at date: Date, options: ChartOptions) -> ZodiacSign {
        ZodiacSign.containing(longitude(of: planet, at: date, options: options))
    }

    private static func isRetrograde(_ planet: Planet, at date: Date, options: ChartOptions) -> Bool {
        let now = longitude(of: planet, at: date, options: options)
        let later = longitude(of: planet, at: date.addingTimeInterval(43_200), options: options)
        return Ephemeris.signedDifference(later, now) < 0
    }

    private static func stamp(_ date: Date) -> String {
        date.formatted(Date.FormatStyle().month(.abbreviated).day().year().locale(locale))
    }

    private static func lifeHouse(_ chart: NatalChart, longitude: Double) -> Int? {
        guard EverydayVoice.housesAreReliable(chart) else { return nil }
        return chart.house(for: longitude)
    }

    private static func age(born: Date?, on date: Date) -> Int? {
        guard let born, let years = calendar.dateComponents([.year], from: born, to: date).year, years >= 0 else { return nil }
        return years
    }

    private static func agePhrase(born: Date?, on date: Date) -> String {
        guard let years = age(born: born, on: date) else { return "" }
        return " At age \(years)."
    }
}
