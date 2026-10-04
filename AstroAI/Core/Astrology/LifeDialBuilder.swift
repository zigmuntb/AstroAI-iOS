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
        if let house = sky.houses[.moon] {
            if [5, 7, 8].contains(house) {
                axis.addSky(-14, because: "The Moon is crossing your \(AstrologyLexicon.ordinal(house)) house, where closeness gathers.")
            } else if [6, 10].contains(house) {
                axis.addSky(14, because: "The Moon is crossing your \(AstrologyLexicon.ordinal(house)) house, where craft and responsibility come into focus.")
            }
        }
        if let moon {
            switch moon.sign {
            case .libra, .cancer, .taurus, .pisces:
                axis.addSky(-8, because: "A \(moon.sign.name) Moon softens the day toward people rather than tasks.")
            case .capricorn, .virgo, .aries:
                axis.addSky(8, because: "A \(moon.sign.name) Moon favors effort you can finish.")
            case .leo, .scorpio:
                axis.addSky(-3)
            default:
                break
            }
            axis.addSky((moon.degreeInSign - 15) * 0.28)
        }
        let venus = aspectPull(sky, transiting: [.venus, .moon], natal: [.venus, .moon, .sun])
        if venus > 0 {
            axis.addSky(-venus, because: "Venus is touching your chart, so rapport carries more weight than output.")
        }
        let duty = aspectPull(sky, transiting: [.saturn, .sun], natal: [.saturn, .sun, .mars])
        if duty > 0 {
            axis.addSky(duty, because: "A sober transit asks for the work that is already yours to do.")
        }
        axis.addSky(visiting([.saturn, .sun], houses: [6, 10], sky: sky, each: 4, cap: 6))
        axis.addSky(-visiting([.venus], houses: [5, 7], sky: sky, each: 5, cap: 6))
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
            axis.addPerson(-6, because: "Your life is already organized around a bond, and today can honor that.")
        case .single, .separated:
            axis.addPerson(3)
        case nil:
            break
        }
        switch profile?.personal?.lifeStage {
        case .buildingCareer, .studying, .established:
            axis.addPerson(6, because: "You are in a season of building, so the practical claim is louder.")
        case .parenting:
            axis.addPerson(-3)
        default:
            break
        }
        if profile?.interests.contains(.love) == true { axis.addPerson(-4) }
        if profile?.interests.contains(.career) == true { axis.addPerson(5) }
        if profile?.intentions.contains(.navigateRelationship) == true {
            axis.addPerson(-6, because: "You asked for help navigating a relationship, and that colors the day.")
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
                case ..<40: "Let relationships set the tone."
                case 40..<50: "A gentle lean toward the people close to you."
                case 51..<62: "A gentle lean toward the work in front of you."
                case 62...: "Give the day to the work itself."
                default: "Relationships and work can share the day."
                }
            }
        )
    }

    private static func circle(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot, moon: Ephemeris.Position?) -> LifeDial {
        var axis = Axis()
        if let house = sky.houses[.moon] {
            if [11, 3].contains(house) {
                axis.addSky(-14, because: "The Moon is in your \(AstrologyLexicon.ordinal(house)) house, among friends, messages and the wider circle.")
            } else if house == 4 {
                axis.addSky(16, because: "The Moon is home, in the house of roots and family.")
            }
        }
        if let moon {
            switch moon.sign {
            case .aquarius, .gemini, .sagittarius:
                axis.addSky(-7, because: "This Moon looks outward, toward the company you choose.")
            case .cancer, .taurus, .capricorn:
                axis.addSky(8, because: "This Moon turns toward home, memory and the people who feel like kin.")
            default:
                break
            }
            axis.addSky((moon.degreeInSign - 15) * 0.22)
        }
        let friendsSky = aspectPull(sky, transiting: [.jupiter, .uranus, .venus], natal: [.mercury, .uranus, .jupiter])
        if friendsSky > 0 {
            axis.addSky(-friendsSky, because: "The sky is stirring the part of you that belongs with friends.")
        }
        let familySky = aspectPull(sky, transiting: [.moon, .saturn, .venus], natal: [.moon, .saturn])
        if familySky > 0 {
            axis.addSky(familySky, because: "A transit is pressing on home, memory and the need to belong.")
        }
        axis.addSky(-visiting([.jupiter, .venus, .uranus], houses: [11, 3], sky: sky, each: 3, cap: 6))
        axis.addSky(visiting([.moon, .saturn, .venus], houses: [4], sky: sky, each: 4, cap: 6))

        if let house = natalHouse(chart, .moon) {
            if house == 4 { axis.addPerson(6) }
            if [11, 3].contains(house) { axis.addPerson(-5) }
        }
        if natalHouse(chart, .venus) == 11 { axis.addPerson(-4) }
        if natalHouse(chart, .sun) == 4 { axis.addPerson(4) }

        if profile?.personal?.lifeStage == .parenting {
            axis.addPerson(10, because: "Raising a family is the center you named, and the day can bend that way.")
        }
        if profile?.interests.contains(.friendship) == true {
            axis.addPerson(-6, because: "Friendship is one of the themes you asked the chart to watch.")
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
                case ..<40: "Friends have the clearer claim."
                case 40..<50: "A slight tilt toward the friends you choose."
                case 51..<62: "A slight tilt toward home and family."
                case 62...: "Family has the clearer claim."
                default: "Friends and family can each have a turn."
                }
            }
        )
    }

    private static func tempo(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot, moon: Ephemeris.Position?) -> LifeDial {
        var axis = Axis()
        if let house = sky.houses[.moon] {
            if [9, 5, 1].contains(house) {
                axis.addSky(-12, because: "The Moon is in a house of beginnings, so one unfamiliar step belongs in the day.")
            } else if [6, 2].contains(house) {
                axis.addSky(12, because: "The Moon is in a house of rhythm, where the familiar is the wiser craft.")
            }
        }
        if let moon {
            switch moon.sign.modality {
            case "Mutable":
                axis.addSky(-7, because: "A mutable Moon loosens the script and makes room for a small experiment.")
            case "Fixed":
                axis.addSky(8, because: "A fixed Moon steadies the day. Keep the rituals that already work.")
            default:
                axis.addSky(-2)
            }
            axis.addSky((15 - moon.degreeInSign) * 0.2)
        }
        if sky.moonPhase.name == "New Moon" || sky.moonPhase.illumination < 12 {
            axis.addSky(-8, because: "A new Moon is a clean start, better used for one beginning than for an overhaul.")
        } else if sky.moonPhase.name.contains("Waning") {
            axis.addSky(4, because: "The Moon is waning, a better time to tend what exists than to invent it.")
        }
        let fresh = aspectPull(sky, transiting: [.uranus, .jupiter], natal: [.sun, .mars, .uranus, .mercury])
        if fresh > 0 {
            axis.addSky(-fresh, because: "Uranus or Jupiter is stirring the part of your chart that wants a break in the pattern.")
        }
        let steady = aspectPull(sky, transiting: [.saturn], natal: [.sun, .moon, .saturn])
        if steady > 0 {
            axis.addSky(steady, because: "Saturn is reinforcing the structures you already keep.")
        }
        axis.addSky(-visiting([.uranus, .jupiter], houses: [1, 5, 9, 11], sky: sky, each: 3, cap: 6))
        axis.addSky(visiting([.saturn], houses: [2, 6, 10], sky: sky, each: 4, cap: 6))
        if sky.retrogrades.contains(.mercury) || sky.retrogrades.contains(.venus) {
            axis.addSky(5, because: "A retrograde asks you to revise the familiar before you add anything new.")
        }

        if let house = natalHouse(chart, .uranus), [1, 5, 9, 11].contains(house) { axis.addPerson(-5) }
        if let house = natalHouse(chart, .saturn), [2, 6, 10].contains(house) { axis.addPerson(5) }
        if modality(chart, "Mutable") >= 40 { axis.addPerson(-4) }
        if modality(chart, "Fixed") >= 40 { axis.addPerson(4) }

        switch profile?.personal?.lifeStage {
        case .changingPath:
            axis.addPerson(-8, because: "You are changing paths, so novelty has a real claim today.")
        case .established, .slowingDown:
            axis.addPerson(5, because: "The season you described is better served by rhythm than by reinvention.")
        default:
            break
        }
        if profile?.interests.contains(.growth) == true { axis.addPerson(-4) }
        if profile?.intentions.contains(.clarityDuringChange) == true {
            axis.addPerson(-6, because: "You asked for clarity during change, so leave a margin for the unfamiliar.")
        }
        if profile?.intentions.contains(.dailyHabits) == true {
            axis.addPerson(8, because: "You asked for help with daily habits, and the sky can support keeping them.")
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
                case 40..<50: "A small opening for something new."
                case 51..<62: "The familiar will serve you better than a reinvention."
                case 62...: "Stay with the rhythm you already trust."
                default: "One new gesture is enough, then return to the usual."
                }
            }
        )
    }

    private static func energy(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot, moon: Ephemeris.Position?) -> LifeDial {
        var axis = Axis()
        if let house = sky.houses[.moon] {
            if [12, 4].contains(house) {
                axis.addSky(-12, because: "The Moon is in a quiet house. Recovery is part of the work.")
            } else if [1, 6, 10].contains(house) {
                axis.addSky(12, because: "The Moon is in a house of doing. Energy wants a direction.")
            }
        }
        if let moon {
            switch moon.sign.element {
            case "Water":
                axis.addSky(-7, because: "A water Moon asks the body to set the pace.")
            case "Fire":
                axis.addSky(8, because: "A fire Moon wants movement more than management.")
            case "Earth":
                axis.addSky(3)
            default:
                break
            }
            axis.addSky((moon.degreeInSign - 15) * 0.18)
        }
        if sky.moonPhase.name.contains("Waning") || sky.moonPhase.name == "Last Quarter" {
            axis.addSky(-5, because: "The Moon is waning, a better time to restore than to launch.")
        } else if sky.moonPhase.name.contains("Waxing") || sky.moonPhase.name == "First Quarter" {
            axis.addSky(5, because: "The Moon is waxing, and effort started now has somewhere to grow.")
        }
        let drive = aspectPull(sky, transiting: [.mars, .sun], natal: [.mars, .sun, .ascendant])
        if drive > 0 {
            axis.addSky(drive, because: "Mars is awake in your chart. Use it on one clear effort.")
        }
        let fade = aspectPull(sky, transiting: [.neptune, .moon], natal: [.moon, .neptune])
        if fade > 0 {
            axis.addSky(-fade, because: "Neptune softens the edges. Rest will be more honest than force.")
        }
        axis.addSky(visiting([.mars, .sun], houses: [1, 10], sky: sky, each: 4, cap: 6))
        axis.addSky(-visiting([.neptune], houses: [12, 4], sky: sky, each: 4, cap: 6))
        if sky.retrogrades.contains(.mars) {
            axis.addSky(-6, because: "Mars is retrograde, so push less and aim better.")
        }

        if let house = natalHouse(chart, .mars), [1, 8, 10].contains(house) { axis.addPerson(5) }
        if let house = natalHouse(chart, .moon), house == 12 { axis.addPerson(-5) }
        if natalHouse(chart, .neptune) == 12 { axis.addPerson(-4) }
        if share(chart, "Fire") >= 40 { axis.addPerson(4) }
        if share(chart, "Water") >= 40 { axis.addPerson(-4) }

        switch profile?.personal?.lifeStage {
        case .slowingDown:
            axis.addPerson(-8, because: "You said you are slowing down. The day can agree without stalling you.")
        case .buildingCareer:
            axis.addPerson(5, because: "You are building, so a measured push still belongs in the day.")
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
                case 40..<50: "Move slowly. Rest is doing something."
                case 51..<62: "Spend the energy on one clear effort."
                case 62...: "The day wants movement more than management."
                default: "Alternate effort and ease, and don't skip either."
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
    private static func visiting(_ planets: Set<Planet>, houses: Set<Int>, sky: SkySnapshot, each: Double, cap: Double) -> Double {
        let hits = planets.filter { planet in
            planet != .moon && sky.houses[planet].map(houses.contains) == true
        }.count
        return min(Double(hits) * each, cap)
    }

    private static func natalHouse(_ chart: NatalChart?, _ planet: Planet) -> Int? {
        chart?.placement(planet)?.houseNumber
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
