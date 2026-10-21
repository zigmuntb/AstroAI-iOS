//
//  LifeDialBuilder.swift
//  AstroAI
//

import Foundation

/// Daily 0...100 leans. Each dial is one scale: 0 is the left pole, 100 is its opposite.
/// The sky moves the number every day; the natal chart and what the user shared shift the center.
enum LifeDialBuilder {
    static func dials(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot) -> [LifeDial] {
        let moon = sky.position(of: .moon)
        return [
            bonds(profile: profile, chart: chart, sky: sky, moon: moon),
            circle(profile: profile, chart: chart, sky: sky, moon: moon),
            tempo(profile: profile, chart: chart, sky: sky, moon: moon),
            energy(profile: profile, chart: chart, sky: sky, moon: moon)
        ]
    }

    // MARK: - Axes

    private static func bonds(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot, moon: Ephemeris.Position?) -> LifeDial {
        var axis = Axis()
        if EverydayVoice.housesAreReliable(chart), let house = sky.houses[.moon] {
            if [5, 7, 8].contains(house) {
                axis.addSky(-14, because: "Closeness may matter more than tasks today.")
            } else if [6, 10].contains(house) {
                axis.addSky(14, because: "Work and responsibility may take more of the day.")
            }
        }
        if let moon {
            switch moon.sign {
            case .libra, .cancer, .taurus, .pisces:
                axis.addSky(-8, because: "The day pulls toward people, not tasks.")
            case .capricorn, .virgo, .aries:
                axis.addSky(8, because: "The day favors work you can finish.")
            case .leo, .scorpio:
                axis.addSky(-3)
            default:
                break
            }
            axis.addSky((moon.degreeInSign - 15) * 0.28)
        }
        let venus = aspectPull(sky, transiting: [.venus, .moon], natal: [.venus, .moon, .sun])
        if venus > 0 {
            axis.addSky(-venus, because: "Connection may matter more than output today.")
        }
        let duty = aspectPull(sky, transiting: [.saturn, .sun], natal: [.saturn, .sun, .mars])
        if duty > 0 {
            axis.addSky(duty, because: "The day asks you to do the work that is already yours.")
        }
        axis.addSky(visiting([.saturn, .sun], houses: [6, 10], sky: sky, chart: chart, each: 4, cap: 6))
        axis.addSky(-visiting([.venus], houses: [5, 7], sky: sky, chart: chart, each: 5, cap: 6))
        axis.addSky(Double(50 - sky.moonPhase.illumination) * 0.05)

        if let house = natalHouse(chart, .venus) {
            if [5, 7, 8].contains(house) { axis.addPerson(-6) }
            if [6, 10].contains(house) { axis.addPerson(4) }
        }
        if let house = natalHouse(chart, .saturn), [6, 10].contains(house) { axis.addPerson(5) }
        if let house = natalHouse(chart, .sun), [6, 10].contains(house) { axis.addPerson(4) }
        if share(chart, "Water") >= 40 { axis.addPerson(-3) }
        if share(chart, "Earth") >= 40 { axis.addPerson(3) }

        switch profile?.personal?.relationship {
        case .dating, .committed, .married, .complicated:
            axis.addPerson(-6, because: "You're already in a relationship, so that can take more of the day.")
        case .single, .separated:
            axis.addPerson(3)
        case nil:
            break
        }
        switch profile?.personal?.lifeStage {
        case .buildingCareer, .studying, .established:
            axis.addPerson(6, because: "You're in a building phase, so practical work can take more of the day.")
        case .parenting:
            axis.addPerson(-3)
        default:
            break
        }
        if profile?.interests.contains(.love) == true { axis.addPerson(-4) }
        if profile?.interests.contains(.career) == true { axis.addPerson(5) }
        if profile?.intentions.contains(.navigateRelationship) == true {
            axis.addPerson(-6, because: "You asked for help with a relationship, so that can shape the day.")
        }
        if focus(profile, contains: ["love", "relationship", "partner", "dating", "romance", "boyfriend", "girlfriend", "wife", "husband", "отношен", "любов", "партнер"]) {
            axis.addPerson(-8, because: "This follows what you said is on your mind right now.")
        }
        if focus(profile, contains: ["work", "job", "career", "office", "project", "boss", "работ", "карьер", "проект", "офис"]) {
            axis.addPerson(8, because: "This follows what you said is on your mind right now.")
        }

        let cares = caresAbout(
            profile,
            interests: [.love, .career],
            intentions: [.navigateRelationship],
            stages: [.buildingCareer, .studying, .established, .parenting]
        ) || profile?.personal?.relationship != nil
        return make(
            id: "bonds",
            left: "Relationships",
            right: "Work",
            leftIcon: "heart",
            rightIcon: "briefcase",
            axis: axis,
            gain: cares ? 1.18 : 1,
            lead: { value in
                switch value {
                case ..<40: "Let relationships lead the day."
                case 40..<50: "A small lean toward the people close to you."
                case 51..<62: "A small lean toward the work in front of you."
                case 62...: "Give the day to the work."
                default: "Relationships and work can share the day."
                }
            }
        )
    }

