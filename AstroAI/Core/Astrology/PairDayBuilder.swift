//
//  PairDayBuilder.swift
//  AstroAI
//

import Foundation

/// One counted group of cross-chart aspects.
struct PairCount: Hashable, Identifiable {
    var id: String { title }
    let title: String
    let value: Int
}

/// A compatibility fact that exists in the two charts. Absent facts are not created.
struct PairFact: Hashable, Identifiable {
    let id: String
    let title: String
    let value: String
    /// A second sentence, only when an exact aspect gives one.
    let detail: String?
}

struct PairCompatibility: Hashable {
    let counts: [PairCount]
    let facts: [PairFact]
}

/// One thing today that an exact sky contact, or a real house, can support.
struct PairTodayItem: Hashable, Identifiable {
    let id: String
    let glyph: String
    let title: String
    /// The contact or house the sentence is read from.
    let basis: String
    let text: String
}

struct PairToday: Hashable {
    let dateLabel: String
    /// Moon phase, sign, and illumination. Always known from the sky.
    let skyLine: String
    /// Today's Moon sign set next to their natal Moon. Nil if either Moon is missing.
    let moonLine: String?
    let items: [PairTodayItem]
}

/// Compatibility of the two charts, plus only the parts of today that their charts actually receive.
struct PairGuide: Hashable {
    let compatibility: PairCompatibility
    let today: PairToday
}

enum PairDayBuilder {
    private static let dayMovers: Set<Planet> = [.moon, .sun, .mercury, .venus, .mars]
    private static let conductTargets: Set<Planet> = [.sun, .moon, .venus, .mars, .jupiter, .saturn]
    private static let talkTargets: Set<Planet> = [.mercury, .moon, .venus, .sun, .mars]

    static func guide(
        user: NatalChart,
        other: NatalChart,
        userName: String,
        otherName: String,
        skyOnThem: SkySnapshot,
        skyOnYou: SkySnapshot
    ) -> PairGuide {
        PairGuide(
            compatibility: compatibility(user: user, other: other, userName: userName, otherName: otherName),
            today: today(other: other, otherName: otherName, skyOnThem: skyOnThem, skyOnYou: skyOnYou)
        )
    }

    // MARK: - Compatibility

    private static func compatibility(user: NatalChart, other: NatalChart, userName: String, otherName: String) -> PairCompatibility {
        let aspects = SynastryCalculator.aspects(between: user, and: other)
        let counts = [
            PairCount(title: "Easy links", value: aspects.filter { $0.kind == .trine || $0.kind == .sextile }.count),
            PairCount(title: "Same place", value: aspects.filter { $0.kind == .conjunction }.count),
            PairCount(title: "Tense links", value: aspects.filter { $0.kind == .square || $0.kind == .opposition }.count)
        ]

        var facts: [PairFact] = []
        if let suns = luminaryFact(id: "suns", title: "Sun signs", planet: .sun, user: user, other: other, userName: userName, otherName: otherName) {
            facts.append(suns)
        }
        if let moons = luminaryFact(id: "moons", title: "Moon signs", planet: .moon, user: user, other: other, userName: userName, otherName: otherName) {
            facts.append(moons)
        }
        if let elements = elementFact(user: user, other: other, otherName: otherName) {
            facts.append(elements)
        }
        if let closest = aspects.first {
            facts.append(crossFact(id: "closest", title: "Strongest link", aspect: closest, otherName: otherName))
        }
        if let venusMars = aspects.first(where: {
            ($0.partnerPlanet == .venus && $0.userPlanet == .mars)
                || ($0.partnerPlanet == .mars && $0.userPlanet == .venus)
        }), venusMars.id != aspects.first?.id {
            facts.append(crossFact(id: "venus-mars", title: "Love and energy", aspect: venusMars, otherName: otherName))
        }
        if let mercury = aspects.first(where: { $0.partnerPlanet == .mercury && $0.userPlanet == .mercury }), mercury.id != aspects.first?.id {
            facts.append(crossFact(id: "mercuries", title: "How you talk", aspect: mercury, otherName: otherName))
        }
        return PairCompatibility(counts: counts, facts: facts)
    }

