//
//  MockData.swift
//  AstroAI
//
//  Sample content taken from the Stitch design. Used by services until the backend is connected.
//

import Foundation

enum MockData {

    // MARK: - Places

    static let places: [BirthPlace] = [
        BirthPlace(city: "Vienna", region: "Austria", latitude: 48.2082, longitude: 16.3738, timeZone: "Central European Time (UTC+1)", timeZoneIdentifier: "Europe/Vienna"),
        BirthPlace(city: "Vienna", region: "Virginia, USA", latitude: 38.9012, longitude: -77.2655, timeZone: "Eastern Standard Time (UTC-5)", timeZoneIdentifier: "America/New_York"),
        BirthPlace(city: "Vienne", region: "Isère, France", latitude: 45.5250, longitude: 4.8744, timeZone: "Central European Time (UTC+1)", timeZoneIdentifier: "Europe/Paris"),
        BirthPlace(city: "Moscow", region: "Russia", latitude: 55.7558, longitude: 37.6173, timeZone: "Moscow Standard Time (UTC+3)", timeZoneIdentifier: "Europe/Moscow"),
        BirthPlace(city: "Kyiv", region: "Ukraine", latitude: 50.4501, longitude: 30.5234, timeZone: "Eastern European Time (UTC+2)", timeZoneIdentifier: "Europe/Kyiv"),
        BirthPlace(city: "London", region: "United Kingdom", latitude: 51.5072, longitude: -0.1276, timeZone: "Greenwich Mean Time (UTC+0)", timeZoneIdentifier: "Europe/London"),
        BirthPlace(city: "New York", region: "New York, USA", latitude: 40.7128, longitude: -74.0060, timeZone: "Eastern Standard Time (UTC-5)", timeZoneIdentifier: "America/New_York"),
        BirthPlace(city: "Paris", region: "France", latitude: 48.8566, longitude: 2.3522, timeZone: "Central European Time (UTC+1)", timeZoneIdentifier: "Europe/Paris"),
        BirthPlace(city: "Berlin", region: "Germany", latitude: 52.5200, longitude: 13.4050, timeZone: "Central European Time (UTC+1)", timeZoneIdentifier: "Europe/Berlin"),
        BirthPlace(city: "Tokyo", region: "Japan", latitude: 35.6762, longitude: 139.6503, timeZone: "Japan Standard Time (UTC+9)", timeZoneIdentifier: "Asia/Tokyo"),
        BirthPlace(city: "Zürich", region: "Switzerland", latitude: 47.3769, longitude: 8.5417, timeZone: "Central European Time (UTC+1)", timeZoneIdentifier: "Europe/Zurich"),
        BirthPlace(city: "San Francisco", region: "California, USA", latitude: 37.7749, longitude: -122.4194, timeZone: "Pacific Standard Time (UTC-8)", timeZoneIdentifier: "America/Los_Angeles")
    ]

    // MARK: - Natal chart

