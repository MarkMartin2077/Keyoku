//
//  DeckColor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

enum DeckColor: String, CaseIterable, Codable, Sendable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown

    // Curated palette — richer and more saturated than raw SwiftUI system colors,
    // ensuring white text is legible on all backgrounds in both light and dark mode.
    var color: Color {
        switch self {
        case .red:    return Color(hex: "#C94B45")  // Vermillion
        case .orange: return Color(hex: "#D87430")  // Amber
        case .yellow: return Color(hex: "#B08618")  // Gold
        case .green:  return Color(hex: "#2D8F5A")  // Emerald
        case .mint:   return Color(hex: "#26908B")  // Jade   (legacy — not shown in picker)
        case .teal:   return Color(hex: "#1B7B82")  // Ocean
        case .cyan:   return Color(hex: "#1D7BA8")  // Steel  (legacy — not shown in picker)
        case .blue:   return Color(hex: "#2558C5")  // Cobalt
        case .indigo: return Color(hex: "#4C42A0")  // Violet (legacy — not shown in picker)
        case .purple: return Color(hex: "#7934C2")  // Grape
        case .pink:   return Color(hex: "#BF3C7E")  // Rose
        case .brown:  return Color(hex: "#7A5038")  // Mahogany (legacy — not shown in picker)
        }
    }

    var displayName: String {
        switch self {
        case .red:    return "Vermillion"
        case .orange: return "Amber"
        case .yellow: return "Gold"
        case .green:  return "Emerald"
        case .mint:   return "Jade"
        case .teal:   return "Ocean"
        case .cyan:   return "Steel"
        case .blue:   return "Cobalt"
        case .indigo: return "Violet"
        case .purple: return "Grape"
        case .pink:   return "Rose"
        case .brown:  return "Mahogany"
        }
    }

    /// The 8 colors shown in the deck color picker.
    /// Legacy cases (mint, cyan, indigo, brown) are excluded from new deck creation
    /// but continue to render correctly for existing decks stored in Firestore.
    static var pickerColors: [DeckColor] {
        [.red, .orange, .yellow, .green, .teal, .blue, .purple, .pink]
    }
}
