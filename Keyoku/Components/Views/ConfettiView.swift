//
//  ConfettiView.swift
//  Keyoku
//

import SwiftUI

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let isCircle: Bool
    let xPosition: CGFloat
    let size: CGFloat
    let delay: Double
    let xDrift: CGFloat
    let rotationAmount: Double
    let duration: Double
}

struct ConfettiView: View {

    @State private var fallen = false
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { proxy in
            ForEach(particles) { particle in
                particleView(particle, in: proxy.size)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            particles = makeParticles()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                fallen = true
            }
        }
    }

    @ViewBuilder
    private func particleView(_ particle: ConfettiParticle, in size: CGSize) -> some View {
        Group {
            if particle.isCircle {
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
                    .frame(width: particle.size * 0.55, height: particle.size * 1.7)
            }
        }
        .position(
            x: particle.xPosition * size.width + (fallen ? particle.xDrift : 0),
            y: fallen ? size.height + 20 : -20
        )
        .rotationEffect(.degrees(fallen ? particle.rotationAmount : 0))
        .opacity(fallen ? 0 : 1)
        .animation(
            .easeIn(duration: particle.duration).delay(particle.delay),
            value: fallen
        )
    }

    private func makeParticles() -> [ConfettiParticle] {
        let colors: [Color] = [
            .red, .blue, .green, .yellow,
            .orange, .purple, .pink, .teal,
            Color(red: 1, green: 0.84, blue: 0)
        ]
        return (0..<80).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? .blue,
                isCircle: Bool.random(),
                xPosition: CGFloat.random(in: 0.02...0.98),
                size: CGFloat.random(in: 6...13),
                delay: Double.random(in: 0...1.0),
                xDrift: CGFloat.random(in: -70...70),
                rotationAmount: Double.random(in: -540...540),
                duration: Double.random(in: 1.8...3.2)
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.05).ignoresSafeArea()
        ConfettiView()
    }
}
