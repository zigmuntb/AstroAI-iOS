//
//  TarotCardStore.swift
//  AstroAI
//

import Foundation

enum TarotCardStoreError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unreadable: "This picture couldn't be saved."
        }
    }
}

/// The drawn tarot card lives in Documents so it is still on Today after a relaunch.
enum TarotCardStore {
    static let descriptionLimit = 180

    private static let descriptionKey = "tarotCardDescription"

    private static var imageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tarot-card.data")
    }

    static func load() -> (data: Data, description: String)? {
        guard let data = try? Data(contentsOf: imageURL), !data.isEmpty else { return nil }
        return (data, UserDefaults.standard.string(forKey: descriptionKey) ?? "")
    }

    static func save(_ data: Data, description: String) throws {
        try data.write(to: imageURL, options: .atomic)
        UserDefaults.standard.set(description, forKey: descriptionKey)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: imageURL)
        UserDefaults.standard.removeObject(forKey: descriptionKey)
    }
}
