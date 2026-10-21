//
//  NatalChartCalculator.swift
//  AstroAI
//

import Foundation

/// Builds a full natal chart (positions, houses, aspects and interpretations) from birth data.
/// Without a birthplace there is no ascendant and houses are counted from the Sun sign (solar chart).
enum NatalChartCalculator {
    static func chart(for birth: BirthData, options: ChartOptions = ChartOptions()) -> NatalChart {
        let moment = birth.moment
        let offset = zodiacOffset(at: moment, options: options)
        let positions = positions(at: moment, options: options)

        var system = options.houseSystem
        var cusps: [Double] = []
        if let place = birth.place {
            if let placidus = Ephemeris.houseCusps(system, at: moment, latitude: place.latitude, longitude: place.longitude, zodiacOffset: offset) {
                cusps = placidus
            } else {
                // Placidus is undefined near the poles.
                system = .wholeSign
                cusps = Ephemeris.houseCusps(.wholeSign, at: moment, latitude: place.latitude, longitude: place.longitude, zodiacOffset: offset) ?? []
            }
        }

        var points = positions.map { (planet: $0.planet, longitude: $0.longitude, isRetrograde: $0.isRetrograde) }
        if let place = birth.place {
            let ascendant = Ephemeris.angles(at: moment, latitude: place.latitude, longitude: place.longitude).ascendant
            points.insert((.ascendant, normalized(ascendant - offset), false), at: 2)
        }

        let aspects = findAspects(points.map { ($0.planet, $0.longitude) })
        let sunLongitude = positions.first { $0.planet == .sun }?.longitude ?? 0
        let housesAreReliable = birth.place != nil && birth.isTimeKnown
        let placements = points.map { point in
            placement(
                planet: point.planet,
                longitude: point.longitude,
                isRetrograde: point.isRetrograde,
                house: point.planet == .ascendant ? 1 : NatalChart.house(for: point.longitude, cusps: cusps, sunLongitude: sunLongitude),
                aspects: aspects,
                housesAreReliable: housesAreReliable,
                timeIsKnown: birth.isTimeKnown
            )
        }

        let elements = shares(placements, keywords: AstrologyLexicon.elementKeywords) { $0.element }
        let modalities = shares(placements, keywords: AstrologyLexicon.modalityKeywords) { $0.modality }

        return NatalChart(
            placements: placements,
            synthesis: synthesis(placements: placements, elements: elements, aspects: aspects, timeIsKnown: birth.isTimeKnown, hasLocation: birth.place != nil),
            tension: tension(aspects: aspects, elements: elements),
            elements: elements,
            modalities: modalities,
            accuracy: birth.place == nil ? 70 : (birth.isTimeKnown ? 96 : 78),
            aspects: aspects,
            houseSystem: birth.place == nil ? "Solar Houses" : system.title,
            cusps: cusps,
            isTimeKnown: birth.isTimeKnown,
            hasLocation: birth.place != nil,
            moonDeclination: Ephemeris.declination(of: .moon, at: moment),
            obliquity: Ephemeris.obliquity(at: moment)
        )
    }

    /// Positions in the zodiac selected by `options`, with the chosen lunar node.
    static func positions(at date: Date, options: ChartOptions) -> [Ephemeris.Position] {
        let offset = zodiacOffset(at: date, options: options)
        let trueNode = options.usesTrueNode ? Ephemeris.trueNode(at: date) : nil
        return Ephemeris.positions(at: date).map { position in
            let longitude = position.planet == .northNode ? (trueNode ?? position.longitude) : position.longitude
            return Ephemeris.Position(planet: position.planet, longitude: normalized(longitude - offset), isRetrograde: position.isRetrograde)
        }
    }

    private static func zodiacOffset(at date: Date, options: ChartOptions) -> Double {
        options.isSidereal ? Ephemeris.ayanamsa(at: date) : 0
    }

    private static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    // MARK: - Aspects

