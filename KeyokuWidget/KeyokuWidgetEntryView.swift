//
//  KeyokuWidgetEntryView.swift
//  KeyokuWidget
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI
import WidgetKit

struct KeyokuWidgetEntryView: View {
    let entry: KeyokuWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        case .systemLarge:
            LargeWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}
