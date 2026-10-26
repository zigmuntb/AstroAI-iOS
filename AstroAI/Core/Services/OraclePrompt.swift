//
//  OraclePrompt.swift
//  AstroAI
//

import Foundation

/// Chart, sky and life context turned into instructions for an Oracle model.
enum OraclePrompt {
    /// How many recent messages are repeated when a session has to be rebuilt.
    static let carriedOverMessages = 4
    /// Shown when the on-device model refuses a message. Not a daily recommendation.
    static let unavailableReply = "I can't answer that. Try asking about a decision, a plan, or your chart in a more specific way."

    /// The text shown in chat. Model output is kept; it is never replaced with Today's recommendation.
    static func deliver(_ generated: String) -> String {
        generated.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// People whose synastry goes straight into the instructions.
    private static let closePeopleCount = 3
    /// Keeps a rebuilt session from being drowned by an earlier long reply.
    private static let recapCharacterLimit = 360

    /// The two on-device models share one answer policy and differ in how it is delivered.
    enum Model {
        /// Apple Intelligence. Follows a system prompt and can call tools.
        case appleIntelligence
        /// Qwen, running locally. A short reminder has to sit next to the question.
        case qwen

        var offersTools: Bool { self == .appleIntelligence }
    }

    struct Prepared {
        let instructions: String
        let toolbox: OracleToolbox
        let profile: UserProfile?
        let connections: [Connection]
        let date: Date
        let options: ChartOptions
        let reading: DailyReading
        let guidanceID: String
    }

    /// Chart, sky, and the Today reading, calculated once so the chat and Today cannot diverge.
    struct SkyFacts {
        let chart: NatalChart?
        let sky: SkySnapshot
        let reading: DailyReading

        var guidanceID: String { OraclePrompt.guidanceID(for: reading) }
    }

    /// Same reading `AstrologyService.dailyReading` builds for the Today screen.
    /// `at` is `.now` for today. Another civil day is passed as noon so the Moon matches that calendar day.
    static func skyFacts(profile: UserProfile?, astrology: AstrologyServicing, at date: Date = .now) async -> SkyFacts {
        var chart: NatalChart?
        if let birth = profile?.birth {
            chart = try? await astrology.natalChart(for: birth)
        }
        let sky = astrology.sky(at: date, natal: chart)
        return SkyFacts(
            chart: chart,
            sky: sky,
            reading: DailyReadingBuilder.reading(profile: profile, chart: chart, sky: sky)
        )
    }

    /// Tomorrow or yesterday, when the question asks for that day. Nil for a question about today.
    static func otherDay(
        in question: String,
        profile: UserProfile?,
        astrology: AstrologyServicing,
        today: Date,
        calendar: Calendar = .current
    ) async -> (label: String, reading: DailyReading)? {
        guard let target = targetDate(in: question, today: today, calendar: calendar) else { return nil }
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: target) ?? target
        let facts = await skyFacts(profile: profile, astrology: astrology, at: noon)
        let label: String
        if calendar.isDateInTomorrow(target) {
            label = "Tomorrow"
        } else if calendar.isDateInYesterday(target) {
            label = "Yesterday"
        } else {
            label = OracleDates.long(target, calendar: calendar)
        }
        return (label, facts.reading)
    }

    static func targetDate(in question: String, today: Date, calendar: Calendar = .current) -> Date? {
        let text = normalized(question)
        let start = calendar.startOfDay(for: today)
        if text.contains("tomorrow") { return calendar.date(byAdding: .day, value: 1, to: start) }
        if text.contains("yesterday") { return calendar.date(byAdding: .day, value: -1, to: start) }
        return nil
    }

    /// Changes when the date changes or Today's recommendation changes, so a session is not reused with yesterday's priority.
    static func guidanceID(for reading: DailyReading) -> String {
        let bonds = reading.dials.first { $0.id == "bonds" }?.value ?? -1
        let day = Calendar.current.startOfDay(for: reading.date).timeIntervalSinceReferenceDate
        return "\(day)|\(bonds)|\(reading.focus)|\(reading.caution)"
    }

    static func make(
        userService: UserServicing,
        astrology: AstrologyServicing,
        connections: ConnectionsServicing,
        journal: JournalServicing,
        memory: OracleMemoryStoring,
        history: [ChatMessage],
        model: Model,
        facts: SkyFacts
    ) async -> Prepared {
        let profile = userService.profile
        let people = connections.connections()
        let toolbox = OracleToolbox(journal: journal, connections: connections, astrology: astrology, natal: facts.chart)
        var peopleNotes: [String] = []
        for person in people.prefix(closePeopleCount) {
            peopleNotes.append(await toolbox.personChart(person))
        }
        let context = OracleContext(
            profile: profile,
            chart: facts.chart,
            sky: facts.sky,
            connections: people,
            peopleNotes: peopleNotes,
            memory: memory.entries(),
            hasJournal: !journal.entries().isEmpty,
            date: facts.sky.date,
            reading: facts.reading
        )
        return Prepared(
            instructions: instructions(context: context, history: history, model: model),
            toolbox: toolbox,
            profile: profile,
            connections: people,
            date: facts.sky.date,
            options: astrology.chartOptions,
            reading: facts.reading,
            guidanceID: facts.guidanceID
        )
    }

