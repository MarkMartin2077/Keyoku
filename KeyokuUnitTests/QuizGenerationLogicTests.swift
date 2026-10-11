//
//  QuizGenerationLogicTests.swift
//  KeyokuUnitTests
//

import Testing
@testable import Keyoku

private func question(
    _ text: String = "Which organelle produces most of a cell's ATP?",
    correct: String = "Mitochondria",
    wrong: [String] = ["Ribosomes", "Nucleus", "Golgi apparatus"],
    explanation: String = "Mitochondria make ATP through cellular respiration."
) -> QuizQuestionModel {
    QuizQuestionModel(question: text, correctAnswer: correct, wrongAnswers: wrong, explanation: explanation)
}

/// A malformed question and the rule it breaks.
struct RejectedQuestionCase: Sendable, CustomTestStringConvertible {
    let rule: String
    let question: QuizQuestionModel

    var testDescription: String { rule }
}

@Suite("QuizQualityFilter")
struct QuizQualityFilterTests {

    static let rejectedCases: [RejectedQuestionCase] = [
        RejectedQuestionCase(rule: "empty question", question: question("   ")),
        RejectedQuestionCase(rule: "empty correct answer", question: question(correct: "")),
        RejectedQuestionCase(rule: "empty wrong answer", question: question(wrong: ["Ribosomes", " \n", "Golgi apparatus"])),
        RejectedQuestionCase(rule: "empty explanation", question: question(explanation: "")),
        RejectedQuestionCase(rule: "two wrong answers", question: question(wrong: ["Ribosomes", "Nucleus"])),
        RejectedQuestionCase(rule: "four wrong answers", question: question(wrong: ["Ribosomes", "Nucleus", "Golgi apparatus", "Vacuole"])),
        RejectedQuestionCase(rule: "correct answer among wrong ones, case-insensitive and trimmed",
                             question: question(wrong: ["Ribosomes", "  mitochondria ", "Nucleus"])),
        RejectedQuestionCase(rule: "duplicate wrong answers", question: question(wrong: ["Ribosomes", "ribosomes", "Nucleus"])),
        RejectedQuestionCase(rule: "question references the source",
                             question: question("According to the text, which organelle produces ATP?")),
        RejectedQuestionCase(rule: "wrong answer references the source",
                             question: question(wrong: ["Ribosomes", "Nucleus", "Something in the text"])),
        RejectedQuestionCase(rule: "explanation references the source",
                             question: question(explanation: "The source text says mitochondria make ATP."))
    ]

    @Test("A complete question with three distinct wrong answers is accepted")
    func acceptsWellFormedQuestion() {
        var filter = QuizQualityFilter()
        let valid = question()

        #expect(filter.accept([valid]) == [valid])
    }

    @Test("Malformed questions are rejected", arguments: rejectedCases)
    func rejectsMalformedQuestion(_ rejected: RejectedQuestionCase) {
        var filter = QuizQualityFilter()

        #expect(filter.accept([rejected.question]).isEmpty)
    }

    @Test("A question matching one already accepted is rejected, in the same batch and in later ones")
    func rejectsDuplicatesOfAcceptedQuestions() {
        var filter = QuizQualityFilter()
        let first = question()
        let sameBatchRepeat = question("WHICH organelle  produces most of a cell's ATP?")
        let laterRepeat = question("which organelle produces most of a cell's atp?")
        let other = question("Which organelle translates messenger RNA?", correct: "Ribosomes", wrong: ["Mitochondria", "Nucleus", "Lysosome"])

        #expect(filter.accept([first, sameBatchRepeat]) == [first])
        #expect(filter.accept([laterRepeat, other]) == [other])
    }

    @Test("A question from another quiz on the deck is rejected")
    func rejectsQuestionsFromOtherQuizzes() {
        var filter = QuizQualityFilter(avoiding: ["Which organelle produces most of a cell's   ATP?"])

        #expect(filter.accept([question()]).isEmpty)
    }

    @Test("A streamed question isn't complete until it has every field and three wrong answers")
    func completeness() {
        #expect(QuizQualityFilter.isComplete(question()))
        #expect(!QuizQualityFilter.isComplete(question(wrong: ["Ribosomes", "Nucleus"])))
        #expect(!QuizQualityFilter.isComplete(question(explanation: "")))
    }
}

@Suite("QuizQuestionCount")
struct QuizQuestionCountTests {

    @Test("Quizzes need at least 1,500 characters of source text")
    func minimumSourceLength() {
        #expect(QuizQuestionCount.minimumSourceLength == 1_500)
        #expect(!QuizQuestionCount.canMakeQuiz(sourceLength: 0))
        #expect(!QuizQuestionCount.canMakeQuiz(sourceLength: 1_499))
        #expect(QuizQuestionCount.canMakeQuiz(sourceLength: 1_500))
    }

