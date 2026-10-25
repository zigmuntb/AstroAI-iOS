//
//  ExploreVoice.swift
//  AstroAI
//
//  Turns calculated Explore facts into everyday recommendations.
//  The collapsed lines stay free of technical terms. The disclosure explains the calculation.
//  Wording is chosen from the combination of planets, aspect, house and life context.
//  It does not invent placements, and the same facts always produce the same draft.
//

import Foundation

enum ExploreSkyFact: Codable, Hashable {
    case moonIngress(sign: ZodiacSign, house: Int?)
    case moonPhase(name: String, sign: ZodiacSign, house: Int?)
    case saturnReturn(sign: ZodiacSign, degree: String, house: Int?, age: Int?, index: Int, count: Int, retrograde: Bool)
    case solarEclipse(kind: String, sign: ZodiacSign, degree: String, house: Int?, age: Int?)
    case nodalShift(entering: ZodiacSign, leaving: ZodiacSign, house: Int?, age: Int?)
}

struct ExploreCard: Identifiable, Hashable {
    let id: String
    let glyph: String
    let when: String
    let headline: String
    var summary: String
    let detail: String

    var draft: ExploreDraft { ExploreDraft(id: id, summary: summary) }
}

struct ExploreYearCard: Identifiable, Hashable {
    var id: String { "year" }
    let eyebrow: String
    let trailing: String
    let headline: String
    var summary: String
    let caution: String
    let detail: String

    var draft: ExploreDraft { ExploreDraft(id: id, summary: summary) }
}

struct ExploreDraft: Identifiable, Hashable {
    let id: String
    let summary: String
}

enum ExplorePolishOutcome: Equatable {
    /// Apple Intelligence cannot run. The draft stays, and a later visit may try again.
    case unavailable
    /// The model ran and added nothing safe to keep.
    case unchanged
    case summaries([String: String])
}

enum ExploreLanguage {
    private static let jargon: Set<String> = [
        "sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto",
        "aries", "taurus", "gemini", "cancer", "leo", "virgo", "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces",
        "ascendant", "natal", "transit", "retrograde", "conjunction", "sextile", "square", "trine", "opposition",
        "eclipse", "node", "nodes", "house", "houses", "zodiac", "horoscope", "ingress", "profection", "ephemeris",
        "aspect", "aspects", "luminary", "cusp", "rising"
    ]

    private static let stops: Set<String> = [
        "about", "after", "again", "also", "and", "are", "because", "before", "can", "dont", "don't",
        "for", "from", "have", "into", "just", "more", "not", "one", "that", "the", "then", "this",
        "with", "you", "your", "what", "when", "than", "them", "they", "their", "will", "would"
    ]

    static func containsJargon(_ text: String) -> Bool {
        words(in: text).contains { jargon.contains($0) }
    }

    /// A rewrite may replace phrasing. It may not add astrology, new numbers, or a different subject.
    static func acceptsRewrite(_ candidate: String, of draft: String) -> Bool {
        let text = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (40...600).contains(text.count) else { return false }
        guard !containsJargon(text) else { return false }
        let lowered = text.lowercased()
        if lowered.contains("the universe") || lowered.contains("destiny") || lowered.contains("guaranteed") || lowered.contains("you must") {
            return false
        }
        let sentences = text.split { ".!?".contains($0) }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard (1...4).contains(sentences.count) else { return false }
        let draftNumbers = numbers(in: draft)
        if !numbers(in: text).subtracting(draftNumbers).isEmpty { return false }
        let anchors = significantWords(in: draft)
        let kept = significantWords(in: text)
        let overlap = anchors.intersection(kept).count
        let needed = anchors.count < 4 ? 1 : 2
        return overlap >= needed
    }

    static func withoutRepeatedOpenings(_ summaries: [String: String], drafts: [ExploreDraft]) -> [String: String] {
        var seen = Set<String>()
        var kept: [String: String] = [:]
        let order = drafts.map(\.id)
        for id in order {
            guard let text = summaries[id] else { continue }
            let opening = words(in: text).prefix(4).joined(separator: " ")
            if seen.contains(opening) { continue }
            seen.insert(opening)
            kept[id] = text
        }
        return kept
    }

    private static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && $0 != "'" }.map(String.init)
    }

    private static func significantWords(in text: String) -> Set<String> {
        Set(words(in: text).filter { $0.count >= 5 && !stops.contains($0) })
    }

    private static func numbers(in text: String) -> Set<String> {
        var values: Set<String> = []
        var current = ""
        for character in text {
            if character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                values.insert(current)
                current = ""
            }
        }
        if !current.isEmpty { values.insert(current) }
        return values
    }
}

enum ExploreVoice {
    static func year(_ year: YearAhead, profile: UserProfile?, includeFocus: Bool) -> ExploreYearCard {
        let context = includeFocus ? focusLine(profile) : lifeContext(profile, house: year.house, lord: year.lord)
        var summary = [yearTry(year.house), lordPace(year.lord)]
        if let lordHouse = year.lordHouse {
            summary.append("That pace shows up especially around \(AstrologyLexicon.houseTheme(lordHouse)).")
        }
        if year.daysUntilBirthday == 0 {
            summary.append("The new year began today. Finish what the last theme left open before you add a new project.")
        } else if year.daysUntilBirthday <= 21 {
            summary.append("The year turns on \(year.trailing). Finish what this theme still asks, instead of starting the next chapter early.")
        }
        if let context {
            summary.append(context)
        }
        return ExploreYearCard(
            eyebrow: year.eyebrow,
            trailing: year.trailing,
            headline: yearHeadline(year.house),
            summary: summary.joined(separator: " "),
            caution: year.refrain,
            detail: yearDetail(year)
        )
    }

    static func month(_ event: PersonalTransitEvent, profile: UserProfile?, includeFocus: Bool) -> ExploreCard {
        let posture = posture(event.aspect)
        let variant = variant(for: event.id, count: 2)
        let lens = lens(interests: profile?.interests ?? [], natal: event.natal, house: event.lifeHouse)
        let context = includeFocus
            ? focusLine(profile)
            : lifeContext(profile, natal: event.natal, house: event.lifeHouse)
        var lines = [
            situation(event.natal, posture, variant),
            action(event.transiting, posture, lens)
        ]
        if let house = event.lifeHouse {
            lines.append(houseMove(house, posture))
        } else {
            lines.append(toneLine(event.skySign, posture))
        }
        lines.append(context ?? caution(event.natal, posture))
        return ExploreCard(
            id: event.id,
            glyph: event.glyph,
            when: event.whenLabel,
            headline: headline(transiting: event.transiting, natal: event.natal, posture: posture, house: event.lifeHouse),
            summary: lines.joined(separator: " "),
            detail: monthDetail(event)
        )
    }