    /// Drops the question being asked and the opening greeting, then keeps the latest turns.
    static func priorTurns(from history: [ChatMessage], question: String) -> [ChatMessage] {
        var turns = history
        if let last = turns.last, last.role == .user, last.text == question {
            turns.removeLast()
        }
        guard let firstUser = turns.firstIndex(where: { $0.role == .user }) else { return [] }
        return Array(turns[firstUser...].suffix(carriedOverMessages))
    }

    /// What the model receives as the user message.
    ///
    /// Apple Intelligence gets the question itself. A limit or a calculated fact is added only when
    /// that question needs it, so an unrelated question never sees Today's recommendation.
    /// Qwen also gets a one-line reminder after the question, because the small model
    /// follows the text nearest the reply more reliably than a long system prompt.
    /// Which part of life a question is about. `.priority` is the day's overall recommendation.
    enum Subject: Equatable {
        case priority
        case work
        case relationships
        case family
        case communication
        case mood
    }

    enum ReplyIntent: Equatable {
        case recommendation
        case topic(Subject)
        case reason(Subject?)
        case detail(Subject?)
        case action(Subject?)
        case otherDay
        case birthFact
        case challenge
        case redirect
        case general
    }

    static func turn(
        _ question: String,
        model: Model,
        reading: DailyReading? = nil,
        otherDay: (label: String, reading: DailyReading)? = nil,
        profile: UserProfile? = nil,
        now: Date = .now,
        history: [ChatMessage] = []
    ) -> String {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let intent = intent(of: question, history: history, now: now)
        var lines: [String] = []
        switch intent {
        case .birthFact:
            lines.append(birthAnchor(profile: profile, now: now))
        case .otherDay:
            lines.append(otherDayAnchor(otherDay))
        case .reason(let subject):
            lines.append(reasonAnchor(reading, subject: subject, history: history, question: question))
        case .detail(let subject):
            lines.append(detailAnchor(reading, subject: subject, history: history, question: question))
        case .action(let subject):
            lines.append(actionAnchor(reading, subject: subject, history: history, question: question))
        case .recommendation:
            if let reading { lines.append(recommendationAnchor(reading)) }
        case .challenge:
            if let reading { lines.append(challengeAnchor(reading)) }
        case .redirect:
            lines.append("They are leaving the previous subject. Ask what they want to talk about now. Do not answer the old question and do not give today's priority.")
        case .topic(let subject):
            lines.append(topicTurn(subject, question: question, reading: reading, otherDay: otherDay, now: now))
            if shiftsWithinConversation(question), let earlier = exchangeLine(in: history, excluding: question) {
                lines.append("They moved on from an earlier message. \(earlier) Answer the new question. Use that earlier concern only where it still applies. Do not repeat today's priority.")
            }
        case .general:
            break
        }
        if asksAboutAnotherPersonsMind(question) {
            lines.append("You cannot know that other person's private thoughts, feelings, intentions, or fidelity. Say so in one short clause, then answer the rest of what they asked.")
        } else if asksForRegulatedAdvice(question) {
            lines.append("Do not diagnose, interpret the law, or tell them what to do with money. Say a professional should decide that part, then answer the rest.")
        }
        if let cue = modelCue(intent, model: model) {
            lines.append(cue)
        }
        lines.append(question)
        return lines.joined(separator: "\n\n")
    }

    /// What the latest message is asking for.
    /// A short follow-up uses the previous exchange. A message that names its own subject does not.
    static func intent(of question: String, history: [ChatMessage], now: Date = .now) -> ReplyIntent {
        if changesSubject(question) { return .redirect }
        if asksAboutBirth(question) { return .birthFact }
        if let topic = specificTopic(in: question), targetDate(in: question, today: now) != nil {
            return .topic(topic)
        }
        if targetDate(in: question, today: now) != nil { return .otherDay }
        if asksForDetail(question) {
            guard latestExchange(in: history, excluding: question) != nil else { return .general }
            return .detail(precedingSubject(in: history, excluding: question))
        }
        if asksWhy(question) {
            guard latestExchange(in: history, excluding: question) != nil else { return .general }
            return .reason(precedingSubject(in: history, excluding: question))
        }
        if isActionFollowUp(question) {
            guard latestExchange(in: history, excluding: question) != nil else { return .general }
            return .action(precedingSubject(in: history, excluding: question))
        }
        if disputesDailyPriority(question) { return .challenge }
        if asksForDailyPriority(question) { return .recommendation }
        if let topic = specificTopic(in: question) { return .topic(topic) }
        return .general
    }

