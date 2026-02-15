//
//  Card3DScrollModifier.swift
//  Keyoku
//

import SwiftUI

struct Card3DScrollModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                view
                    .rotation3DEffect(
                        .degrees(phase.value * 45),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.8
                    )
                    .scaleEffect(1 - abs(phase.value) * 0.2)
            }
    }
}

extension View {

    func card3DScroll() -> some View {
        modifier(Card3DScrollModifier())
    }
}
