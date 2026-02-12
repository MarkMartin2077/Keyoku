//
//  BouncyScrollModifier.swift
//  Keyoku
//

import SwiftUI

struct BouncyScrollModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .scrollTransition(
                .animated(
                    .spring(duration: 0.5, bounce: 0.5)
                )
            ) { view, phase in
                view
                    .opacity(phase.isIdentity ? 1 : 0.5)
                    .offset(x: phase.value * 80)
                    .scaleEffect(phase.isIdentity ? 1 : 0.8)
                    .brightness(phase.isIdentity ? 0 : -0.2)
                    .blur(radius: phase.isIdentity ? 0 : 5)
            }
    }
}

extension View {

    func bouncyScroll() -> some View {
        modifier(BouncyScrollModifier())
    }
}