    static let natalChart = NatalChart(
        placements: [
            PlanetPlacement(
                planet: .sun, sign: .scorpio, degree: "2° 14'", house: "House IV",
                title: "Intense and private · who you are",
                summary: "Your core self comes out as intense, private, and hard to fool. In the 4th house, this is about home, roots, and family.",
                longitude: 212
            ),
            PlanetPlacement(
                planet: .moon, sign: .taurus, degree: "19° 42'", house: "House X",
                title: "Steady and sensual · your feelings",
                summary: "Your feelings come out as steady, sensual, and patient. The Moon is exalted in Taurus, so this part of you is at its best. In the 10th house, this is about career and how you show up in public.",
                longitude: 49
            ),
            PlanetPlacement(
                planet: .ascendant, sign: .leo, degree: "27° 08'", house: "Ascendant",
                title: "Warm and expressive · first impression",
                summary: "People first see you as warm, expressive, and generous. Your chart ruler is the Sun.",
                longitude: 147
            ),
            PlanetPlacement(
                planet: .venus, sign: .libra, degree: "29° 02'", house: "House III",
                title: "Fair and relational · how you love",
                summary: "Your love and taste come out as fair, polite, and focused on people. Venus is in its own sign, so this works easily.",
                aspectNote: "Trine Midheaven: Work and public life flow with how you talk and write.",
                longitude: 209
            ),
            PlanetPlacement(
                planet: .mars, sign: .virgo, degree: "7° 44'", house: "House II",
                title: "Careful and useful · how you act",
                summary: "Your drive comes out as careful, helpful, and precise. In the 2nd house, this is about money and self-worth.",
                aspectNote: "Sextile Sun: Hard tasks feel easier when you do them carefully.",
                longitude: 157
            ),
            PlanetPlacement(
                planet: .jupiter, sign: .sagittarius, degree: "11° 20'", house: "House V",
                title: "Honest and adventurous · how you grow",
                summary: "Your growth comes out as honest, adventurous, and big-picture. Jupiter is in its own sign, so this works easily. In the 5th house, this is about creativity, romance, and joy.",
                longitude: 251
            ),
            PlanetPlacement(
                planet: .saturn, sign: .pisces, degree: "5° 12' ℞", house: "House VIII",
                title: "Sensitive and imaginative · what you build",
                summary: "Your discipline comes out as sensitive and imaginative. In the 8th house, this is about intimacy, shared money, and deep change. Saturn was retrograde, so you review this before you act.",
                longitude: 335
            ),
            PlanetPlacement(
                planet: .northNode, sign: .scorpio, degree: "15° 22'", house: "Houses IV • X",
                title: "Intense and private · where you're headed",
                summary: "You grow by leaving the comfort of Taurus and practicing the intense, private side of Scorpio. This shows up most around home, roots, and family.",
                longitude: 225
            )
        ],
        synthesis: "Sun in Scorpio, Moon in Taurus, Leo rising. Your core is intense and private. Your feelings are steady and sensual. Water is the strongest element (40%), so the chart leans toward feeling. The closest important link is Sun opposite Moon. Your core self and your feelings sit on opposite sides. The task is to use both.",
        tension: "The main tension is between your core self and your feelings.",
        elements: [
            ChartShare(name: "Water", keyword: "Intuition", percent: 40),
            ChartShare(name: "Earth", keyword: "Pragmatism", percent: 30),
            ChartShare(name: "Fire", keyword: "Vitality", percent: 20),
            ChartShare(name: "Air", keyword: "Intellect", percent: 10)
        ],
        modalities: [
            ChartShare(name: "Fixed", keyword: "Enduring", percent: 50),
            ChartShare(name: "Cardinal", keyword: "Initiating", percent: 30),
            ChartShare(name: "Mutable", keyword: "Adaptable", percent: 20)
        ],
        accuracy: 94
    )

    // MARK: - Today

    static func dailyReading(moonPhase: MoonPhase) -> DailyReading {
        DailyReading(
            date: .now,
            moonPhase: moonPhase.name,
            moonSign: .gemini,
            moonIllumination: moonPhase.illumination,
            atmosphere: "Reflective & Receptive",
            ephemerisTitle: "Structured Expansion",
            ephemerisText: "Mars forms a harmonious trine with Saturn (18° 42'), lending patience and measured discipline to sudden creative impulses.",
            transitLine: "♂ △ ♄ exact at 14:18",
            orb: "0° 12'",
            synthesisTitle: "Make room for a different perspective.",
            synthesisText: "With Mercury forming a gentle aspect to your natal Neptune, intuitive impressions carry unusual weight today. Observe conversations without rushing to conclude their meaning.",
            imageCaption: "Quiet contemplation • 08:30 Ethereal focus",
            areas: [
                LifeArea(icon: "heart", title: "Love & Rapport", text: "Allow space for unspoken understanding without assuming distance. Silence is often restful, not vacant."),
                LifeArea(icon: "pencil.and.scribble", title: "Work & Vocation", text: "A quiet review of past decisions reveals a clearer path forward. Favor systematic revision over fresh drafts."),
                LifeArea(icon: "leaf", title: "Inner World", text: "Notice where your body holds tension during routine tasks. Release the jaw, loosen shoulders, exhale deeply.")
            ],
            tendencies: [
                Tendency(title: "Focus", value: "Calm / Deep", level: 0.72),
                Tendency(title: "Connection", value: "Open & Subtle", level: 0.58),
                Tendency(title: "Reflection", value: "Heightened", level: 0.88)
            ],
            dials: [
                LifeDial(id: "bonds", left: "Relationships", right: "Work", leftIcon: "heart", rightIcon: "briefcase", value: 64, note: "Give the day to the work itself. A Capricorn Moon favors effort you can finish."),
                LifeDial(id: "circle", left: "Friends", right: "Family", leftIcon: "person.2", rightIcon: "house", value: 71, note: "Family has the clearer claim. The Moon is home, in the house of roots."),
                LifeDial(id: "tempo", left: "New", right: "Routine", leftIcon: "sparkles", rightIcon: "repeat", value: 38, note: "Try one thing that isn't already in the plan. A mutable Moon loosens the script."),
                LifeDial(id: "energy", left: "Rest", right: "Action", leftIcon: "moon.stars", rightIcon: "bolt", value: 44, note: "Move slowly. Rest is doing something. The Moon is waning.")
            ],
            luckyNumbers: LuckyNumbers(
                values: [7, 16, 23, 34, 41],
                personalDay: 7,
                note: "Read from your birth date and today's Gemini Moon."
            ),
            moods: ["Quietly Inspired", "Seeking Grounding", "Content", "Restless"],
            oracleQuestions: [
                "How does today's Gemini Moon affect my natal placements?",
                "What should I pay attention to in conversations today?",
                "Help me understand the Mars-Saturn transit in my 9th house."
            ]
        )
    }

