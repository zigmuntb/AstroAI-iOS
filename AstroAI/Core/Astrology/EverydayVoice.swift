//
//  EverydayVoice.swift
//  AstroAI
//
//  Turns calculated sky and chart facts into everyday language.
//  Technical terms stay in the optional detail, and only when the chart supports them.
//

import Foundation

enum EverydayVoice {
    struct DayCopy {
        let atmosphere: String
        let title: String
        let text: String
        let astrologyTitle: String
        let astrologyText: String
        let focus: String
        let caution: String
        let reflection: String
        let areas: [LifeArea]
        let questions: [String]
        let journalQuestion: String
        let journalNote: String
    }

    struct WidgetLines {
        let headline: String
        let detail: String
    }

    /// The tightest transit the available birth data can support.
    /// Natal Moon and rising contacts need an exact birth time.
    static func supportedTransit(chart: NatalChart?, sky: SkySnapshot) -> NatalTransit? {
        guard let chart else { return nil }
        return sky.transits.first { transit in
            guard transit.transiting != .moon else { return false }
            if chart.isTimeKnown { return true }
            return transit.natal != .moon && transit.natal != .ascendant
        }
    }

    /// House numbers and the rising sign need an exact birth time and a birthplace.
    static func housesAreReliable(_ chart: NatalChart?) -> Bool {
        chart?.hasLocation == true && chart?.isTimeKnown == true
    }

    static func day(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot) -> DayCopy {
        let moonSign = sky.position(of: .moon)?.sign ?? .gemini
        let transit = supportedTransit(chart: chart, sky: sky)
        let focusNote = profile?.personal?.currentFocus?.trimmingCharacters(in: .whitespacesAndNewlines)
        let focus = focusNote?.isEmpty == false ? focusNote : nil
        let tone = tone(for: transit, moon: moonSign)

        return DayCopy(
            atmosphere: atmosphere(for: tone, moon: moonSign),
            title: title(for: tone, focus: focus),
            text: outlook(name: profile?.name, moon: moonSign, phase: sky.moonPhase, transit: transit, focus: focus, tone: tone),
            astrologyTitle: astrologyTitle(transit: transit, moon: moonSign, phase: sky.moonPhase),
            astrologyText: astrologyText(chart: chart, sky: sky, moon: moonSign, transit: transit),
            focus: action(for: tone, transit: transit),
            caution: caution(for: tone, transit: transit),
            reflection: reflection(for: tone, transit: transit),
            areas: areas(chart: chart, sky: sky, transit: transit, moon: moonSign),
            questions: questions(profile: profile, transit: transit),
            journalQuestion: journalQuestion(transit: transit, moon: moonSign),
            journalNote: "A reflection on the day. It is not a record of what happened."
        )
    }

    static func widgetLines(chart: NatalChart?, sky: SkySnapshot) -> WidgetLines {
        let moon = sky.position(of: .moon)?.sign ?? .gemini
        let transit = supportedTransit(chart: chart, sky: sky)
        let tone = tone(for: transit, moon: moon)
        return WidgetLines(headline: shortFocus(for: tone, transit: transit, moon: moon), detail: action(for: tone, transit: transit))
    }

    static func morningBody(chart: NatalChart?, sky: SkySnapshot) -> String {
        widgetLines(chart: chart, sky: sky).detail
    }

    // MARK: - Outlook

    private enum Tone {
        case strained, open, focused, steady
    }

    private static func tone(for transit: NatalTransit?, moon: ZodiacSign) -> Tone {
        switch transit?.kind {
        case .square, .opposition: .strained
        case .trine, .sextile: .open
        case .conjunction: .focused
        case nil: moon.element == "Earth" ? .steady : .open
        }
    }

    private static func atmosphere(for tone: Tone, moon: ZodiacSign) -> String {
        switch tone {
        case .strained: "A day to go a little slower"
        case .open: "A little more room than usual"
        case .focused: "One theme may stand out"
        case .steady: moodLine(moon)
        }
    }

    private static func title(for tone: Tone, focus: String?) -> String {
        if focus != nil { return "Next to what's on your mind" }
        return switch tone {
        case .strained: "A day for patience"
        case .open: "A day with a little more ease"
        case .focused: "One thing at a time"
        case .steady: "Your day, in a nutshell"
        }
    }

