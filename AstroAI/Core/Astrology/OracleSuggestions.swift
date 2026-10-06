//
//  OracleSuggestions.swift
//  AstroAI
//

import Foundation

/// Three ready questions for the Oracle, built from this person's chart and today's sky.
enum OracleSuggestions {
    static func make(chart: NatalChart?, sky: SkySnapshot?, interests: Set<Interest>) -> [String] {
        var questions: [String] = []

        if let chart {
            if let transit = sky?.keyTransit {
                questions.append(transitQuestion(transit, house: sky?.houses[transit.transiting]))
            }
            if let sun = chart.placement(.sun), let moon = chart.placement(.moon) {
                if let moonSign = sky?.position(of: .moon)?.sign {
                    questions.append("What should my \(label(sun)) and \(label(moon)) notice under a \(moonSign.name) Moon?")
                } else {
                    questions.append("How do my \(label(sun)) and \(label(moon)) want to work together right now?")
                }
            }
            if let aspect = bestAspect(in: chart) {
                questions.append("How does the \(aspect.kind.name.lowercased()) between my \(aspect.first.name) and \(aspect.second.name) show up in my life?")
            }
            if let moon = chart.placement(.moon), let house = moon.houseNumber {
                questions.append("What does my \(moon.sign.name) Moon in the \(AstrologyLexicon.ordinal(house)) house need from me?")
            }
            if let rising = chart.placement(.ascendant) {
                let ruler = rising.sign.ruler
                if let placement = chart.placement(ruler) {
                    let house = placement.houseNumber.map { " in the \(AstrologyLexicon.ordinal($0)) house" } ?? ""
                    questions.append("With \(rising.sign.name) rising, how is \(ruler.name) in \(placement.sign.name)\(house) steering me?")
                }
            }
            questions.append(contentsOf: interestQuestions(chart: chart, interests: interests))
            if let node = chart.placement(.northNode) {
                questions.append("How can I move toward my North Node in \(node.sign.name)?")
            }
        } else if let sky, let moon = sky.position(of: .moon) {
            questions.append("How can I meet this \(moon.sign.name) Moon honestly?")
            questions.append("What is the \(sky.moonPhase.name) asking me to feel before I decide?")
        }

        var seen = Set<String>()
        return Array(questions.filter { seen.insert($0).inserted }.prefix(3))
    }

    private static func transitQuestion(_ transit: NatalTransit, house: Int?) -> String {
        if let house {
            return "What happens when \(transit.transiting.name) in my \(AstrologyLexicon.ordinal(house)) house \(transit.verb) my natal \(transit.natal.name)?"
        }
        return "What happens when \(transit.transiting.name) \(transit.verb) my natal \(transit.natal.name)?"
    }

    /// Tightest aspect that touches a personal point, so the question is about the chart's live tension.
    private static func bestAspect(in chart: NatalChart) -> ChartAspect? {
        let personal: Set<Planet> = [.sun, .moon, .mercury, .venus, .mars, .ascendant]
        let ranked = chart.aspects.sorted { $0.orb < $1.orb }
        return ranked.first { personal.contains($0.first) || personal.contains($0.second) } ?? ranked.first
    }

    private static func interestQuestions(chart: NatalChart, interests: Set<Interest>) -> [String] {
        var result: [String] = []
        if interests.contains(.love), let venus = chart.placement(.venus) {
            result.append("How does my \(label(venus)) want to love right now?")
        }
        if interests.contains(.career), let saturn = chart.placement(.saturn) {
            result.append("What does my \(label(saturn)) say about my work right now?")
        }
        if interests.contains(.emotions), let moon = chart.placement(.moon) {
            result.append("Why does my \(label(moon)) feel so much lately?")
        }
        if interests.contains(.selfDiscovery), let sun = chart.placement(.sun) {
            result.append("Where does my \(label(sun)) already know its strength?")
        }
        if interests.contains(.growth), let jupiter = chart.placement(.jupiter) {
            result.append("What is my \(label(jupiter)) opening up for me?")
        }
        if interests.contains(.friendship), let mercury = chart.placement(.mercury) {
            result.append("Which people does my \(label(mercury)) actually thrive with?")
        }
        if interests.contains(.dailyGuidance), let mars = chart.placement(.mars) {
            result.append("Where should my \(label(mars)) spend its energy today?")
        }
        return result
    }

    private static func label(_ placement: PlanetPlacement) -> String {
        guard let house = placement.houseNumber else {
            return "\(placement.sign.name) \(placement.planet.name)"
        }
        return "\(placement.sign.name) \(placement.planet.name) in the \(AstrologyLexicon.ordinal(house)) house"
    }
}