    private static func luminaryFact(
        id: String,
        title: String,
        planet: Planet,
        user: NatalChart,
        other: NatalChart,
        userName: String,
        otherName: String
    ) -> PairFact? {
        guard let yours = user.placement(planet), let theirs = other.placement(planet) else { return nil }
        let who = "\(personIs(userName, sign: yours.sign, isUser: true)). \(otherName) is \(theirs.sign.name)."
        let elements = elementSentence(yours.sign, theirs.sign)
        if let aspect = NatalChartCalculator.aspect(between: theirs.longitude, and: yours.longitude, planet, planet) {
            let about = "\(side(planet, name: userName, isUser: true)) and \(side(planet, name: otherName, isUser: false))"
            return PairFact(
                id: id,
                title: title,
                value: who,
                detail: "\(elements). \(about.capitalizedFirst) \(fit(aspect.kind)). They are \(format(aspect.orb)) apart."
            )
        }
        return PairFact(
            id: id,
            title: title,
            value: who,
            detail: "\(elements). \(signLink(yours.sign, theirs.sign))."
        )
    }

    private static func elementFact(user: NatalChart, other: NatalChart, otherName: String) -> PairFact? {
        guard let yours = user.elements.first, yours.percent > 0,
              let theirs = other.elements.first, theirs.percent > 0 else { return nil }
        return PairFact(
            id: "elements",
            title: "Main element",
            value: "You are mostly \(yours.name) (\(yours.percent)%). \(otherName) is mostly \(theirs.name) (\(theirs.percent)%).",
            detail: nil
        )
    }

    private static func crossFact(id: String, title: String, aspect: SynastryAspect, otherName: String) -> PairFact {
        let about = "\(side(aspect.partnerPlanet, name: otherName, isUser: false)) and \(side(aspect.userPlanet, name: "", isUser: true))"
        return PairFact(
            id: id,
            title: title,
            value: "\(about.capitalizedFirst) \(fit(aspect.kind)).",
            detail: "\(otherName)'s \(aspect.partnerPlanet.name) and your \(aspect.userPlanet.name) are \(format(aspect.orb)) apart."
        )
    }

    // MARK: - Today

    private static func today(
        other: NatalChart,
        otherName: String,
        skyOnThem: SkySnapshot,
        skyOnYou: SkySnapshot
    ) -> PairToday {
        let housesAreReal = other.isTimeKnown && other.hasLocation
        let conduct = skyOnThem.transits.first {
            dayMovers.contains($0.transiting) && $0.transiting != .mercury && conductTargets.contains($0.natal)
        }

        var items: [PairTodayItem] = []
        if let conduct {
            items.append(conductItem(conduct, name: otherName))
        }
        if let talk = talkItem(sky: skyOnThem, name: otherName, housesAreReal: housesAreReal) {
            items.append(talk)
        }
        if housesAreReal, let house = skyOnThem.houses[.moon], skyOnThem.houses[.mercury] != house {
            items.append(PairTodayItem(
                id: "moon-house",
                glyph: Planet.moon.glyph,
                title: "What \(otherName)'s day is about",
                basis: "From their \(AstrologyLexicon.ordinal(house)) house",
                text: "This is about \(plainHouse(house))."
            ))
        }
        if let venus = skyOnThem.transits.first(where: { $0.transiting == .venus && [.venus, .mars, .moon].contains($0.natal) }),
           !same(venus, conduct) {
            items.append(contactItem(id: "affection", title: "Closeness today", transit: venus, name: otherName))
        }
        if let mars = skyOnThem.transits.first(where: { $0.transiting == .mars && [.mars, .venus, .moon].contains($0.natal) }),
           !same(mars, conduct) {
            items.append(contactItem(id: "energy", title: "Energy today", transit: mars, name: otherName))
        }
        if let shared = sharedItem(onThem: skyOnThem, onYou: skyOnYou, name: otherName) {
            items.append(shared)
        }

        return PairToday(
            dateLabel: skyOnThem.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
            skyLine: skyLine(skyOnThem),
            moonLine: moonLine(sky: skyOnThem, other: other, name: otherName),
            items: items
        )
    }

