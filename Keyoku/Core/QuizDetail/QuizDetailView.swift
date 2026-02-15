//
//  QuizDetailView.swift
//  Keyoku
//

import SwiftUI
import SwiftfulUI

struct QuizDetailDelegate {
    let quiz: QuizModel

    var eventParameters: [String: Any]? {
        quiz.eventParameters
    }
}

struct QuizDetailView: View {

    @State var presenter: QuizDetailPresenter
    let delegate: QuizDetailDelegate

    var body: some View {
        List {
            if !presenter.questions.isEmpty {
                practiceSection
            }

            if presenter.questions.isEmpty {
                emptyStateView
            } else {
                questionsSection
            }
        }
        .navigationTitle(presenter.quizName)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Practice Section

    private var practiceSection: some View {
        Section {
            Button {
                presenter.onPracticePressed()
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(presenter.quizColor.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Practice")
                            .font(.headline)
                        Text("Answer all \(presenter.questions.count) questions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Start practicing all questions in this quiz")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Questions Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("This quiz doesn't have any questions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Questions Section

    private var questionsSection: some View {
        Section {
            ForEach(Array(presenter.questions.enumerated()), id: \.element.id) { index, question in
                questionRow(index: index, question: question)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            presenter.onDeleteQuestion(at: IndexSet(integer: index))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        } header: {
            Text("\(presenter.questions.count) Question\(presenter.questions.count == 1 ? "" : "s")")
        }
    }

    private func questionRow(index: Int, question: QuizQuestionModel) -> some View {
        Button {
            presenter.onQuestionPressed(question: question)
        } label: {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(presenter.quizColor.color.gradient)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(question.questionText)
                        .font(.subheadline)
                        .lineLimit(2)

                    Text(question.questionType.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(presenter.quizColor.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(presenter.quizColor.color.opacity(0.12))
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question \(index + 1), \(question.questionText)")
        .accessibilityHint("Start quiz at this question")
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = QuizDetailDelegate(quiz: .mock)

    return NavigationStack {
        RouterView { router in
            builder.quizDetailView(router: router, delegate: delegate)
        }
    }
}

extension CoreBuilder {

    func quizDetailView(router: AnyRouter, delegate: QuizDetailDelegate) -> some View {
        QuizDetailView(
            presenter: QuizDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                quiz: delegate.quiz
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showQuizDetailView(quiz: QuizModel) {
        let delegate = QuizDetailDelegate(quiz: quiz)
        router.showScreen(.push) { router in
            builder.quizDetailView(router: router, delegate: delegate)
        }
    }

}
