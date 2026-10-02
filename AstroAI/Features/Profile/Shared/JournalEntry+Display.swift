//
//  JournalEntry+Display.swift
//  AstroAI
//

import Foundation

extension JournalEntry.Kind {
    /// Title of the filter chip on the Journal screen.
    var filterTitle: String {
        switch self {
        case .reflection: "Transit Prompts"
        case .oracle: "AI Oracle Archives"
        case .bookmark: "Lunar Bookmarks"
        }
    }

    /// SF Symbol shown at the trailing edge of an entry card.
    var icon: String {
        switch self {
        case .reflection: "heart"
        case .oracle: "brain.head.profile"
        case .bookmark: "bookmark"
        }
    }
}

extension JournalEntry {
    var dayTitle: String { date.formatted(.dateTime.month(.abbreviated).day()) }
    var timeTitle: String { date.formatted(.dateTime.hour(.twoDigits(amPM: .abbreviated)).minute(.twoDigits)) }
}