    static func birthAnchor(profile: UserProfile?, now: Date, calendar: Calendar = .current) -> String {
        let current = OracleDates.iso(now, calendar: calendar)
        guard let birth = profile?.birth else {
            return "Stored birth date: none. Do not answer with the current date \(current)."
        }
        let stored = OracleDates.iso(birth.date, calendar: calendar)
        let long = OracleDates.long(birth.date, calendar: calendar)
        let age = OracleDates.age(born: birth.date, on: now, calendar: calendar)
        let years = age.map(String.init) ?? "unknown"
        return "Stored birth date: \(stored) (\(long)). Current date: \(current). These are different facts. Age on the current date: \(years). Answer with the stored birth date."
    }

    static func instructions(context: OracleContext, history: [ChatMessage], model: Model) -> String {
        let personal = context.profile?.personal
        let length = personal?.length?.instruction ?? "Use as many sentences as the question needs. A simple question gets one or two sentences."
        let tone = personal?.tone?.instruction ?? "Sound calm and plain."
        let grounding = model.offersTools
            ? context.toolRules
            : "You cannot look anything up. Use only the facts below and any dated guidance included with the question. Never invent placements, people, or transits. If they ask about a day that was not calculated, say that day's sky was not calculated."
        var text = """
            You are StellarSage's Oracle. Talk with the user in the language of their latest message, in plain words. Never answer by repeating their question.

            How to answer:
            The first sentence answers that question. When they ask what to do, name two or three specific actions. A follow-up adds something new and does not restate the previous reply. If you are unsure, say what is uncertain and still give the most useful answer.
            A reason comes after that sentence, and only when it helps. Add one practical next step when they asked for advice. Then stop.
            \(length) \(tone)
            Stay on their question for the whole reply. Use a fact below only when it changes the answer.
            A follow-up such as "Why?", "Can you explain?", or "Be more specific" expands the previous answer. A new subject replaces the previous one immediately. If they correct a misunderstanding, answer the corrected request.
            Today's guidance is attached to a message only when that message is about the day, a conversation, or someone in their life. The balance on that attachment is the same one Today shows. Do not invent the opposite lean. Leave the day, the chart, and their long-term goals out of an answer that is about something else.
            When they ask about another day, use that day's calculated guidance if it is included with the question.
            When they ask when they were born or how old they are, use the Birth date field. Never substitute the current date. If the birth date is not stored, say so.
            Life notes can make an answer more specific. They do not replace Today's guidance when the question is what to focus on today. For a longer-term goal, use Life notes, and ask one short question if a needed fact is missing.
            If they challenge today's primary recommendation, keep it unless they add a real constraint, such as a deadline or a plan already underway. If an earlier reply contradicted Today's guidance, correct it. Do not adopt their alternative just because they suggested it.
            If the message has no clear question, ask what they want to know.
            The chart and today's sky are an interpretation, not a fact about their future. Never invent a placement, transit, birth detail, or event. If birth time or birthplace is missing, do not state houses, a rising sign, or a natal Moon sign. Leave astrology out when it does not help.
            Do not promise an outcome. No poetry, headings, or lists.

            \(grounding)

            \(context.prompt)
            """
        let recap = priorTurns(from: history, question: "")
            .map { "\($0.role == .user ? "User" : "Oracle"): \(clip($0.text))" }
            .joined(separator: "\n")
        if !recap.isEmpty {
            text += "\n\nRecent conversation (use it only to resolve a follow-up such as \"that\" or \"the other one\"):\n\(recap)"
        }
        text += "\n\nAnswer only the user's latest message, in its language. Match the subject of that message: a person, a conversation, a feeling, a task, or a fact. Do not reuse the wording of an earlier reply. A short follow-up such as \"Why?\" explains the previous answer. Anything else is a new question."
        return text
    }

    /// Keeps the live transcript so a follow-up can continue the conversation.
    /// The previous reply is not copied into the new request.
    static func continuesConversation(_ question: String, history: [ChatMessage], now: Date = .now) -> Bool {
        latestExchange(in: history, excluding: question) != nil
    }

    // MARK: - Follow-ups

    /// The same lean the Today balance card shows. A task sentence must not override it.
    /// Nil when Today has no balance card, so an area question is not filled with a task line.
    private static func dayBalance(_ reading: DailyReading, day: String = "Today") -> String? {
        guard let bonds = reading.dials.first(where: { $0.id == "bonds" }) else { return nil }
        let score = "Score: \(100 - bonds.value) toward relationships, \(bonds.value) toward work."
        if bonds.value < 50 {
            return "\(day) shows the day leaning toward close people, not work. \(bonds.note) \(score) Do not tell them to focus on work."
        }
        if bonds.value > 50 {
            return "\(day) shows the day leaning toward the work in front of them, not toward relationships. \(bonds.note) \(score) Do not tell them to focus on close people instead."
        }
        return "\(day) shows an even balance between close people and work. \(bonds.note) \(score)"
    }

