//
//  DeckSortOption.swift
//  Keyoku
//

import Foundation

enum DeckSortOption: String, CaseIterable {
    case recentlyStudied = "recently_studied"
    case alphabetical = "alphabetical"
    case mostDue = "most_due"
    case mostCards = "most_cards"

    var title: String {
        switch self {
        case .recentlyStudied: return "Recently Studied"
        case .alphabetical:    return "Alphabetical"
        case .mostDue:         return "Most Due"
        case .mostCards:       return "Most Cards"
        }
    }
}
