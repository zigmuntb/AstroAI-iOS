//
//  DailyReadingBuilder.swift
//  AstroAI
//

import Foundation

/// Builds today's reading from the natal chart and the current sky, not from mock copy.
enum DailyReadingBuilder {
    static func reading(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot) -> DailyReading {
        let moon = sky.position(of: .moon)
        let moonSign = moon?.sign ?? .gemini
        let transit = sky.keyTransit
        let atmosphere = atmosphere(phase: sky.moonPhase, moonSign: moonSign, transit: transit)
        let focus = profile?.personal?.currentFocus?.trimmingCharacters(in: .whitespacesAndNewlines)

        return DailyReading(
            date: sky.date,
            moonPhase: sky.moonPhase.name,
            moonSign: moonSign,
            moonIllumination: sky.moonPhase.illumination,
            atmosphere: atmosphere,
            ephemerisTitle: transit.map { "\($0.transiting.name) \($0.kind.name) Natal \($0.natal.name)" } ?? "\(sky.moonPhase.name) in \(moonSign.name)",
            ephemerisText: ephemerisText(sky: sky, chart: chart, transit: transit),
            transitLine: transit.map { "\($0.transiting.glyph) \($0.kind.glyph) natal \($0.natal.glyph)" } ?? "☽ in \(moonSign.glyph)",
            orb: transit.map { NatalChartCalculator.formatDegrees($0.orb) } ?? "—",
            synthesisTitle: synthesisTitle(moonSign: moonSign, transit: transit, focus: focus),
            synthesisText: synthesisText(profile: profile, chart: chart, moonSign: moonSign, transit: transit, focus: focus),
            imageCaption: "\(sky.moonPhase.name) • \(moonSign.name) Moon",
            areas: areas(profile: profile, chart: chart, sky: sky, transit: transit),
            tendencies: tendencies(chart: chart, moonSign: moonSign, transit: transit),
            dials: LifeDialBuilder.dials(profile: profile, chart: chart, sky: sky),
            moods: moods(moonSign: moonSign, transit: transit),
            oracleQuestions: questions(profile: profile, chart: chart, moonSign: moonSign, transit: transit)
        )
    }

    static func journalPrompt(chart: NatalChart?, sky: SkySnapshot) -> JournalPrompt {
        if let transit = sky.keyTransit {
            return JournalPrompt(
                context: "Ephemeris Prompt · \(transit.transiting.glyph) \(transit.kind.glyph) \(transit.natal.glyph)",
                question: "Where is \(transit.transiting.name) asking you to notice your \(transit.natal.meaning) today?",
                note: transit.sentence
            )
        }
        let moon = sky.position(of: .moon)?.sign.name ?? "the current"
        return JournalPrompt(
            context: "Ephemeris Prompt · \(sky.moonPhase.name)",
            question: "What does the \(moon) Moon want you to feel, rather than solve?",
            note: "The Moon is \(sky.moonPhase.illumination)% illuminated. Let the day's emotional weather speak before you interpret it."
        )
    }

    // MARK: - Copy

    private static func atmosphere(phase: MoonPhase, moonSign: ZodiacSign, transit: NatalTransit?) -> String {
        if let transit, transit.orb < 1 {
            return "\(transit.kind.name) in the air"
        }
        return "\(phase.name.replacingOccurrences(of: " Moon", with: "")) & \(moonSign.element)"
    }

    private static func ephemerisText(sky: SkySnapshot, chart: NatalChart?, transit: NatalTransit?) -> String {
        var parts: [String] = []
        if let transit {
            parts.append(transit.sentence)
            if let house = sky.houses[transit.transiting] {
                parts.append("This is moving through your \(AstrologyLexicon.ordinal(house)) house of \(AstrologyLexicon.houseTheme(house)).")
            }
        } else if let moon = sky.position(of: .moon) {
            parts.append("The Moon travels through \(moon.sign.name), coloring the day with a \(moon.sign.qualities) mood.")
        }
        if let retro = sky.retrogrades.first {
            parts.append("\(retro.name) is retrograde: its usual themes of \(retro.meaning) turn inward for review.")
        }
        return parts.joined(separator: " ")
    }

    private static func synthesisTitle(moonSign: ZodiacSign, transit: NatalTransit?, focus: String?) -> String {
        if focus?.isEmpty == false {
            return "Hold today's sky against what is already on your mind."
        }
        if let transit {
            return "Let \(transit.transiting.name) speak to your \(transit.natal.meaning.split(separator: " ").first ?? "path")."
        }
        return "Move at the pace of a \(moonSign.name) Moon."
    }

