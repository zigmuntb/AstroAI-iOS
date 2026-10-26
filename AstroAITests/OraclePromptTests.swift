//
//  OraclePromptTests.swift
//  AstroAITests
//

import XCTest
@testable import AstroAI

/// Prompt construction and a repeatable check for answers.
/// The on-device models are not called here: a fluent reply is not treated as a correct one.
final class OraclePromptTests: XCTestCase {
    private let focus = "shipping the iOS app"

    func testPolicyAnswersTheQuestionBeforeUsingTheChart() {
        let prompt = instructions(model: .appleIntelligence)

        XCTAssertTrue(prompt.contains("The first sentence answers that question."))
        XCTAssertTrue(prompt.contains("Name the goal, the choice, the reason, the steps, or the fact they asked for."))
        XCTAssertTrue(prompt.contains("Stay on their question"))
        XCTAssertTrue(prompt.contains("Today's guidance"))
        XCTAssertTrue(prompt.contains("ask one short question if a needed fact is missing"))
        XCTAssertTrue(prompt.contains("correct it"))
        XCTAssertFalse(prompt.contains("use Life notes first"))
        XCTAssertTrue(prompt.contains("Leave astrology out when it does not help."))
        XCTAssertTrue(prompt.contains("Never invent a placement"))
        XCTAssertFalse(prompt.contains("another person's thoughts"))
        XCTAssertFalse(prompt.contains("what you can control"))
        XCTAssertFalse(prompt.contains("ordinary good sense"))
        XCTAssertFalse(prompt.contains("Focus on one meaningful goal you can make progress on"))
        XCTAssertLessThan(prompt.range(of: "Life notes")!.lowerBound, prompt.range(of: "Chart reference")!.lowerBound)
        XCTAssertLessThan(prompt.range(of: "Chart reference")!.lowerBound, prompt.range(of: "Answer only the user's latest message")!.lowerBound)
    }

    func testBothModelsShareThePolicyAndKeepTheirOwnMechanics() {
        let apple = instructions(model: .appleIntelligence)
        let qwen = instructions(model: .qwen)

        XCTAssertTrue(apple.contains("The first sentence answers that question."))
        XCTAssertTrue(qwen.contains("The first sentence answers that question."))
        XCTAssertTrue(apple.contains("getSkyOnDate"))
        XCTAssertFalse(qwen.contains("getSkyOnDate"))
        XCTAssertTrue(qwen.contains("that day's sky was not calculated"))
        XCTAssertFalse(apple.contains("Answer the question above."))
        XCTAssertFalse(qwen.contains("Answer the question above."))
    }

    func testPersonalContextIsAvailableAndComesBeforeTheChart() throws {
        let prompt = instructions(model: .qwen)
        let life = try slice(prompt, from: "Life notes", to: "Current sky")

        XCTAssertTrue(life.contains("Name: Ada."))
        XCTAssertTrue(life.contains("\"\(focus)\""))
        XCTAssertTrue(life.contains("building a career"))
        XCTAssertTrue(life.contains("Build better daily habits"))
        XCTAssertTrue(life.contains("Career & ambition"))
        XCTAssertFalse(life.contains("Mina"))
        XCTAssertTrue(prompt.contains("Saved people (use only when the question is about one of them):"))
        XCTAssertTrue(prompt.contains("Mina (Romantic): Sun in Leo."))
        XCTAssertLessThan(prompt.range(of: "Chart reference")!.lowerBound, prompt.range(of: "Saved people")!.lowerBound)
        XCTAssertTrue(prompt.contains("Sun in \(try sunSign())"))
        XCTAssertTrue(prompt.contains("House cusps:"))
        XCTAssertTrue(prompt.contains("do not copy their wording"))
        XCTAssertTrue(prompt.contains("What should I focus on at work?"))
        XCTAssertFalse(prompt.contains("Finish the release."))
        XCTAssertFalse(prompt.contains("you said:"))
    }

    func testMissingBirthFactsAreOmittedInsteadOfInvented() throws {
        let prompt = instructions(timeKnown: false, placeKnown: false, model: .appleIntelligence)
        let natal = try slice(prompt, from: "Natal chart", to: "Birth time is missing")

        XCTAssertFalse(natal.contains("Rising in"))
        XCTAssertFalse(natal.contains("Moon in"))
        XCTAssertFalse(natal.contains("House I"))
        XCTAssertTrue(prompt.contains("Do not invent them, and do not state houses."))
        XCTAssertTrue(prompt.contains("Birth time is unknown. Do not state a rising sign or houses."))
        XCTAssertFalse(prompt.contains("House cusps:"))
        XCTAssertFalse(prompt.contains("On their mind"))
    }

    func testUnreliableHousesAreNotListedBesideAWarning() throws {
        let prompt = instructions(timeKnown: false, placeKnown: true, model: .qwen)
        XCTAssertFalse(prompt.contains("1st house"))
        XCTAssertFalse(prompt.contains("Rising in"))
        XCTAssertTrue(prompt.contains("do not state houses"))
        XCTAssertTrue(prompt.contains("Today's Moon in the sky is still usable."))
    }

    func testRebuiltHistoryKeepsTheFollowUpAndDropsTheGreeting() throws {
        let priorQuestion = "Should I start a new project or finish an existing one?"
        let longAnswer = String(repeating: "Finish the existing one. ", count: 40)
        let history = [
            ChatMessage(role: .oracle, text: "You can ask in ordinary words.", title: "What's on your mind?"),
            ChatMessage(role: .user, text: priorQuestion),
            ChatMessage(role: .oracle, text: longAnswer),
            ChatMessage(role: .user, text: "Why?")
        ]
        let prior = OraclePrompt.priorTurns(from: history, question: "Why?")
        let prompt = instructions(history: prior, model: .appleIntelligence)

        XCTAssertEqual(prior.first?.text, priorQuestion)
        XCTAssertFalse(prior.contains { $0.title == "What's on your mind?" })
        XCTAssertTrue(prompt.contains(priorQuestion))
        XCTAssertTrue(prompt.contains("…"))
        XCTAssertFalse(prompt.contains(longAnswer))
        XCTAssertFalse(prompt.contains("You can ask in ordinary words."))
        XCTAssertFalse(prompt.contains("\nUser: Why?"))
        XCTAssertLessThan(prompt.range(of: "\"\(focus)\"")!.lowerBound, prompt.range(of: "Recent conversation")!.lowerBound)
    }

    func testOnlyFourRecentTurnsAreCarried() {
        var history: [ChatMessage] = []
        for index in 0..<6 {
            history.append(ChatMessage(role: .user, text: "Question \(index)"))
            history.append(ChatMessage(role: .oracle, text: "Answer \(index)"))
        }
        history.append(ChatMessage(role: .user, text: "Latest"))
        let prior = OraclePrompt.priorTurns(from: history, question: "Latest")

        XCTAssertEqual(prior.count, 4)
        XCTAssertEqual(prior.map(\.text), ["Question 4", "Answer 4", "Question 5", "Answer 5"])
    }

    func testTurnsStayOnTheQuestionUnlessARealLimitApplies() {
        let cases: [(String, OraclePrompt.Model, Bool, Bool)] = [
            ("What is the best goal for me to focus on?", .appleIntelligence, false, false),
            ("What is the best goal for me to focus on?", .qwen, false, false),
            ("What should I focus on this week?", .qwen, false, false),
            ("Should I start a new project or finish an existing one?", .appleIntelligence, false, false),
            ("Why might this be a good time to make a change?", .qwen, false, false),
            ("What is the capital of France?", .appleIntelligence, false, false),
            ("Should I tell her how I feel?", .qwen, false, false),
            ("Should I investigate a new idea?", .appleIntelligence, false, false),
            ("help", .qwen, false, false),
            ("Why?", .appleIntelligence, false, false),
            ("Does she love me?", .appleIntelligence, true, false),
            ("What is she thinking about the project?", .qwen, true, false),
            ("Is he cheating on me?", .appleIntelligence, true, false),
            ("Should I invest my savings in stocks?", .qwen, false, true),
            ("What medication should I take for this pain?", .appleIntelligence, false, true),
            ("Is it legal for me to skip this contract?", .qwen, false, true)
        ]

        for (question, model, mind, regulated) in cases {
            let turn = OraclePrompt.turn(question, model: model)
            XCTAssertTrue(turn.hasSuffix(question), question)
            XCTAssertEqual(turn.contains("cannot know that other person"), mind, question)
            XCTAssertEqual(turn.contains("professional should decide"), regulated, question)
            XCTAssertFalse(turn.contains("Reply to the message above"), question)
        }
    }

