//
//  ExploreVoiceTests.swift
//  AstroAITests
//

import XCTest
@testable import AstroAI

@MainActor
final class ExploreVoiceTests: XCTestCase {
    func testDifferentFactorsChangeTheRecommendation() {
        let closeness = card(transiting: .mars, natal: .venus, aspect: .square, sign: .aries, house: 7)
        let work = card(transiting: .jupiter, natal: .saturn, aspect: .trine, sign: .sagittarius, house: 10)

        XCTAssertNotEqual(closeness.headline, work.headline)
        XCTAssertNotEqual(closeness.summary, work.summary)
        XCTAssertTrue(closeness.headline.localizedCaseInsensitiveContains("relationship"))
        XCTAssertTrue(work.headline.localizedCaseInsensitiveContains("work"))
        XCTAssertFalse(closeness.summary.localizedCaseInsensitiveContains(work.summary))
    }

    func testSameFactsStayStableAndPlain() {
        let first = card(transiting: .mercury, natal: .moon, aspect: .opposition, sign: .virgo, house: nil)
        let second = card(transiting: .mercury, natal: .moon, aspect: .opposition, sign: .virgo, house: nil)

        XCTAssertEqual(first, second)
        XCTAssertFalse(ExploreLanguage.containsJargon(first.headline))
        XCTAssertFalse(ExploreLanguage.containsJargon(first.summary))
        XCTAssertTrue(first.detail.localizedCaseInsensitiveContains("Mercury"))
        XCTAssertFalse(first.detail.localizedCaseInsensitiveContains("1st house"))
        XCTAssertFalse(first.summary.localizedCaseInsensitiveContains("Give this theme the day"))
    }

    func testDatingContextStaysOnCloseTopics() {
        let profile = profile(relationship: .dating, stage: nil, interests: [.love])
        let close = ExploreVoice.month(event(transiting: .venus, natal: .moon, aspect: .square, sign: .cancer, house: 7), profile: profile, includeFocus: false)
        let work = ExploreVoice.month(event(transiting: .saturn, natal: .sun, aspect: .square, sign: .capricorn, house: 10), profile: profile, includeFocus: false)

        XCTAssertTrue(close.summary.localizedCaseInsensitiveContains("dating"))
        XCTAssertFalse(work.summary.localizedCaseInsensitiveContains("dating"))
        XCTAssertFalse(ExploreLanguage.containsJargon(close.summary))
        XCTAssertFalse(ExploreLanguage.containsJargon(work.summary))
    }

    func testCareerStageDoesNotAttachToAClosenessTransit() {
        let profile = profile(relationship: nil, stage: .buildingCareer, interests: [.career])
        let close = ExploreVoice.month(event(transiting: .venus, natal: .venus, aspect: .trine, sign: .libra, house: 5), profile: profile, includeFocus: false)
        let work = ExploreVoice.month(event(transiting: .saturn, natal: .sun, aspect: .conjunction, sign: .capricorn, house: 10), profile: profile, includeFocus: false)

        XCTAssertFalse(close.summary.localizedCaseInsensitiveContains("career"))
        XCTAssertTrue(work.summary.localizedCaseInsensitiveContains("career"))
    }

    func testFocusIsOptionalAndQuotedOnlyWhenAsked() {
        let profile = profile(relationship: nil, stage: nil, interests: [], focus: "the conversation I keep postponing")
        let shown = ExploreVoice.month(event(transiting: .mercury, natal: .mercury, aspect: .square, sign: .gemini, house: 3), profile: profile, includeFocus: true)
        let hidden = ExploreVoice.month(event(transiting: .mercury, natal: .mercury, aspect: .square, sign: .gemini, house: 3), profile: profile, includeFocus: false)

        XCTAssertTrue(shown.summary.contains("the conversation I keep postponing"))
        XCTAssertFalse(hidden.summary.contains("the conversation I keep postponing"))
    }