    private static func outlook(name: String?, moon: ZodiacSign, phase: MoonPhase, transit: NatalTransit?, focus: String?, tone: Tone) -> String {
        var sentences = [feeling(moon)]
        if let transit {
            sentences.append(transitLife(transit))
        } else {
            sentences.append(phaseLine(phase))
        }
        if let focus, !focus.isEmpty {
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let who = (trimmed?.isEmpty == false) ? "\(trimmed!), you" : "You"
            sentences.append("\(who) said this is on your mind: \"\(focus)\". Use today as a way to think about that, not as an answer.")
        } else {
            sentences.append(action(for: tone, transit: transit))
        }
        return sentences.joined(separator: " ")
    }

    private static func moodLine(_ sign: ZodiacSign) -> String {
        switch sign.element {
        case "Water": "Feelings may sit closer to the surface"
        case "Fire": "More energy than patience"
        case "Earth": "A steadier, practical mood"
        default: "A good day for talking things through"
        }
    }

    private static func feeling(_ sign: ZodiacSign) -> String {
        switch sign {
        case .aries: "You may feel ready to start, and a little impatient if things move slowly."
        case .taurus: "You may want the day to feel steady. Rushing a decision is unlikely to help."
        case .gemini: "Your mind may jump between a few conversations. One clear reply is enough."
        case .cancer: "You may take other people's moods more personally than usual."
        case .leo: "You may want to be seen. Attention is not the same thing as agreement."
        case .virgo: "Small details may bother you. Fix one of them, then leave the rest."
        case .libra: "You may want everyone to get along. A kind no is still kind."
        case .scorpio: "You may notice what is not being said. Ask before you decide what it means."
        case .sagittarius: "You may want a bigger view. The next step can still be small."
        case .capricorn: "Responsibility may feel heavier. Finish what is already yours."
        case .aquarius: "You may want some distance. That is not the same as not caring."
        case .pisces: "You may absorb the mood around you. A short break can make it clearer what is yours."
        }
    }

    private static func phaseLine(_ phase: MoonPhase) -> String {
        switch phase.name {
        case "New Moon": "This is a quieter point in the month. You do not need a full plan today."
        case "Full Moon": "Feelings, including other people's, may be easier to notice. You still do not have to act on all of them."
        case "First Quarter", "Last Quarter": "Something half-finished may ask for a decision. Choose the smaller version."
        default: "The day does not have to be dramatic to be useful. Notice what keeps coming back."
        }
    }

    /// Everyday meaning of a calculated transit. The planet names stay out of this sentence.
    private static func transitLife(_ transit: NatalTransit) -> String {
        let theme = transit.natal.meaning
        switch transit.kind {
        case .square, .opposition:
            return "Something about your \(theme) may feel a little strained. Give it time before you react."
        case .trine, .sextile:
            return "Your \(theme) may be a bit easier to work with. A small step can be enough."
        case .conjunction:
            return "Your \(theme) may be more noticeable today. Notice it without turning every feeling into a decision."
        }
    }

    // MARK: - Actions

    private static func action(for tone: Tone, transit: NatalTransit?) -> String {
        switch transit?.natal {
        case .mercury:
            return "If something was unclear, say what you mean in one or two sentences."
        case .venus, .moon:
            return "If someone seems quiet, ask one simple question instead of guessing."
        case .mars:
            return "Put the extra energy into one task, then stop."
        case .saturn, .sun:
            return "Pick the task that is already yours and finish it before you add another."
        case .jupiter:
            return "Say yes to one opportunity, not to every one that appears."
        default:
            switch tone {
            case .strained: return "Pause before you answer something that bothers you."
            case .open: return "Do the one thing you have been putting off in a small way."
            case .focused: return "Give one subject your attention and leave the rest for later."
            case .steady: return "Keep the plan you already have. You do not need a new one."
            }
        }
    }

    private static func caution(for tone: Tone, transit: NatalTransit?) -> String {
        switch transit?.natal {
        case .venus, .moon:
            return "Do not treat someone's quiet mood as proof that something is wrong."
        case .mercury:
            return "Do not send the long message while you are still irritated."
        case .mars:
            return "Do not make the sharp comment just because you can."
        default:
            switch tone {
            case .strained: return "Do not decide the whole situation from one awkward moment."
            case .open: return "Ease is not a reason to start three things at once."
            case .focused: return "A strong feeling is not the same as a finished decision."
            case .steady: return "Do not fill a calm day with problems you cannot solve today."
            }
        }
    }

    private static func reflection(for tone: Tone, transit: NatalTransit?) -> String {
        switch transit?.natal {
        case .venus, .moon: return "What am I assuming before I have asked?"
        case .mercury: return "What do I actually want them to understand?"
        case .saturn, .sun: return "What is mine to finish, and what can wait?"
        default:
            switch tone {
            case .strained: return "What would a calmer reply look like?"
            case .open: return "What is one conversation worth having today?"
            default: return "What can I leave unfinished without making it a problem?"
            }
        }
    }

