//
//  RippleView.swift
//  Keyoku
//

import SwiftUI

struct RippleView: View {

    let color: Color

    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 1.5)
                    .scaleEffect(animate ? 3.5 : 0.3)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 2.8)
                            .delay(Double(index) * 0.8)
                            .repeatForever(autoreverses: false),
                        value: animate
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.05).ignoresSafeArea()
        RippleView(color: .blue)
    }
}
