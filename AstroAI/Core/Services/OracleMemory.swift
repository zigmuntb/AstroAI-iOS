//
//  OracleMemory.swift
//  AstroAI
//

import Foundation

/// What the user asked the Oracle before, kept across launches so the Oracle can refer back.
/// Only a question and the gist of the answer are stored to keep the prompt small.
struct OracleMemoryEntry: Codable, Hashable {
    let date: Date
    let question: String
    let gist: String
}

protocol OracleMemoryStoring {
    func entries() -> [OracleMemoryEntry]
    func record(question: String, answer: String)
}

final class OracleMemoryStore: OracleMemoryStoring {
    private let storage: StorageManaging
    private let capacity = 12
    private let questionLength = 160
    private let gistLength = 200

    init(storage: StorageManaging) {
        self.storage = storage
    }

    /// Oldest first.
    func entries() -> [OracleMemoryEntry] {
        storage.load([OracleMemoryEntry].self, for: .oracleMemory) ?? []
    }

    func record(question: String, answer: String) {
        let entry = OracleMemoryEntry(
            date: .now,
            question: Self.clip(question, to: questionLength),
            gist: Self.clip(Self.firstSentences(of: answer), to: gistLength)
        )
        storage.save(Array((entries() + [entry]).suffix(capacity)), for: .oracleMemory)
    }

    private static func firstSentences(of text: String) -> String {
        var result = ""
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, stop in
            guard let sentence else { return }
            result += sentence
            if result.count >= 80 { stop = true }
        }
        return result.isEmpty ? text : result
    }

    private static func clip(_ text: String, to length: Int) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard flat.count > length else { return flat }
        return String(flat.prefix(length - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