    /// Worth-doing copy is omitted when it contradicts the balance card.
    private static func worthDoing(_ reading: DailyReading) -> String? {
        guard !reading.focus.isEmpty else { return nil }
        guard let bonds = reading.dials.first(where: { $0.id == "bonds" }) else { return reading.focus }
        let lower = reading.focus.lowercased()
        let task = ["task", "work", "finish", "inbox"]
        let people = ["someone", "ask one", "quiet", "conversation"]
        let mentionsTask = task.contains { lower.contains($0) }
        let mentionsPeople = people.contains { lower.contains($0) }
        if bonds.value < 50, mentionsTask, !mentionsPeople { return nil }
        if bonds.value > 50, mentionsPeople, !mentionsTask { return nil }
        return reading.focus
    }

    private static func recommendationAnchor(_ reading: DailyReading) -> String {
        var text = dayBalance(reading) ?? "Today shows: \(reading.focus)."
        text += " The lean is the direction only. They asked what to actually do. Answer with two or three specific actions drawn from these lines, in their language: \(concreteDay(reading))."
        text += " Do not answer with only the lean. Do not invent the opposite priority."
        text += " Factor: \(reading.ephemerisTitle)."
        return text
    }

    /// Area lines that match the balance card, so "what should I do?" can name actions.
    private static func concreteDay(_ reading: DailyReading) -> String {
        let bonds = reading.dials.first { $0.id == "bonds" }?.value
        let titles: [String]
        if let bonds, bonds < 50 {
            titles = ["Love & relationships", "Friends & family", "Mood & energy"]
        } else if let bonds, bonds > 50 {
            titles = ["Work & goals", "Mood & energy"]
        } else {
            titles = ["Love & relationships", "Work & goals", "Friends & family", "Mood & energy"]
        }
        var lines = titles.compactMap { title -> String? in
            guard let area = reading.areas.first(where: { $0.title == title }), !area.text.isEmpty else { return nil }
            return "\(title): \(area.text)"
        }
        if let extra = worthDoing(reading) {
            lines.append("Worth doing: \(extra)")
        }
        if !reading.caution.isEmpty {
            lines.append("Be careful: \(reading.caution)")
        }
        if lines.isEmpty {
            let fallback = reading.focus.isEmpty ? "No specific action was calculated." : reading.focus
            lines.append(fallback)
        }
        return lines.joined(separator: " ")
    }

    private static func reasonAnchor(
        _ reading: DailyReading?,
        subject: Subject?,
        history: [ChatMessage],
        question: String
    ) -> String {
        let previous = exchangeLine(in: history, excluding: question)
        switch subject {
        case .priority:
            guard let reading else { return explainPrevious(previous) }
            let explained = dayBalance(reading) ?? "Recommendation being explained: \(reading.focus)."
            var text = "Explain why, in the first sentence. Do not repeat the recommendation as the whole answer. \(explained) Factor: \(reading.ephemerisTitle). Supporting interpretation: \(clip(reading.ephemerisText, limit: 480))"
            if let bonds = reading.dials.first(where: { $0.id == "bonds" }) {
                text += " Also: \(bonds.note)"
            }
            if let previous { text += " " + previous }
            text += " Do not invent a planet, transit, or birth fact that is not written here."
            return text
        case .work, .relationships, .family, .communication, .mood:
            guard let reading, let subject else { return explainPrevious(previous) }
            var text = "Explain why, in the first sentence. Explain the previous answer, which was about \(label(subject)). \(material(for: subject, reading: reading)) Do not repeat that answer as the whole reply, and do not switch to the day's overall priority."
            if let previous { text += " " + previous }
            text += " Do not invent a planet, transit, or birth fact that is not written here."
            return text
        case nil:
            return explainPrevious(previous)
        }
    }

    private static func detailAnchor(
        _ reading: DailyReading?,
        subject: Subject?,
        history: [ChatMessage],
        question: String
    ) -> String {
        let previous = exchangeLine(in: history, excluding: question)
        var text = "Add a concrete example or the next step. Do not repeat the previous answer unchanged, and do not switch to today's overall priority."
        if let subject, subject != .priority, let reading {
            text += " The previous answer was about \(label(subject)). \(material(for: subject, reading: reading))"
        }
        if let previous { text += " " + previous }
        return text
    }

    private static func explainPrevious(_ previous: String?) -> String {
        var text = "Explain why, in the first sentence. Explain the previous answer. Do not repeat it unchanged, and do not switch to today's priority."
        if let previous { text += " " + previous }
        text += " Do not invent a planet, transit, or birth fact that is not written here."
        return text
    }