    private static func conductItem(_ transit: NatalTransit, name: String) -> PairTodayItem {
        PairTodayItem(
            id: "conduct",
            glyph: transit.transiting.glyph,
            title: "With \(name) today",
            basis: basis(transit, name: name),
            text: todayReading(transit.kind, meaning: topic(transit.natal, name: name))
        )
    }

    private static func talkItem(sky: SkySnapshot, name: String, housesAreReal: Bool) -> PairTodayItem? {
        let mercuryHit = sky.transits.first { $0.transiting == .mercury && talkTargets.contains($0.natal) }
        let moonHit = sky.transits.first { $0.transiting == .moon && $0.natal == .mercury }
        let hit = mercuryHit ?? moonHit
        let house = housesAreReal ? sky.houses[.mercury] : nil
        guard hit != nil || house != nil else { return nil }

        var lines: [String] = []
        if let hit {
            lines.append("Talk about \(topic(hit.natal, name: name)).")
            if hit.transiting == .mercury, sky.retrogrades.contains(.mercury) {
                lines.append("Mercury is moving backward, so continue a talk you already started.")
            }
        }
        if let house {
            let theme = plainHouse(house)
            lines.append(hit == nil ? "This is about \(theme)." : "It also points to \(theme).")
        }
        let basisText = hit.map { basis($0, name: name) }
            ?? "From their \(AstrologyLexicon.ordinal(house ?? 1)) house"
        return PairTodayItem(
            id: "talk",
            glyph: Planet.mercury.glyph,
            title: "What to talk about",
            basis: basisText,
            text: lines.joined(separator: " ")
        )
    }

    private static func contactItem(id: String, title: String, transit: NatalTransit, name: String) -> PairTodayItem {
        PairTodayItem(
            id: id,
            glyph: transit.transiting.glyph,
            title: title,
            basis: basis(transit, name: name),
            text: todayReading(transit.kind, meaning: topic(transit.natal, name: name))
        )
    }

    private static func sharedItem(onThem: SkySnapshot, onYou: SkySnapshot, name: String) -> PairTodayItem? {
        let personal: Set<Planet> = [.sun, .moon, .mercury, .venus, .mars]
        guard let hit = onThem.transits.first(where: { transit in
            dayMovers.contains(transit.transiting) && personal.contains(transit.natal)
                && onYou.transits.contains { $0.transiting == transit.transiting && $0.kind == transit.kind && $0.natal == transit.natal }
        }), let yours = onYou.transits.first(where: { $0.transiting == hit.transiting && $0.kind == hit.kind && $0.natal == hit.natal }) else {
            return nil
        }
        return PairTodayItem(
            id: "shared",
            glyph: hit.transiting.glyph,
            title: "Same for both of you",
            basis: "You are \(format(yours.orb)) apart. \(name) is \(format(hit.orb)) apart.",
            text: "\(skyBody(hit.transiting)) is on both of you. \(side(hit.natal, name: "You", isUser: true).capitalizedFirst) and \(side(hit.natal, name: name, isUser: false)) \(fit(hit.kind))."
        )
    }

    private static func skyLine(_ sky: SkySnapshot) -> String {
        let sign = sky.position(of: .moon)?.sign.name ?? "an unknown sign"
        return "Today's mood follows a \(sign) style. This is a \(sky.moonPhase.name)."
    }

    private static func moonLine(sky: SkySnapshot, other: NatalChart, name: String) -> String? {
        guard let today = sky.position(of: .moon)?.sign, let natal = other.placement(.moon)?.sign else { return nil }
        return "Today may feel \(today.qualities). \(name) tends to feel things in a \(natal.qualities) way. \(elementSentence(today, natal)). \(signLink(today, natal))."
    }

    // MARK: - Wording

    /// Plain reading of the aspect. It names the planet's area and does not add a scene.
    private static func todayReading(_ kind: AspectKind, meaning: String) -> String {
        switch kind {
        case .conjunction: "Today brings \(meaning) forward. Notice it before you turn it into a plan."
        case .sextile: "A small step could help with \(meaning)."
        case .square: "Something about \(meaning) may feel slightly off. Don't force a conclusion."
        case .trine: "\(meaning.prefix(1).uppercased())\(meaning.dropFirst()) may feel a little easier today."
        case .opposition: "You and this situation may want different things around \(meaning). Both can be heard."
        }
    }