    @Test("The maximum is one question per 300 characters, clamped to 5...20",
          arguments: [(0, 5), (1_500, 5), (2_999, 9), (3_000, 10), (4_500, 15), (6_000, 20), (100_000, 20)])
    func maximum(sourceLength: Int, expected: Int) {
        #expect(QuizQuestionCount.maximum(sourceLength: sourceLength) == expected)
    }

    @Test("The default is 10, or the maximum when that is lower",
          arguments: [(1_500, 5), (2_700, 9), (3_000, 10), (50_000, 10)])
    func defaultCount(sourceLength: Int, expected: Int) {
        #expect(QuizQuestionCount.defaultCount(sourceLength: sourceLength) == expected)
    }

    @Test("A requested count is clamped to what the source allows")
    func clamped() {
        #expect(QuizQuestionCount.clamped(1, sourceLength: 10_000) == 5)
        #expect(QuizQuestionCount.clamped(12, sourceLength: 10_000) == 12)
        #expect(QuizQuestionCount.clamped(50, sourceLength: 10_000) == 20)
        #expect(QuizQuestionCount.clamped(10, sourceLength: 2_100) == 7)
    }
}

@Suite("GenerationProfile.quiz")
struct QuizGenerationProfileTests {

    @Test("Quiz questions cost 180 output tokens and about 1,300 free tokens each, 2 to 20 per call")
    func profileValues() {
        #expect(GenerationProfile.quiz.outputTokensPerItem == 180)
        #expect(GenerationProfile.quiz.freeTokensPerItem == 1_300)
        #expect(GenerationProfile.quiz.itemsPerCallFloor == 2)
        #expect(GenerationProfile.quiz.itemsPerCallCeiling == 20)
    }

    @Test("A 4K window gets 2 questions per call, 8K gets 5 and 32K fits a whole 20-question quiz")
    func questionsPerCall() {
        let small = GenerationBudget(contextSize: 4_096, overheadTokens: 700, tokensPerCharacter: 0.25, profile: .quiz)
        let medium = GenerationBudget(contextSize: 8_192, overheadTokens: 700, tokensPerCharacter: 0.25, profile: .quiz)
        let large = GenerationBudget(contextSize: 32_768, overheadTokens: 700, tokensPerCharacter: 0.25, profile: .quiz)

        #expect(small.cardsPerBatch == 2)
        #expect(medium.cardsPerBatch == 5)
        #expect(large.cardsPerBatch == 20)
    }

    @Test("Source, overhead and the reserved question output fit inside the window")
    func budgetFitsWindow() {
        let budget = GenerationBudget(contextSize: 4_096, overheadTokens: 700, tokensPerCharacter: 0.25, profile: .quiz)

        let used = 700 + budget.sourceTokens + budget.cardsPerBatch * GenerationProfile.quiz.outputTokensPerItem
        #expect(used <= 4_096)
    }
}

@Suite("Quiz title")
@MainActor
struct QuizTitleTests {

    @Test("A generated title loses surrounding quotes and extra whitespace")
    func cleansTitle() {
        #expect(QuizGenerationManager.cleanedTitle("  \"Cell   Biology Basics\" \n") == "Cell Biology Basics")
    }

    @Test("An empty or overlong title is rejected")
    func rejectsUnusableTitles() {
        #expect(QuizGenerationManager.cleanedTitle("  ") == nil)
        #expect(QuizGenerationManager.cleanedTitle("One two three four five six seven eight nine") == nil)
    }

    @Test("The fallback title is the deck name plus Quiz, or just Quiz for a blank name")
    func fallbackTitle() {
        #expect(QuizGenerationManager.fallbackTitle(deckName: " Biology 101 ") == "Biology 101 Quiz")
        #expect(QuizGenerationManager.fallbackTitle(deckName: "  ") == "Quiz")
    }
}

@Suite("QuizGenerationError messages")
struct QuizGenerationErrorMessageTests {

    static let allErrors: [QuizGenerationError] = [
        .notEnoughSourceText,
        .tooFewQuestions(generated: 0),
        .tooFewQuestions(generated: 4)
    ] + [
        GenerationFailure.contextTooLarge,
        .restricted,
        .refused,
        .rateLimited(retryAfter: nil),
        .unsupportedLanguage,
        .modelUnavailable,
        .cloudUnavailable,
        .cancelled,
        .unreadableText,
        .other("boom")
    ].map(QuizGenerationError.generation)

    @Test("No quiz error message mentions flashcards", arguments: allErrors)
    func messagesAreAboutQuizzes(error: QuizGenerationError) {
        #expect(!error.userMessage.isEmpty)
        #expect(!error.userMessage.localizedCaseInsensitiveContains("flashcard"))
    }
}