    func testTodayGuidanceIsTheSameSourceForBothModels() throws {
        let work = try XCTUnwrap(firstReading(profile: workProfile, where: { $0.value >= 62 }))
        let relationships = try XCTUnwrap(firstReading(profile: relationshipProfile, where: { $0.value <= 40 }))

        let workPrompt = prompt(for: work)
        let relationshipPrompt = prompt(for: relationships)
        let qwenWork = OraclePrompt.instructions(context: work.context, history: [], model: .qwen)
        let appleWork = OraclePrompt.instructions(context: work.context, history: [], model: .appleIntelligence)

        XCTAssertGreaterThanOrEqual(work.bonds.value, 62)
        XCTAssertLessThanOrEqual(relationships.bonds.value, 40)
        XCTAssertFalse(workPrompt.contains("Primary recommendation:"))
        XCTAssertFalse(workPrompt.contains("Give this recommendation."))
        XCTAssertFalse(relationshipPrompt.contains("Primary recommendation:"))
        XCTAssertFalse(appleWork.contains(work.reading.focus))
        XCTAssertFalse(qwenWork.contains(work.reading.focus))
        let workTurn = OraclePrompt.turn("What should I focus on today?", model: .appleIntelligence, reading: work.reading)
        let relationshipTurn = OraclePrompt.turn("What should I focus on today?", model: .qwen, reading: relationships.reading)
        XCTAssertTrue(workTurn.contains("Today shows the day leaning toward the work in front of them"))
        XCTAssertTrue(workTurn.contains(work.bonds.note))
        XCTAssertTrue(workTurn.contains("\(work.bonds.value) toward work."))
        XCTAssertTrue(workTurn.contains("Do not tell them to focus on close people instead."))
        XCTAssertTrue(relationshipTurn.contains("Today shows the day leaning toward close people, not work."))
        XCTAssertTrue(relationshipTurn.contains(relationships.bonds.note))
        XCTAssertTrue(relationshipTurn.contains("Do not tell them to focus on work."))
        XCTAssertNotEqual(work.reading.focus, relationships.reading.focus)
        XCTAssertEqual(
            OraclePrompt.turn("What should I focus on today?", model: .appleIntelligence, reading: work.reading),
            OraclePrompt.turn("What should I focus on today?", model: .qwen, reading: work.reading)
                .replacingOccurrences(of: "\n\nName specific actions from the lines above. The lean is only the direction.", with: "")
        )
        XCTAssertNotEqual(OraclePrompt.guidanceID(for: work.reading), OraclePrompt.guidanceID(for: relationships.reading))
    }