    private static func actionAnchor(
        _ reading: DailyReading?,
        subject: Subject?,
        history: [ChatMessage],
        question: String
    ) -> String {
        let previous = exchangeLine(in: history, excluding: question)
        switch subject {
        case .priority:
            guard let reading else { return stepsForPrevious(previous) }
            let basis = worthDoing(reading) ?? concreteDay(reading)
            var text = "Give practical steps for carrying this out: \(basis)."
            text += " They already heard the direction. Name two or three specific actions from these lines, and do not stop at the lean: \(concreteDay(reading))"
            text += " Do not only repeat the recommendation."
            if let previous { text += " " + previous }
            return text
        case .work, .relationships, .family, .communication, .mood:
            guard let reading, let subject else { return stepsForPrevious(previous) }
            var text = "Give practical steps for the previous answer, which was about \(label(subject)). \(material(for: subject, reading: reading)) Do not only repeat the previous answer, and do not switch to the day's overall priority."
            if let previous { text += " " + previous }
            return text
        case nil:
            return stepsForPrevious(previous)
        }
    }

    private static func stepsForPrevious(_ previous: String?) -> String {
        var text = "Give practical steps for the previous answer. Do not only repeat it, and do not switch to today's overall priority."
        if let previous { text += " " + previous }
        return text
    }

    private static func topicTurn(
        _ subject: Subject,
        question: String,
        reading: DailyReading?,
        otherDay: (label: String, reading: DailyReading)?,
        now: Date
    ) -> String {
        if targetDate(in: question, today: now) != nil {
            guard let otherDay else {
                return "That day's sky was not calculated. Do not reuse today's recommendation or invent the sky."
            }
            return topicAnchor(subject, reading: otherDay.reading, day: otherDay.label)
        }
        guard let reading else {
            return "No daily guidance was calculated. Do not invent an area or a task."
        }
        let day = asksAboutToday(question) ? "Today" : "This"
        return topicAnchor(subject, reading: reading, day: day)
    }

    private static func topicAnchor(_ subject: Subject, reading: DailyReading, day: String) -> String {
        let guidance = material(for: subject, reading: reading)
        let balance = dayBalance(reading, day: day).map { $0 + " " } ?? ""
        switch subject {
        case .work:
            return "\(day) question about work, not a request to reassign the whole day. \(guidance) \(balance)Give one concrete priority or next step. If the balance is toward close people, keep the step small and say the day is still for people. If their assignment is unknown, say so and ask what the task is. Do not claim the day is for work when the balance says it is for people."
        case .relationships:
            return "\(day) question about someone close. \(guidance) \(balance)Answer about that person: why they might seem distant, or what would help. You cannot know their private thoughts. If they did not say who, ask. Do not replace this with a work recommendation."
        case .family:
            return "\(day) question about family. \(guidance) \(balance)Answer about their family. If you do not know who they mean, say so and ask. Do not replace this with a work recommendation."
        case .communication:
            return "\(day) question about whether to have an important conversation. \(guidance) \(balance)The first sentence answers the conversation: yes, no, or a qualified yes. Then one practical sentence about how to talk. Do not replace this with a work recommendation."
        case .mood:
            return "\(day) question about mood or energy. \(guidance) \(balance)Answer about mood or energy. Do not replace this with a work recommendation."
        case .priority:
            return recommendationAnchor(reading)
        }
    }

    private static func material(for subject: Subject, reading: DailyReading) -> String {
        switch subject {
        case .priority:
            return ""
        case .work:
            return areaLine(reading, title: "Work & goals", missing: "No separate work guidance was calculated. Do not invent a task.")
        case .relationships:
            return areaLine(reading, title: "Love & relationships", missing: "No separate relationship guidance was calculated. Do not invent a relationship fact.")
        case .family:
            return areaLine(reading, title: "Friends & family", missing: "No separate family guidance was calculated. Do not invent a family fact.")
        case .communication:
            var parts = [
                areaLine(reading, title: "Love & relationships", missing: "No relationship guidance was calculated.", includeDetail: true),
                areaLine(reading, title: "Mood & energy", missing: "No mood guidance was calculated.", includeDetail: false)
            ]
            if let friends = reading.areas.first(where: { $0.title == "Friends & family" }) {
                parts.append("Friends & family: \(friends.text)")
            }
            parts.append("Do not invent a timing rule that is not written here.")
            return parts.joined(separator: " ")
        case .mood:
            return areaLine(reading, title: "Mood & energy", missing: "No mood guidance was calculated.")
        }
    }

    private static func areaLine(_ reading: DailyReading, title: String, missing: String, includeDetail: Bool = true) -> String {
        guard let area = reading.areas.first(where: { $0.title == title }) else { return missing }
        var text = "\(title): \(area.text)"
        if includeDetail, let detail = area.detail, !detail.isEmpty {
            text += " " + clip(detail, limit: 220)
        }
        return text
    }

    private static func label(_ subject: Subject) -> String {
        switch subject {
        case .priority: "today's priority"
        case .work: "work"
        case .relationships: "relationships"
        case .family: "family"
        case .communication: "an important conversation"
        case .mood: "mood and energy"
        }
    }

    private static func challengeAnchor(_ reading: DailyReading) -> String {
        var text = dayBalance(reading) ?? "Today shows: \(reading.focus)."
        if let extra = worthDoing(reading) {
            text += " \(extra)"
        }
        text += " Do not replace it because the user disagrees. If an earlier reply contradicted it, correct that reply."
        return text
    }