    static func notice(
        transiting: Planet,
        natal: Planet,
        aspect: AspectKind,
        skySign: ZodiacSign,
        house: Int?
    ) -> String {
        let posture = posture(aspect)
        let move = action(transiting, posture, .general)
        let placed = house.map { houseMove($0, posture) } ?? toneLine(skySign, posture)
        let care = caution(natal, posture)
        let line = "\(move) \(placed) \(care)"
        if line.count <= 240 { return line }
        return "\(move) \(care)"
    }

    static func sky(_ transit: Transit, profile: UserProfile?, chart: NatalChart?, includeFocus: Bool) -> ExploreCard {
        guard let fact = transit.fact else {
            return ExploreCard(
                id: "\(transit.kind)-\(transit.date)",
                glyph: transit.glyph,
                when: transit.date,
                headline: transit.title,
                summary: transit.detail,
                detail: ""
            )
        }
        let copy = skyCopy(fact, when: transit.date, profile: profile, chart: chart, includeFocus: includeFocus)
        return ExploreCard(
            id: "\(transit.kind)-\(transit.date)",
            glyph: transit.glyph,
            when: transit.date,
            headline: copy.headline,
            summary: copy.summary,
            detail: copy.detail
        )
    }

    // MARK: - Sky

    private static func skyCopy(
        _ fact: ExploreSkyFact,
        when: String,
        profile: UserProfile?,
        chart: NatalChart?,
        includeFocus: Bool
    ) -> (headline: String, summary: String, detail: String) {
        switch fact {
        case .moonIngress(let sign, let house):
            return ingressCopy(sign: sign, house: house, when: when, profile: profile, chart: chart, includeFocus: includeFocus)
        case .moonPhase(let name, let sign, let house):
            return phaseCopy(name: name, sign: sign, house: house, when: when, profile: profile, chart: chart, includeFocus: includeFocus)
        case .saturnReturn(let sign, let degree, let house, let age, let index, let count, let retrograde):
            return saturnCopy(sign: sign, degree: degree, house: house, age: age, index: index, count: count, retrograde: retrograde, when: when, profile: profile, chart: chart)
        case .solarEclipse(let kind, let sign, let degree, let house, let age):
            return eclipseCopy(kind: kind, sign: sign, degree: degree, house: house, age: age, when: when, chart: chart)
        case .nodalShift(let entering, let leaving, let house, let age):
            return nodeCopy(entering: entering, leaving: leaving, house: house, age: age, when: when, chart: chart)
        }
    }

    private static func ingressCopy(
        sign: ZodiacSign,
        house: Int?,
        when: String,
        profile: UserProfile?,
        chart: NatalChart?,
        includeFocus: Bool
    ) -> (headline: String, summary: String, detail: String) {
        var lines = [ingressBody(sign)]
        if let house {
            lines.append("This is most likely to color \(AstrologyLexicon.houseTheme(house)).")
        }
        if let personal = natalMoodContrast(sign, chart: chart) {
            lines.append(personal)
        } else if includeFocus, let focus = focusLine(profile) {
            lines.append(focus)
        }
        lines.append(ingressCaution(sign))
        var detail = "The Moon describes mood and what helps people feel safe. Around \(when) it enters \(sign.name), a sign often described as \(sign.qualities). That is read as a shift in tone, not as something that has to happen."
        if let house {
            detail += " It passes through the part of your chart about \(AstrologyLexicon.houseTheme(house)), called the \(AstrologyLexicon.ordinal(house)) house."
        } else if chart == nil {
            detail += " There is no birth chart yet, so this describes the shared mood rather than a personal chart."
        }
        detail += " This is an interpretation of the sky, not a prediction."
        return (ingressHeadline(sign), lines.joined(separator: " "), detail)
    }

    private static func phaseCopy(
        name: String,
        sign: ZodiacSign,
        house: Int?,
        when: String,
        profile: UserProfile?,
        chart: NatalChart?,
        includeFocus: Bool
    ) -> (headline: String, summary: String, detail: String) {
        var lines = [phaseBody(name, sign)]
        if let house {
            lines.append("Pay special attention to \(AstrologyLexicon.houseTheme(house)).")
        }
        if let personal = natalMoodContrast(sign, chart: chart) {
            lines.append(personal)
        } else if includeFocus, let focus = focusLine(profile) {
            lines.append(focus)
        }
        lines.append(phaseCaution(name))
        let geometry = switch name {
        case "New Moon": "The Sun and Moon meet, which is traditionally a quieter start."
        case "Full Moon": "The Moon stands opposite the Sun, which is traditionally when feelings are easier to notice."
        case "First Quarter", "Last Quarter": "The Moon is square to the Sun, which is traditionally a halfway point that asks for a smaller decision."
        default: "This is one of the month's lunar turning points."
        }
        var detail = "\(name) in \(sign.name) around \(when). \(sign.name) is often described as \(sign.qualities). \(geometry)"
        if let house {
            detail += " It falls in the part of your chart about \(AstrologyLexicon.houseTheme(house)), the \(AstrologyLexicon.ordinal(house)) house."
        } else if chart == nil {
            detail += " There is no birth chart yet, so this describes the shared mood rather than a personal chart."
        }
        detail += " This describes the mood of the month. It does not decide an outcome."
        return (phaseHeadline(name), lines.joined(separator: " "), detail)
    }

    private static func saturnCopy(
        sign: ZodiacSign,
        degree: String,
        house: Int?,
        age: Int?,
        index: Int,
        count: Int,
        retrograde: Bool,
        when: String,
        profile: UserProfile?,
        chart: NatalChart?
    ) -> (headline: String, summary: String, detail: String) {
        let pass = saturnPass(index: index, count: count, retrograde: retrograde)
        let area = house.map { "especially around \(AstrologyLexicon.houseTheme($0))" } ?? "in the responsibilities you already carry"
        let ageLine = age.map { " You would be about \($0)." } ?? ""
        let context = lifeContext(profile, house: house ?? 10, lord: .saturn)
        var summary = "\(pass) \(area.capitalizedFirst).\(ageLine)"
        if let context { summary += " \(context)" }
        summary += " You do not have to rebuild a whole life in one season."
        var detail = "Saturn returns to the same place it occupied at birth, at \(degree) \(sign.name). Saturn is associated with discipline and long-term goals. Around \(when) that meeting is exact."
        if count > 1 {
            detail += " A return like this can be exact more than once. This is \(pass.lowercased())."
        }
        if retrograde {
            detail += " Saturn is retrograde, which is traditionally read as a reason to review a commitment rather than launch a new one."
        }
        if let house {
            detail += " It falls in the part of life about \(AstrologyLexicon.houseTheme(house)), the \(AstrologyLexicon.ordinal(house)) house."
        } else if chart != nil, !EverydayVoice.housesAreReliable(chart) {
            detail += " House areas are left out because the birth time or birthplace is not exact enough."
        }
        if let age { detail += " That is about age \(age)." }
        detail += " This is a chapter to interpret, not a verdict."
        return ("A long look at what you are responsible for", summary, detail)
    }