    func testANewDateRefreshesTheGuidanceIdentity() throws {
        let calendar = Calendar(identifier: .gregorian)
        let first = calendar.date(from: DateComponents(year: 2026, month: 1, day: 3, hour: 12))!
        let later = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 12))!
        let start = reading(profile: workProfile, on: first)
        let next = reading(profile: workProfile, on: later)

        XCTAssertNotEqual(OraclePrompt.guidanceID(for: start.reading), OraclePrompt.guidanceID(for: next.reading))
        XCTAssertNotEqual(Calendar.current.startOfDay(for: start.reading.date), Calendar.current.startOfDay(for: next.reading.date))
    }

    func testChallengingTodayDoesNotDropTheCalculatedPriority() throws {
        let work = try XCTUnwrap(firstReading(profile: workProfile, where: { $0.value >= 62 }))
        let history = [
            ChatMessage(role: .user, text: "What should I focus on today?"),
            ChatMessage(role: .oracle, text: "Finish the task that is already yours.")
        ]
        let challenge = "But it says that I should focus on work more today."
        for model in [OraclePrompt.Model.appleIntelligence, .qwen] {
            let turn = OraclePrompt.turn(challenge, model: model, reading: work.reading, history: history)
            XCTAssertTrue(turn.contains(work.bonds.note), model == .qwen ? "qwen" : "apple")
            XCTAssertTrue(turn.contains("Do not tell them to focus on close people instead."))
            XCTAssertTrue(turn.contains("Do not replace it because the user disagrees."))
        }
        let followUp = OraclePrompt.turn("Why?", model: .appleIntelligence, reading: work.reading, history: history)
        XCTAssertTrue(followUp.contains("Explain why"))
        XCTAssertTrue(followUp.contains(work.reading.ephemerisTitle))
        XCTAssertFalse(followUp.contains("Do not replace it because the user disagrees."))

        let unrelated = OraclePrompt.turn("What is the capital of France?", model: .qwen, reading: work.reading, history: [])
        XCTAssertFalse(unrelated.contains("Today's calculated recommendation"))
        let longerTerm = OraclePrompt.turn("What is the best goal for me to focus on?", model: .appleIntelligence, reading: work.reading)
        XCTAssertFalse(longerTerm.contains("Today's calculated recommendation"))
    }

    func testAnswersThatFlipTodaysPriorityFailTheCheck() throws {
        let work = try XCTUnwrap(firstReading(profile: workProfile, where: { $0.value >= 62 }))
        let relationships = try XCTUnwrap(firstReading(profile: relationshipProfile, where: { $0.value <= 40 }))
        let question = "What should I focus on today?"

        XCTAssertTrue(TodayAnswerCheck.contradicts("Focus on your relationships today. That is the better use of the day.", reading: work.reading))
        XCTAssertFalse(TodayAnswerCheck.contradicts("Finish the task that is already yours before you add another. That is today's work priority. Relationships can wait.", reading: work.reading))
        XCTAssertTrue(TodayAnswerCheck.contradicts("You're right, focus on your relationships instead.", reading: work.reading))
        XCTAssertFalse(TodayAnswerCheck.contradicts("I had that wrong. Today's recommendation is still the work in front of you: \(work.reading.focus)", reading: work.reading))

        XCTAssertTrue(TodayAnswerCheck.contradicts("Focus on work and finish a task. Leave people for later.", reading: relationships.reading))
        XCTAssertFalse(TodayAnswerCheck.contradicts("Ask someone close one simple question instead of guessing. Relationships lead today, and \(relationships.reading.focus)", reading: relationships.reading))

        let workAsk = OraclePrompt.turn(question, model: .appleIntelligence, reading: work.reading)
        let relationshipAsk = OraclePrompt.turn(question, model: .qwen, reading: relationships.reading)
        XCTAssertTrue(workAsk.contains("Do not tell them to focus on close people instead."))
        XCTAssertTrue(relationshipAsk.contains("Do not tell them to focus on work."))
        XCTAssertFalse(work.prompt.contains(work.reading.focus))
        XCTAssertFalse(relationships.prompt.contains(relationships.reading.focus))
        XCTAssertTrue(question.contains("today"))
    }

    func testMissingBirthDataDoesNotInventAChart() {
        let now = Date(timeIntervalSince1970: 1_761_400_000)
        let sky = TransitCalculator.sky(at: now, natal: nil)
        let reading = DailyReadingBuilder.reading(profile: nil, chart: nil, sky: sky)
        let context = OracleContext(
            profile: nil,
            chart: nil,
            sky: sky,
            connections: [],
            memory: [],
            date: now,
            reading: reading
        )
        let prompt = OraclePrompt.instructions(context: context, history: [], model: .qwen)

        XCTAssertTrue(prompt.contains("Birth date: not stored. Do not use the current date as the birth date."))
        XCTAssertTrue(prompt.contains("No natal chart is available"))
        XCTAssertTrue(prompt.contains("Do not invent placements"))
        XCTAssertFalse(prompt.contains("Primary recommendation:"))
        XCTAssertFalse(prompt.contains(reading.focus))
        let asked = OraclePrompt.turn("What should I focus on today?", model: .qwen, reading: reading)
        if reading.dials.contains(where: { $0.id == "bonds" }) {
            XCTAssertTrue(asked.contains("Today shows the day leaning"))
        } else {
            XCTAssertTrue(asked.contains("Today shows: \(reading.focus)."))
        }
        XCTAssertFalse(prompt.contains("Rising in"))
        XCTAssertFalse(prompt.contains("House cusps:"))
    }

    func testStoredBirthDateIsNotReplacedByTheCurrentDate() {
        let calendar = Calendar.current
        let born = calendar.date(from: DateComponents(year: 1995, month: 2, day: 14, hour: 12))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
        let profile = datedProfile(born: born)
        let day = reading(profile: profile, on: now)

        XCTAssertEqual(OracleDates.iso(born), "1995-02-14")
        XCTAssertEqual(OracleDates.long(born), "February 14, 1995")
        XCTAssertEqual(OracleDates.age(born: born, on: now), 31)
        XCTAssertTrue(day.prompt.contains("Birth date: 1995-02-14 (February 14, 1995)."))
        XCTAssertTrue(day.prompt.contains("Current date: 2026-10-26"))
        XCTAssertTrue(day.prompt.contains("Age on the current date: 31."))
        XCTAssertTrue(day.prompt.contains("The birthday has already occurred this year."))
        XCTAssertLessThan(day.prompt.range(of: "Birth date:")!.lowerBound, day.prompt.range(of: "Current sky")!.lowerBound)
        XCTAssertFalse(day.prompt.contains("Primary recommendation:"))
        XCTAssertFalse(day.prompt.contains("Birth date: 2026-10-26"))

        for model in [OraclePrompt.Model.appleIntelligence, .qwen] {
            let turn = OraclePrompt.turn(
                "When was I born?",
                model: model,
                reading: day.reading,
                profile: profile,
                now: now
            )
            XCTAssertTrue(turn.contains("Stored birth date: 1995-02-14 (February 14, 1995)."), model == .qwen ? "qwen" : "apple")
            XCTAssertTrue(turn.contains("Current date: 2026-10-26."))
            XCTAssertTrue(turn.contains("These are different facts."))
            XCTAssertFalse(turn.contains("Today's calculated recommendation"))
        }

        let age = OraclePrompt.turn("How old am I?", model: .appleIntelligence, profile: profile, now: now)
        XCTAssertTrue(age.contains("Age on the current date: 31."))
        XCTAssertTrue(age.contains("1995-02-14"))
    }

    func testAgeUsesWhetherTheBirthdayHasOccurred() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let born = calendar.date(from: DateComponents(year: 1995, month: 2, day: 14, hour: 12))!
        let before = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12))!
        let onDay = calendar.date(from: DateComponents(year: 2026, month: 2, day: 14, hour: 12))!
        let after = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!

        XCTAssertEqual(OracleDates.age(born: born, on: before, calendar: calendar), 30)
        XCTAssertEqual(OracleDates.age(born: born, on: onDay, calendar: calendar), 31)
        XCTAssertEqual(OracleDates.age(born: born, on: after, calendar: calendar), 31)
        XCTAssertFalse(OracleDates.birthdayHasOccurred(born: born, on: before, calendar: calendar))
        XCTAssertTrue(OracleDates.birthdayHasOccurred(born: born, on: onDay, calendar: calendar))
        XCTAssertEqual(OracleDates.weekday(born, calendar: calendar), "Tuesday")
    }

    func testADateOnlyValueKeepsItsCalendarDay() {
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        let stored = auckland.date(from: DateComponents(year: 1995, month: 2, day: 14))!
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        XCTAssertEqual(OracleDates.iso(stored, calendar: auckland), "1995-02-14")
        XCTAssertEqual(OracleDates.long(stored, calendar: auckland), "February 14, 1995")
        XCTAssertEqual(OracleDates.iso(stored, calendar: losAngeles), "1995-02-13")
    }

    func testMissingBirthDateIsNeverTheCurrentDate() {
        let now = Date(timeIntervalSince1970: 1_761_400_000)
        let current = OracleDates.iso(now)
        let turn = OraclePrompt.turn("When was I born?", model: .qwen, profile: nil, now: now)

        XCTAssertTrue(turn.contains("Stored birth date: none."))
        XCTAssertTrue(turn.contains("Do not answer with the current date \(current)."))
        XCTAssertFalse(turn.contains("Stored birth date: \(current)"))
    }

    func testChangingTheProfileChangesTheBirthFact() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
        let first = reading(profile: datedProfile(born: calendar.date(from: DateComponents(year: 1995, month: 2, day: 14, hour: 12))!), on: now)
        let second = reading(profile: datedProfile(born: calendar.date(from: DateComponents(year: 1990, month: 7, day: 4, hour: 12))!), on: now)

        XCTAssertTrue(first.prompt.contains("Birth date: 1995-02-14"))
        XCTAssertTrue(second.prompt.contains("Birth date: 1990-07-04"))
        XCTAssertFalse(second.prompt.contains("Birth date: 1995-02-14"))
        XCTAssertNotEqual(first.context.profile, second.context.profile)
    }

    func testWhyExplainsTheFactorInsteadOfRepeatingTheRecommendation() throws {
        let work = try XCTUnwrap(firstReading(profile: workProfile, where: { $0.value >= 62 }))
        let history = [
            ChatMessage(role: .user, text: "What should I focus on today?"),
            ChatMessage(role: .oracle, text: work.reading.focus)
        ]
        let questions = [
            "Why?",
            "Why do you think so?",
            "How did you come to that conclusion?",
            "Can you explain?",
            "What makes today good for this?",
            "How does this relate to my chart?"
        ]
        for question in questions {
            XCTAssertEqual(OraclePrompt.intent(of: question, history: history), .reason(.priority), question)
            for model in [OraclePrompt.Model.appleIntelligence, .qwen] {
                let turn = OraclePrompt.turn(question, model: model, reading: work.reading, history: history)
                XCTAssertTrue(turn.contains("Explain why"), question)
                XCTAssertTrue(turn.contains(work.reading.ephemerisTitle), question)
                XCTAssertTrue(turn.contains("Do not invent a planet"))
                XCTAssertFalse(turn.contains("Do not replace it because the user disagrees."), question)
            }
        }

        XCTAssertTrue(FollowUpCheck.repeats(work.reading.focus, reading: work.reading))
        XCTAssertFalse(FollowUpCheck.explains(work.reading.focus, reading: work.reading))
        let explanation = "Because \(work.reading.ephemerisTitle) is the calculated factor behind that recommendation."
        XCTAssertTrue(FollowUpCheck.explains(explanation, reading: work.reading))
        XCTAssertFalse(FollowUpCheck.repeats(explanation, reading: work.reading))

        let cold = OraclePrompt.turn("Why is the sky blue?", model: .appleIntelligence, reading: work.reading)
        XCTAssertTrue(cold.hasPrefix("Why is the sky blue?"))
        XCTAssertFalse(cold.contains("Today shows"))
        let otherTopic = [
            ChatMessage(role: .user, text: "What is the capital of France?"),
            ChatMessage(role: .oracle, text: "Paris.")
        ]
        let unrelatedWhy = OraclePrompt.turn("Why?", model: .appleIntelligence, reading: work.reading, history: otherTopic)
        XCTAssertEqual(OraclePrompt.intent(of: "Why?", history: otherTopic), .reason(nil))
        XCTAssertTrue(unrelatedWhy.contains("Previous answer: Paris."))
        XCTAssertTrue(unrelatedWhy.contains("do not switch to today's priority."))
        XCTAssertFalse(unrelatedWhy.contains("Today's calculated recommendation"))
        XCTAssertFalse(unrelatedWhy.contains(work.reading.focus))
    }

    func testHowToActAsksForStepsRatherThanACopy() throws {
        let work = try XCTUnwrap(firstReading(profile: workProfile, where: { $0.value >= 62 }))
        let history = [
            ChatMessage(role: .user, text: "What should I focus on today?"),
            ChatMessage(role: .oracle, text: work.reading.focus)
        ]
        for model in [OraclePrompt.Model.appleIntelligence, .qwen] {
            let turn = OraclePrompt.turn("How should I act on that?", model: model, reading: work.reading, history: history)
            XCTAssertEqual(OraclePrompt.intent(of: "How should I act on that?", history: history), .action(.priority))
            XCTAssertTrue(turn.contains("Give practical steps for carrying this out: \(work.reading.focus)."))
            XCTAssertTrue(turn.contains("Do not only repeat the recommendation."))
            if !work.reading.caution.isEmpty {
                XCTAssertTrue(turn.contains(work.reading.caution))
            }
        }
    }

    func testTomorrowUsesThatDaysGuidance() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 15))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let todayReading = reading(profile: workProfile, on: today)
        let tomorrowReading = reading(profile: workProfile, on: tomorrow)
        let history = [
            ChatMessage(role: .user, text: "What should I focus on today?"),
            ChatMessage(role: .oracle, text: todayReading.reading.focus)
        ]
        XCTAssertEqual(
            OraclePrompt.targetDate(in: "What about tomorrow?", today: today, calendar: calendar),
            calendar.startOfDay(for: tomorrow)
        )

        for model in [OraclePrompt.Model.appleIntelligence, .qwen] {
            let turn = OraclePrompt.turn(
                "What about tomorrow?",
                model: model,
                reading: todayReading.reading,
                otherDay: ("Tomorrow", tomorrowReading.reading),
                history: history
            )
            XCTAssertTrue(turn.contains("Tomorrow shows"))
            XCTAssertTrue(turn.contains(tomorrowReading.bonds.note))
            XCTAssertTrue(turn.contains("Use this day, not a different day's priority."))
            XCTAssertFalse(turn.contains("Today's calculated recommendation"))
            XCTAssertFalse(turn.contains("Do not replace it because the user disagrees."))
        }

        let missing = OraclePrompt.turn("What about tomorrow?", model: .qwen, reading: todayReading.reading, history: history)
        XCTAssertTrue(missing.contains("That day's sky was not calculated"))
        XCTAssertFalse(missing.contains("Today's calculated recommendation"))
    }

    func testMissingFactorsForbidAnInventedExplanation() {
        let now = Date(timeIntervalSince1970: 1_761_400_000)
        let sky = TransitCalculator.sky(at: now, natal: nil)
        let reading = DailyReadingBuilder.reading(profile: nil, chart: nil, sky: sky)
        let history = [
            ChatMessage(role: .user, text: "What should I focus on today?"),
            ChatMessage(role: .oracle, text: reading.focus)
        ]
        let turn = OraclePrompt.turn("Why?", model: .appleIntelligence, reading: reading, history: history)

        XCTAssertTrue(turn.contains("There is no birth chart yet, so this uses today's Moon only."))
        XCTAssertTrue(turn.contains("Do not invent a planet, transit, or birth fact that is not written here."))
        let factors = reading.ephemerisTitle + " " + reading.ephemerisText
        let outsider = ["pluto", "uranus", "neptune"].first { !factors.lowercased().contains($0) }!
        XCTAssertTrue(FollowUpCheck.invents("This is because \(outsider) is square the natal Sun.", reading: reading))
        XCTAssertFalse(FollowUpCheck.invents("This uses today's Moon only.", reading: reading))
    }

    func testSwitchingModelsKeepsTheSameFactsAndHistory() throws {
        let calendar = Calendar.current
        let born = calendar.date(from: DateComponents(year: 1995, month: 2, day: 14, hour: 12))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 12))!
        let day = reading(profile: datedProfile(born: born), on: now)
        let history = [
            ChatMessage(role: .user, text: "What should I focus on today?"),
            ChatMessage(role: .oracle, text: day.reading.focus),
            ChatMessage(role: .user, text: "Why?")
        ]
        let prior = OraclePrompt.priorTurns(from: history, question: "Why?")
        let apple = OraclePrompt.instructions(context: day.context, history: prior, model: .appleIntelligence)
        let qwen = OraclePrompt.instructions(context: day.context, history: prior, model: .qwen)

        XCTAssertTrue(apple.contains("Birth date: 1995-02-14"))
        XCTAssertTrue(qwen.contains("Birth date: 1995-02-14"))
        XCTAssertTrue(apple.contains("What should I focus on today?"))
        XCTAssertTrue(qwen.contains("What should I focus on today?"))
        XCTAssertEqual(slicePrimary(apple), slicePrimary(qwen))
        XCTAssertFalse(apple.contains("Primary recommendation:"))
        XCTAssertFalse(qwen.contains("Primary recommendation:"))

        let appleTurn = OraclePrompt.turn("Why?", model: .appleIntelligence, reading: day.reading, profile: day.context.profile, now: now, history: prior)
        let qwenTurn = OraclePrompt.turn("Why?", model: .qwen, reading: day.reading, profile: day.context.profile, now: now, history: prior)
        XCTAssertTrue(appleTurn.contains(day.reading.ephemerisTitle))
        XCTAssertTrue(qwenTurn.contains(day.reading.ephemerisTitle))
        XCTAssertTrue(qwenTurn.contains("Explain why in the first sentence"))
    }

    func testAConversationAnswersEachQuestionOnItsOwn() throws {
        let work = try XCTUnwrap(firstReading(profile: workProfile, where: { $0.value >= 62 }))
        let workArea = try XCTUnwrap(work.reading.areas.first { $0.title == "Work & goals" })
        let loveArea = try XCTUnwrap(work.reading.areas.first { $0.title == "Love & relationships" })
        let moodArea = try XCTUnwrap(work.reading.areas.first { $0.title == "Mood & energy" })
        let questions = [
            "What should I focus on today?",
            "What exactly should I focus on at work?",
            "Is today a good day to talk about something important?",
            "Why?",
            "What about relationships?",
            "When was I born?"
        ]
        var history: [ChatMessage] = []

        for question in questions {
            for model in [OraclePrompt.Model.appleIntelligence, .qwen] {
                let turn = OraclePrompt.turn(
                    question,
                    model: model,
                    reading: work.reading,
                    profile: work.context.profile,
                    now: work.reading.date,
                    history: history
                )
                switch question {
                case "What should I focus on today?":
                    XCTAssertEqual(OraclePrompt.intent(of: question, history: history), .recommendation)
                    XCTAssertTrue(turn.contains("Today shows"))
                    XCTAssertTrue(turn.contains(work.bonds.note))
                    XCTAssertTrue(turn.contains("specific actions"))
                    XCTAssertTrue(turn.hasSuffix(question))
                case "What exactly should I focus on at work?":
                    XCTAssertEqual(OraclePrompt.intent(of: question, history: history), .topic(.work))
                    XCTAssertTrue(turn.contains(workArea.text), question)
                    XCTAssertTrue(turn.contains("Give one concrete priority"))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                    XCTAssertFalse(turn.contains("Give this recommendation."))
                case "Is today a good day to talk about something important?":
                    XCTAssertEqual(OraclePrompt.intent(of: question, history: history), .topic(.communication))
                    XCTAssertTrue(turn.contains(loveArea.text))
                    XCTAssertTrue(turn.contains(moodArea.text))
                    XCTAssertTrue(turn.contains("important conversation"))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                    XCTAssertFalse(turn.contains(workArea.text))
                case "Why?":
                    XCTAssertEqual(OraclePrompt.intent(of: question, history: history), .reason(.communication))
                    XCTAssertTrue(turn.contains("Explain why"))
                    XCTAssertTrue(turn.contains("an important conversation"))
                    XCTAssertTrue(turn.contains(loveArea.text))
                    XCTAssertFalse(turn.contains("Recommendation being explained"))
                case "What about relationships?":
                    XCTAssertEqual(OraclePrompt.intent(of: question, history: history), .topic(.relationships))
                    XCTAssertTrue(turn.contains(loveArea.text))
                    XCTAssertTrue(turn.contains("Answer about that person"))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                case "When was I born?":
                    let stored = OracleDates.iso(try XCTUnwrap(work.context.profile?.birth.date))
                    XCTAssertEqual(OraclePrompt.intent(of: question, history: history), .birthFact)
                    XCTAssertTrue(turn.contains("Stored birth date: \(stored)"))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                default:
                    XCTFail(question)
                }
            }
            history.append(ChatMessage(role: .user, text: question))
            history.append(ChatMessage(role: .oracle, text: "Noted."))
        }

        let aside = OraclePrompt.turn(
            "What is the capital of France?",
            model: .qwen,
            reading: work.reading,
            history: history
        )
        XCTAssertEqual(OraclePrompt.intent(of: "What is the capital of France?", history: history), .general)
        XCTAssertFalse(aside.contains("Today's calculated recommendation"))
        XCTAssertTrue(aside.hasSuffix("What is the capital of France?"))
        XCTAssertFalse(aside.contains("Reply to the message above"))

        let vague = OraclePrompt.turn("What about that?", model: .appleIntelligence, reading: work.reading, history: history)
        XCTAssertEqual(OraclePrompt.intent(of: "What about that?", history: history), .detail(nil))
        XCTAssertTrue(vague.contains("Previous question: When was I born?"))
        XCTAssertFalse(vague.contains("Today's calculated recommendation"))
        XCTAssertFalse(vague.contains("Give this recommendation."))
    }

    /// The conversation that was answering every turn with Today's work priority.
    /// Checks the request each provider would send. A live model is not called.
    func testMixedConversationDoesNotCollapseToTheDailyPriority() throws {
        let work = try XCTUnwrap(firstReading(profile: workProfile, where: { $0.value >= 62 }))
        let workArea = try XCTUnwrap(work.reading.areas.first { $0.title == "Work & goals" })
        let loveArea = try XCTUnwrap(work.reading.areas.first { $0.title == "Love & relationships" })
        let familyArea = work.reading.areas.first { $0.title == "Friends & family" }
        let questions = [
            "What should I focus on today?",
            "What exactly should I focus on at work?",
            "Is today a good day to talk about something important?",
            "Why?",
            "Can you be more specific?",
            "I'm worried about a decision I have to make. Can you help?",
            "What about my family?",
            "When was I born?",
            "How do I cook a simple dinner?",
            "Actually, I want to ask about something completely different."
        ]
        var history: [ChatMessage] = []

        for question in questions {
            let intent = OraclePrompt.intent(of: question, history: history)
            for model in [OraclePrompt.Model.appleIntelligence, .qwen] {
                let turn = OraclePrompt.turn(
                    question,
                    model: model,
                    reading: work.reading,
                    profile: work.context.profile,
                    now: work.reading.date,
                    history: history
                )
                XCTAssertTrue(turn.hasSuffix(question), question)
                XCTAssertNotEqual(turn, "You should focus on work today.")
                switch question {
                case questions[0]:
                    XCTAssertEqual(intent, .recommendation)
                    XCTAssertTrue(turn.contains("Today shows the day leaning toward the work in front of them"))
                    XCTAssertTrue(turn.contains("Do not tell them to focus on close people instead."))
                case questions[1]:
                    XCTAssertEqual(intent, .topic(.work))
                    XCTAssertTrue(turn.contains(workArea.text))
                    XCTAssertTrue(turn.contains("Give one concrete priority"))
                    XCTAssertFalse(turn.contains("Give this recommendation."))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                case questions[2]:
                    XCTAssertEqual(intent, .topic(.communication))
                    XCTAssertTrue(turn.contains(loveArea.text))
                    XCTAssertTrue(turn.contains("important conversation"))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                case questions[3]:
                    XCTAssertEqual(intent, .reason(.communication))
                    XCTAssertTrue(turn.contains("Explain why"))
                    XCTAssertTrue(turn.contains("an important conversation"))
                    XCTAssertFalse(turn.contains("Recommendation being explained"))
                    XCTAssertFalse(turn.contains("Give this recommendation."))
                case questions[4]:
                    XCTAssertEqual(intent, .detail(.communication))
                    XCTAssertTrue(turn.contains("concrete example"))
                    XCTAssertTrue(turn.contains("Previous question: \(questions[3])") || turn.contains("an important conversation"))
                    XCTAssertFalse(turn.contains("Give this recommendation."))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                case questions[5]:
                    XCTAssertEqual(intent, .general)
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                    XCTAssertFalse(turn.contains("Give this recommendation."))
                    XCTAssertFalse(turn.contains(work.reading.focus))
                case questions[6]:
                    XCTAssertEqual(intent, .topic(.family))
                    if let familyArea {
                        XCTAssertTrue(turn.contains(familyArea.text))
                    } else {
                        XCTAssertTrue(turn.contains("No separate family guidance was calculated."))
                    }
                    XCTAssertTrue(turn.contains("Answer about their family."))
                    XCTAssertFalse(turn.contains("Give this recommendation."))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                case questions[7]:
                    let stored = OracleDates.iso(try XCTUnwrap(work.context.profile?.birth.date))
                    XCTAssertEqual(intent, .birthFact)
                    XCTAssertTrue(turn.contains("Stored birth date: \(stored)"))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                    XCTAssertFalse(turn.contains(work.reading.focus))
                case questions[8]:
                    XCTAssertEqual(intent, .general)
                    XCTAssertFalse(turn.contains("Give practical steps for carrying this out"))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                    XCTAssertFalse(turn.contains(work.reading.focus))
                case questions[9]:
                    XCTAssertEqual(intent, .redirect)
                    XCTAssertTrue(turn.contains("leaving the previous subject"))
                    XCTAssertFalse(turn.contains("Today's calculated recommendation"))
                    XCTAssertFalse(turn.contains(work.reading.focus))
                default:
                    XCTFail(question)
                }
                XCTAssertFalse(turn.contains("Reply to the message above"))
            }
            let slogan = "You should focus on work today."
            if question == questions[0] {
                XCTAssertFalse(DailyRepetition.substitutesPriority(slogan, question: question, reading: work.reading, history: history))
            } else {
                XCTAssertTrue(DailyRepetition.substitutesPriority(slogan, question: question, reading: work.reading, history: history), question)
            }
            history.append(ChatMessage(role: .user, text: question))
            history.append(ChatMessage(role: .oracle, text: "Noted \(question)."))
        }

        var asSent = history
        asSent.removeLast()
        let prior = OraclePrompt.priorTurns(from: asSent, question: questions[9])
        XCTAssertEqual(prior.map(\.text), [
            questions[7],
            "Noted \(questions[7]).",
            questions[8],
            "Noted \(questions[8])."
        ])
        XCTAssertFalse(prior.contains { $0.text == questions[9] })

        let cooked = "How do I cook a simple dinner?"
        let afterPriority = [
            ChatMessage(role: .user, text: questions[0]),
            ChatMessage(role: .oracle, text: work.reading.focus)
        ]
        XCTAssertEqual(OraclePrompt.intent(of: cooked, history: afterPriority), .general)
        let cookedTurn = OraclePrompt.turn(cooked, model: .qwen, reading: work.reading, history: afterPriority)
        XCTAssertTrue(cookedTurn.hasSuffix(cooked))
        XCTAssertFalse(cookedTurn.contains("Reply to the message above"))
        XCTAssertFalse(cookedTurn.contains("Give practical steps for carrying this out"))
        XCTAssertFalse(cookedTurn.contains(work.reading.focus))

        let afterCooking = afterPriority + [
            ChatMessage(role: .user, text: cooked),
            ChatMessage(role: .oracle, text: "Boil pasta, then add garlic and salt.")
        ]
        let stuck = "What if that doesn't work?"
        XCTAssertEqual(OraclePrompt.intent(of: stuck, history: afterCooking), .action(nil))
        let stuckTurn = OraclePrompt.turn(stuck, model: .appleIntelligence, reading: work.reading, history: afterCooking)
        XCTAssertTrue(stuckTurn.contains("Previous answer: Boil pasta, then add garlic and salt."))
        XCTAssertFalse(stuckTurn.contains("question about work"))
        XCTAssertFalse(stuckTurn.contains("Today's calculated recommendation"))

        let apple = OraclePrompt.instructions(context: work.context, history: prior, model: .appleIntelligence)
        let qwen = OraclePrompt.instructions(context: work.context, history: prior, model: .qwen)
        XCTAssertFalse(apple.contains("Primary recommendation:"))
        XCTAssertFalse(qwen.contains("Primary recommendation:"))
        XCTAssertFalse(apple.contains(work.reading.focus))
        XCTAssertFalse(qwen.contains(work.reading.focus))
        XCTAssertTrue(apple.contains(questions[8]))
        XCTAssertTrue(qwen.contains(questions[8]))
        XCTAssertFalse(apple.contains(questions[9]))
        XCTAssertLessThan(apple.range(of: questions[7])!.lowerBound, apple.range(of: questions[8])!.lowerBound)

        let cookingAnswer = "Boil pasta, drain it, and toss it with olive oil, garlic, and salt."
        XCTAssertEqual(OraclePrompt.deliver(cookingAnswer), cookingAnswer)
        XCTAssertFalse(OraclePrompt.deliver(cookingAnswer).contains(work.reading.focus))
        XCTAssertFalse(OraclePrompt.unavailableReply.contains(work.reading.focus))
        XCTAssertFalse(OraclePrompt.unavailableReply.contains("focus on work"))
    }

    func testARussianConversationFollowsTheQuestionAndTodaysBalance() throws {
        let people = try XCTUnwrap(firstReading(profile: relationshipProfile, where: { $0.value <= 40 }))
        let love = try XCTUnwrap(people.reading.areas.first { $0.title == "Love & relationships" })
        let talk = "Хороший ли сегодня день что бы поговорить о чем-то важном?"
        let distant = "Почему кто-то близкий мне чувствуется отстраненным?"
        var history: [ChatMessage] = []

        for model in [OraclePrompt.Model.appleIntelligence, .qwen] {
            let first = OraclePrompt.turn(talk, model: model, reading: people.reading, history: history)
            XCTAssertEqual(OraclePrompt.intent(of: talk, history: history), .topic(.communication))
            XCTAssertTrue(first.hasSuffix(talk))
            XCTAssertTrue(first.contains(love.text))
            XCTAssertTrue(first.contains("Do not tell them to focus on work."))
            XCTAssertTrue(first.contains(people.bonds.note))
            XCTAssertTrue(first.contains("answers the conversation"))
            XCTAssertFalse(first.contains("Do not tell them to focus on close people instead."))
            XCTAssertFalse(first.contains("Reply to the message above"))
        }

        history.append(ChatMessage(role: .user, text: talk))
        history.append(ChatMessage(role: .oracle, text: "Сегодня лучше для близкого разговора, чем для работы."))

        for model in [OraclePrompt.Model.appleIntelligence, .qwen] {
            let second = OraclePrompt.turn(distant, model: model, reading: people.reading, history: history)
            XCTAssertEqual(OraclePrompt.intent(of: distant, history: history), .topic(.relationships))
            XCTAssertTrue(second.hasSuffix(distant))
            XCTAssertTrue(second.contains(love.text))
            XCTAssertTrue(second.contains("Do not replace this with a work recommendation."))
            XCTAssertFalse(second.contains("Сегодня лучше для близкого разговора"))
            XCTAssertFalse(second.contains("Reply to the message above"))
        }

        let bare = OraclePrompt.turn("Почему?", model: .appleIntelligence, reading: people.reading, history: history)
        XCTAssertEqual(OraclePrompt.intent(of: "Почему?", history: history), .reason(.communication))
        XCTAssertTrue(bare.contains("Explain why"))
        XCTAssertTrue(bare.hasSuffix("Почему?"))
        XCTAssertFalse(bare.contains("Do not tell them to focus on work.") && bare.contains("specific actions"))

        let specifics = "Подскажи, что именно лучше сегодня сделать?"
        XCTAssertEqual(OraclePrompt.intent(of: specifics, history: history), .recommendation)
        let specificTurn = OraclePrompt.turn(specifics, model: .qwen, reading: people.reading, history: history)
        XCTAssertTrue(specificTurn.hasSuffix(specifics))
        XCTAssertTrue(specificTurn.contains("specific actions"))
        XCTAssertTrue(specificTurn.contains(love.text))
        XCTAssertTrue(specificTurn.contains("Do not tell them to focus on work."))
        XCTAssertFalse(specificTurn.contains("Reply to the message above"))

        let next = "Что именно я могу сделать?"
        let afterAdvice = history + [
            ChatMessage(role: .user, text: specifics),
            ChatMessage(role: .oracle, text: "Сегодня день для близких.")
        ]
        XCTAssertEqual(OraclePrompt.intent(of: next, history: afterAdvice), .action(.priority))
        let nextTurn = OraclePrompt.turn(next, model: .appleIntelligence, reading: people.reading, history: afterAdvice)
        XCTAssertTrue(nextTurn.hasSuffix(next))
        XCTAssertTrue(nextTurn.contains("specific actions"))
        XCTAssertTrue(nextTurn.contains(love.text))
        XCTAssertFalse(nextTurn.contains("Reply to the message above"))

        XCTAssertFalse(OraclePrompt.continuesConversation(talk, history: []))
        XCTAssertTrue(OraclePrompt.continuesConversation(distant, history: history))
        XCTAssertTrue(OraclePrompt.continuesConversation("Почему?", history: history))
        XCTAssertTrue(OraclePrompt.continuesConversation("Объясни", history: history))
        XCTAssertTrue(OraclePrompt.continuesConversation("Что делать?", history: history))
        XCTAssertTrue(OraclePrompt.continuesConversation(next, history: afterAdvice))
    }

    func testMissingAreaGuidanceIsNotReplacedByTheDailyPriority() {
        let reading = DailyReading(
            date: Date(timeIntervalSince1970: 1_761_400_000),
            moonPhase: "New Moon",
            moonSign: .aries,
            moonIllumination: 0,
            atmosphere: "",
            ephemerisTitle: "Moon",
            ephemerisText: "There is no birth chart yet, so this uses today's Moon only.",
            transitLine: "",
            orb: "",
            synthesisTitle: "",
            synthesisText: "",
            imageCaption: "",
            areas: [],
            tendencies: [],
            dials: [],
            luckyNumbers: LuckyNumbers(values: [], personalDay: 1, note: ""),
            moods: [],
            oracleQuestions: [],
            focus: "Give the day to the work.",
            caution: "",
            reflection: ""
        )
        let work = OraclePrompt.turn("What exactly should I focus on at work?", model: .appleIntelligence, reading: reading)
        let talk = OraclePrompt.turn("Is today a good day to talk about something important?", model: .qwen, reading: reading)

        XCTAssertTrue(work.contains("No separate work guidance was calculated. Do not invent a task."))
        XCTAssertTrue(talk.contains("No relationship guidance was calculated."))
        XCTAssertTrue(talk.contains("No mood guidance was calculated."))
        XCTAssertFalse(work.contains("Today's calculated recommendation"))
        XCTAssertFalse(talk.contains("Give the day to the work."))
    }

    func testWorkTomorrowUsesThatDaysWorkGuidance() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 15))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let todayReading = reading(profile: workProfile, on: today)
        let tomorrowReading = reading(profile: workProfile, on: tomorrow)
        let tomorrowWork = try XCTUnwrap(tomorrowReading.reading.areas.first { $0.title == "Work & goals" })
        let history = [ChatMessage(role: .user, text: "What should I focus on today?")]

        let turn = OraclePrompt.turn(
            "What about work tomorrow?",
            model: .qwen,
            reading: todayReading.reading,
            otherDay: ("Tomorrow", tomorrowReading.reading),
            history: history
        )

        XCTAssertEqual(OraclePrompt.intent(of: "What about work tomorrow?", history: history), .topic(.work))
        XCTAssertTrue(turn.contains("Tomorrow question about work"))
        XCTAssertTrue(turn.contains(tomorrowWork.text))
        XCTAssertFalse(turn.contains("Today's calculated recommendation"))
    }

    func testRepresentativeAnswersAreJudgedByRelevanceNotFluency() {
        let poorGoal = """
        You cannot know another person's thoughts or feelings, but you can focus on what you can control. \
        Focus on taking care of yourself and improving your relationships with those around you. \
        It’s a good start to prioritize your well-being and communication with others.
        """
        let usefulGoal = """
        Focus on one meaningful goal you can make progress on consistently over the next month. \
        Choose something that matters to you and define a clear result you want to achieve. \
        If you tell me what matters most to you right now, I can help you choose a more specific goal.
        """
        let personalGoal = """
        Focus on shipping the iOS app. You said that is what is on your mind, and you are building a career, \
        so finishing that app is the clearest goal. Set aside the next open evening for one unfinished piece of it.
        """
        let fixtures: [AnswerFixture] = [
            AnswerFixture("goal, generic", "What is the best goal for me to focus on?", poorGoal, acceptable: false),
            AnswerFixture("goal, useful without personal facts", "What is the best goal for me to focus on?", usefulGoal, acceptable: true),
            AnswerFixture("goal, personalized", "What is the best goal for me to focus on?", personalGoal, acceptable: true),
            AnswerFixture(
                "week, generic",
                "What should I focus on this week?",
                "Take care of yourself and improve communication with those around you. Your well-being comes first.",
                acceptable: false
            ),
            AnswerFixture(
                "week, specific",
                "What should I focus on this week?",
                "Finish one piece of the iOS app this week. You already named that as what is on your mind, so a finished piece beats a new idea. Pick the piece tonight and do it in the next free evening.",
                acceptable: true
            ),
            AnswerFixture(
                "decision, avoided",
                "Should I start a new project or finish an existing one?",
                "You cannot know another person's thoughts. Focus on what you can control and your relationships.",
                acceptable: false
            ),
            AnswerFixture(
                "decision, chosen",
                "Should I start a new project or finish an existing one?",
                "Finish the existing project. It is already underway, so you reach a result sooner than you would by starting over. Do the next unfinished piece this week.",
                acceptable: true
            ),
            AnswerFixture(
                "explanation, off topic",
                "Why might this be a good time to make a change?",
                "The stars are silent. Take care of yourself and tend to your relationships with those around you.",
                acceptable: false
            ),
            AnswerFixture(
                "explanation, direct",
                "Why might this be a good time to make a change?",
                "It is a good time to make a change when the current plan has stalled and you can name the result you want instead. Write that result down before you change anything.",
                acceptable: true
            ),
            AnswerFixture(
                "missing facts, still answers",
                "What is the best goal for me to focus on?",
                usefulGoal,
                acceptable: true
            ),
            AnswerFixture(
                "fact, direct",
                "What is the capital of France?",
                "Paris is the capital of France.",
                acceptable: true,
                allowsAstrology: false
            ),
            AnswerFixture(
                "fact, astrology detour",
                "What is the capital of France?",
                "Your chart suggests focusing on relationships. Paris is sometimes called the capital, but take care of yourself.",
                acceptable: false,
                allowsAstrology: false
            ),
            AnswerFixture(
                "follow-up, stays with the choice",
                "Why?",
                "Because finishing the existing project uses the work you already started, instead of splitting the week in two.",
                acceptable: true
            ),
            AnswerFixture(
                "follow-up, changes the subject",
                "Why?",
                "You cannot know another person's thoughts or feelings. Focus on communication with others.",
                acceptable: false
            ),
            AnswerFixture(
                "ambiguous, asks",
                "help",
                "What do you want help with?",
                acceptable: true
            ),
            AnswerFixture(
                "ambiguous, generic",
                "help",
                "Take care of yourself and improve your relationships with those around you.",
                acceptable: false
            ),
            AnswerFixture(
                "complex, chooses",
                "Should I start a new project or finish an existing one if I only have evenings free and the existing one is almost done?",
                "Finish the existing one. Evenings are enough for something that is almost done, and a new project would need more room than you have. Use the next evening to close the last piece.",
                acceptable: true
            )
        ]

        for fixture in fixtures {
            let problems = OracleAnswerRubric.problems(in: fixture.answer, for: fixture.question, allowsAstrology: fixture.allowsAstrology)
            if fixture.acceptable {
                XCTAssertEqual(problems, [], "\(fixture.name): \(problems.joined(separator: "; "))")
            } else {
                XCTAssertFalse(problems.isEmpty, fixture.name)
            }
        }
    }

    // MARK: - Fixtures

    private struct GuidedDay {
        let reading: DailyReading
        let bonds: LifeDial
        let context: OracleContext

        var prompt: String {
            OraclePrompt.instructions(context: context, history: [], model: .appleIntelligence)
        }
    }

    private var workProfile: UserProfile {
        UserProfile(
            name: "Ada",
            birth: birthData(timeKnown: true, placeKnown: true),
            interests: [.career],
            intentions: [],
            personal: PersonalContext(
                relationship: nil,
                lifeStage: .buildingCareer,
                pronouns: nil,
                currentFocus: "the work project at my job",
                tone: nil,
                length: nil
            )
        )
    }

    private var relationshipProfile: UserProfile {
        UserProfile(
            name: "Ada",
            birth: birthData(timeKnown: true, placeKnown: true),
            interests: [.love],
            intentions: [.navigateRelationship],
            personal: PersonalContext(
                relationship: .dating,
                lifeStage: nil,
                pronouns: nil,
                currentFocus: "my relationship with my partner",
                tone: nil,
                length: nil
            )
        )
    }

    private func firstReading(profile: UserProfile, where predicate: (LifeDial) -> Bool) -> GuidedDay? {
        let calendar = Calendar(identifier: .gregorian)
        var date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 3, hour: 15))!
        for _ in 0..<60 {
            let day = reading(profile: profile, on: date)
            if predicate(day.bonds) { return day }
            guard let next = calendar.date(byAdding: .day, value: 6, to: date) else { return nil }
            date = next
        }
        return nil
    }

    private func reading(profile: UserProfile, on date: Date) -> GuidedDay {
        let chart = NatalChartCalculator.chart(for: profile.birth)
        let sky = TransitCalculator.sky(at: date, natal: chart)
        let built = DailyReadingBuilder.reading(profile: profile, chart: chart, sky: sky)
        let bonds = built.dials.first { $0.id == "bonds" }!
        let context = OracleContext(
            profile: profile,
            chart: chart,
            sky: sky,
            connections: [],
            memory: [],
            date: date,
            reading: built
        )
        return GuidedDay(reading: built, bonds: bonds, context: context)
    }

    private func prompt(for day: GuidedDay) -> String { day.prompt }

    private func slicePrimary(_ prompt: String) -> String {
        let line = prompt.split(separator: "\n").first { $0.hasPrefix("Primary recommendation:") }
        return String(line ?? "")
    }

    private func instructions(
        timeKnown: Bool = true,
        placeKnown: Bool = true,
        history: [ChatMessage] = [],
        model: OraclePrompt.Model
    ) -> String {
        OraclePrompt.instructions(context: context(timeKnown: timeKnown, placeKnown: placeKnown), history: history, model: model)
    }

    private func context(timeKnown: Bool, placeKnown: Bool) -> OracleContext {
        let birth = birthData(timeKnown: timeKnown, placeKnown: placeKnown)
        let chart = NatalChartCalculator.chart(for: birth)
        let now = Date(timeIntervalSince1970: 1_761_400_000)
        let personal = timeKnown
            ? PersonalContext(
                relationship: nil,
                lifeStage: .buildingCareer,
                pronouns: nil,
                currentFocus: focus,
                tone: nil,
                length: nil
            )
            : nil
        let profile = UserProfile(
            name: "Ada",
            birth: birth,
            interests: [.career],
            intentions: [.dailyHabits],
            personal: personal
        )
        let sky = TransitCalculator.sky(at: now, natal: timeKnown ? chart : nil)
        let reading = DailyReadingBuilder.reading(profile: profile, chart: chart, sky: sky)
        return OracleContext(
            profile: profile,
            chart: chart,
            sky: sky,
            connections: [],
            peopleNotes: ["Mina (Romantic): Sun in Leo."],
            memory: [OracleMemoryEntry(date: now, question: "What should I focus on at work?", gist: "Finish the release.")],
            date: now,
            reading: reading
        )
    }

    private func datedProfile(born: Date) -> UserProfile {
        UserProfile(
            name: "Ada",
            birth: BirthData(date: born, time: nil, place: nil),
            interests: [],
            intentions: []
        )
    }

    private func birthData(timeKnown: Bool, placeKnown: Bool) -> BirthData {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let date = calendar.date(from: DateComponents(year: 1992, month: 3, day: 21))!
        let time = timeKnown
            ? calendar.date(from: DateComponents(year: 1992, month: 3, day: 21, hour: 10, minute: 30))
            : nil
        let place = placeKnown
            ? BirthPlace(
                city: "London",
                region: "UK",
                latitude: 51.5074,
                longitude: -0.1278,
                timeZone: "GMT",
                timeZoneIdentifier: "Europe/London"
            )
            : nil
        return BirthData(date: date, time: time, place: place)
    }

    private func sunSign() throws -> String {
        let chart = NatalChartCalculator.chart(for: birthData(timeKnown: true, placeKnown: true))
        return try XCTUnwrap(chart.placement(.sun)).sign.name
    }

    private func slice(_ text: String, from start: String, to end: String) throws -> String {
        let lower = try XCTUnwrap(text.range(of: start))
        let upper = try XCTUnwrap(text.range(of: end, range: lower.upperBound..<text.endIndex))
        return String(text[lower.lowerBound..<upper.lowerBound])
    }
}