    private static func shortFocus(for tone: Tone, transit: NatalTransit?, moon: ZodiacSign) -> String {
        switch transit?.natal {
        case .mercury: return "Say what you mean"
        case .venus, .moon: return "Don't assume the worst"
        case .mars: return "Use the energy once"
        case .saturn, .sun: return "Finish one task"
        case .jupiter: return "Choose one yes"
        default:
            switch tone {
            case .strained: return "Pause before you react"
            case .focused: return "One thing at a time"
            case .steady: return moon.element == "Earth" ? "Finish one task" : "Keep it simple"
            case .open: return "Take one small step"
            }
        }
    }

    // MARK: - Areas

    private static func areas(chart: NatalChart?, sky: SkySnapshot, transit: NatalTransit?, moon: ZodiacSign) -> [LifeArea] {
        var result = [
            area(
                icon: "heart",
                title: "Love & relationships",
                text: loveText(sky: sky, transit: transit),
                planet: .venus,
                sky: sky,
                chart: chart
            ),
            area(
                icon: "briefcase",
                title: "Work & goals",
                text: workText(sky: sky, transit: transit, moon: moon),
                planet: .saturn,
                sky: sky,
                chart: chart
            ),
            area(
                icon: "leaf",
                title: "Mood & energy",
                text: feeling(moon),
                planet: .moon,
                sky: sky,
                chart: chart
            )
        ]
        if showsMoney(chart: chart, sky: sky, transit: transit) {
            result.append(area(
                icon: "banknote",
                title: "Money & decisions",
                text: "Wait before a purchase or a promise you cannot undo. Write down why you want it, then decide tomorrow if you still do.",
                planet: .jupiter,
                sky: sky,
                chart: chart
            ))
        } else {
            result.append(area(
                icon: "person.2",
                title: "Friends & family",
                text: friendsText(sky: sky),
                planet: .mercury,
                sky: sky,
                chart: chart
            ))
        }
        return result
    }

    private static func showsMoney(chart: NatalChart?, sky: SkySnapshot, transit: NatalTransit?) -> Bool {
        let moneyPlanets: Set<Planet> = [.jupiter, .saturn, .venus]
        if let transit, moneyPlanets.contains(transit.transiting) || moneyPlanets.contains(transit.natal) {
            return transit.natal == .venus || transit.natal == .jupiter || transit.natal == .saturn || transit.transiting == .jupiter
        }
        guard housesAreReliable(chart) else { return false }
        let venusHouse = sky.houses[.venus]
        let jupiterHouse = sky.houses[.jupiter]
        return venusHouse == 2 || venusHouse == 8 || jupiterHouse == 2 || jupiterHouse == 8
    }

    private static func loveText(sky: SkySnapshot, transit: NatalTransit?) -> String {
        let involved = transit.map { [.venus, .moon].contains($0.natal) || $0.transiting == .venus } ?? false
        if involved, transit?.kind == .square || transit?.kind == .opposition {
            return "Someone close may seem distant. They could be tired or preoccupied. Ask something simple, like whether they are all right, instead of deciding for them."
        }
        if involved {
            return "If something is unsaid, one honest sentence is better than a long explanation. Then leave room for their answer."
        }
        let venus = sky.position(of: .venus)?.sign
        if venus?.element == "Water" || venus?.element == "Earth" {
            return "Closeness may matter more than being right. If someone is quiet, give them a little room before you decide what it means."
        }
        return "Keep the important conversation specific. Ask what the other person means before you react to the tone."
    }

    private static func workText(sky: SkySnapshot, transit: NatalTransit?, moon: ZodiacSign) -> String {
        let involved = transit.map { [.saturn, .sun, .mars].contains($0.natal) || [.saturn, .mars].contains($0.transiting) } ?? false
        if involved, transit?.kind == .square || transit?.kind == .opposition {
            return "A task may feel heavier than it is. Do the next concrete step, and leave the bigger decision until you are less frustrated."
        }
        if involved || moon.element == "Earth" {
            return "Finish one piece of work before you open something new. A finished small task will feel better than a long list."
        }
        let mercury = sky.position(of: .mercury)?.sign
        if mercury?.element == "Air" {
            return "Meetings and messages may multiply. Decide which one actually needs you, and let the others wait."
        }
        return "Protect a short block of time for the work that matters. Starting the day in your inbox can use it up."
    }