    private static func fit(_ kind: AspectKind) -> String {
        switch kind {
        case .conjunction: "sit in the same place"
        case .sextile: "help each other with a small step"
        case .square: "pull in different directions"
        case .trine: "work easily together"
        case .opposition: "stand on opposite sides"
        }
    }

    /// Short name for what a planet describes, already including "your" or the person's name.
    private static func side(_ planet: Planet, name: String, isUser: Bool) -> String {
        if isUser {
            switch planet {
            case .sun: "who you are"
            case .moon: "your feelings"
            case .mercury: "your way of talking"
            case .venus: "your way of loving"
            case .mars: "your energy"
            case .jupiter: "your wish to grow"
            case .saturn: "your sense of duty"
            default: "your \(planet.name.lowercased())"
            }
        } else {
            switch planet {
            case .sun: "who \(name) is"
            case .moon: "\(name)'s feelings"
            case .mercury: "\(name)'s way of talking"
            case .venus: "\(name)'s way of loving"
            case .mars: "\(name)'s energy"
            case .jupiter: "\(name)'s wish to grow"
            case .saturn: "\(name)'s sense of duty"
            default: "\(name)'s \(planet.name.lowercased())"
            }
        }
    }

    /// What today's line is about, named for this person.
    private static func topic(_ planet: Planet, name: String) -> String {
        switch planet {
        case .sun: "who \(name) is"
        case .moon: "\(name)'s feelings"
        case .mercury: "how \(name) talks"
        case .venus: "how \(name) loves"
        case .mars: "\(name)'s energy"
        case .jupiter: "\(name)'s wish to grow"
        case .saturn: "what \(name) takes seriously"
        default: "\(name)'s \(planet.name.lowercased())"
        }
    }

    private static func skyBody(_ planet: Planet) -> String {
        switch planet {
        case .sun, .moon: "The \(planet.name)"
        default: planet.name
        }
    }

    private static func basis(_ transit: NatalTransit, name: String) -> String {
        "\(transit.transiting.name) and \(name)'s \(transit.natal.name) are \(format(transit.orb)) apart"
    }

    private static func elementSentence(_ a: ZodiacSign, _ b: ZodiacSign) -> String {
        a.element == b.element ? "Both are \(a.element)" : "One is \(a.element), the other is \(b.element)"
    }

    /// Major link between the two signs, in plain words. Smaller links the app does not use are left as "no strong link".
    private static func signLink(_ a: ZodiacSign, _ b: ZodiacSign) -> String {
        let distance = min((a.index - b.index + 12) % 12, (b.index - a.index + 12) % 12)
        return switch distance {
        case 0: "They share a sign"
        case 2: "The signs have a small easy link"
        case 3: "The signs have a tense link"
        case 4: "The signs have an easy link"
        case 6: "The signs are opposite"
        default: "The signs have no strong link"
        }
    }

    /// Same twelve areas as the chart, in shorter words.
    private static func plainHouse(_ house: Int) -> String {
        switch house {
        case 1: "how they come across"
        case 2: "money and what they own"
        case 3: "talking, learning, and siblings"
        case 4: "home and family"
        case 5: "fun, romance, and creativity"
        case 6: "daily work and health"
        case 7: "partnership"
        case 8: "closeness and shared money"
        case 9: "travel, beliefs, and study"
        case 10: "public work and reputation"
        case 11: "friends and future plans"
        default: "time alone and rest"
        }
    }

    private static func personIs(_ name: String, sign: ZodiacSign, isUser: Bool) -> String {
        if isUser, name == "You" { return "You are \(sign.name)" }
        return "\(name) is \(sign.name)"
    }

    private static func same(_ transit: NatalTransit, _ other: NatalTransit?) -> Bool {
        guard let other else { return false }
        return transit.transiting == other.transiting && transit.natal == other.natal && transit.kind == other.kind
    }

    private static func format(_ degrees: Double) -> String {
        NatalChartCalculator.formatDegrees(degrees)
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
