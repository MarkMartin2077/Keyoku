//
//  QuizPlayView.swift
//  Keyoku
//

import SwiftUI
import SwiftfulUI

struct QuizPlayDelegate {
    let quiz: QuizModel
    let deckColor: DeckColor

    var eventParameters: [String: Any] {
        var params = quiz.eventParameters
        params["deck_color"] = deckColor.rawValue
        return params
    }
}

struct QuizPlayView: View {

    @State var presenter: QuizPlayPresenter
    let delegate: QuizPlayDelegate

    private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        Group {
            if presenter.isFinished {
                resultsView
            } else {
                questionView
            }
        }
        .navigationTitle(presenter.isFinished ? "" : presenter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !presenter.isFinished {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .padding(8)
                        .anyButton {
                            presenter.onClosePressed()
                        }
                        .accessibilityLabel("Close quiz")
                        .accessibilityIdentifier("QuizCloseButton")
                }
            }
        }
        .sheet(item: Binding(get: { presenter.feedback }, set: { _ in })) { feedback in
            ScrollView {
                QuizFeedbackView(
                    isCorrect: feedback.isCorrect,
                    correctAnswer: feedback.correctAnswer,
                    explanation: feedback.explanation,
                    buttonTitle: feedback.buttonTitle,
                    onContinue: { presenter.onContinuePressed() }
                )
            }
            .scrollBounceBehavior(.basedOnSize)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Question

    private var questionView: some View {
        // Scrolls once wrapped text at large Dynamic Type no longer fits on screen.
        ScrollView {
            questionContent
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var questionContent: some View {
        VStack(spacing: 20) {
            QuizProgressStripView(
                segments: presenter.progressSegments,
                tint: presenter.deckColor.color
            )

            if let question = presenter.currentQuestion {
                questionCard(question)

                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(question.answers.enumerated(), id: \.offset) { answerIndex, answer in
                        QuizAnswerTileView(
                            text: answer,
                            state: presenter.answerState(at: answerIndex),
                            onTap: { presenter.onAnswerSelected(answerIndex: answerIndex) }
                        )
                        .accessibilityIdentifier("QuizAnswerTile_\(answerIndex)")
                    }
                }
                .id(question.id)
            }
        }
        .padding()
    }

    private func questionCard(_ question: QuizPlayQuestion) -> some View {
        VStack(spacing: 12) {
            Text("Question \(presenter.currentIndex + 1) of \(presenter.total)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(presenter.deckColor.color)

            Text(question.question)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(presenter.deckColor.color.opacity(0.12))
        )
        .id(question.id)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        .animation(.easeInOut(duration: 0.25), value: question.id)
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 20) {
            QuizScoreRingView(
                score: presenter.score,
                total: presenter.total,
                tint: presenter.deckColor.color
            )
            .padding(.bottom, 8)

            Text(presenter.isPerfect ? "Perfect!" : "Quiz complete")
                .font(.title.bold())

            VStack(spacing: 10) {
                Text("Best score \(presenter.bestScore)/\(presenter.total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                streakLine
            }

            VStack(spacing: 12) {
                Text("Retake")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(presenter.deckColor.color)
                    )
                    .anyButton(.press) {
                        presenter.onRetakePressed()
                    }
                    .accessibilityIdentifier("QuizRetakeButton")

                Text("Done")
                    .font(.headline)
                    .foregroundStyle(presenter.deckColor.color)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .anyButton(.press) {
                        presenter.onDonePressed()
                    }
                    .accessibilityIdentifier("QuizDoneButton")
            }
            .padding(.top, 16)
        }
        .padding(32)
        .frame(maxHeight: .infinity)
        .overlay {
            if presenter.isPerfect {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var streakLine: some View {
        if presenter.newStreakCount > 0 {
            Label("\(presenter.newStreakCount) day streak — keep it going!", systemImage: "flame.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12), in: Capsule())
                .symbolEffect(.bounce, value: presenter.newStreakCount)
                .transition(.scale.combined(with: .opacity))
        } else if presenter.currentStreak > 0 {
            Label("\(presenter.currentStreak) day streak", systemImage: "flame.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
    }
}

#Preview("Quiz") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = QuizPlayDelegate(quiz: .mock, deckColor: .blue)

    return NavigationStack {
        RouterView { router in
            builder.quizPlayView(router: router, delegate: delegate)
        }
    }
}

extension CoreBuilder {

    func quizPlayView(router: AnyRouter, delegate: QuizPlayDelegate) -> some View {
        QuizPlayView(
            presenter: QuizPlayPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                quiz: delegate.quiz,
                deckColor: delegate.deckColor
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showQuizPlayView(quiz: QuizModel, deckColor: DeckColor) {
        let delegate = QuizPlayDelegate(quiz: quiz, deckColor: deckColor)
        router.showScreen(.fullScreenCover) { router in
            builder.quizPlayView(router: router, delegate: delegate)
        }
    }

}