    private static func eclipseCopy(
        kind: String,
        sign: ZodiacSign,
        degree: String,
        house: Int?,
        age: Int?,
        when: String,
        chart: NatalChart?
    ) -> (headline: String, summary: String, detail: String) {
        let area = house.map { "around \(AstrologyLexicon.houseTheme($0))" } ?? "in whatever you have already been reconsidering"
        let summary = "A rare quiet point in the month can mark a turning point \(area). \(eclipseTry(kind)) \(eclipseCaution(kind))"
        var detail = "A solar eclipse is a new moon aligned so that the Moon passes in front of the Sun. This one is \(kind.lowercased()), at \(degree) \(sign.name), around \(when). \(sign.name) is often described as \(sign.qualities)."
        if let house {
            detail += " It falls in the part of your chart about \(AstrologyLexicon.houseTheme(house)), the \(AstrologyLexicon.ordinal(house)) house."
        } else if chart != nil, !EverydayVoice.housesAreReliable(chart) {
            detail += " House areas are left out because the birth time or birthplace is not exact enough."
        }
        if let age { detail += " You would be about \(age)." }
        detail += " An eclipse highlights a theme. It does not force an ending or a beginning."
        return ("A turning point worth noticing", summary, detail)
    }

    private static func nodeCopy(
        entering: ZodiacSign,
        leaving: ZodiacSign,
        house: Int?,
        age: Int?,
        when: String,
        chart: NatalChart?
    ) -> (headline: String, summary: String, detail: String) {
        let toward = house.map { AstrologyLexicon.houseTheme($0) } ?? "a \(entering.qualities) way of growing"
        let summary = "For about a year and a half, growth may feel more connected to \(toward), and less to a \(leaving.qualities) habit. Take one step in the newer direction. Keep what still works from the older one."
        var detail = "The lunar node changes sign around \(when), leaving \(leaving.name) for \(entering.name). The node is associated with a direction of growth, and it stays in one sign for about 18 months. \(entering.name) is often described as \(entering.qualities)."
        if let house {
            detail += " The new sign falls in the part of your chart about \(AstrologyLexicon.houseTheme(house)), the \(AstrologyLexicon.ordinal(house)) house."
        } else if chart != nil, !EverydayVoice.housesAreReliable(chart) {
            detail += " House areas are left out because the birth time or birthplace is not exact enough."
        }
        if let age { detail += " You would be about \(age)." }
        detail += " Treat it as a direction, not a deadline."
        return ("A longer shift in what growth feels like", summary, detail)
    }

    // MARK: - Year

    private static func yearHeadline(_ house: Int) -> String {
        switch house {
        case 1: "A year to get clearer about how you show up"
        case 2: "A year for money and what you value"
        case 3: "A year for conversations and learning"
        case 4: "A year for home and the people you come from"
        case 5: "A year for making things and enjoying them"
        case 6: "A year for daily work and how your body feels"
        case 7: "A year for one close relationship"
        case 8: "A year for what you share, and what you can release"
        case 9: "A year for a wider view"
        case 10: "A year for the work other people can see"
        case 11: "A year for friends and the future you want"
        default: "A year for time that is actually yours"
        }
    }

    private static func yearTry(_ house: Int) -> String {
        switch house {
        case 1: "Try a way of showing up that you can sustain, and drop a performance that tires you."
        case 2: "Make one part of your money clearer: what you earn, what you owe, or what you want to keep."
        case 3: "Have one conversation you have been postponing, or learn the skill that would make an ordinary day easier."
        case 4: "Give home, or a family question, a real block of time. A repair you can see beats a plan for everyone else."
        case 5: "Make something you enjoy, or let a hobby be bad again. The point is the pleasure, not a result."
        case 6: "Improve one daily habit your body already agrees with. Redesigning the whole routine can wait."
        case 7: "Put the effort into one close relationship. Ask for a specific change, and leave the rest of the history for later."
        case 8: "Look at something you share, including money or trust. Name one arrangement that is only still there because nobody has ended it."
        case 9: "Study or go somewhere in a way that helps a decision you are actually facing. A bigger belief is not required."
        case 10: "Improve the work people already associate with you. A clearer result will do more than a new title."
        case 11: "Spend time with the few people who are actually yours, and take one step toward a hope you still mean."
        default: "Keep some time that you do not have to explain. Use it to rest, or to finish something private."
        }
    }

    private static func lordPace(_ lord: Planet) -> String {
        switch lord {
        case .mars: "The pace comes from how you act. Fewer starts, and more finished ones, will serve you better than a burst of effort."
        case .venus: "The pace comes from what you enjoy and who you keep close. A smaller calendar with better company beats a busier one."
        case .mercury: "The pace comes from conversations and decisions. Write the agreement down before you accept it."
        case .moon: "The pace comes from what helps you feel safe. Protect the routines that actually restore you."
        case .sun: "The pace comes from what you want to stand for. Choose work you are willing to be seen doing."
        case .jupiter: "The pace comes from where you want more. One real expansion is enough."
        case .saturn: "The pace comes from responsibilities you keep. A standard you can live with matters more than a sprint."
        default: "The pace is slower than a mood. Build something you can still respect later."
        }
    }

