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
                title: "The Archetype of Inner Depth & Subconscious Alchemy",
                summary: "Your primary solar drive operates within the private foundations of the psyche. Rather than external applause, you seek total emotional truth, self-governance, and regenerative renewal behind closed doors.",
                longitude: 212
            ),
            PlanetPlacement(
                planet: .moon, sign: .taurus, degree: "19° 42'", house: "House X",
                title: "Emotional Grounding & Sensual Stability in the Public Eye",
                summary: "Exalted in Taurus, your nervous system craves tangible calm, consistency, and tactile beauty. Sitting at your midheaven, your public leadership emanates serene composure and resolute patience.",
                longitude: 49
            ),
            PlanetPlacement(
                planet: .ascendant, sign: .leo, degree: "27° 08'", house: "Ascendant",
                title: "Warmth, Magnetism & Unapologetic Creative Radiance",
                summary: "The interface through which you touch the outer world. While your Scorpio core remains private, your immediate energetic presence is generous, regal, and instinctively warm.",
                longitude: 147
            ),
            PlanetPlacement(
                planet: .venus, sign: .libra, degree: "29° 02'", house: "House III",
                title: "Essential Dignity",
                summary: "At the critical 29th degree, Venus in domicile possesses a distilled, masterful intuition for relational equilibrium, aesthetic order, and cadence in speech. You navigate negotiations with disarming elegance.",
                aspectNote: "Trine Midheaven: Professional grace emerges organically through written or spoken synthesis.",
                longitude: 209
            ),
            PlanetPlacement(
                planet: .mars, sign: .virgo, degree: "7° 44'", house: "House II",
                title: "Practical Execution",
                summary: "Action is expressed through precision, deliberate craftsmanship, and rigorous systemic hygiene. You channel raw ambition into meticulously organized routines and material security.",
                aspectNote: "Sextile Sun: Low emotional friction when executing demanding mental tasks.",
                longitude: 157
            ),
            PlanetPlacement(
                planet: .jupiter, sign: .sagittarius, degree: "11° 20'", house: "House V",
                title: "Expansive Horizon",
                summary: "Located in its home sign of Sagittarius, Jupiter instills boundless curiosity, joyful risk tolerance in creative pursuits, and philosophical optimism that continually rejuvenates your spirit.",
                longitude: 251
            ),
            PlanetPlacement(
                planet: .saturn, sign: .pisces, degree: "5° 12' ℞", house: "House VIII",
                title: "Karmic Boundaries",
                summary: "Saturn asks you to construct concrete architecture around elusive spiritual, psychological, and shared-asset domains. Maturity arrives through honoring boundaries without turning cynical.",
                longitude: 335
            ),
            PlanetPlacement(
                planet: .northNode, sign: .scorpio, degree: "15° 22'", house: "Houses IV • X",
                title: "Evolution",
                summary: "Your evolutionary vector asks you to step beyond mere material comfort (South Node in Taurus) toward emotional authenticity, psychological courage, and transformational vulnerability (North Node in Scorpio).",
                longitude: 225
            )
        ],
        synthesis: "Your chart holds a fascinating tension between radical self-reliance and the desire for deep emotional anchoring. The Sun-Moon opposition across your 4th and 10th houses invites you to reconcile quiet private sanctuary with outward public devotion.",
        tension: "A fascinating tension between radical independence and deep emotional anchorage.",
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

    static let oracleSuggestions = [
        "What should I focus on this week?",
        "What does my chart say about my creative work?",
        "How can I find more balance right now?"
    ]

    static func oracleAnswer(to question: String) -> ChatMessage {
        ChatMessage(
            role: .oracle,
            text: "Consider this question through the lens of your fourth-house Sun: the answer rarely arrives through force. With Mercury in Libra forming a gentle trine to your natal Venus, the coming days favor slow, honest conversation over decisive action. Notice what you protect, and what you are ready to share.",
            title: "A Quiet Reading",
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

    // MARK: - Subscription

    static let plans = [
        SubscriptionPlan(id: "astroai.annual", title: "Annual Sanctuary", subtitle: "$4.99 / month, billed annually", price: "$59.99", period: "/ year", badge: "7-Day Free Trial • Save 48%"),
        SubscriptionPlan(id: "astroai.monthly", title: "Monthly Membership", subtitle: "Standard monthly cadence", price: "$9.99", period: "/ month")
    ]

    // MARK: - Helpers

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .now
    }
}