    private static func otherDayAnchor(_ otherDay: (label: String, reading: DailyReading)?) -> String {
        guard let otherDay else {
            return "That day's sky was not calculated. Do not reuse today's recommendation or invent the sky."
        }
        let balance = dayBalance(otherDay.reading, day: otherDay.label) ?? "\(otherDay.label) shows: \(otherDay.reading.focus)."
        return "\(balance) Factor: \(otherDay.reading.ephemerisTitle). Use this day, not a different day's priority."
    }

    private static func modelCue(_ intent: ReplyIntent, model: Model) -> String? {
        guard model == .qwen else { return nil }
        switch intent {
        case .reason(let subject):
            if subject == .priority {
                return "Explain why in the first sentence, using the factors above. Do not only repeat the previous answer."
            }
            return "Explain why in the first sentence. Do not only repeat the previous answer, and do not switch to today's priority."
        case .detail:
            return "Add a concrete detail in the first sentence. Do not repeat the previous answer unchanged, and do not switch to today's priority."
        case .redirect:
            return "Ask what they want to talk about. Do not give today's priority."
        case .action:
            return "Give the practical steps in the first sentence. Do not only repeat the previous answer."
        case .birthFact:
            return "Answer with the stored birth date in the first sentence. Do not use the current date."
        case .otherDay:
            return "Answer about that other day in the first sentence. Do not reuse today's recommendation."
        case .recommendation:
            return "Name specific actions from the lines above. The lean is only the direction."
        case .challenge:
            return "Keep today's direction, then say what that means in practice."
        case .topic:
            return "Answer this question from the lines above. Follow which way the day leans."
        case .general:
            return "Write the answer in their language."
        }
    }

    private static func asksAboutBirth(_ question: String) -> Bool {
        let text = normalized(question)
        let markers = ["born", "birthday", "birth date", "birthdate", "date of birth", "how old", "my age", "what age"]
        return markers.contains { text.contains($0) }
    }

    private static func asksWhy(_ question: String) -> Bool {
        let text = normalized(question)
        let strong = [
            "why do you", "why did you", "how did you", "how come", "how does this relate",
            "what is the reason", "whats the reason"
        ]
        let tokens = words(in: question)
        let russianWhy: Set<String> = ["почему", "зачем", "объясни", "поясни", "это", "так", "же"]
        if tokens.count <= 3, Set(tokens).isSubset(of: russianWhy), tokens.contains(where: { ["почему", "зачем", "объясни", "поясни"].contains($0) }) {
            return true
        }
        if strong.contains(where: { text.contains($0) }) { return true }
        let soft = ["what makes", "can you explain", "explain", "what do you mean"]
        if soft.contains(where: { text.contains($0) }), !introducesOwnRequest(question) { return true }
        let followUp = Set(["why", "so", "then", "exactly", "though", "that", "this", "do", "you", "think", "is", "it", "come", "again", "really", "and", "can"])
        return tokens.contains("why") && tokens.allSatisfy { followUp.contains($0) }
    }

    /// A request to expand the previous answer, not a new question that happens to contain "specific".
    private static func asksForDetail(_ question: String) -> Bool {
        let text = normalized(question)
        if words(in: question).count <= 4, ["подробнее", "конкретнее", "детальнее"].contains(where: { text.contains($0) }) {
            return true
        }
        let phrases = [
            "more specific", "be specific", "go deeper", "tell me more", "in more detail",
            "elaborate", "for example", "what about that", "what about this", "what about it"
        ]
        guard phrases.contains(where: { text.contains($0) }) else { return false }
        return !introducesOwnRequest(question)
    }

    /// The user is dropping the current subject. This is not a follow-up to Today's recommendation.
    private static func changesSubject(_ question: String) -> Bool {
        let text = normalized(question)
        let markers = [
            "completely different", "something else", "forget that",
            "never mind", "nevermind", "different question", "meant something else",
            "change the subject", "new topic", "start over"
        ]
        return markers.contains { text.contains($0) }
    }

    private static func shiftsWithinConversation(_ question: String) -> Bool {
        let text = normalized(question)
        return text.contains("what about") || text.contains("how about")
    }

    /// A short request for steps about the previous answer.
    /// "How do I cook dinner?" names its own task and is not a follow-up.
    private static func isActionFollowUp(_ question: String) -> Bool {
        if specificTopic(in: question) != nil || asksForDailyPriority(question) { return false }
        let text = normalized(question)
        let russianSteps = ["что делать", "что мне делать", "как быть", "как мне быть", "что дальше"]
        if russianSteps.contains(where: { text.contains($0) }), words(in: question).count <= 6 { return true }
        let asksForSteps = [
            "what exactly can", "what can i do", "what could i do", "what do i do",
            "что именно", "что я могу", "что можно сделать", "что мне можно",
            "как именно", "какие шаги"
        ]
        if asksForSteps.contains(where: { text.contains($0) }) { return true }
        if text.contains("doesnt work") || text.contains("does not work") {
            return words(in: question).count <= 8
        }
        let phrases = [
            "how should i", "how do i do", "how would i", "how can i do", "what should i do",
            "how to act", "act on", "next step", "what do i do"
        ]
        if phrases.contains(where: { text.contains($0) }) {
            return !introducesOwnRequest(question)
        }
        let tokens = words(in: question)
        let followUp = Set(["how", "so", "then", "exactly", "though", "that", "this", "again"])
        return tokens.first == "how" && tokens.allSatisfy { followUp.contains($0) }
    }