    func testSunCountedYearDoesNotClaimARisingSign() {
        let calendar = Calendar(identifier: .gregorian)
        let born = calendar.date(from: DateComponents(year: 1992, month: 3, day: 21))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25))!
        let chart = NatalChartCalculator.chart(for: BirthData(date: born, time: nil, place: nil))
        let year = AnnualProfection.reading(chart: chart, born: born, now: now)

        XCTAssertEqual(year?.countedFromSun, true)
        let card = ExploreVoice.year(year!, profile: nil, includeFocus: false)
        XCTAssertFalse(ExploreLanguage.containsJargon(card.headline))
        XCTAssertFalse(ExploreLanguage.containsJargon(card.summary))
        XCTAssertFalse(ExploreLanguage.containsJargon(card.caution))
        XCTAssertFalse(card.summary.localizedCaseInsensitiveContains("rising"))
        XCTAssertTrue(card.detail.localizedCaseInsensitiveContains("birth time"))
        XCTAssertTrue(card.detail.localizedCaseInsensitiveContains("house"))
    }

    func testExactBirthUsesRisingAndStillKeepsTheSummaryPlain() throws {
        let calendar = Calendar(identifier: .gregorian)
        let born = try XCTUnwrap(calendar.date(from: DateComponents(year: 1990, month: 6, day: 15)))
        let time = try XCTUnwrap(calendar.date(from: DateComponents(year: 1990, month: 6, day: 15, hour: 8, minute: 30)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let place = BirthPlace(
            city: "Kyiv",
            region: "Ukraine",
            latitude: 50.4501,
            longitude: 30.5234,
            timeZone: "EET",
            timeZoneIdentifier: "Europe/Kyiv"
        )
        let chart = NatalChartCalculator.chart(for: BirthData(date: born, time: time, place: place))
        let year = try XCTUnwrap(AnnualProfection.reading(chart: chart, born: born, now: now))

        XCTAssertFalse(year.countedFromSun)
        let card = ExploreVoice.year(year, profile: nil, includeFocus: false)
        XCTAssertFalse(ExploreLanguage.containsJargon(card.summary))
        XCTAssertTrue(card.detail.localizedCaseInsensitiveContains("rising"))
    }

    func testWeekMoodChangesWithTheCalculatedSign() {
        let taurus = skyCard(.moonIngress(sign: .taurus, house: 2))
        let aquarius = skyCard(.moonIngress(sign: .aquarius, house: nil))

        XCTAssertNotEqual(taurus.headline, aquarius.headline)
        XCTAssertTrue(taurus.summary.localizedCaseInsensitiveContains("money") || taurus.summary.localizedCaseInsensitiveContains("practical") || taurus.summary.localizedCaseInsensitiveContains("steady"))
        XCTAssertFalse(ExploreLanguage.containsJargon(taurus.summary))
        XCTAssertFalse(ExploreLanguage.containsJargon(taurus.headline))
        XCTAssertTrue(taurus.detail.localizedCaseInsensitiveContains("Taurus"))
        XCTAssertTrue(taurus.detail.localizedCaseInsensitiveContains("2nd house"))
        XCTAssertFalse(aquarius.detail.localizedCaseInsensitiveContains("2nd house"))
    }

    func testSaturnPassesDoNotRepeatTheSameInstruction() {
        let first = skyCard(.saturnReturn(sign: .capricorn, degree: "12°", house: 10, age: 29, index: 0, count: 3, retrograde: false))
        let last = skyCard(.saturnReturn(sign: .capricorn, degree: "12°", house: 10, age: 29, index: 2, count: 3, retrograde: true))

        XCTAssertNotEqual(first.summary, last.summary)
        XCTAssertTrue(first.summary.localizedCaseInsensitiveContains("first"))
        XCTAssertTrue(last.summary.localizedCaseInsensitiveContains("last") || last.summary.localizedCaseInsensitiveContains("review"))
        XCTAssertFalse(ExploreLanguage.containsJargon(first.summary))
        XCTAssertTrue(first.detail.localizedCaseInsensitiveContains("Saturn"))
        XCTAssertTrue(first.detail.localizedCaseInsensitiveContains("10th house"))
    }

    func testRealMonthUsesCalculatedEventsWithoutGenericAdvice() {
        let calendar = Calendar(identifier: .gregorian)
        let born = calendar.date(from: DateComponents(year: 1988, month: 11, day: 2))!
        let time = calendar.date(from: DateComponents(year: 1988, month: 11, day: 2, hour: 14, minute: 10))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!
        let place = BirthPlace(
            city: "Lisbon",
            region: "Portugal",
            latitude: 38.7223,
            longitude: -9.1393,
            timeZone: "WET",
            timeZoneIdentifier: "Europe/Lisbon"
        )
        let chart = NatalChartCalculator.chart(for: BirthData(date: born, time: time, place: place))
        let timeline = PersonalTransitForecast.timeline(chart: chart, options: ChartOptions(), now: now)
        let profile = profile(relationship: .committed, stage: .buildingCareer, interests: [.career, .love])

        XCTAssertFalse(timeline.events.isEmpty)
        var summaries = Set<String>()
        for event in timeline.events {
            let card = ExploreVoice.month(event, profile: profile, includeFocus: false)
            summaries.insert(card.summary)
            XCTAssertFalse(card.summary.isEmpty)
            XCTAssertFalse(ExploreLanguage.containsJargon(card.headline), card.headline)
            XCTAssertFalse(ExploreLanguage.containsJargon(card.summary), card.summary)
            XCTAssertFalse(event.advice.localizedCaseInsensitiveContains("Give this theme the day"))
            XCTAssertFalse(ExploreLanguage.containsJargon(event.advice), event.advice)
            if event.lifeHouse == nil {
                XCTAssertFalse(card.detail.localizedCaseInsensitiveContains("house"))
            }
        }
        if timeline.events.count >= 2 {
            XCTAssertGreaterThan(summaries.count, 1)
        }
    }

    func testRewriteKeepsMeaningAndDropsAstrology() {
        let draft = "Closeness may feel more sensitive than the facts deserve. Ask one plain question before you decide what a silence means."
        let clean = "Closeness may feel sharper than it is. Ask one plain question before you decide what the silence means."
        let jargon = "Mars squares your Venus, so closeness will change on the 12th."
        let inventedNumber = "Closeness may feel more sensitive in 2027. Ask one plain question before you decide."

        XCTAssertTrue(ExploreLanguage.acceptsRewrite(clean, of: draft))
        XCTAssertFalse(ExploreLanguage.acceptsRewrite(jargon, of: draft))
        XCTAssertFalse(ExploreLanguage.acceptsRewrite(inventedNumber, of: draft))
    }

    private func card(transiting: Planet, natal: Planet, aspect: AspectKind, sign: ZodiacSign, house: Int?) -> ExploreCard {
        ExploreVoice.month(event(transiting: transiting, natal: natal, aspect: aspect, sign: sign, house: house), profile: nil, includeFocus: false)
    }

    private func event(transiting: Planet, natal: Planet, aspect: AspectKind, sign: ZodiacSign, house: Int?) -> PersonalTransitEvent {
        PersonalTransitEvent(
            id: "\(transiting.rawValue)-\(natal.rawValue)-\(aspect.rawValue)-\(sign.rawValue)-\(house ?? 0)",
            glyph: transiting.glyph,
            glyphPlanet: transiting.rawValue,
            when: Date(timeIntervalSince1970: 1_700_000_000),
            whenLabel: "Thu, Jan 4, 9:00 AM",
            title: "technical title",
            houseLine: "technical house",
            advice: ExploreVoice.notice(transiting: transiting, natal: natal, aspect: aspect, skySign: sign, house: house),
            transiting: transiting,
            natal: natal,
            aspect: aspect,
            skySign: sign,
            lifeHouse: house
        )
    }

    private func skyCard(_ fact: ExploreSkyFact) -> ExploreCard {
        let transit = Transit(
            glyph: "☽",
            kind: "Sky",
            date: "Oct 28 · 4:00 PM",
            title: "technical",
            detail: "technical",
            fact: fact
        )
        return ExploreVoice.sky(transit, profile: nil, chart: nil, includeFocus: false)
    }

    private func profile(
        relationship: RelationshipStatus?,
        stage: LifeStage?,
        interests: Set<Interest>,
        focus: String? = nil
    ) -> UserProfile {
        let personal = PersonalContext(
            relationship: relationship,
            lifeStage: stage,
            pronouns: nil,
            currentFocus: focus,
            tone: nil,
            length: nil
        )
        return UserProfile(
            name: "Ada",
            birth: BirthData(date: Date(timeIntervalSince1970: 640_000_000), time: nil, place: nil),
            interests: interests,
            intentions: []
        ).with(personal: personal)
    }
}

private extension UserProfile {
    func with(personal: PersonalContext) -> UserProfile {
        var copy = self
        copy.personal = personal
        return copy
    }
}