    private static func yearDetail(_ year: YearAhead) -> String {
        let root = year.countedFromSun
            ? "the Sun sign, because the birth time or birthplace is not exact enough for a rising sign"
            : "the rising sign"
        var text = "Astrologers count each year of life as one area of the chart, moving in order from \(root). This year that area is the \(AstrologyLexicon.ordinal(year.house)) house, in \(year.sign.name). \(year.sign.name) is often described as \(year.sign.qualities). The theme is \(AstrologyLexicon.houseTheme(year.house))."
        text += " \(year.lord.name) leads the year. \(year.lord.name) is associated with \(year.lord.meaning)."
        if let sign = year.lordSign {
            text += " In your chart it is in \(sign.name), a \(sign.qualities) style."
        }
        if let house = year.lordHouse {
            text += " That placement sits in the part of life about \(AstrologyLexicon.houseTheme(house)), the \(AstrologyLexicon.ordinal(house)) house."
        }
        if let turning = year.turningLine {
            text += " \(turning)"
        }
        text += " \(year.basis) This is an interpretation of the year, not a promise about what will happen."
        return text
    }

    // MARK: - Month

    private enum Posture { case friction, opening, focus, both }

    private static func posture(_ kind: AspectKind) -> Posture {
        switch kind {
        case .square: .friction
        case .opposition: .both
        case .trine, .sextile: .opening
        case .conjunction: .focus
        }
    }

    private enum Lens { case career, closePeople, general }

    private static func lens(interests: Set<Interest>, natal: Planet, house: Int?) -> Lens {
        let loveDomain = [.venus, .moon].contains(natal) || house == 5 || house == 7
        let workDomain = [.saturn, .sun, .mars, .jupiter].contains(natal) || house == 6 || house == 10 || house == 2
        if loveDomain, interests.contains(.love) || interests.contains(.friendship) { return .closePeople }
        if workDomain, interests.contains(.career) { return .career }
        return .general
    }

    private static func headline(transiting: Planet, natal: Planet, posture: Posture, house: Int?) -> String {
        let topic = house.map { shortTopic($0) } ?? natalTopic(natal)
        return "\(frame(transiting, posture)) \(topic)"
    }

    private static func frame(_ planet: Planet, _ posture: Posture) -> String {
        switch (planet, posture) {
        case (.mars, .friction): "Extra heat"
        case (.mars, .opening): "A useful push"
        case (.mars, .focus): "One strong push"
        case (.mars, .both): "Two strong wills"
        case (.saturn, .friction): "A slower test"
        case (.saturn, .opening): "A steady opening"
        case (.saturn, .focus): "One serious focus"
        case (.saturn, .both): "Duty on both sides"
        case (.mercury, .friction): "A risk of talking past each other"
        case (.mercury, .opening): "A clearer conversation"
        case (.mercury, .focus): "One conversation that matters"
        case (.mercury, .both): "Two versions of the story"
        case (.venus, .friction): "A tender spot"
        case (.venus, .opening): "An easier warmth"
        case (.venus, .focus): "One relationship in focus"
        case (.venus, .both): "Two ways of being close"
        case (.jupiter, .friction): "A bigger appetite than the moment needs"
        case (.jupiter, .opening): "A generous opening"
        case (.jupiter, .focus): "One opportunity in focus"
        case (.jupiter, .both): "More than one good option"
        case (.sun, .friction): "A brighter spotlight than you asked for"
        case (.sun, .opening): "A chance to be seen"
        case (.sun, .focus): "One thing you want seen"
        case (.sun, .both): "Your needs and someone else's"
        case (.uranus, .friction): "An unsettled change"
        case (.uranus, .opening): "A fresh opening"
        case (.uranus, .focus): "One change that will not stay small"
        case (.uranus, .both): "Freedom pulling both ways"
        case (.neptune, .friction): "A foggy patch"
        case (.neptune, .opening): "A softer imagination"
        case (.neptune, .focus): "One hope that wants attention"
        case (.neptune, .both): "A hope and a doubt"
        case (.pluto, .friction): "A deeper pressure"
        case (.pluto, .opening): "A quiet deepening"
        case (.pluto, .focus): "One ending or beginning"
        case (.pluto, .both): "Holding on and letting go"
        default:
            switch posture {
            case .friction: "A tense stretch"
            case .opening: "A usable opening"
            case .focus: "One theme in focus"
            case .both: "Two needs at once"
            }
        }
    }

    private static func shortTopic(_ house: Int) -> String {
        switch house {
        case 1: "in how you come across"
        case 2: "with money and what you value"
        case 3: "in a conversation or something you are learning"
        case 4: "at home or with family"
        case 5: "in something you create or enjoy"
        case 6: "in daily work or how your body feels"
        case 7: "in a close relationship"
        case 8: "in what you share or are ready to release"
        case 9: "in a plan, a trip, or a belief you are testing"
        case 10: "in the work other people can see"
        case 11: "with friends or a future plan"
        default: "in time you keep to yourself"
        }
    }

    private static func natalTopic(_ natal: Planet) -> String {
        switch natal {
        case .sun: "in who you are becoming"
        case .moon: "in what helps you feel safe"
        case .mercury: "in how you explain yourself"
        case .venus: "in closeness"
        case .mars: "in how you take action"
        case .jupiter: "in where you want more"
        case .saturn: "in a responsibility you keep"
        case .ascendant: "in how you come across"
        default: "in ordinary life"
        }
    }

    private static func situation(_ natal: Planet, _ posture: Posture, _ variant: Int) -> String {
        let lines = situations(natal, posture)
        return lines[variant % lines.count]
    }

