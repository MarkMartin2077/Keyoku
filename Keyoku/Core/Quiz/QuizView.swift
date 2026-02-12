//
//  QuizView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI
import SwiftfulUI

struct QuizDelegate {
    let quiz: QuizModel

    var eventParameters: [String: Any]? {
        quiz.eventParameters
    }
}

struct QuizView: View {

    @State var presenter: QuizPresenter
    let delegate: QuizDelegate

    var body: some View {
        VStack(spacing: 0) {
            if presenter.questions.isEmpty {
                emptyStateView
            } else if presenter.isQuizComplete {
                QuizResultView(
                    score: presenter.correctAnswers,
                    totalQuestions: presenter.questions.count,
                    quizName: presenter.quizName,
                    accentColor: presenter.quizColor.color,
                    onRetakePressed: {
                        presenter.onRetakePressed()
                    },
                    onDonePressed: {
                        presenter.onDonePressed()
                    }
                )
            } else {
                activeQuizView
            }
        }
        .navigationTitle(presenter.quizName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Questions",
            systemImage: "questionmark.circle",
            description: Text("This quiz doesn't have any questions yet.")
        )
    }

    // MARK: - Active Quiz

    private var activeQuizView: some View {
        VStack(spacing: 0) {
            progressSection
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)

            ScrollView {
                QuizQuestionView(
                    questionText: presenter.currentQuestion?.questionText,
                    options: presenter.currentQuestion?.options,
                    questionType: presenter.currentQuestion?.questionType,
                    selectedIndex: presenter.selectedAnswerIndex,
                    correctAnswerIndex: presenter.currentQuestion?.correctAnswerIndex,
                    isRevealed: presenter.isAnswerRevealed,
                    accentColor: presenter.quizColor.color,
                    onOptionSelected: { index in
                        presenter.onOptionSelected(index: index)
                    }
                )
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)

            if presenter.isAnswerRevealed {
                nextButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: presenter.isAnswerRevealed)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 8) {
            Text("\(presenter.currentIndex + 1) / \(presenter.questions.count)")
                .font(.headline)
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(presenter.quizColor.color)
                        .frame(width: geometry.size.width * presenter.progress)
                        .animation(.easeInOut(duration: 0.3), value: presenter.progress)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Next Button

    private var nextButton: some View {
        HStack(spacing: 6) {
            Text(presenter.currentIndex < presenter.questions.count - 1 ? "Next" : "See Results")
            Image(systemName: presenter.currentIndex < presenter.questions.count - 1 ? "chevron.right" : "checkmark")
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(presenter.quizColor.color)
        )
        .anyButton(.press) {
            presenter.onNextPressed()
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = QuizDelegate(quiz: .mock)

    return NavigationStack {
        RouterView { router in
            builder.quizView(router: router, delegate: delegate)
        }
    }
}

extension CoreBuilder {

    func quizView(router: AnyRouter, delegate: QuizDelegate) -> some View {
        QuizView(
            presenter: QuizPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                quiz: delegate.quiz
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showQuizView(quiz: QuizModel) {
        let delegate = QuizDelegate(quiz: quiz)
        router.showScreen(.push) { router in
            builder.quizView(router: router, delegate: delegate)
        }
    }

}