private struct AnswerFixture {
    let name: String
    let question: String
    let answer: String
    let acceptable: Bool
    var allowsAstrology = true

    init(_ name: String, _ question: String, _ answer: String, acceptable: Bool, allowsAstrology: Bool = true) {
        self.name = name
        self.question = question
        self.answer = answer
        self.acceptable = acceptable
        self.allowsAstrology = allowsAstrology
    }
}

/// Checks that an answer addresses the question. Fluency alone does not pass.
private enum OracleAnswerRubric {
    static func problems(in answer: String, for question: String, allowsAstrology: Bool = true) -> [String] {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return ["The answer is empty."] }
        var problems: [String] = []
        let lower = text.lowercased()
        let asked = question.lowercased()

        if !OraclePrompt.asksAboutAnotherPersonsMind(question) {
            let mindReading = [
                "another person's thoughts",
                "another person's feelings",
                "cannot know another",
                "what you can control"
            ]
            if mindReading.contains(where: { lower.contains($0) }) {
                problems.append("The answer brings in a limit the question did not ask about.")
            }
        }

        if asksForAdvice(asked), !asksAbout(asked, topics: relationshipWords) {
            let generic = [
                "take care of yourself",
                "taking care of yourself",
                "those around you",
                "your relationships",
                "communication with others",
                "well-being",
                "wellbeing"
            ]
            if generic.contains(where: { lower.contains($0) }) {
                problems.append("The answer substitutes generic relationship or self-care advice.")
            }
        }

