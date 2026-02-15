//
//  WidgetColorHelper.swift
//  KeyokuWidget
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

enum WidgetColorHelper {

    private static let colorMap: [String: Color] = [
        "red": .red,
        "orange": .orange,
        "yellow": .yellow,
        "green": .green,
        "mint": .mint,
        "teal": .teal,
        "cyan": .cyan,
        "blue": .blue,
        "indigo": .indigo,
        "purple": .purple,
        "pink": .pink,
        "brown": .brown
    ]

    static func color(from rawValue: String) -> Color {
        colorMap[rawValue] ?? .blue
    }
}