    private static func circle(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot, moon: Ephemeris.Position?) -> LifeDial {
        var axis = Axis()
        if EverydayVoice.housesAreReliable(chart), let house = sky.houses[.moon] {
            if [11, 3].contains(house) {
                axis.addSky(-14, because: "Friends and messages may take more of the day.")
            } else if house == 4 {
                axis.addSky(16, because: "Home and family may have the clearer claim.")
            }
        }
        if let moon {
            switch moon.sign {
            case .aquarius, .gemini, .sagittarius:
                axis.addSky(-7, because: "The people you choose to spend time with may matter more.")
            case .cancer, .taurus, .capricorn:
                axis.addSky(8, because: "Home and the people who feel like family may matter more.")
            default:
                break
            }
            axis.addSky((moon.degreeInSign - 15) * 0.22)
        }
        let friendsSky = aspectPull(sky, transiting: [.jupiter, .uranus, .venus], natal: [.mercury, .uranus, .jupiter])
        if friendsSky > 0 {
            axis.addSky(-friendsSky, because: "The people you choose to spend time with may matter more today.")
        }
        let familySky = aspectPull(sky, transiting: [.moon, .saturn, .venus], natal: [.moon, .saturn])
        if familySky > 0 {
            axis.addSky(familySky, because: "Home and the need to belong may ask for more attention.")
        }
        axis.addSky(-visiting([.jupiter, .venus, .uranus], houses: [11, 3], sky: sky, chart: chart, each: 3, cap: 6))
        axis.addSky(visiting([.moon, .saturn, .venus], houses: [4], sky: sky, chart: chart, each: 4, cap: 6))

        if let house = natalHouse(chart, .moon) {
            if house == 4 { axis.addPerson(6) }
            if [11, 3].contains(house) { axis.addPerson(-5) }
        }
        if natalHouse(chart, .venus) == 11 { axis.addPerson(-4) }
        if natalHouse(chart, .sun) == 4 { axis.addPerson(4) }

        if profile?.personal?.lifeStage == .parenting {
            axis.addPerson(10, because: "You said raising a family is the center, so the day can lean that way.")
        }
        if profile?.interests.contains(.friendship) == true {
            axis.addPerson(-6, because: "You asked for help with friendship, so that can shape the day.")
        }
        if focus(profile, contains: ["friend", "друз", "подруг"]) {
            axis.addPerson(-8, because: "This follows what you said is on your mind right now.")
        }
        if focus(profile, contains: ["family", "parent", "mom", "dad", "mother", "father", "kids", "child", "home", "семь", "родител", "мама", "папа", "дети"]) {
            axis.addPerson(8, because: "This follows what you said is on your mind right now.")
        }

        let cares = caresAbout(
            profile,
            interests: [.friendship],
            intentions: [],
            stages: [.parenting]
        )
        return make(
            id: "circle",
            left: "Friends",
            right: "Family",
            leftIcon: "person.2",
            rightIcon: "house",
            axis: axis,
            gain: cares ? 1.18 : 1,
            lead: { value in
                switch value {
                case ..<40: "Spend more of the day with friends."
                case 40..<50: "A small lean toward friends."
                case 51..<62: "A small lean toward home and family."
                case 62...: "Spend more of the day with family."
                default: "Friends and family can share the day."
                }
            }
        )
    }