        if asksForAdvice(asked) {
            let first = firstSentence(text).lowercased()
            let hedges = ["you cannot know", "you can't know", "the stars are silent", "focus on what you can control", "it depends"]
            if hedges.contains(where: { first.contains($0) }) {
                problems.append("The first sentence avoids the question.")
            }
        }

        if !allowsAstrology {
            let astrology = ["your chart", "rising sign", "natal "]
            if astrology.contains(where: { lower.contains($0) }) {
                problems.append("The answer adds astrology the question did not need.")
            }
        }

        if !asksForAdvice(asked), !OraclePrompt.asksAboutAnotherPersonsMind(question), lower.contains("take care of yourself") {
            problems.append("The answer adds self-care the question did not ask for.")
        }

        return problems
    }

    private static func asksForAdvice(_ question: String) -> Bool {
        let markers = ["goal", "focus on", "should i", "what should", "how should", "how do i", "how can i", "why might", "best way"]
        return markers.contains { question.contains($0) }
    }

    private static func asksAbout(_ question: String, topics: [String]) -> Bool {
        topics.contains { question.contains($0) }
    }

    private static let relationshipWords = ["relationship", "partner", "love", "friend", "family", "boyfriend", "girlfriend", "wife", "husband", "dating"]

    private static func firstSentence(_ text: String) -> String {
        var sentence = ""
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { piece, _, _, stop in
            sentence = piece ?? ""
            stop = true
        }
        return sentence.isEmpty ? text : sentence
    }
}