    private static func situations(_ natal: Planet, _ posture: Posture) -> [String] {
        switch natal {
        case .venus:
            switch posture {
            case .friction: [
                "Closeness may feel more sensitive than the facts deserve. Ask one plain question before you decide what a silence means.",
                "You may want reassurance sooner than the other person can offer it. Say what you need in one sentence, then let them answer."
            ]
            case .opening: [
                "Warmth is a little easier to offer and to receive. One honest sentence will do more than a long explanation.",
                "Something you enjoy, or someone you like, may feel more available. Meet it once, without turning it into a plan for the month."
            ]
            case .focus: [
                "Love, taste, or a particular person may take up more of the day than usual. Notice that without making every feeling a verdict.",
                "What you find beautiful or comforting is louder right now. Choose one pleasure on purpose, instead of chasing all of them."
            ]
            case .both: [
                "You may want closeness and space in the same afternoon. Both can be real. You do not have to settle it today.",
                "Someone else's way of caring may not match yours. Describe yours, and ask about theirs, before you call it a problem."
            ]
            }
        case .moon:
            switch posture {
            case .friction: [
                "A small disappointment may land harder than it should. Name the feeling before you answer anyone.",
                "You may take the mood around you personally. A short break will show you which part is actually yours."
            ]
            case .opening: [
                "It may be easier to say what would help you feel settled. Ask for that, specifically.",
                "Comfort is available if you make a little room for it. A meal, a walk, or an earlier night counts."
            ]
            case .focus: [
                "What helps you feel safe is in the foreground. Protect it for an hour before you add anything else.",
                "Home, food, or a familiar person may matter more than the schedule. Let one of those be enough."
            ]
            case .both: [
                "Part of you wants to be looked after, and part of you wants to be left alone. Tell someone which one is true this hour.",
                "A mood and a duty may pull in different directions. Do the duty in a smaller form, then rest."
            ]
            }
        case .mercury:
            switch posture {
            case .friction: [
                "A message is easy to misread today. Ask what was meant before you write the long reply.",
                "Your mind may want to win the explanation. The useful version is the short one."
            ]
            case .opening: [
                "A stuck conversation can move if you say the point in a few sentences and then stop.",
                "Learning or writing may come more easily. Use that on the thing you have already started."
            ]
            case .focus: [
                "One subject wants your full attention. Give it a block of time, and silence the other tabs.",
                "You may finally know what you have been trying to say. Write it down before you decorate it."
            ]
            case .both: [
                "Two explanations can both be partly right. Repeat what you heard before you add yours.",
                "You may be asked to choose between saying it and keeping the peace. Say the one sentence that matters, kindly."
            ]
            }
        case .mars:
            switch posture {
            case .friction: [
                "Irritation may arrive before the reason does. Put the energy into a task, not into the first person nearby.",
                "You may want to force a pace other people cannot match. Do your part, and leave theirs alone."
            ]
            case .opening: [
                "There is enough energy to begin something you have delayed. Keep the first step small enough to finish.",
                "Courage is cheaper than usual. Use it on one honest ask, not on a fight."
            ]
            case .focus: [
                "One goal can take the whole push. Starting a second one will waste it.",
                "You may feel ready to act. Act on the task that was already yours."
            ]
            case .both: [
                "You and someone else may both be sure you are right. Say your side, then stop long enough to hear theirs.",
                "Wanting to move and wanting to win can get tangled. Move the work. Leave the score for later."
            ]
            }
        case .saturn, .sun:
            switch posture {
            case .friction: [
                "A responsibility may feel heavier than the task itself. Do the next concrete piece, and leave the judgment for tomorrow.",
                "Feedback, or your own standard, may sound like a verdict. It is one piece of information."
            ]
            case .opening: [
                "The work you have already claimed may move with less friction. Finish a visible piece of it.",
                "Structure is on your side if you use it for one standard you can keep, not for a new set of rules."
            ]
            case .focus: [
                "What you want to be known for is in the foreground. Spend the time on the work, not on how it looks.",
                "A duty you respect can have the day. Drop a duty you are keeping only out of habit."
            ]
            case .both: [
                "Being seen and being left in peace may both matter. Choose which one this particular task needs.",
                "Your standard and someone else's may not match. Agree the next deliverable, not the whole philosophy."
            ]
            }
        case .jupiter:
            switch posture {
            case .friction: [
                "More may sound like better. Check whether you can actually carry the bigger version.",
                "An opportunity can feel urgent because it is large. Size is not the same as fit."
            ]
            case .opening: [
                "One door is more useful than a hallway of maybes. Walk through the one that matches a plan you already have.",
                "Generosity, including your own, has room. Offer a specific help, not a blank promise."
            ]
            case .focus: [
                "Growth wants a decision, not a vision board. Choose the expansion you will still want next month.",
                "A teacher, a trip, or a bigger role may stand out. Ask what it costs in ordinary days."
            ]
            case .both: [
                "Two good options can stall you. Pick the one you can start this week, and let the other stay a possibility.",
                "Optimism and caution may both be right. Let optimism choose the direction and caution choose the size."
            ]
            }
        case .ascendant:
            switch posture {
            case .friction: [
                "How you are coming across may not match how you feel. Adjust one thing people can actually see.",
                "A first impression, including your own of someone else, may be louder than it is accurate."
            ]
            case .opening: [
                "It is a little easier to let people see the version of you that you actually like. You do not have to perform the rest.",
                "A meeting or a first conversation has a tailwind. Be specific about what you want from it."
            ]
            case .focus: [
                "The way you enter a room, a message, or a meeting matters more than usual. Decide that on purpose.",
                "You may be more visible than you feel. Use it for one clear introduction, then step back."
            ]
            case .both: [
                "You may want to be known and to be left alone. Tell people which hours are which.",
                "Someone's first read of you and your own read of them may both be incomplete. Ask one question before you decide."
            ]
            }
        default:
            switch posture {
            case .friction: [
                "Something familiar may feel slightly harder. Deal with the piece in front of you, not the whole story.",
                "A snag is information. Name it, then choose the smaller repair."
            ]
            case .opening: [
                "There is a little more room than usual. Use it on one thing you have already chosen.",
                "Ease is available for a single step. Take that step, and leave the sequel for later."
            ]
            case .focus: [
                "One theme will keep returning. Give it a defined block of time.",
                "What you keep noticing is the subject. You do not have to solve it to take it seriously."
            ]
            case .both: [
                "Two needs can both be legitimate. Hear both before you pick a next step.",
                "You do not have to make the two sides agree today. You only have to keep both in view."
            ]
            }
        }
    }

