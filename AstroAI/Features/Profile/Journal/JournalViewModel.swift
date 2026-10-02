//
//  JournalViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class JournalViewModel {
    enum Filter: Hashable, Identifiable {
        case all
        case kind(JournalEntry.Kind)

        var id: String {
            switch self {
            case .all: "all"
            case .kind(let kind): kind.rawValue
            }
        }
    }

    var searchText = ""
    var selectedFilter: Filter = .all
    var draft = ""

    private(set) var entries: [JournalEntry] = []
    private(set) var prompt: JournalPrompt

    let filters: [Filter] = [.all] + JournalEntry.Kind.allCases.map(Filter.kind)
    let promptBadge = "9th House Ingress"

    var visibleEntries: [JournalEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { entry in
            if case .kind(let kind) = selectedFilter, entry.kind != kind { return false }
            guard !query.isEmpty else { return true }
            return ([entry.context, entry.quote, entry.body] + entry.tags)
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    let seasonTitle = "Scorpio Season · 2024"

    @ObservationIgnored private let journal: JournalServicing
    @ObservationIgnored private weak var router: MainRouting?

    init(journal: JournalServicing, router: MainRouting) {
        self.journal = journal
        self.router = router
        prompt = journal.prompt
        reload()
    }

    func title(for filter: Filter) -> String {
        switch filter {
        case .all: "All Entries (\(entries.count))"
        case .kind(let kind): kind.filterTitle
        }
    }

    func select(_ filter: Filter) {
        selectedFilter = filter
    }

    func reload() {
        prompt = journal.prompt
        entries = journal.entries()
    }

    func submitReflection() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        journal.add(JournalEntry(
            date: .now,
            kind: .reflection,
            context: prompt.context,
            quote: text,
            body: "",
            tags: ["Private Reflection"]
        ))
        draft = ""
        reload()
    }
}
