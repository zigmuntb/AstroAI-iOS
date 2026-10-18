//
//  OraclePrompt.swift
//  AstroAI
//

import Foundation

/// Chart, sky and life context turned into instructions for an Oracle model.
enum OraclePrompt {
    /// How many recent messages are repeated when a session has to be rebuilt.
    static let carriedOverMessages = 4
    /// People whose synastry goes straight into the instructions.
    private static let closePeopleCount = 3

    struct Prepared {
        let instructions: String
        let toolbox: OracleToolbox
        let profile: UserProfile?
        let connections: [Connection]
        let date: Date
        let options: ChartOptions
    }

    static func make(
        userService: UserServicing,
        astrology: AstrologyServicing,
        connections: ConnectionsServicing,
        journal: JournalServicing,
        memory: OracleMemoryStoring,
        history: [ChatMessage],
        offersTools: Bool
    ) async -> Prepared {
        let profile = userService.profile
        let people = connections.connections()
        var chart: NatalChart?
        if let birth = profile?.birth {
            chart = try? await astrology.natalChart(for: birth)
        }
        let now = Date.now
        let toolbox = OracleToolbox(journal: journal, connections: connections, astrology: astrology, natal: chart)
        var peopleNotes: [String] = []
        for person in people.prefix(closePeopleCount) {
            peopleNotes.append(await toolbox.personChart(person))
        }
        let context = OracleContext(
            profile: profile,
            chart: chart,
            sky: astrology.sky(at: now, natal: chart),
            connections: people,
            peopleNotes: peopleNotes,
            memory: memory.entries(),
            hasJournal: !journal.entries().isEmpty,
            date: now
        )
        return Prepared(
            instructions: instructions(context: context, history: history, offersTools: offersTools),
            toolbox: toolbox,
            profile: profile,
            connections: people,
            date: now,
            options: astrology.chartOptions
        )
    }

    private static func instructions(context: OracleContext, history: [ChatMessage], offersTools: Bool) -> String {
        let personal = context.profile?.personal
        let grounding = offersTools
            ? context.toolRules
            : "You cannot look anything up. Use only the facts below, and never invent placements, people or transits. If they ask about a day other than today, say you can only read today's sky."
        var instructions = """
            You are the AstroAI Oracle. Explain astrology in plain, everyday language.
            Help the user understand their feelings, relationships, and choices.
            \(personal?.length?.instruction ?? "Answer in 2–4 short paragraphs.") Reply in the same language the user writes in.
            \(personal?.tone?.instruction ?? "Be warm and honest. Keep the words simple.")
            Use short sentences. Say what a placement or transit means in real life, then give one practical suggestion.
            If you use an astrology term, explain it in the same sentence.
            Do not use poetry, metaphors, rare words, or mystical language.
            Do not use markdown headings or lists.
            Never give medical, legal, or financial advice. Suggest a professional instead.
            \(offersTools ? "" : "Answer directly. Do not write a draft, a plan, or thinking tags.")

            The facts below are private context. Use a placement, today's sky, or their situation only when it answers the question.
            Use their name sometimes. Never recite this information back as a list.
            When they ask about today, use the transits below.
            \(grounding)

            \(context.prompt)
            """
        let recap = history
            .map { "\($0.role == .user ? "User" : "Oracle"): \($0.text)" }
            .joined(separator: "\n")
        if !recap.isEmpty {
            instructions += "\n\nRecent conversation:\n\(recap)"
        }
        return instructions
    }
}