    static func orbLimit(_ kind: AspectKind, _ a: Planet, _ b: Planet) -> Double {
        let personal = a.isLuminaryOrAngle || b.isLuminaryOrAngle
        switch kind {
        case .conjunction, .opposition: return personal ? 8 : 6
        case .square, .trine: return personal ? 7 : 5
        case .sextile: return personal ? 5 : 4
        }
    }

    static func aspect(between a: Double, and b: Double, _ first: Planet, _ second: Planet) -> ChartAspect? {
        let separation = Ephemeris.separation(a, b)
        for kind in [AspectKind.conjunction, .sextile, .square, .trine, .opposition] {
            let orb = abs(separation - Double(kind.degrees))
            if orb <= orbLimit(kind, first, second) {
                return ChartAspect(first: first, second: second, kind: kind, orb: orb)
            }
        }
        return nil
    }

    private static func findAspects(_ points: [(Planet, Double)]) -> [ChartAspect] {
        var result: [ChartAspect] = []
        for i in points.indices {
            for j in points.indices where j > i {
                let (a, b) = (points[i], points[j])
                // The node axis is interpreted on its own; skip its aspects to keep notes focused.
                guard a.0 != .northNode, b.0 != .northNode else { continue }
                if let aspect = aspect(between: a.1, and: b.1, a.0, b.0) {
                    result.append(aspect)
                }
            }
        }
        return result.sorted { $0.orb < $1.orb }
    }

    // MARK: - Placements

    private static func placement(planet: Planet, longitude: Double, isRetrograde: Bool, house: Int, aspects: [ChartAspect], housesAreReliable: Bool, timeIsKnown: Bool) -> PlanetPlacement {
        let sign = ZodiacSign.containing(longitude)
        let houseLabel: String = switch planet {
        case .ascendant: "Rising sign"
        case .northNode where housesAreReliable: "Houses \(AstrologyLexicon.roman(house)) • \(AstrologyLexicon.roman((house + 5) % 12 + 1))"
        case .northNode: "Direction of growth"
        case _ where housesAreReliable: "House \(AstrologyLexicon.roman(house))"
        default: "Sign"
        }

        let summary: String
        switch planet {
        case .ascendant:
            summary = "People may first notice you as \(sign.qualities)."
        case .moon where !timeIsKnown:
            summary = "The Moon describes feelings, and its sign changes during the day. Without an exact birth time, that sign is left out. Today's mood still uses the Moon in the sky, which does not need a birth time."
        case .northNode where housesAreReliable:
            summary = "A direction of growth is toward the \(sign.qualities) side of \(sign.name), especially around \(AstrologyLexicon.houseTheme(house)). This is a theme, not a deadline."
        case .northNode:
            summary = "A direction of growth is toward the \(sign.qualities) side of \(sign.name). House areas need an exact birth time and place, so those are left out."
        case _ where housesAreReliable:
            summary = "Your \(planet.meaning) tends to come out as \(sign.qualities). In the part of life about \(AstrologyLexicon.houseTheme(house)), that style shows up more often."
        default:
            summary = "Your \(planet.meaning) tends to come out as \(sign.qualities). An exact birth time and place are needed before this can name a house."
        }

        var details: [String] = []
        if let dignity = AstrologyLexicon.dignity(of: planet, in: sign) { details.append(dignity) }
        if isRetrograde, planet != .northNode {
            details.append("\(planet.name) was retrograde when you were born, so you tend to review and rethink this before you act.")
        }

        let strongest = aspects.first { $0.first == planet || $0.second == planet }
        let aspectNote = strongest.map { aspect in
            let other = aspect.first == planet ? aspect.second : aspect.first
            return "\(aspect.kind.name) \(other.name) (orb \(formatDegrees(aspect.orb))): \(AstrologyLexicon.aspectSentence(aspect.kind, planet, other))"
        } ?? ""

        return PlanetPlacement(
            planet: planet,
            sign: sign,
            degree: formatDegrees(longitude.truncatingRemainder(dividingBy: 30)) + (isRetrograde && planet != .northNode ? " ℞" : ""),
            house: houseLabel,
            title: planet == .moon && !timeIsKnown ? "Feelings · birth time needed" : "\(sign.archetype) \(planet.titleSuffix)",
            summary: summary,
            detail: details.joined(separator: " "),
            aspectNote: aspectNote,
            longitude: longitude,
            houseNumber: house,
            isRetrograde: isRetrograde
        )
    }

