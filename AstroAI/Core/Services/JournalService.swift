//
//  JournalService.swift
//  AstroAI
//

import Foundation

protocol JournalServicing {
    var prompt: JournalPrompt { get }

    func entries() -> [JournalEntry]
    func add(_ entry: JournalEntry)
}

struct JournalPrompt: Hashable {
    let context: String
    let question: String
    let note: String
}

/// Personal journal stored on device. Will sync to Supabase later.
final class JournalService: JournalServicing {
    private let storage: StorageManaging
    private let astrology: AstrologyServicing
    private let userService: UserServicing

    init(storage: StorageManaging, astrology: AstrologyServicing, userService: UserServicing) {
        self.storage = storage
        self.astrology = astrology
        self.userService = userService
    }

    var prompt: JournalPrompt { astrology.journalPrompt(for: userService.profile) }

    func entries() -> [JournalEntry] {
        (storage.load([JournalEntry].self, for: .journal) ?? []).sorted { $0.date > $1.date }
    }

    func add(_ entry: JournalEntry) {
        let saved = storage.load([JournalEntry].self, for: .journal) ?? []
        storage.save(saved + [entry], for: .journal)
    }
}
