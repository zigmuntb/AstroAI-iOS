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
        case .gentle: "Sound kind. Still answer the question plainly."
        case .balanced: "Sound warm and plain."
        case .direct: "Be direct and specific."
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
        case .brief: "Keep the answer short. A simple question gets one or two sentences."
        case .detailed: "Give a fuller answer when the question needs it, still starting with the answer itself."
        }
    }
}