    private static func tempo(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot, moon: Ephemeris.Position?) -> LifeDial {
        var axis = Axis()
        if EverydayVoice.housesAreReliable(chart), let house = sky.houses[.moon] {
            if [9, 5, 1].contains(house) {
                axis.addSky(-12, because: "One new step fits today better than a full overhaul.")
            } else if [6, 2].contains(house) {
                axis.addSky(12, because: "Sticking with what you already know works better today.")
            }
        }
        if let moon {
            switch moon.sign.modality {
            case "Mutable":
                axis.addSky(-7, because: "There is room for one small experiment.")
            case "Fixed":
                axis.addSky(8, because: "The habits that already work are the better bet.")
            default:
                axis.addSky(-2)
            }
            axis.addSky((15 - moon.degreeInSign) * 0.2)
        }
        if sky.moonPhase.name == "New Moon" || sky.moonPhase.illumination < 12 {
            axis.addSky(-8, because: "This is a clean start. Use it for one new beginning, not a full overhaul.")
        } else if sky.moonPhase.name.contains("Waning") {
            axis.addSky(4, because: "This is a better time to take care of what you already have.")
        }
        let fresh = aspectPull(sky, transiting: [.uranus, .jupiter], natal: [.sun, .mars, .uranus, .mercury])
        if fresh > 0 {
            axis.addSky(-fresh, because: "There is room for one change, not a full restart.")
        }
        let steady = aspectPull(sky, transiting: [.saturn], natal: [.sun, .moon, .saturn])
        if steady > 0 {
            axis.addSky(steady, because: "The habits you already keep are the better bet today.")
        }
        axis.addSky(-visiting([.uranus, .jupiter], houses: [1, 5, 9, 11], sky: sky, chart: chart, each: 3, cap: 6))
        axis.addSky(visiting([.saturn], houses: [2, 6, 10], sky: sky, chart: chart, each: 4, cap: 6))
        if sky.retrogrades.contains(.mercury) || sky.retrogrades.contains(.venus) {
            axis.addSky(5, because: "Review what you already have before you add anything new.")
        }

        if let house = natalHouse(chart, .uranus), [1, 5, 9, 11].contains(house) { axis.addPerson(-5) }
        if let house = natalHouse(chart, .saturn), [2, 6, 10].contains(house) { axis.addPerson(5) }
        if modality(chart, "Mutable") >= 40 { axis.addPerson(-4) }
        if modality(chart, "Fixed") >= 40 { axis.addPerson(4) }

        switch profile?.personal?.lifeStage {
        case .changingPath:
            axis.addPerson(-8, because: "You're changing paths, so something new can take more of the day.")
        case .established, .slowingDown:
            axis.addPerson(5, because: "The phase you described works better with routine than with starting over.")
        default:
            break
        }
        if profile?.interests.contains(.growth) == true { axis.addPerson(-4) }
        if profile?.intentions.contains(.clarityDuringChange) == true {
            axis.addPerson(-6, because: "You asked for clarity during change, so leave room for something unfamiliar.")
        }
        if profile?.intentions.contains(.dailyHabits) == true {
            axis.addPerson(8, because: "You asked for help with daily habits, and today can support keeping them.")
        }
        if focus(profile, contains: ["new", "change", "travel", "adventure", "start over", "нов", "перемен", "путешеств"]) {
            axis.addPerson(-8, because: "This follows what you said is on your mind right now.")
        }
        if focus(profile, contains: ["routine", "habit", "schedule", "рутин", "привыч", "режим"]) {
            axis.addPerson(8, because: "This follows what you said is on your mind right now.")
        }

        let cares = caresAbout(
            profile,
            interests: [.growth, .dailyGuidance],
            intentions: [.dailyHabits, .clarityDuringChange],
            stages: [.changingPath, .slowingDown, .established]
        )
        return make(
            id: "tempo",
            left: "New",
            right: "Routine",
            leftIcon: "sparkles",
            rightIcon: "repeat",
            axis: axis,
            gain: cares ? 1.18 : 1,
            lead: { value in
                switch value {
                case ..<40: "Try one thing that isn't already in the plan."
                case 40..<50: "Leave a small opening for something new."
                case 51..<62: "What you already do will work better than starting over."
                case 62...: "Stay with the routine you already trust."
                default: "Try one new thing, then go back to your usual day."
                }
            }
        )
    }