    private static func friendsText(sky: SkySnapshot) -> String {
        let mercury = sky.position(of: .mercury)?.sign
        if mercury?.element == "Air" || mercury?.element == "Fire" {
            return "A short, direct message may clear more than you expect. Say what you mean, then stop."
        }
        return "Listen before you offer a fix. Someone close may want to be heard more than they want advice."
    }

    private static func area(icon: String, title: String, text: String, planet: Planet, sky: SkySnapshot, chart: NatalChart?) -> LifeArea {
        LifeArea(icon: icon, title: title, text: text, detail: planetDetail(planet, sky: sky, chart: chart))
    }

    private static func planetDetail(_ planet: Planet, sky: SkySnapshot, chart: NatalChart?) -> String? {
        guard let position = sky.position(of: planet == .moon ? .moon : planet) else { return nil }
        var text = "\(position.planet.name) is associated with \(position.planet.meaning). Today it is in \(position.sign.name), a sign often described as \(position.sign.qualities)."
        if position.isRetrograde, planet != .moon {
            text += " It is retrograde, which is traditionally read as a reason to review this area instead of starting something new."
        }
        if housesAreReliable(chart), let house = sky.houses[position.planet] {
            text += " It is passing through the part of your chart about \(AstrologyLexicon.houseTheme(house)). Astrologers call that the \(AstrologyLexicon.ordinal(house)) house."
        }
        text += " This is an interpretation of the sky, not a fact about what will happen."
        return text
    }

    // MARK: - Astrology detail

    private static func astrologyTitle(transit: NatalTransit?, moon: ZodiacSign, phase: MoonPhase) -> String {
        if let transit {
            return "\(transit.transiting.name) and your \(transit.natal.name)"
        }
        return "\(phase.name) · Moon in \(moon.name)"
    }

    private static func astrologyText(chart: NatalChart?, sky: SkySnapshot, moon: ZodiacSign, transit: NatalTransit?) -> String {
        var parts: [String] = []
        parts.append("The Moon describes mood and what helps people feel safe. It is in \(moon.name) during a \(sky.moonPhase.name), about \(sky.moonPhase.illumination)% lit. \(moon.name) is often described as \(moon.qualities).")
        if let transit {
            let kind = transit.kind.name.lowercased()
            parts.append("\(transit.transiting.name) is associated with \(transit.transiting.meaning). Its current relationship with your natal \(transit.natal.name) — your \(transit.natal.meaning) — is a \(kind). A \(kind) is traditionally read as \(aspectPlain(transit.kind)).")
            if housesAreReliable(chart), let house = sky.houses[transit.transiting] {
                parts.append("That planet is passing through the part of your chart about \(AstrologyLexicon.houseTheme(house)), called the \(AstrologyLexicon.ordinal(house)) house.")
            }
        } else if chart == nil {
            parts.append("There is no birth chart yet, so this uses today's Moon only.")
        }
        if let retro = sky.retrogrades.first {
            parts.append("\(retro.name) is retrograde. That is traditionally a time to review \(retro.meaning) rather than begin something new.")
        }
        if chart != nil, !housesAreReliable(chart) {
            if chart?.hasLocation == false {
                parts.append("Birthplace is missing, so this reading does not use houses or a rising sign.")
            } else {
                parts.append("The birth time is missing or approximate, so houses and the rising sign are left out.")
            }
        }
        return parts.joined(separator: " ")
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

    // MARK: - Questions

    private static func questions(profile: UserProfile?, transit: NatalTransit?) -> [String] {
        var result: [String] = []
        let interests = profile?.interests ?? []
        if interests.contains(.love) || transit?.natal == .venus || transit?.natal == .moon {
            result.append("Why might someone close to me seem distant today?")
        }
        if interests.contains(.career) || transit?.natal == .saturn || transit?.natal == .sun {
            result.append("What should I focus on at work today?")
        }
        if interests.contains(.emotions) {
            result.append("Why am I feeling this way today?")
        }
        result.append("Is today a good day to talk about something important?")
        result.append("What should I focus on today?")
        result.append("How should I approach a difficult conversation?")
        var seen = Set<String>()
        return Array(result.filter { seen.insert($0).inserted }.prefix(3))
    }

    private static func journalQuestion(transit: NatalTransit?, moon: ZodiacSign) -> String {
        if let transit {
            return "Where did your \(transit.natal.meaning) ask for more care today, and what would you do differently?"
        }
        return "What did a \(moon.name) mood bring up that you do not need to solve tonight?"
    }
}