    private static func action(_ planet: Planet, _ posture: Posture, _ lens: Lens) -> String {
        switch planet {
        case .mercury:
            switch (posture, lens) {
            case (.friction, .career): "At work, write the unclear point in two sentences and wait before you follow up."
            case (.friction, .closePeople): "If a message from someone close landed badly, ask what they meant before you explain yourself."
            case (.opening, .career): "Clarify the one work question that is stuck, then leave the thread."
            case (.opening, .closePeople): "Tell one person what you actually meant, in a few lines, and let them answer."
            case (.focus, _): "Give the subject one uninterrupted block, and close the other conversations."
            case (.both, _): "Repeat what you heard, then add only the sentence you most need them to understand."
            default: "Say what you mean in one or two sentences, then wait. A second message usually makes it muddier."
            }
        case .venus:
            switch (posture, lens) {
            case (.friction, .closePeople): "Ask for one thing that would feel better, without making it a test of the relationship."
            case (.opening, .closePeople): "Plan one ordinary hour together, or with a friend, and leave the rest of the week alone."
            case (.focus, .closePeople): "Tell the person what you appreciate, specifically, and stop there."
            case (.both, .closePeople): "Say which kind of closeness you want today, and ask which kind they have."
            case (.friction, _): "If you want to buy or promise something for comfort, write down why and decide tomorrow."
            case (.opening, _): "Choose one pleasure that does not create a new obligation."
            case (.focus, _): "Spend the attention on the relationship or the taste that is already yours."
            case (.both, _): "You can want beauty and honesty. Ask for the honest version first."
            }
        case .mars:
            switch (posture, lens) {
            case (.friction, .career): "Put the heat into a task you can finish, not into a fight about whose job it is."
            case (.opening, .career): "Start the work task you have been postponing. Stop when the first piece is done."
            case (.friction, _): "Use the extra energy on one physical or practical job, then leave the argument."
            case (.opening, _): "Begin the thing you have delayed. The first step should be small enough to finish today."
            case (.focus, _): "Choose one push and see it through. A second start will spend the energy."
            case (.both, _): "Be direct, then leave the other person room. Your side does not need a second speech."
            }
        case .saturn:
            switch (posture, lens) {
            case (.friction, .career): "Finish the piece you already promised at work before you take on a higher standard."
            case (.opening, .career): "Set one standard for the work you can keep next week, and drop an extra rule."
            case (.friction, _): "Give the heavy thing a deadline you can actually meet, and do the next piece only."
            case (.opening, _): "The slow way is the useful way. Improve something you already maintain."
            case (.focus, _): "Let one responsibility have the day. Decline a second one."
            case (.both, _): "Name what you owe and what can wait. Do not try to pay both debts this afternoon."
            }
        case .jupiter:
            switch posture {
            case .friction: "Say no to the largest version. If you still want it tomorrow, make it smaller and look again."
            case .opening: "Say yes to one opportunity that fits a plan you already have, and let the others pass."
            case .focus: "Choose the growth you can support with an ordinary week, not the one that only works if everything goes right."
            case .both: "Keep the option that you can start now. Thank the other one and do not chase it today."
            }
        case .sun:
            switch (posture, lens) {
            case (.friction, .career): "Do the visible task before you defend it. The work answers more than the explanation."
            case (.opening, .career): "Show one finished piece of work to the person who actually needs to see it."
            case (.friction, _): "If you feel judged, separate the comment from your character, and respond only to the comment."
            case (.opening, _): "Let yourself be seen doing the thing you mean. You do not need a bigger stage."
            case (.focus, _): "Spend the attention on the role that is already yours."
            case (.both, _): "Ask what the other person needs to see, and show that, not your whole case."
            }
        case .uranus:
            switch posture {
            case .friction: "Change one routine on purpose. Do not blow up the whole arrangement because one part feels stale."
            case .opening: "Try a different way of doing a familiar task. Keep the goal the same."
            case .focus: "If something needs to change, change the smallest piece that would actually matter."
            case .both: "You can want freedom and a promise you already made. Keep the promise, and change how you carry it."
            }
        case .neptune:
            switch posture {
            case .friction: "If the story feels foggy, wait until you can name one fact. Do not fill the gap with a guess."
            case .opening: "Imagination is useful if it serves a real task. Sketch the idea, then return to the next step."
            case .focus: "Give the dream an hour, then write the one action that would make it less imaginary."
            case .both: "A hope and a doubt can share the day. Write both down before you act on either."
            }
        case .pluto:
            switch posture {
            case .friction: "Notice what you are tired of carrying. You can name it without ending it today."
            case .opening: "A deeper conversation is available if you keep it to one truth, not the whole history."
            case .focus: "One ending or one honest beginning deserves the time. Do not open three of them."
            case .both: "Holding on and letting go may both be wise. Decide which object, habit, or talk is actually in question."
            }
        default:
            switch posture {
            case .friction: "Deal with the snag in front of you, and leave the larger story for a calmer hour."
            case .opening: "Take the small step that was already on your list."
            case .focus: "Give one subject a defined block of time, then stop."
            case .both: "Hear both needs, then choose only the next step."
            }
        }
    }

    private static func houseMove(_ house: Int, _ posture: Posture) -> String {
        let careful = posture == .friction || posture == .both
        switch house {
        case 1:
            return careful
                ? "In how you come across, change one habit people can see, and leave the rest of your image alone."
                : "In how you come across, try one small way of showing up that feels more like you."
        case 2:
            return careful
                ? "With money, wait a day before a purchase or a promise you cannot undo."
                : "With money, make one number clearer: what comes in, what goes out, or what you can set aside."
        case 3:
            return careful
                ? "In the conversation you keep replaying, send the short version or do not send it yet."
                : "Use the ease to ask the question, or to learn the next small piece."
        case 4:
            return careful
                ? "At home, repair one practical thing or take a quiet hour. Do not hold the family meeting while everyone is tired."
                : "At home, make one hour simpler: a meal, a cleared surface, or a call you have been meaning to make."
        case 5:
            return careful
                ? "If this touches romance, play, or a creative project, keep it light. Do not turn the fun into a verdict."
                : "Give an hour to something you enjoy, with no product required at the end."
        case 6:
            return careful
                ? "In the workday or in how your body feels, fix the next concrete task and skip the full overhaul."
                : "Improve one ordinary routine: the list, the desk, the meal, or the time you stop."
        case 7:
            return careful
                ? "With someone close, ask one question. Do not try to settle the relationship in a single talk."
                : "With someone close, make one specific plan or one specific request."
        case 8:
            return careful
                ? "If money, trust, or a shared decision is involved, name the fact before you name the fear."
                : "Look at one shared thing, money or otherwise, and make the terms easier to understand."
        case 9:
            return careful
                ? "If this is about a belief, a course, or a trip, decide the next booking or the next page, not the whole future."
                : "Take one step that widens the view: a page, a class, or a plan you can actually afford."
        case 10:
            return careful
                ? "At work, finish the piece people are waiting on before you argue about the credit."
                : "At work, ship or improve one thing your name is already on."
        case 11:
            return careful
                ? "With friends or a group, say what you mean to the person it concerns, not to the whole room."
                : "Reach out to one person who is actually yours, or take one step toward a plan you still mean."
        default:
            return careful
                ? "If you need time alone, take it without explaining the whole reason. Do not make a permanent decision in that quiet."
                : "Keep a private hour for rest or for a piece of work nobody else needs to see."
        }
    }