    /// "7° 44'"
    static func formatDegrees(_ value: Double) -> String {
        let totalMinutes = Int((value * 60).rounded())
        return "\(totalMinutes / 60)° \(String(format: "%02d", totalMinutes % 60))'"
    }

    // MARK: - Balance

    private static func shares(_ placements: [PlanetPlacement], keywords: [String: String], key: (ZodiacSign) -> String) -> [ChartShare] {
        let counted = placements.filter { ![.uranus, .neptune, .pluto, .northNode].contains($0.planet) }
        var weights: [String: Double] = [:]
        for placement in counted {
            weights[key(placement.sign), default: 0] += placement.planet.isLuminaryOrAngle ? 2 : 1
        }
        let total = weights.values.reduce(0, +)
        var result = keywords.keys.map { name in
            ChartShare(name: name, keyword: keywords[name] ?? "", percent: total > 0 ? Int((weights[name, default: 0] / total * 100).rounded()) : 0)
        }
        result.sort { $0.percent == $1.percent ? $0.name < $1.name : $0.percent > $1.percent }
        // Make rounded percentages add up to exactly 100.
        if let first = result.first {
            let drift = 100 - result.reduce(0) { $0 + $1.percent }
            result[0] = ChartShare(name: first.name, keyword: first.keyword, percent: first.percent + drift)
        }
        return result
    }

    // MARK: - Synthesis

    private static func synthesis(placements: [PlanetPlacement], elements: [ChartShare], aspects: [ChartAspect], timeIsKnown: Bool, hasLocation: Bool) -> String {
        let find = { (planet: Planet) in placements.first { $0.planet == planet } }
        guard let sun = find(.sun), let moon = find(.moon) else { return "" }

        var text = "You tend to go after things in a \(sun.sign.qualities) way."
        if timeIsKnown {
            text += " Your feelings tend to be \(moon.sign.qualities)."
        } else {
            text += " Feelings need an exact birth time before a Moon sign can be named."
        }
        if hasLocation, timeIsKnown, let rising = find(.ascendant) {
            text += " People may first notice the \(rising.sign.qualities) side of you."
        }
        if let element = elements.first {
            text += " The strongest style here is \(element.keyword.lowercased()) (\(element.percent)% \(element.name.lowercased()))."
        }
        text += timeIsKnown
            ? " In astrology that is a \(sun.sign.name) Sun and a \(moon.sign.name) Moon."
            : " In astrology that is a \(sun.sign.name) Sun. The Moon sign is left out until the birth time is known."
        if hasLocation, timeIsKnown, let rising = find(.ascendant) {
            text += " The rising sign is \(rising.sign.name)."
        } else if !hasLocation {
            text += " Without a birthplace, there is no rising sign."
        } else {
            text += " The birth time is not exact enough for a rising sign."
        }
        if let key = aspects.first(where: { $0.first.isLuminaryOrAngle || $0.second.isLuminaryOrAngle }) {
            text += " The closest link is between your \(key.first.meaning) and your \(key.second.meaning). "
            text += AstrologyLexicon.aspectSentence(key.kind, key.first, key.second)
        }
        return text
    }

    private static func tension(aspects: [ChartAspect], elements: [ChartShare]) -> String {
        if let hard = aspects.first(where: { [.square, .opposition].contains($0.kind) && !isOuterPair($0) }) {
            return "The main tension is between your \(hard.first.meaning) and your \(hard.second.meaning)."
        }
        let leading = elements.first?.keyword.lowercased() ?? "inner life"
        return "The chart is fairly smooth. It leans toward \(leading), with few hard clashes."
    }

    private static func isOuterPair(_ aspect: ChartAspect) -> Bool {
        let outer: Set<Planet> = [.uranus, .neptune, .pluto]
        return outer.contains(aspect.first) && outer.contains(aspect.second)
    }
}
