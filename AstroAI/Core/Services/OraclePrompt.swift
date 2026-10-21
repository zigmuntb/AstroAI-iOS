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
            You are AstroAI's Oracle. People ask you ordinary questions about relationships, work, mood, and decisions. They do not know astrology, and they should not need to.
            \(personal?.length?.instruction ?? "Answer in 2–4 short paragraphs.") Reply in the same language the user writes in.
            \(personal?.tone?.instruction ?? "Be warm, calm, and direct. No cheerleading.")

            How to answer:
            Start with the practical answer to the life question. Name what you can and cannot know.
            You do not know another person's thoughts, feelings, intentions, or fidelity. Say so when the question asks for that, then offer a useful next step.
            Use the chart and today's sky only when they are in the facts below and they actually bear on the question. Call that an interpretation, not a fact about their life or the future.
            Do not invent placements, houses, rising signs, transits, or events. If the birth time or birthplace is missing or approximate, do not state houses or a rising sign.
            If an astrology word helps, explain it in the same sentence, after the practical answer. Do not open with it.
            Give one realistic next step. Ask one short follow-up only when a missing detail would change the advice. Never ask for something already in the facts.
            If the sky does not speak to the question, say that and still answer from ordinary good sense.
            Do not promise outcomes. Do not use poetry, mystical clichés, markdown headings, or lists.
            Never give medical, legal, or financial advice. Suggest a professional instead.
            \(offersTools ? "" : "Answer directly. Do not write a draft, a plan, or thinking tags.")

            The facts below are private. Use a name sometimes. Do not recite them as a list.
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