    private static func toneLine(_ sign: ZodiacSign, _ posture: Posture) -> String {
        switch (sign.element, posture) {
        case ("Fire", .friction): "The pace wants to move fast. Slow the reply, not the task."
        case ("Earth", .friction): "The pace wants a practical fix. Fix one piece, then leave it."
        case ("Air", .friction): "The pace wants an explanation. One clear version is enough."
        case ("Water", .friction): "The pace wants to feel everything. Name the feeling before you act on it."
        case ("Fire", .opening): "There is energy to start. Keep the start small enough to finish."
        case ("Earth", .opening): "A practical step will go further than a big idea."
        case ("Air", .opening): "A single conversation can move this. Have it, then stop."
        case ("Water", .opening): "Warmth is available. Ask for what you need, then let the answer come."
        case ("Fire", .focus): "Put the heat on one task and let the others wait."
        case ("Earth", .focus): "Stay with the concrete piece until it is done."
        case ("Air", .focus): "Decide what you are actually trying to say, and say only that."
        case ("Water", .focus): "Stay with the feeling long enough to name it, then choose one response."
        case ("Fire", .both): "Both sides may want to win. Give each one sentence."
        case ("Earth", .both): "Both sides may want a practical result. Pick the one you can keep."
        case ("Air", .both): "Both sides may want to be right. Repeat what you heard before you answer."
        case ("Water", .both): "Both sides may feel urgent. You can care about both and still wait a day."
        default: "Keep the next step smaller than the feeling."
        }
    }

    private static func caution(_ natal: Planet, _ posture: Posture) -> String {
        switch (natal, posture) {
        case (.venus, .friction), (.venus, .both):
            "Don't treat a quiet mood as proof that a relationship is failing."
        case (.mercury, .friction), (.mercury, .both):
            "Don't send the long version while you are still irritated."
        case (.mars, .friction), (.mars, .both):
            "Don't make the sharp comment just because you can."
        case (.saturn, .friction), (.saturn, .both), (.sun, .friction):
            "Don't quit a responsibility, or defend your whole character, on the heaviest hour."
        case (.moon, .friction), (.moon, .both):
            "Don't make a lasting decision from a passing feeling."
        case (.jupiter, .friction), (.jupiter, .both):
            "Don't agree to the biggest version just to end the discomfort."
        case (.ascendant, .friction), (.ascendant, .both):
            "Don't rebuild how you come across just to make one moment easier."
        case (_, .friction):
            "Don't decide the whole situation from one awkward moment."
        case (_, .both):
            "Don't pick a winner between the two needs today."
        case (.venus, .opening), (.moon, .opening):
            "Don't turn a pleasant mood into a promise you have not thought through."
        case (.jupiter, .opening):
            "Don't say yes to every opening because one of them is good."
        case (.mars, .opening):
            "Don't spend the extra energy on three different starts."
        case (_, .opening):
            "Ease is not a reason to take on more than you can finish."
        case (_, .focus):
            "A strong focus is not the same thing as a finished decision."
        }
    }

    private static func monthDetail(_ event: PersonalTransitEvent) -> String {
        let kind = event.aspect.name.lowercased()
        var text = "\(event.transiting.name) is associated with \(event.transiting.meaning). On this date it is in \(event.skySign.name), a sign often described as \(event.skySign.qualities). Its meeting with your natal \(event.natal.name) — your \(event.natal.meaning) — is a \(kind). A \(kind) is traditionally read as \(aspectPlain(event.aspect))."
        if let house = event.lifeHouse {
            text += " It passes through the part of your chart about \(AstrologyLexicon.houseTheme(house)). Astrologers call that the \(AstrologyLexicon.ordinal(house)) house."
        }
        text += " The timing is \(event.whenLabel). This is an interpretation of a calculated meeting, not a prediction."
        return text
    }

    private static func aspectPlain(_ kind: AspectKind) -> String {
        switch kind {
        case .conjunction: "two themes showing up together, so one of them is hard to ignore"
        case .sextile: "a small opening, useful if you take a step"
        case .square: "friction, which asks for patience rather than a quick fix"
        case .trine: "an easier flow between two parts of life"
        case .opposition: "two needs pulling in different directions, both worth hearing"
        }
    }

    // MARK: - Week and cycles, pieces