    // MARK: - Oracle

    static func oracleAnswer(to question: String) -> ChatMessage {
        ChatMessage(
            role: .oracle,
            text: "Your Sun is in the 4th house, the part of the chart about home and private life. The answer is unlikely to come from pushing. Mercury in Libra is flowing with your Venus, so the next few days are better for a slow, honest conversation than for a fast decision. Notice what you want to keep private, and what you are ready to say.",
            title: "A clear reading",
            transitNote: "Active Transit: ☿ Mercury in Libra (14° 18')"
        )
    }

    // MARK: - Connections

    static let synastry = SynastryReport(
        title: "The Core Resonance",
        subtitle: "Romantic Partnership • 3y 4m synced",
        harmony: "Harmonic Concordance",
        quote: "An instinctive emotional shelter with a quiet, steady rhythm.",
        summary: "Tuning into this bond requires no performance. Where Elena seeks profound depth, Julian offers patient container-space.",
        dimensions: [
            SynastryDimension(icon: "drop", title: "Emotional Resonance", badge: "Deep & Intuitive", text: "Water and Earth synergy creates profound mutual comfort without requiring constant verbal explanation. Silence between you feels earned and resting rather than distant."),
            SynastryDimension(icon: "bubble.left.and.bubble.right", title: "Dialectic & Dialogue", badge: "Grounding", text: "Julian's pragmatic Capricorn Moon anchors Elena's intense Scorpio reflections. What feels tempestuous internally transforms into structured, practical resolution."),
            SynastryDimension(icon: "camera.macro", title: "Creative & Sensual Chemistry", badge: "Trine ♀ / ♂", text: "Venus-Mars trine fosters effortless sensual ease and shared aesthetic appreciation. Physical environments, shared meals, and tactile surroundings recharge your connection."),
            SynastryDimension(icon: "exclamationmark.circle", title: "Growth & Friction Points", badge: "Fixed Tension", text: "A subtle tendency toward shared stubbornness when daily domestic routines are disrupted unexpectedly. Elena withdraws into protective silence; Julian doubles down on logic.")
        ],
        questions: [
            "Where do we each feel most responsible for the other's peace?",
            "How do we signal when we need solitary recharging before irritation speaks?"
        ]
    )

    // MARK: - Journal

    static let journalPrompt = JournalPrompt(
        context: "Ephemeris Prompt · Mars ⚹ Saturn",
        question: "Where in your life is discipline beginning to feel like freedom rather than constriction?",
        note: "Mars harmonizes with Saturn at 14° Pisces. Energy crystallizes around deliberate commitments today."
    )

    static let journalEntries: [JournalEntry] = [
        JournalEntry(
            date: date(2024, 10, 23, 22, 42), kind: .oracle, context: "Moon in Scorpio",
            quote: "Realized I don't need to force verbal clarity when emotional resonance is already speaking.",
            body: "Sat by the bay window listening to the rain. The reading earlier highlighted Mercury in conjunction with Neptune: an invitation to surrender the impulse to define every subtle boundary before it breathes.",
            tags: ["Mercury Trine Neptune · 0.2°", "☉ 00° ♏ 45'"]
        ),
        JournalEntry(
            date: date(2024, 10, 20, 8, 15), kind: .bookmark, context: "Waxing Crescent · 9th House",
            quote: "A quiet urge to rethink long-term creative plans without rushing into execution.",
            body: "A slow morning cataloging typography proofs. There is a peaceful rhythm in postponing conclusions until the full moon reveals missing perspectives.",
            tags: ["Sagittarius Horizon · 18°", "Creative Solitude"]
        ),
        JournalEntry(
            date: date(2024, 10, 16, 16, 15), kind: .reflection, context: "Venus Ingress Scorpio",
            quote: "The space between words in conversation with Julian felt unusually grounding.",
            body: "Venus leaving balanced Libra for the deeper waters of Scorpio brings an acute honesty. No pleasant superficialities needed today; silence carried its own weight.",
            tags: ["Synastry Transit", "♀ Ingress 0° ♏"]
        )
    ]

    // MARK: - Helpers

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .now
    }
}