    /// True when the message names a subject of its own, beyond a follow-up such as "that" or "why".
    private static func introducesOwnRequest(_ question: String) -> Bool {
        let ignored = scaffoldWords.union(anaphoraWords)
        return words(in: question).contains { !ignored.contains($0) }
    }

    private static let scaffoldWords: Set<String> = [
        "a", "an", "the", "i", "you", "we", "me", "my", "your", "our", "it", "its", "that", "this",
        "how", "do", "does", "did", "should", "can", "could", "would", "will", "what", "why", "when",
        "where", "who", "to", "be", "more", "specific", "exactly", "explain", "explained", "mean", "means",
        "again", "so", "then", "and", "or", "if", "not", "dont", "is", "are", "was", "were", "act", "on",
        "next", "step", "steps", "come", "really", "just", "please", "about", "of", "for", "with", "in",
        "though", "think", "make", "makes", "am", "im", "ok", "okay", "yes", "no", "now", "tell", "give",
        "want", "ask", "something", "anything", "else", "different", "completely", "actually"
    ]

    private static let anaphoraWords: Set<String> = [
        "today", "tonight", "good", "recommendation", "recommend", "recommended", "focusing", "focus",
        "priority", "conclusion", "relate", "chart", "reason", "answer", "said", "meant"
    ]

    private static func words(in question: String) -> [String] {
        question.split { !$0.isLetter }.map { $0.lowercased() }
    }

    // MARK: - Today

    private static func asksAboutToday(_ question: String) -> Bool {
        let text = normalized(question)
        let markers = ["today", "tonight", "this morning", "this afternoon", "this evening", "right now", "сегодня", "сегодняшн"]
        return markers.contains { text.contains($0) }
    }

    /// The day's overall priority, as opposed to a question about one part of life.
    private static func asksForDailyPriority(_ question: String) -> Bool {
        let text = normalized(question)
        if asksWhichSide(question) && (asksAboutToday(question) || text.contains("focus") || text.contains("priorit")) {
            return true
        }
        if specificTopic(in: question) != nil || !asksAboutToday(question) { return false }
        if text.contains("focus") || text.contains("priorit") || asksWhatToDo(text) { return true }
        // "What should I do today?" is the daily question. "What should I cook today?" is not.
        if text.contains("what should i do") || text.contains("what should i") {
            return !introducesOwnRequest(question)
        }
        return false
    }

    private static func asksWhatToDo(_ text: String) -> Bool {
        let markers = [
            "worth doing", "what matters", "what to do", "what can i do",
            "сосредоточ", "приоритет", "чем заняться", "на чем", "на чём",
            "что сделать", "что мне сделать", "что лучше сделать", "лучше сегодня",
            "сегодня сделать", "что можно сделать", "чем мне заняться",
            "что именно лучше", "что именно сегодня", "подскажи что",
            "что сегодня делать", "что мне делать"
        ]
        return markers.contains { text.contains($0) }
    }

    private static func asksWhichSide(_ question: String) -> Bool {
        let text = normalized(question)
        let work = text.contains("work") || text.contains("career") || text.contains("job")
        let people = text.contains("relationship")
        return work && people
    }

    private static func specificTopic(in question: String) -> Subject? {
        let text = normalized(question)
        let communication = ["talk", "conversation", "discuss", "say something", "tell them", "bring it up", "поговор", "разговор", "обсуд", "бесед"]
        if communication.contains(where: { text.contains($0) }) { return .communication }
        if text.contains("семь") || text.contains("семей") { return .family }
        let family = ["family", "parent", "parents", "mom", "dad", "mother", "father", "kids", "children", "brother", "sister", "relatives", "household", "родител", "мама", "папа"]
        if family.contains(where: { containsWord(text, $0) || (text.contains($0) && $0.count > 4) }) { return .family }
        let relationships = ["relationship", "partner", "dating", "romance", "близк", "отстранен", "отдал", "отношен", "партнер"]
        if relationships.contains(where: { text.contains($0) }) { return .relationships }
        let mood = ["mood", "my energy", "how do i feel", "how will i feel"]
        if mood.contains(where: { text.contains($0) }) { return .mood }
        let work = ["at work", "my work", "my job", "career", "the office", "my boss", "a task", "the task"]
        if work.contains(where: { text.contains($0) }) { return .work }
        if containsWord(text, "work"), !text.contains("doesnt work"), !text.contains("does not work") { return .work }
        return nil
    }

