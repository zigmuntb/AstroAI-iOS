//
//  StorageManager.swift
//  AstroAI
//

import Foundation

enum StorageKey: String {
    case userProfile
    case preferences
    case connections
    case journal
    case oracleMemory
    case oracleQuota
    /// Id of the on-device fallback model, once its weights are on this phone.
    case localOracleModel
}

protocol StorageManaging {
    func load<T: Decodable>(_ type: T.Type, for key: StorageKey) -> T?
    func save<T: Encodable>(_ value: T, for key: StorageKey)
    func remove(_ key: StorageKey)
    func removeAll()
}

/// Local persistence for small Codable values.
final class StorageManager: StorageManaging {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load<T: Decodable>(_ type: T.Type, for key: StorageKey) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, for key: StorageKey) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }

    func remove(_ key: StorageKey) {
        defaults.removeObject(forKey: key.rawValue)
    }

    func removeAll() {
        [StorageKey.userProfile, .preferences, .connections, .journal, .oracleMemory, .oracleQuota].forEach(remove)
    }
}
