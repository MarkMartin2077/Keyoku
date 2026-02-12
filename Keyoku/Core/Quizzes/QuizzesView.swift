//
//  QuizzesView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI
import SwiftfulUI

struct QuizzesDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct QuizzesView: View {

    @State var presenter: QuizzesPresenter
    let delegate: QuizzesDelegate

    var body: some View {
        List {
            if presenter.quizzes.isEmpty {
                emptyStateView
            } else {
                quizzesSection
            }
        }
        .navigationTitle("Quizzes")
        .searchable(text: $presenter.searchText, prompt: "Search quizzes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addButton
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Quizzes Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create your first quiz to test your knowledge")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Create Quiz") {
                presenter.onAddQuizPressed()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }

    private var quizzesSection: some View {
        Section {
            ForEach(presenter.filteredQuizzes) { quiz in
                quizRow(quiz: quiz)
            }
            .onDelete { indexSet in
                presenter.onDeleteQuizzes(at: indexSet)
            }
        } header: {
            Text("\(presenter.filteredQuizzes.count) Quiz\(presenter.filteredQuizzes.count == 1 ? "" : "zes")")
        }
    }

    private func quizRow(quiz: QuizModel) -> some View {
        HStack {
            Circle()
                .fill(quiz.color.color.gradient)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(quiz.name)
                    .font(.headline)
                Text("\(quiz.questions.count) question\(quiz.questions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .anyButton(.highlight) {
            presenter.onQuizPressed(quiz: quiz)
        }
    }

    private var addButton: some View {
        Button("Add Quiz", systemImage: "plus") {
            presenter.onAddQuizPressed()
        }
        .buttonStyle(.glassProminent)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = QuizzesDelegate()

    return RouterView { router in
        builder.quizzesView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func quizzesView(router: AnyRouter, delegate: QuizzesDelegate) -> some View {
        QuizzesView(
            presenter: QuizzesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showQuizzesView(delegate: QuizzesDelegate) {
        router.showScreen(.push) { router in
            builder.quizzesView(router: router, delegate: delegate)
        }
    }

}