    private static func energy(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot, moon: Ephemeris.Position?) -> LifeDial {
        var axis = Axis()
        if EverydayVoice.housesAreReliable(chart), let house = sky.houses[.moon] {
            if [12, 4].contains(house) {
                axis.addSky(-12, because: "Rest is part of the work today.")
            } else if [1, 6, 10].contains(house) {
                axis.addSky(12, because: "The energy needs somewhere to go. Give it one clear task.")
            }
        }
        if let moon {
            switch moon.sign.element {
            case "Water":
                axis.addSky(-7, because: "Let your energy set the pace.")
            case "Fire":
                axis.addSky(8, because: "Movement will feel better than more planning.")
            case "Earth":
                axis.addSky(3)
            default:
                break
            }
            axis.addSky((moon.degreeInSign - 15) * 0.18)
        }
        if sky.moonPhase.name.contains("Waning") || sky.moonPhase.name == "Last Quarter" {
            axis.addSky(-5, because: "This is a better time to recover than to start something big.")
        } else if sky.moonPhase.name.contains("Waxing") || sky.moonPhase.name == "First Quarter" {
            axis.addSky(5, because: "Effort you start now has room to grow.")
        }
        let drive = aspectPull(sky, transiting: [.mars, .sun], natal: [.mars, .sun, .ascendant])
        if drive > 0 {
            axis.addSky(drive, because: "Use the extra energy on one clear task.")
        }
        let fade = aspectPull(sky, transiting: [.neptune, .moon], natal: [.moon, .neptune])
        if fade > 0 {
            axis.addSky(-fade, because: "The edges may feel fuzzy. Rest will be more honest than pushing.")
        }
        axis.addSky(visiting([.mars, .sun], houses: [1, 10], sky: sky, chart: chart, each: 4, cap: 6))
        axis.addSky(-visiting([.neptune], houses: [12, 4], sky: sky, chart: chart, each: 4, cap: 6))
        if sky.retrogrades.contains(.mars) {
            axis.addSky(-6, because: "Push less and aim better.")
        }

        if let house = natalHouse(chart, .mars), [1, 8, 10].contains(house) { axis.addPerson(5) }
        if let house = natalHouse(chart, .moon), house == 12 { axis.addPerson(-5) }
        if natalHouse(chart, .neptune) == 12 { axis.addPerson(-4) }
        if share(chart, "Fire") >= 40 { axis.addPerson(4) }
        if share(chart, "Water") >= 40 { axis.addPerson(-4) }

        switch profile?.personal?.lifeStage {
        case .slowingDown:
            axis.addPerson(-8, because: "You said you are slowing down. Today can match that without stopping you.")
        case .buildingCareer:
            axis.addPerson(5, because: "You're building, so a steady push still fits today.")
        default:
            break
        }
        if profile?.interests.contains(.emotions) == true { axis.addPerson(-3) }
        if profile?.intentions.contains(.exploreStrengths) == true { axis.addPerson(4) }
        if profile?.intentions.contains(.understandMyself) == true { axis.addPerson(-3) }
        if focus(profile, contains: ["rest", "tired", "sleep", "burnout", "exhausted", "отдых", "устал", "сон", "выгоран"]) {
            axis.addPerson(-8, because: "This follows what you said is on your mind right now.")
        }
        if focus(profile, contains: ["energy", "gym", "workout", "goal", "трениров", "спорт", "энерг", "цель"]) {
            axis.addPerson(8, because: "This follows what you said is on your mind right now.")
        }

        let cares = caresAbout(
            profile,
            interests: [.emotions],
            intentions: [.exploreStrengths, .understandMyself],
            stages: [.slowingDown, .buildingCareer]
        )
        return make(
            id: "energy",
            left: "Rest",
            right: "Action",
            leftIcon: "moon.stars",
            rightIcon: "bolt",
            axis: axis,
            gain: cares ? 1.18 : 1,
            lead: { value in
                switch value {
                case ..<40: "Protect the quiet. Keep action small."
                case 40..<50: "Move slowly. Rest counts."
                case 51..<62: "Spend the energy on one clear task."
                case 62...: "This is a day to move, not to organize."
                default: "Switch between effort and rest. Don't skip either."
                }
            }
        )
    }

