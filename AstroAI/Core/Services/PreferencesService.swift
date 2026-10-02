//
//  PreferencesService.swift
//  AstroAI
//

import Foundation

protocol PreferencesServicing {
    func load() -> Preferences
    func save(_ preferences: Preferences)
}

final class PreferencesService: PreferencesServicing {
    private let storage: StorageManaging

    init(storage: StorageManaging) {
        self.storage = storage
    }

    func load() -> Preferences {
        storage.load(Preferences.self, for: .preferences) ?? Preferences()
    }

    func save(_ preferences: Preferences) {
        storage.save(preferences, for: .preferences)
    }
}