    /// The user is pushing back on today's priority, not opening a new topic.
    private static func disputesDailyPriority(_ question: String) -> Bool {
        let text = normalized(question)
        let hard = ["disagree", "are you sure", "thats wrong", "that is wrong", "shouldnt", "should not", "you said", "it says", "instead"]
        let rejects = hard.contains { text.contains($0) } || text.contains("i think")
        guard rejects else { return false }
        if let topic = specificTopic(in: question), topic == .communication || topic == .mood || topic == .family { return false }
        if specificTopic(in: question) == .work {
            let correcting = ["it says", "you said", "disagree", "instead", "thats wrong", "that is wrong", "shouldnt", "should not"]
            return correcting.contains { text.contains($0) }
        }
        return asksAboutToday(question) || text.contains("focus") || text.contains("priority") || asksWhichSide(question) || specificTopic(in: question) == .relationships
    }

    /// The last substantive user question, skipping "Why?", "Be more specific", and "How should I act on that?"
    private static func precedingSubject(in history: [ChatMessage], excluding question: String = "") -> Subject? {
        var turns = history
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let last = turns.last, last.role == .user, last.text == trimmed {
            turns.removeLast()
        }
        for message in turns.reversed() where message.role == .user {
            if asksWhy(message.text) || asksForDetail(message.text) || isActionFollowUp(message.text) || changesSubject(message.text) {
                continue
            }
            if asksForDailyPriority(message.text) { return .priority }
            if let topic = specificTopic(in: message.text) { return topic }
            return nil
        }
        return nil
    }

    private static func latestExchange(in history: [ChatMessage], excluding question: String) -> (question: String, answer: String)? {
        var turns = history
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let last = turns.last, last.role == .user, last.text == trimmed {
            turns.removeLast()
        }
        var answer: String?
        for message in turns.reversed() {
            switch message.role {
            case .oracle where answer == nil:
                answer = message.text
            case .user where answer != nil:
                return (message.text, answer ?? "")
            default:
                continue
            }
        }
        return nil
    }

    private static func exchangeLine(in history: [ChatMessage], excluding question: String) -> String? {
        guard let exchange = latestExchange(in: history, excluding: question) else { return nil }
        var text = "Previous question: \(clip(exchange.question, limit: 180))."
        if !exchange.answer.isEmpty {
            text += " Previous answer: \(clip(exchange.answer))."
        }
        return text
    }

    // MARK: - Question-specific limits

    /// True only when the user is asking for someone else's private mind.
    /// Mentioning another person while asking for advice does not qualify.
    static func asksAboutAnotherPersonsMind(_ question: String) -> Bool {
        let text = normalized(question)
        let fidelity = ["cheating", "having an affair", "is he faithful", "is she faithful", "are they faithful", "is he loyal", "is she loyal"]
        if fidelity.contains(where: { text.contains($0) }) { return true }
        let patterns = [
            "does he think", "does she think", "do they think",
            "does he feel", "does she feel", "do they feel",
            "does he want", "does she want", "do they want",
            "does he love", "does she love", "do they love",
            "does he like", "does she like",
            "what is he thinking", "what is she thinking", "what are they thinking",
            "what does he think", "what does she think", "what do they think",
            "what does he feel", "what does she feel", "what do they feel",
            "what does he want", "what does she want", "what do they want",
            "how does he feel", "how does she feel", "how do they feel",
            "is he mad", "is she mad", "are they mad",
            "what is on his mind", "what is on her mind", "what is on their mind"
        ]
        return patterns.contains(where: { text.contains($0) })
    }

    /// True when the question asks for a diagnosis, a legal conclusion, or a money instruction.
    static func asksForRegulatedAdvice(_ question: String) -> Bool {
        let text = normalized(question)
        let words = Set(text.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        let exact: Set<String> = [
            "invest", "investing", "investment", "investments", "stocks", "stock", "crypto",
            "mortgage", "lawsuit", "medication", "dosage"
        ]
        if !words.isDisjoint(with: exact) { return true }
        if words.contains(where: { $0.hasPrefix("diagnos") || $0.hasPrefix("prescri") }) { return true }
        let phrases = ["is it legal", "what does the law", "tax advice", "my savings", "which stock", "sue "]
        return phrases.contains { text.contains($0) }
    }

    private static func normalized(_ question: String) -> String {
        " " + question.lowercased()
            .replacingOccurrences(of: "?", with: " ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
    }

    private static func containsWord(_ text: String, _ word: String) -> Bool {
        let padded = text.hasSuffix(" ") ? text : text + " "
        return padded.contains(" \(word) ")
    }

    private static func clip(_ text: String, limit: Int = recapCharacterLimit) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard flat.count > limit else { return flat }
        let end = flat.index(flat.startIndex, offsetBy: limit)
        let trimmed = flat[..<end]
        guard let space = trimmed.lastIndex(of: " "), space > trimmed.startIndex else {
            return trimmed + "…"
        }
        return trimmed[..<space] + "…"
    }
}
