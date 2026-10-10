//
//  NewQuizSheet.swift
//  Keyoku
//

import SwiftUI
import SwiftfulUI

/// Picks how many questions a new quiz has, then starts making it from the deck's source text.
struct NewQuizSheet: View {

    let presenter: DeckDetailPresenter

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        "^[\(presenter.quizQuestionCount) question](inflect: true)",
                        value: Binding(
                            get: { presenter.quizQuestionCount },
                            set: { presenter.onQuizQuestionCountChanged($0) }
                        ),
                        in: presenter.minQuizQuestionCount...presenter.maxQuizQuestionCount
                    )
                    .accessibilityIdentifier("QuizQuestionCountStepper")
                } footer: {
                    Text("Up to \(presenter.maxQuizQuestionCount) for this deck's source text. Add more text for longer quizzes.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                makeQuizButton
                    .padding()
            }
            .navigationTitle("New Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Text("Cancel")
                        .foregroundStyle(.tint)
                        .anyButton {
                            presenter.onNewQuizSheetCancelled()
                        }
                        .accessibilityIdentifier("NewQuizCancelButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var makeQuizButton: some View {
        Text("Make Quiz")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(presenter.deckColor.color)
            )
            .anyButton(.press) {
                presenter.onMakeQuizPressed()
            }
            .accessibilityIdentifier("MakeQuizButton")
    }
}
