//
//  DeckDetailView+Quizzes.swift
//  Keyoku
//

import SwiftUI

extension DeckDetailView {

    // MARK: - Quizzes Section

    var quizzesSection: some View {
        Section {
            switch presenter.quizSectionState {
            case .strip:
                quizStrip

                if let reason = presenter.quizUnavailableReason {
                    AppleIntelligenceUnavailableView(
                        reason: reason,
                        onOpenSettings: presenter.onOpenSettingsPressed,
                        purpose: .quizzes
                    )
                }
            case .needsMoreSource:
                quizExplanation(String(localized: "Add more source text to make a quiz. Quizzes need at least \(presenter.minQuizSourceLength.formatted()) characters of source text."))
            case .handMade:
                quizExplanation(String(localized: "Quizzes are made from a deck's source text. This deck was made by hand, so it has no source text to quiz you on."))
            }
        } header: {
            Text("Quizzes")
        }
    }

    /// Routes swipe-to-dismiss through the presenter. Make Quiz and Cancel close the sheet themselves first,
    /// so the presenter ignores the write-back when they do.
    var newQuizSheetBinding: Binding<Bool> {
        Binding(
            get: { presenter.showNewQuizSheet },
            set: { isPresented in
                if !isPresented {
                    presenter.onNewQuizSheetCancelled()
                }
            }
        )
    }

    private var quizStrip: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                NewQuizCardView(
                    status: presenter.newQuizCardStatus,
                    tint: presenter.deckColor.color,
                    onTap: presenter.onNewQuizCardPressed
                )
                .accessibilityIdentifier("NewQuizCard")

                ForEach(presenter.quizzes) { quiz in
                    QuizCardView(
                        title: quiz.title,
                        bestScore: quiz.bestScore,
                        questionCount: quiz.questions.count,
                        createdAt: quiz.createdAt,
                        tint: presenter.deckColor.color,
                        onTap: { presenter.onQuizPressed(quiz: quiz) },
                        onDelete: { presenter.onDeleteQuizPressed(quiz: quiz) }
                    )
                    .accessibilityIdentifier("QuizCard_\(quiz.id)")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 4)
            .padding(.horizontal, 16)
            .animation(.default, value: presenter.quizzes.map(\.id))
        }
        .scrollIndicators(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }

    private func quizExplanation(_ text: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "questionmark.square.dashed")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

// MARK: - Previews (one per Quizzes section state)

@MainActor
private func quizSectionPreview(
    deck: DeckModel,
    quizzes: [QuizModel],
    availability: GenerationAvailability = .available(.onDevice)
) -> some View {
    let container = DevPreview.shared.container()
    let flashcardManager = FlashcardManager(services: MockFlashcardServices(decks: [deck]))
    flashcardManager.loadDecks()
    let quizManager = QuizManager(services: MockQuizServices(quizzes: quizzes))
    quizManager.loadQuizzes()
    container.register(FlashcardManager.self, service: flashcardManager)
    container.register(QuizManager.self, service: quizManager)
    container.register(
        QuizGenerationManager.self,
        service: QuizGenerationManager(service: MockQuizGenerationService(availability: availability, delayPerQuestion: .milliseconds(400)))
    )
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return NavigationStack {
        RouterView { router in
            builder.deckDetailView(router: router, delegate: DeckDetailDelegate(deck: deck))
        }
    }
}

private func previewDeck(sourceText: String) -> DeckModel {
    DeckModel(
        deckId: "deck1",
        name: "Spanish Essentials",
        color: .orange,
        sourceText: sourceText,
        flashcards: FlashcardModel.mocks.filter { $0.deckId == "deck1" }
    )
}

#Preview("Quizzes") {
    quizSectionPreview(deck: .mock, quizzes: [QuizModel.mock, QuizModel(deckId: "deck1", title: "Ser and Estar", questions: QuizQuestionModel.mocks)])
}

#Preview("No Quizzes Yet (tap + to watch generation)") {
    quizSectionPreview(deck: .mock, quizzes: [])
}

#Preview("AI Unavailable") {
    quizSectionPreview(deck: .mock, quizzes: [QuizModel.mock], availability: .unavailable(.appleIntelligenceNotEnabled))
}

#Preview("Short Source") {
    quizSectionPreview(deck: previewDeck(sourceText: "Core Spanish vocabulary for beginners."), quizzes: [])
}

#Preview("Hand-made Deck") {
    quizSectionPreview(deck: previewDeck(sourceText: ""), quizzes: [])
}
