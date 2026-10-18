//
//  PersonalContext.swift
//  AstroAI
//

import Foundation

/// Optional life context the user shares so the Oracle can answer about their actual situation.
/// Every field is optional: the user can skip any question.
struct PersonalContext: Codable, Hashable {
    var relationship: RelationshipStatus?
    var lifeStage: LifeStage?
    var pronouns: Pronouns?
    /// Free text: what is happening in their life right now.
    var currentFocus: String?
    var tone: AnswerTone?
    var length: AnswerLength?

    static let focusMaxLength = 280

    var isEmpty: Bool {
        relationship == nil && lifeStage == nil && pronouns == nil
            && (currentFocus ?? "").isEmpty && tone == nil && length == nil
    }
}

enum RelationshipStatus: String, CaseIterable, Codable, Identifiable {
    case single, dating, committed, married, separated, complicated
    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: "Single"
        case .dating: "Dating"
        case .committed: "In a relationship"
        case .married: "Married"
        case .separated: "Recently separated"
        case .complicated: "It's complicated"
        }
    }
}

enum LifeStage: String, CaseIterable, Codable, Identifiable {
    case studying, buildingCareer, established, changingPath, parenting, slowingDown
    var id: String { rawValue }

    var title: String {
        switch self {
        case .studying: "Studying"
        case .buildingCareer: "Building a career"
        case .established: "Established in my work"
        case .changingPath: "Changing paths"
        case .parenting: "Raising a family"
        case .slowingDown: "Slowing down"
        }
    }
}

enum Pronouns: String, CaseIterable, Codable, Identifiable {
    case she, he, they
    var id: String { rawValue }

    var title: String {
        switch self {
        case .she: "She / her"
        case .he: "He / him"
        case .they: "They / them"
        }
    }
}

enum AnswerTone: String, CaseIterable, Codable, Identifiable {
    case gentle, balanced, direct
    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: "Gentle"
        case .balanced: "Balanced"
        case .direct: "Direct"
        }
    }

    /// Instruction for the Oracle model.
    var instruction: String {
        switch self {
        case .gentle: "Be kind and reassuring. Keep the words simple."
        case .balanced: "Be warm and honest. Keep the words simple."
        case .direct: "Be direct. Name hard patterns clearly, without dressing them up."
        }
    }
}

enum AnswerLength: String, CaseIterable, Codable, Identifiable {
    case brief, detailed
    var id: String { rawValue }

    var title: String {
        switch self {
        case .brief: "Brief"
        case .detailed: "In depth"
        }
    }

    var instruction: String {
        switch self {
        case .brief: "Answer in 1–2 short paragraphs, in plain language."
        case .detailed: "Answer in 3–5 short paragraphs. Explain the astrology in plain words, then say what it means for their life."
        }
    }
}