    private static func ingressHeadline(_ sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "A mood that wants to start"
        case .taurus: "A mood that wants things steady"
        case .gemini: "A mood that wants to talk"
        case .cancer: "A mood that takes things to heart"
        case .leo: "A mood that wants to be seen"
        case .virgo: "A mood that notices the small things"
        case .libra: "A mood that wants people to get along"
        case .scorpio: "A mood that notices what is unsaid"
        case .sagittarius: "A mood that wants a wider view"
        case .capricorn: "A mood that feels the weight of duty"
        case .aquarius: "A mood that wants a little distance"
        case .pisces: "A mood that picks up the room"
        }
    }

    private static func ingressBody(_ sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "If you have been waiting to begin, this is a fair window for the first step. Stop while it is still a step."
        case .taurus: "Finish something practical and let the pace stay unhurried. A rushed decision will not feel better later."
        case .gemini: "One clear conversation can untangle more than a day of thinking. Have it, then do something that is not a screen."
        case .cancer: "Check on home, food, or someone you care about. Offer care without taking over their problem."
        case .leo: "Share one thing you made or decided. Attention is not the same as agreement, so leave room for their response."
        case .virgo: "Fix one detail that has been bothering you, then leave the rest of the list alone."
        case .libra: "If people are out of sorts, a fair question will help more than smoothing it over. A kind no still counts as kind."
        case .scorpio: "Ask before you decide what a silence means. Privacy, yours or theirs, is not an insult."
        case .sagittarius: "Look past the immediate snag at the next real step, and keep that step small enough for this week."
        case .capricorn: "Finish a duty that is already yours. A new title, or a new system, can wait."
        case .aquarius: "Take a little distance if you need to think. Distance is not the same as not caring, so say when you will be back."
        case .pisces: "The mood around you may stick. A short walk or a quiet hour will show you which feeling is yours."
        }
    }

    private static func ingressCaution(_ sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "Don't start three things because the first one felt good."
        case .taurus: "Don't buy or promise something just to make the day feel stable."
        case .gemini: "Don't keep explaining after the other person has understood."
        case .cancer: "Don't treat someone else's bad day as a verdict on you."
        case .leo: "Don't confuse being noticed with being agreed with."
        case .virgo: "Don't let one flaw convince you the whole thing failed."
        case .libra: "Don't agree just to end the tension."
        case .scorpio: "Don't build a story out of what nobody has said."
        case .sagittarius: "Don't skip the boring step because the big picture is exciting."
        case .capricorn: "Don't measure the day only by what you produced."
        case .aquarius: "Don't disappear without saying you need a minute."
        case .pisces: "Don't make a firm plan while you are still absorbing everyone else."
        }
    }

    private static func phaseHeadline(_ name: String) -> String {
        switch name {
        case "New Moon": "A quiet point for one small beginning"
        case "Full Moon": "Feelings are easier to notice"
        case "First Quarter": "A halfway point that wants a decision"
        default: "A halfway point for setting something down"
        }
    }

    private static func phaseBody(_ name: String, _ sign: ZodiacSign) -> String {
        let pace: String = switch sign.element {
        case "Earth": "Keep the next step practical."
        case "Water": "Notice the feeling, then decide if it needs a conversation."
        case "Fire": "Use the energy on one action, then stop."
        default: "Talk it through once, then leave it."
        }
        switch name {
        case "New Moon":
            return "You do not need a full plan. Pick one intention and leave it small. \(pace)"
        case "Full Moon":
            return "You can listen, including to yourself, without taking every feeling on. \(pace)"
        case "First Quarter":
            return "Something half-finished may want an answer. Choose the smaller version. \(pace)"
        default:
            return "This is a fair time to drop a plan that is only still here out of habit. \(pace)"
        }
    }

    private static func phaseCaution(_ name: String) -> String {
        switch name {
        case "New Moon": "Don't turn a wish into a commitment today."
        case "Full Moon": "Don't have the biggest conversation just because feelings are loud."
        case "First Quarter": "Don't solve the whole project in order to make one decision."
        default: "Don't throw out something useful just because you are tired of it."
        }
    }

    private static func natalMoodContrast(_ sign: ZodiacSign, chart: NatalChart?) -> String? {
        guard let chart else { return nil }
        if chart.isTimeKnown, let moon = chart.placement(.moon) {
            if moon.sign.element == sign.element {
                return "This is close to the way you usually feel things, so it may seem natural. You still choose what to do with it."
            }
            return "The way you usually feel things is more \(plainElement(moon.sign.element)). This mood is more \(plainElement(sign.element)). Let it change the pace without treating it as a new personality."
        }
        guard let sun = chart.placement(.sun) else { return nil }
        return "The way you usually take action is more \(plainElement(sun.sign.element)). This mood is more \(plainElement(sign.element)). Use the mood for the pace, and your usual way of acting for the decision."
    }

    private static func plainElement(_ element: String) -> String {
        switch element {
        case "Fire": "direct and energetic"
        case "Earth": "practical and steady"
        case "Air": "talkative and changeable"
        default: "feeling-led and close"
        }
    }

    private static func saturnPass(index: Int, count: Int, retrograde: Bool) -> String {
        let review = retrograde
            ? "Review a commitment you already have before you add a new one."
            : "Choose one commitment you still want, and loosen one you are keeping only out of habit."
        guard count > 1 else { return "A long chapter about responsibility is getting exact. \(review)" }
        switch index {
        case 0: return "This is the first exact pass of a longer chapter about responsibility. Notice what feels too heavy. You do not have to fix it yet."
        case count - 1: return "This is the last exact pass of that chapter. Keep the change that proved useful, and drop the experiment that did not. \(review)"
        default: return "You have already felt this once. Adjust the plan rather than starting over. \(review)"
        }
    }

    private static func eclipseTry(_ kind: String) -> String {
        switch kind {
        case "Total": "Notice what feels louder than usual, and write down the one change you might actually want."
        case "Annular": "Look again before you call something finished. A missing piece may still be out of view."
        default: "Only part of the story is visible. Note what shifted, and leave the conclusion for later."
        }
    }

    private static func eclipseCaution(_ kind: String) -> String {
        switch kind {
        case "Total": "Don't act on the whole feeling in one day."
        case "Annular": "Don't announce an ending that you have not checked."
        default: "Don't treat one strong moment as the entire change."
        }
    }

    // MARK: - Life context

    private static func focusLine(_ profile: UserProfile?) -> String? {
        guard let focus = profile?.personal?.currentFocus?.trimmingCharacters(in: .whitespacesAndNewlines),
              !focus.isEmpty else { return nil }
        let clipped = String(focus.prefix(180))
        return "You said this is on your mind: \"\(clipped)\". Use the timing to think about that, not as an answer to it."
    }

    private static func lifeContext(_ profile: UserProfile?, house: Int, lord: Planet) -> String? {
        if let line = relationshipLine(profile, natal: lord, house: house) { return line }
        return stageLine(profile, natal: lord, house: house)
    }

    private static func lifeContext(_ profile: UserProfile?, natal: Planet, house: Int?) -> String? {
        if let line = relationshipLine(profile, natal: natal, house: house) { return line }
        return stageLine(profile, natal: natal, house: house)
    }

    private static func relationshipLine(_ profile: UserProfile?, natal: Planet, house: Int?) -> String? {
        guard let status = profile?.personal?.relationship else { return nil }
        let relevant = [.venus, .moon].contains(natal) || house == 5 || house == 7
        guard relevant else { return nil }
        return switch status {
        case .single:
            "Since you are not seeing anyone in particular, this is about how you treat your own company and your friends, not about forcing a date."
        case .dating:
            "While you are dating, keep the conversation about this stretch of time, not about the whole future."
        case .committed, .married:
            "With a partner in the picture, one specific request will land better than a talk about the entire relationship."
        case .separated:
            "If a separation is still close, you do not have to resolve it in this stretch."
        case .complicated:
            "When the situation is already unclear, add one fact before you add another meaning."
        }
    }

    private static func stageLine(_ profile: UserProfile?, natal: Planet, house: Int?) -> String? {
        guard let stage = profile?.personal?.lifeStage else { return nil }
        let relevant = [.sun, .saturn, .mars, .jupiter].contains(natal) || house == 2 || house == 6 || house == 10
        guard relevant else { return nil }
        return switch stage {
        case .studying:
            "If you are studying, protect the work that is actually due before you redesign the whole plan."
        case .buildingCareer:
            "While you are building a career, improve work you can point to, rather than the story of where it is going."
        case .established:
            "You can use the stability you already have. You do not need to prove it again this week."
        case .changingPath:
            "A change of path goes better as the next concrete step, not as a full announcement."
        case .parenting:
            "With family depending on you, a shorter plan you can keep beats a perfect one."
        case .slowingDown:
            "You are allowed to do less. Keep the obligation that still matters, and let a smaller one wait."
        }
    }

    private static func variant(for seed: String, count: Int) -> Int {
        guard count > 1 else { return 0 }
        var hash = 5381
        for byte in seed.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        let value = hash == Int.min ? 0 : abs(hash)
        return value % count
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
