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
            luckyNumbers: LuckyNumberBuilder.numbers(profile: profile, chart: chart, sky: sky),
            moods: moods(moonSign: moonSign, transit: transit),
            oracleQuestions: questions(profile: profile, chart: chart, moonSign: moonSign, transit: transit)
        )
    }

    static func journalPrompt(chart: NatalChart?, sky: SkySnapshot) -> JournalPrompt {
        if let transit = sky.keyTransit {
            return JournalPrompt(
                context: "Today · \(transit.transiting.glyph) \(transit.kind.glyph) \(transit.natal.glyph)",
                question: "Where do you notice your \(transit.natal.meaning) today, with \(transit.transiting.name) in the sky?",
                note: transit.sentence
            )
        }
        let moon = sky.position(of: .moon)?.sign.name ?? "today's"
        return JournalPrompt(
            context: "Today · \(sky.moonPhase.name)",
            question: "What is the \(moon) Moon bringing up that you don't need to fix right now?",
            note: "The Moon is \(sky.moonPhase.illumination)% lit. Notice the mood before you try to explain it."
        )
    }

    // MARK: - Copy

    private static func atmosphere(phase: MoonPhase, moonSign: ZodiacSign, transit: NatalTransit?) -> String {
        if let transit, transit.orb < 1 {
            return "A strong \(transit.kind.name.lowercased()) today"
        }
        return "\(phase.name.replacingOccurrences(of: " Moon", with: "")) · \(moonSign.element)"
    }

    private static func ephemerisText(sky: SkySnapshot, chart: NatalChart?, transit: NatalTransit?) -> String {
        var parts: [String] = []
        if let transit {
            parts.append(transit.sentence)
            if let house = sky.houses[transit.transiting] {
                parts.append("It is passing through your \(AstrologyLexicon.ordinal(house)) house: \(AstrologyLexicon.houseTheme(house)).")
            }
        } else if let moon = sky.position(of: .moon) {
            parts.append("The Moon is in \(moon.sign.name) today, so the mood is \(moon.sign.qualities).")
        }
        if let retro = sky.retrogrades.first {
            parts.append("\(retro.name) is retrograde. Themes of \(retro.meaning) turn inward: review them instead of starting something new.")
        }
        return parts.joined(separator: " ")
    }

    private static func synthesisTitle(moonSign: ZodiacSign, transit: NatalTransit?, focus: String?) -> String {
        if focus?.isEmpty == false {
            return "Today, next to what's on your mind"
        }
        if let transit {
            return "\(transit.transiting.name) meets your \(transit.natal.name)"
        }
        return "A \(moonSign.name) Moon day"
    }

    private static func synthesisText(profile: UserProfile?, chart: NatalChart?, moonSign: ZodiacSign, transit: NatalTransit?, focus: String?) -> String {
        var text = ""
        if let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            text += "\(name), "
        }
        if let sun = chart?.placement(.sun), let moon = chart?.placement(.moon) {
            text += "your Sun is in \(sun.sign.name) and your Moon is in \(moon.sign.name). Today's Moon is in \(moonSign.name). "
        } else {
            text += "today's Moon is in \(moonSign.name), and that sets the mood. "
        }
        if let transit {
            text += transit.sentence + " "
        }
        if let focus, !focus.isEmpty {
            text += "You said this is on your mind: \"\(focus)\". Read today through that. It is a reflection, not a verdict."
        } else if let intention = profile?.intentions.first {
            text += "Keep this aim in view: \(intention.title.lowercased())."
        } else {
            text += "Notice what asks for attention. You don't have to decide anything yet."
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
                title: "Love",
                text: areaText(theme: loveHouse.map(AstrologyLexicon.houseTheme), transit: transit, fallback: "Show up before you analyze. Warmth works better than advice today.")
            ),
            LifeArea(
                icon: "pencil.and.scribble",
                title: "Work",
                text: areaText(theme: workHouse.map(AstrologyLexicon.houseTheme), transit: transit, fallback: "Finish one task well. Doing too many things at once will scatter you.")
            ),
            LifeArea(
                icon: "leaf",
                title: "How you feel",
                text: areaText(theme: innerHouse.map(AstrologyLexicon.houseTheme), transit: transit, fallback: "Check your body first: jaw, breath, shoulders. Feelings show up there before thoughts do.")
            )
        ]
    }

    private static func areaText(theme: String?, transit: NatalTransit?, fallback: String) -> String {
        if let transit, let theme {
            return "Today \(transit.transiting.name) \(transit.verb) your \(transit.natal.meaning), especially around \(theme)."
        }
        if let theme {
            return "Pay attention to \(theme). Go slowly there."
        }
        return fallback
    }

    private static func tendencies(chart: NatalChart?, moonSign: ZodiacSign, transit: NatalTransit?) -> [Tendency] {
        let fire = Double(chart?.elements.first { $0.name == "Fire" }?.percent ?? 25) / 100
        let water = Double(chart?.elements.first { $0.name == "Water" }?.percent ?? 25) / 100
        let transitBoost = transit.map { $0.kind == .square || $0.kind == .opposition ? 0.15 : 0.05 } ?? 0
        return [
            Tendency(title: "Focus", value: moonSign.element == "Earth" ? "Steady" : "Changeable", level: min(0.95, 0.45 + fire * 0.4 + transitBoost)),
            Tendency(title: "Connection", value: moonSign.element == "Water" ? "Close" : "Curious", level: min(0.95, 0.4 + water * 0.45)),
            Tendency(title: "Reflection", value: skyReflection(transit), level: min(0.95, 0.55 + ((transit?.orb ?? 2) < 1 ? 0.25 : 0.1)))
        ]
    }

    private static func skyReflection(_ transit: NatalTransit?) -> String {
        guard let transit else { return "Open" }
        switch transit.kind {
        case .square, .opposition: return "Tense"
        case .trine, .sextile: return "Easy"
        case .conjunction: return "Focused"
        }
    }

    private static func moods(moonSign: ZodiacSign, transit: NatalTransit?) -> [String] {
        let mood = moonSign.archetype.components(separatedBy: " and ").first ?? moonSign.name
        var result = ["Calm", mood]
        if let transit {
            result.append(transit.kind == .square || transit.kind == .opposition ? "Restless" : "Open")
        } else {
            result.append("Content")
        }
        result.append("Needs rest")
        return Array(result.prefix(4))
    }

    private static func questions(profile: UserProfile?, chart: NatalChart?, moonSign: ZodiacSign, transit: NatalTransit?) -> [String] {
        var result: [String] = []
        if let transit {
            result.append("How does \(transit.transiting.name) \(transit.kind.name.lowercased()) my natal \(transit.natal.name) show up today?")
        }
        if let sun = chart?.placement(.sun) {
            result.append("What should my \(sun.sign.name) Sun keep in mind with the Moon in \(moonSign.name)?")
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