    // MARK: - Scoring

    private static func make(
        id: String,
        left: String,
        right: String,
        leftIcon: String,
        rightIcon: String,
        axis: Axis,
        gain: Double,
        lead: (Int) -> String
    ) -> LifeDial {
        let value = axis.value(gain: gain)
        let because = axis.explanation(towardRight: value > 50)
        let note = because.isEmpty || value == 50 ? lead(value) : "\(lead(value)) \(because)"
        return LifeDial(id: id, left: left, right: right, leftIcon: leftIcon, rightIcon: rightIcon, value: value, note: note)
    }

    /// How strongly today's aspects pull, capped so several hits cannot pin the dial.
    private static func aspectPull(_ sky: SkySnapshot, transiting: Set<Planet>, natal: Set<Planet>) -> Double {
        var total = 0.0
        for transit in sky.transits where transiting.contains(transit.transiting) && natal.contains(transit.natal) {
            let closeness = max(0, (3 - min(transit.orb, 3)) / 3)
            let weight = transit.transiting == .moon ? 6.0 : 9.0
            total += closeness * weight
            if total >= 12 { return 12 }
        }
        return total
    }

    /// Transiting planets currently walking a set of natal houses. The Moon is scored on its own.
    private static func visiting(_ planets: Set<Planet>, houses: Set<Int>, sky: SkySnapshot, chart: NatalChart?, each: Double, cap: Double) -> Double {
        guard EverydayVoice.housesAreReliable(chart) else { return 0 }
        let hits = planets.filter { planet in
            planet != .moon && sky.houses[planet].map(houses.contains) == true
        }.count
        return min(Double(hits) * each, cap)
    }

    private static func natalHouse(_ chart: NatalChart?, _ planet: Planet) -> Int? {
        guard EverydayVoice.housesAreReliable(chart) else { return nil }
        return chart?.placement(planet)?.houseNumber
    }

    private static func share(_ chart: NatalChart?, _ name: String) -> Int {
        chart?.elements.first { $0.name == name }?.percent ?? 0
    }

    private static func modality(_ chart: NatalChart?, _ name: String) -> Int {
        chart?.modalities.first { $0.name == name }?.percent ?? 0
    }

    private static func focus(_ profile: UserProfile?, contains keywords: [String]) -> Bool {
        guard let text = profile?.personal?.currentFocus?.lowercased(), !text.isEmpty else { return false }
        return keywords.contains { text.contains($0) }
    }

    private static func caresAbout(
        _ profile: UserProfile?,
        interests: Set<Interest>,
        intentions: Set<Intention>,
        stages: Set<LifeStage>
    ) -> Bool {
        guard let profile else { return false }
        if !profile.interests.isDisjoint(with: interests) { return true }
        if !profile.intentions.isDisjoint(with: intentions) { return true }
        if let stage = profile.personal?.lifeStage, stages.contains(stage) { return true }
        return false
    }
}

/// Accumulates a lean. Positive amounts move toward the right pole.
private struct Axis {
    private struct Reason {
        let amount: Double
        let text: String
    }

    private var sky = 0.0
    private var person = 0.0
    private var reasons: [Reason] = []

    mutating func addSky(_ amount: Double, because text: String? = nil) {
        sky += amount
        remember(amount, text)
    }

    mutating func addPerson(_ amount: Double, because text: String? = nil) {
        person += amount
        remember(amount, text)
    }

    func value(gain: Double) -> Int {
        let skyCapped = min(28, max(-28, sky))
        let personCapped = min(16, max(-16, person))
        let raw = 50 + skyCapped * gain + personCapped
        return Int(min(92, max(8, raw)).rounded())
    }

    /// The strongest reason that points the same way as the finished score.
    func explanation(towardRight: Bool) -> String {
        let pool = reasons.filter { towardRight ? $0.amount > 0 : $0.amount < 0 }
        return pool.max(by: { abs($0.amount) < abs($1.amount) })?.text ?? ""
    }

    private mutating func remember(_ amount: Double, _ text: String?) {
        guard let text, amount != 0 else { return }
        reasons.append(Reason(amount: amount, text: text))
    }
}
