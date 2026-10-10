//
//  DeckDetailPresenter+Quizzes.swift
//  Keyoku
//

import SwiftUI

extension DeckDetailPresenter {

    /// What the deck screen's Quizzes section shows.
    enum QuizSectionState: Equatable {
        /// The deck has no source text (made by hand), so it can't be quizzed (ADR 0001).
        case handMade
        /// The source text is shorter than a quiz needs.
        case needsMoreSource
        /// The strip of saved quizzes, led by the "+ New Quiz" card.
        case strip
    }

    // MARK: - Derived State

    /// This deck's saved quizzes, newest first. Read through the interactor on every access,
    /// so the strip picks up new quizzes and best scores from attempts as soon as they're saved.
    var quizzes: [QuizModel] {
        interactor.quizzes(forDeckId: deckId)
    }

    var quizSourceLength: Int {
        deck?.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0
    }

    var quizSectionState: QuizSectionState {
        if quizSourceLength == 0 {
            return .handMade
        }
        if !interactor.canMakeQuiz(sourceLength: quizSourceLength) {
            return .needsMoreSource
        }
        return .strip
    }

    var quizUnavailableReason: UnavailableReason? {
        if case .unavailable(let reason) = interactor.quizGenerationAvailability {
            return reason
        }
        return nil
    }

    var newQuizCardStatus: NewQuizCardStatus {
        if let quizGeneratedCount {
            return .generating(questionCount: quizGeneratedCount)
        }
        if quizUnavailableReason != nil {
            return .unavailable
        }
        return .ready
    }

    var isGeneratingQuiz: Bool {
        quizGeneratedCount != nil
    }

    var maxQuizQuestionCount: Int {
        interactor.maxQuizQuestionCount(sourceLength: quizSourceLength)
    }

    /// The Quizzes section is hidden on an empty hand-made deck, where the empty state already explains what to do.
    var showsQuizSection: Bool {
        !(flashcards.isEmpty && quizSectionState == .handMade)
    }

    // MARK: - Actions

    func onQuizPressed(quiz: QuizModel) {
        interactor.trackEvent(event: Event.onQuizPressed(quiz: quiz))
        router.showQuizPlayView(quiz: quiz, deckColor: deckColor)
    }

    func onDeleteQuizPressed(quiz: QuizModel) {
        interactor.trackEvent(event: Event.onQuizDeletePressed(quiz: quiz))
        router.showDeleteQuizAlert(quizTitle: quiz.title) { [weak self] in
            self?.onDeleteQuizConfirmed(quiz: quiz)
        }
    }

    func onDeleteQuizConfirmed(quiz: QuizModel) {
        interactor.trackEvent(event: Event.onQuizDeleteConfirmed(quiz: quiz))
        do {
            try interactor.deleteQuiz(id: quiz.id)
            interactor.trackEvent(event: Event.onQuizDeleteSuccess(quizId: quiz.id))
        } catch {
            interactor.trackEvent(event: Event.onQuizDeleteFail(error: error))
            router.showSimpleAlert(
                title: String(localized: "Couldn't Delete Quiz"),
                subtitle: String(localized: "Please try again.")
            )
        }
    }

    /// The "+" card: opens the New Quiz sheet, or cancels the quiz being made.
    func onNewQuizCardPressed() {
        let status = newQuizCardStatus
        interactor.trackEvent(event: Event.onQuizNewCardPressed(status: status))

        switch status {
        case .ready:
            quizQuestionCount = interactor.defaultQuizQuestionCount(sourceLength: quizSourceLength)
            interactor.prewarmQuizGeneration()
            showNewQuizSheet = true
        case .generating:
            cancelQuizGeneration()
        case .unavailable:
            break
        }
    }

    func onQuizQuestionCountChanged(_ count: Int) {
        let clamped = min(max(count, QuizQuestionCount.minimum), maxQuizQuestionCount)
        interactor.trackEvent(event: Event.onQuizCountChanged(count: clamped))
        quizQuestionCount = clamped
    }

    func onNewQuizSheetCancelled() {
        interactor.trackEvent(event: Event.onQuizNewSheetCancelled)
        showNewQuizSheet = false
    }

    func onMakeQuizPressed() {
        let questionCount = quizQuestionCount
        interactor.trackEvent(event: Event.onQuizMakePressed(questionCount: questionCount, sourceLength: quizSourceLength))
        showNewQuizSheet = false

        guard let currentDeck = deck, quizSectionState == .strip, !isGeneratingQuiz else { return }

        quizGeneratedCount = 0
        quizGenerationTask = Task {
            do {
                let quiz = try await interactor.generateQuiz(for: currentDeck, questionCount: questionCount) { [weak self] progress in
                    guard let self, self.isGeneratingQuiz else { return }
                    self.quizGeneratedCount = progress.generatedCount
                }
                guard !Task.isCancelled else {
                    // Cancelled after the save landed: cancelling must leave nothing behind.
                    try? interactor.deleteQuiz(id: quiz.id)
                    return
                }
                finishQuizGeneration()
                interactor.trackEvent(event: Event.onQuizMakeSuccess(quiz: quiz, requestedCount: questionCount))
                interactor.playHaptic(option: .achievementUnlocked())
            } catch {
                guard !Task.isCancelled else { return }
                finishQuizGeneration()
                let quizError = error as? QuizGenerationError
                if quizError?.isCancelled == true { return }
                interactor.trackEvent(event: Event.onQuizMakeFail(error: error))
                router.showSimpleAlert(
                    title: String(localized: "Couldn't Make Quiz"),
                    subtitle: quizError?.userMessage
                        ?? String(localized: "Your quiz was made but couldn't be saved. Please try again.")
                )
            }
        }
    }

    // MARK: - Private

    private func cancelQuizGeneration() {
        interactor.trackEvent(event: Event.onQuizMakeCancelled(questionsSoFar: quizGeneratedCount ?? 0))
        quizGenerationTask?.cancel()
        finishQuizGeneration()
    }

    private func finishQuizGeneration() {
        quizGenerationTask = nil
        quizGeneratedCount = nil
    }
}
