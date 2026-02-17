//
//  FlashcardView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/10/26.
//

import SwiftUI

struct FlashcardView: View {
    
    let question: String
    let answer: String
    var accentColor: Color = .blue
    
    @State private var showingAnswer = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                rotation += 180
                showingAnswer.toggle()
            }
        } label: {
            cardContent
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showingAnswer ? "Answer: \(answer)" : "Question: \(question)")
        .accessibilityHint("Tap to flip to \(showingAnswer ? "question" : "answer")")
        .onChange(of: question) {
            showingAnswer = false
            rotation = 0
        }
    }
    
    private var cardContent: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: accentColor.opacity(0.2), radius: 10, y: 5)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [accentColor.opacity(0.5), accentColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                }
            
            // Card content
            VStack(spacing: 16) {
                // Label pill
                Text(showingAnswer ? "Answer" : "Question")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(showingAnswer ? Color.green : accentColor)
                    )
                    .scaleEffect(x: showingAnswer ? -1 : 1, y: 1)
                    .accessibilityHidden(true)
                
                Spacer()
                
                // Main text
                if showingAnswer {
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(answer)
                            .font(.title3)
                            .fontWeight(.regular)
                            .multilineTextAlignment(.center)
                            .scaleEffect(x: -1, y: 1)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Text(question)
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                }
                
                Spacer()
                
                // Tap hint
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap")
                    Text("Tap to flip")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .scaleEffect(x: showingAnswer ? -1 : 1, y: 1)
                .accessibilityHidden(true)
            }
            .padding(24)
        }
        .containerRelativeFrame([.horizontal, .vertical]) { size, axis in
            if axis == .horizontal {
                size * 0.85
            } else {
                size * 0.55
            }
        }
    }
}

#Preview("Question") {
    FlashcardView(
        question: "What is the capital of Japan?",
        answer: "Tokyo",
        accentColor: .blue
    )
}

#Preview("With Long Text") {
    FlashcardView(
        question: "Explain the process of photosynthesis and why it's important for life on Earth.",
        answer: "Photosynthesis is the process by which plants convert sunlight, water, and carbon dioxide into glucose and oxygen. It's essential because it produces oxygen for breathing and forms the base of most food chains.",
        accentColor: .green
    )
}