/// A why-reply has to add the calculated factor. Copying the recommendation does not explain it.
private enum FollowUpCheck {
    static func repeats(_ answer: String, reading: DailyReading) -> Bool {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        return text == reading.focus || text == reading.synthesisText
    }

    static func explains(_ answer: String, reading: DailyReading) -> Bool {
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repeats(text, reading: reading), text.count > reading.focus.count else { return false }
        let lower = text.lowercased()
        return lower.contains("because") || text.contains(reading.ephemerisTitle)
    }

    static func invents(_ answer: String, reading: DailyReading) -> Bool {
        let allowed = (reading.ephemerisTitle + " " + reading.ephemerisText).lowercased()
        let planets = ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto"]
        return planets.contains { answer.lowercased().contains($0) && !allowed.contains($0) }
    }
}

/// A short reply that only restates Today's priority is the failure this suite exists to catch.
private enum DailyRepetition {
    static func substitutesPriority(_ answer: String, question: String, reading: DailyReading, history: [ChatMessage]) -> Bool {
        switch OraclePrompt.intent(of: question, history: history) {
        case .recommendation, .challenge, .otherDay, .reason(.priority), .action(.priority), .detail(.priority):
            return false
        default:
            break
        }
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text == reading.focus.lowercased() { return true }
        return text.count < 80 && text.contains("focus on work today")
    }
}

/// A reply contradicts Today when it treats the other side of the calculated lean as the priority.
private enum TodayAnswerCheck {
    static func contradicts(_ answer: String, reading: DailyReading) -> Bool {
        guard let bonds = reading.dials.first(where: { $0.id == "bonds" }), bonds.value != 50 else { return false }
        let lower = answer.lowercased()
        let work = ["work", "task", "career", "job", "finish"]
        let relationships = ["relationship", "relationships", "partner", "someone close", "love"]
        let mentionsWork = work.contains { lower.contains($0) }
        let mentionsRelationships = relationships.contains { lower.contains($0) }
        if bonds.value > 50 {
            return mentionsRelationships && !mentionsWork
        }
        return mentionsWork && !mentionsRelationships
    }
}