    private static func synthesisText(profile: UserProfile?, chart: NatalChart?, moonSign: ZodiacSign, transit: NatalTransit?, focus: String?) -> String {
        var text = ""
        if let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            text += "\(name), "
        }
        if let sun = chart?.placement(.sun), let moon = chart?.placement(.moon) {
            text += "your \(sun.sign.name) Sun and \(moon.sign.name) Moon meet a \(moonSign.name) Moon in the sky. "
        } else {
            text += "today's \(moonSign.name) Moon sets the emotional weather. "
        }
        if let transit {
            text += transit.sentence + " "
        }
        if let focus, !focus.isEmpty {
            text += "You named this as being on your mind: \"\(focus)\". Read the day through that lens, not as a verdict."
        } else if let intention = profile?.intentions.first {
            text += "Keep your aim in view: \(intention.title.lowercased())."
        } else {
            text += "Notice what wants attention without forcing a conclusion."
        }
        return text
    }

    private static func areas(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot, transit: NatalTransit?) -> [LifeArea] {
        let loveHouse = sky.houses[.venus] ?? chart?.placement(.venus)?.houseNumber
        let workHouse = sky.houses[.saturn] ?? sky.houses[.sun] ?? chart?.placement(.sun)?.houseNumber
        let innerHouse = sky.houses[.moon] ?? chart?.placement(.moon)?.houseNumber

        return [
            LifeArea(
                icon: "heart",
                title: "Love & Rapport",
                text: areaText(theme: loveHouse.map(AstrologyLexicon.houseTheme), transit: transit, fallback: "Offer presence before interpretation. Warmth lands better than analysis today.")
            ),
            LifeArea(
                icon: "pencil.and.scribble",
                title: "Work & Vocation",
                text: areaText(theme: workHouse.map(AstrologyLexicon.houseTheme), transit: transit, fallback: "Choose one task that can be finished well. Breadth scatters; depth accumulates.")
            ),
            LifeArea(
                icon: "leaf",
                title: "Inner World",
                text: areaText(theme: innerHouse.map(AstrologyLexicon.houseTheme), transit: transit, fallback: "Track the body first: jaw, breath, shoulders. The chart speaks through sensation before it speaks through thought.")
            )
        ]
    }

    private static func areaText(theme: String?, transit: NatalTransit?, fallback: String) -> String {
        if let transit, let theme {
            return "Today's \(transit.transiting.name) \(transit.verb) your \(transit.natal.meaning), especially around \(theme)."
        }
        if let theme {
            return "Attention gathers around \(theme). Move gently there."
        }
        return fallback
    }

    private static func tendencies(chart: NatalChart?, moonSign: ZodiacSign, transit: NatalTransit?) -> [Tendency] {
        let fire = Double(chart?.elements.first { $0.name == "Fire" }?.percent ?? 25) / 100
        let water = Double(chart?.elements.first { $0.name == "Water" }?.percent ?? 25) / 100
        let transitBoost = transit.map { $0.kind == .square || $0.kind == .opposition ? 0.15 : 0.05 } ?? 0
        return [
            Tendency(title: "Focus", value: moonSign.element == "Earth" ? "Steady" : "Fluid", level: min(0.95, 0.45 + fire * 0.4 + transitBoost)),
            Tendency(title: "Connection", value: moonSign.element == "Water" ? "Tender" : "Curious", level: min(0.95, 0.4 + water * 0.45)),
            Tendency(title: "Reflection", value: skyReflection(transit), level: min(0.95, 0.55 + ((transit?.orb ?? 2) < 1 ? 0.25 : 0.1)))
        ]
    }

    private static func skyReflection(_ transit: NatalTransit?) -> String {
        guard let transit else { return "Open" }
        switch transit.kind {
        case .square, .opposition: return "Activated"
        case .trine, .sextile: return "Easeful"
        case .conjunction: return "Concentrated"
        }
    }

    private static func moods(moonSign: ZodiacSign, transit: NatalTransit?) -> [String] {
        var result = ["Quietly Attuned", moonSign.archetype.components(separatedBy: " & ").first ?? moonSign.name]
        if let transit {
            result.append(transit.kind == .square || transit.kind == .opposition ? "Restless" : "Receptive")
        } else {
            result.append("Content")
        }
        result.append("Seeking Grounding")
        return Array(result.prefix(4))
    }

    private static func questions(profile: UserProfile?, chart: NatalChart?, moonSign: ZodiacSign, transit: NatalTransit?) -> [String] {
        var result: [String] = []
        if let transit {
            result.append("How does \(transit.transiting.name) \(transit.kind.name.lowercased()) my natal \(transit.natal.name) play out today?")
        }
        if let sun = chart?.placement(.sun) {
            result.append("What should my \(sun.sign.name) Sun remember under a \(moonSign.name) Moon?")
        }
        if profile?.interests.contains(.love) == true {
            result.append("What does today ask of me in love?")
        } else if profile?.interests.contains(.career) == true {
            result.append("Is this a wise day for a career move?")
        } else {
            result.append("What should I focus on for the rest of today?")
        }
        return Array(result.prefix(3))
    }
}
