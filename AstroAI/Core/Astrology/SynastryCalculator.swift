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
            questions: questions(kinship: connection.kinship, otherName: connection.name, contact: tightest.first)
        )
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
            return "Two charts meeting without a loud aspect still have a weather of their own."
        }
        switch contact.kind {
        case .conjunction:
            return "Where \(otherName)'s \(contact.from.name.lowercased()) sits on your \(contact.to.name.lowercased()), the two of you speak one language."
        case .trine, .sextile:
            return "An easy current runs between \(otherName)'s \(contact.from.meaning) and your \(contact.to.meaning)."
        case .square:
            return "The spark between you is also the work: \(otherName) presses on your \(contact.to.meaning)."
        case .opposition:
            return "You see in \(otherName) what you are learning to hold in yourself."
        }
    }

    private static func summary(user: NatalChart, other: NatalChart, userName: String, otherName: String, kinship: Kinship, contacts: [Contact]) -> String {
        let userSun = user.placement(.sun)?.sign.name ?? "your"
        let otherSun = other.placement(.sun)?.sign.name ?? otherName
        var text = "\(userName)'s \(userSun) Sun meets \(otherName)'s \(otherSun) Sun in a \(kinship.title.lowercased()) bond. "
        if let first = contacts.first {
            text += "The tightest contact is \(first.title) (orb \(NatalChartCalculator.formatDegrees(first.orb))). "
        }
        text += "Read the geometry as a conversation, not a verdict: each of you remains the author of how it is lived."
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
                title: "Emotional Resonance",
                badge: emotional.map { $0.kind.name } ?? "Quiet",
                text: emotional.map { "\($0.title.capitalizingFirstLetter()) colors how safe you feel together." }
                    ?? "The Moons do not speak loudly here. Comfort will be built in practice, not assumed from the chart."
            ),
            SynastryDimension(
                icon: "bubble.left.and.bubble.right",
                title: "Dialectic & Dialogue",
                badge: dialogue.map { $0.kind.name } ?? "Uncharted",
                text: dialogue.map { "Conversation is shaped by \($0.title): listen for the tone as much as the words." }
                    ?? "Mercury is quiet between you. Shared language may take longer, and that slowness can be a kindness."
            ),
            SynastryDimension(
                icon: "camera.macro",
                title: "Creative & Sensual Chemistry",
                badge: chemistry.map { "\($0.from.glyph) \($0.kind.glyph) \($0.to.glyph)" } ?? "Subtle",
                text: chemistry.map { "Attraction gathers where \($0.title)." }
                    ?? "Desire may arrive through friendship, work or shared taste rather than an obvious spark."
            ),
            SynastryDimension(
                icon: "exclamationmark.circle",
                title: "Growth & Friction Points",
                badge: friction.map { $0.kind.name } ?? "Gentle",
                text: friction.map { "The growth edge is \($0.title). Name the tension early so it does not harden into a story about the other person." }
                    ?? "Few hard aspects. Watch for the quieter risk: assuming ease means nothing needs to be said."
            )
        ]
    }

    private static func questions(kinship: Kinship, otherName: String, contact: Contact?) -> [String] {
        var result = [
            "Where do I feel most responsible for \(otherName)'s peace?",
            "How do we signal when we need solitude before irritation speaks?"
        ]
        if let contact {
            result.insert("How does \(otherName)'s \(contact.from.name) touch my \(contact.to.meaning)?", at: 0)
        }
        if kinship == .romantic {
            result.append("What does this bond ask me to grow, not just to receive?")
        }
        return Array(result.prefix(3))
    }
}

private extension String {
    func capitalizingFirstLetter() -> String { prefix(1).uppercased() + dropFirst() }
}
