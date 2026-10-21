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
        let transit = EverydayVoice.supportedTransit(chart: chart, sky: sky)
        let copy = EverydayVoice.day(profile: profile, chart: chart, sky: sky)

        return DailyReading(
            date: sky.date,
            moonPhase: sky.moonPhase.name,
            moonSign: moonSign,
            moonIllumination: sky.moonPhase.illumination,
            atmosphere: copy.atmosphere,
            ephemerisTitle: copy.astrologyTitle,
            ephemerisText: copy.astrologyText,
            transitLine: copy.focus,
            orb: transit.map { NatalChartCalculator.formatDegrees($0.orb) } ?? "—",
            synthesisTitle: copy.title,
            synthesisText: copy.text,
            imageCaption: copy.atmosphere,
            areas: copy.areas,
            tendencies: tendencies(chart: chart, moonSign: moonSign, transit: transit),
            dials: LifeDialBuilder.dials(profile: profile, chart: chart, sky: sky),
            luckyNumbers: LuckyNumberBuilder.numbers(profile: profile, chart: chart, sky: sky),
            moods: moods(moonSign: moonSign, transit: transit),
            oracleQuestions: copy.questions,
            focus: copy.focus,
            caution: copy.caution,
            reflection: copy.reflection
        )
    }

    static func journalPrompt(chart: NatalChart?, sky: SkySnapshot) -> JournalPrompt {
        let copy = EverydayVoice.day(profile: nil, chart: chart, sky: sky)
        return JournalPrompt(
            context: "Today · \(sky.moonPhase.name)",
            question: copy.journalQuestion,
            note: copy.journalNote
        )
    }

    // MARK: - Copy

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
}
