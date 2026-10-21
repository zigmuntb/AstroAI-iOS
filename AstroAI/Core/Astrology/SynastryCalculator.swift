//
//  SynastryCalculator.swift
//  AstroAI
//

import Foundation

/// An aspect between the partner's planet and the user's planet, tightest first.
struct SynastryAspect: Hashable, Identifiable {
    var id: String { "\(partnerPlanet.rawValue)-\(userPlanet.rawValue)-\(kind.rawValue)" }
    let partnerPlanet: Planet
    let userPlanet: Planet
    let kind: AspectKind
    let orb: Double
}

/// Compares two natal charts and writes a synastry report from the tightest contacts.
enum SynastryCalculator {
    private static let personal: Set<Planet> = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .ascendant]

    static func report(user: NatalChart, other: NatalChart, userName: String, connection: Connection) -> SynastryReport {
        let contacts = contacts(from: other, to: user)
        let tightest = contacts.prefix(6)
        let hardCount = contacts.filter { $0.kind == .square || $0.kind == .opposition }.count
        let softCount = contacts.filter { $0.kind == .trine || $0.kind == .sextile || $0.kind == .conjunction }.count

        let userSun = user.placement(.sun)?.sign
        let otherSun = other.placement(.sun)?.sign
        let subtitle = [
            connection.kinship.title,
            userSun.map { "\($0.name) Sun" },
            otherSun.map { "\($0.name) Sun" }
        ].compactMap { $0 }.joined(separator: " • ")

        return SynastryReport(
            title: "\(userName) & \(connection.name)",
            subtitle: subtitle,
            harmony: hardCount > softCount ? "Creative Friction" : "Harmonic Concordance",
            quote: quote(from: tightest.first, userName: userName, otherName: connection.name),
            summary: summary(user: user, other: other, userName: userName, otherName: connection.name, kinship: connection.kinship, contacts: Array(tightest)),
            dimensions: dimensions(contacts: contacts, userName: userName, otherName: connection.name),
            questions: questions(kinship: connection.kinship, otherName: connection.name, contact: tightest.first),
            composite: composite(user: user, other: other)
        )
    }

    /// Midpoint composite: the chart of the relationship, not of either person.
    private static func composite(user: NatalChart, other: NatalChart) -> CompositeReading {
        var bodies: [Planet] = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn]
        if user.placement(.ascendant) != nil, other.placement(.ascendant) != nil {
            bodies.append(.ascendant)
        }

        let points: [(planet: Planet, longitude: Double)] = bodies.compactMap { planet in
            guard let ours = user.placement(planet), let theirs = other.placement(planet) else { return nil }
            return (planet, midpoint(ours.longitude, theirs.longitude))
        }

        var aspects: [ChartAspect] = []
        for i in points.indices {
            for j in points.indices where j > i {
                let (a, b) = (points[i], points[j])
                if let aspect = NatalChartCalculator.aspect(between: a.longitude, and: b.longitude, a.planet, b.planet) {
                    aspects.append(aspect)
                }
            }
        }
        aspects.sort { $0.orb < $1.orb }

        let hard = aspects.filter { $0.kind == .square || $0.kind == .opposition }.count
        let soft = aspects.filter { $0.kind == .trine || $0.kind == .sextile || $0.kind == .conjunction }.count
        let sunSign = points.first { $0.planet == .sun }.map { ZodiacSign.containing($0.longitude).name } ?? "an unknown"
        let moonSign = points.first { $0.planet == .moon }.map { ZodiacSign.containing($0.longitude).name } ?? "an unknown"

        var text = "This is the chart of the relationship itself. Its Sun is in \(sunSign) and its Moon is in \(moonSign). "
        if let tightest = aspects.first {
            text += "The closest link is \(tightest.first.name) \(tightest.kind.name.lowercased()) \(tightest.second.name) (orb \(NatalChartCalculator.formatDegrees(tightest.orb))). "
        }
        text += hard > soft
            ? "There are more hard aspects, so the relationship grows by working through friction."
            : "There are more easy aspects, so the relationship tends to feel smooth."

        return CompositeReading(
            harmony: hard > soft ? "More friction" : "More ease",
            summary: text,
            points: points.map { point in
                let sign = ZodiacSign.containing(point.longitude)
                let degree = NatalChartCalculator.formatDegrees(point.longitude.truncatingRemainder(dividingBy: 30))
                return CompositePoint(
                    glyph: point.planet.glyph,
                    name: point.planet == .ascendant ? "Ascendant" : point.planet.name,
                    placement: "\(degree) \(sign.name)"
                )
            }
        )
    }

    /// Midpoint longitudes of the relationship's own chart. Used for the week's sky on the bond.
    static func compositeLongitudes(user: NatalChart, other: NatalChart) -> [(planet: Planet, longitude: Double)] {
        [Planet.sun, .moon, .mercury, .venus, .mars].compactMap { planet in
            guard let ours = user.placement(planet)?.longitude, let theirs = other.placement(planet)?.longitude else { return nil }
            return (planet, midpoint(ours, theirs))
        }
    }

    /// Shorter-arc midpoint of two ecliptic longitudes.
    private static func midpoint(_ a: Double, _ b: Double) -> Double {
        var value = b + Ephemeris.signedDifference(a, b) / 2
        value.formTruncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }

    static func placements(from chart: NatalChart) -> [(planet: Planet, label: String, value: String)] {
        let planets: [Planet] = chart.placement(.ascendant) == nil
            ? [.sun, .moon, .venus]
            : [.sun, .moon, .ascendant]
        return planets.compactMap { planet in
            guard let placement = chart.placement(planet) else { return nil }
            return (planet, planet.name.uppercased(), "\(placement.sign.name) \(placement.degree)")
        }
    }

    // MARK: - Contacts

    struct Contact: Hashable {
        let from: Planet
        let to: Planet
        let kind: AspectKind
        let orb: Double

        var title: String { "their \(from.name) \(kind.name.lowercased()) your \(to.name)" }
    }

    private static func contacts(from other: NatalChart, to user: NatalChart) -> [Contact] {
        var result: [Contact] = []
        for theirs in other.placements where personal.contains(theirs.planet) {
            for ours in user.placements where personal.contains(ours.planet) {
                if let aspect = NatalChartCalculator.aspect(between: theirs.longitude, and: ours.longitude, theirs.planet, ours.planet) {
                    result.append(Contact(from: theirs.planet, to: ours.planet, kind: aspect.kind, orb: aspect.orb))
                }
            }
        }
        return result.sorted { $0.orb < $1.orb }
    }

    /// Every cross-chart aspect the report is written from, tightest first.
    static func aspects(between user: NatalChart, and partner: NatalChart) -> [SynastryAspect] {
        contacts(from: partner, to: user).map {
            SynastryAspect(partnerPlanet: $0.from, userPlanet: $0.to, kind: $0.kind, orb: $0.orb)
        }
    }

    // MARK: - Copy

    private static func quote(from contact: Contact?, userName: String, otherName: String) -> String {
        guard let contact else {
            return "There is no loud clash between these charts. The relationship still has its own feel."
        }
        switch contact.kind {
        case .conjunction:
            return "You may understand each other quickly around \(otherName)'s \(contact.from.meaning) and your \(contact.to.meaning)."
        case .trine, .sextile:
            return "Things flow between \(otherName)'s \(contact.from.meaning) and your \(contact.to.meaning)."
        case .square:
            return "\(otherName) pushes on your \(contact.to.meaning). That spark is also the work."
        case .opposition:
            return "\(otherName) shows you a side of yourself you are still learning to hold."
        }
    }

    private static func summary(user: NatalChart, other: NatalChart, userName: String, otherName: String, kinship: Kinship, contacts: [Contact]) -> String {
        var text = "\(userName) and \(otherName) are connected as \(kinship.title.lowercased()). "
        if let sun = user.placement(.sun)?.sign {
            text += "\(userName) tends to go after things in a \(sun.qualities) way. "
        }
        if let sun = other.placement(.sun)?.sign {
            text += "\(otherName) tends to be \(sun.qualities). "
        }
        if let first = contacts.first {
            text += "The closest pattern is between \(otherName)'s \(first.from.meaning) and your \(first.to.meaning). "
        }
        text += "This describes a pattern in the charts. It does not decide the relationship, and it does not reveal what either of you is thinking."
        return text
    }

    private static func dimensions(contacts: [Contact], userName: String, otherName: String) -> [SynastryDimension] {
        let emotional = contacts.first { [.moon, .venus].contains($0.from) || [.moon, .venus].contains($0.to) }
        let dialogue = contacts.first { $0.from == .mercury || $0.to == .mercury }
        let chemistry = contacts.first { ($0.from == .venus && $0.to == .mars) || ($0.from == .mars && $0.to == .venus) || $0.from == .mars || $0.to == .venus }
        let friction = contacts.first { $0.kind == .square || $0.kind == .opposition }

        return [
            SynastryDimension(
                icon: "drop",
                title: "Feelings",
                badge: emotional.map { $0.kind.name } ?? "Quiet",
                text: emotional.map { "\($0.title.capitalizingFirstLetter()) shapes how safe you feel together." }
                    ?? "The Moons don't connect strongly. Comfort will come from what you do together, not from the chart alone."
            ),
            SynastryDimension(
                icon: "bubble.left.and.bubble.right",
                title: "How you talk",
                badge: dialogue.map { $0.kind.name } ?? "Quiet",
                text: dialogue.map { "How you talk is shaped by \($0.title). Listen to the tone, not only the words." }
                    ?? "Mercury is quiet between you. It may take longer to find a shared way of talking, and that is fine."
            ),
            SynastryDimension(
                icon: "camera.macro",
                title: "Attraction",
                badge: chemistry.map { "\($0.from.glyph) \($0.kind.glyph) \($0.to.glyph)" } ?? "Subtle",
                text: chemistry.map { "Attraction shows up where \($0.title)." }
                    ?? "Attraction may come through friendship, work, or shared taste, not a sudden spark."
            ),
            SynastryDimension(
                icon: "exclamationmark.circle",
                title: "Friction",
                badge: friction.map { $0.kind.name } ?? "Gentle",
                text: friction.map { "The hard part is \($0.title). Name the tension early, before it becomes a story about the other person." }
                    ?? "There are few hard aspects. The risk is assuming that easy means nothing needs to be said."
            )
        ]
    }

    private static func questions(kinship: Kinship, otherName: String, contact: Contact?) -> [String] {
        var result = [
            "Where do I take too much responsibility for \(otherName)'s mood?",
            "How do we say we need space before we get irritated?"
        ]
        if let contact {
            result.insert("How does \(otherName)'s \(contact.from.name) affect my \(contact.to.meaning)?", at: 0)
        }
        if kinship == .romantic {
            result.append("What does this relationship ask me to grow, not only to receive?")
        }
        return Array(result.prefix(3))
    }
}

private extension String {
    func capitalizingFirstLetter() -> String { prefix(1).uppercased() + dropFirst() }
}
