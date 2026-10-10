//
//  QuizGenerationManagerTests.swift
//  KeyokuUnitTests
//

import Testing
import Foundation
@testable import Keyoku

/// About 3,900 characters of varied study text: room for up to 12 questions.
private let quizSourceText = [
    "Mitochondria produce ATP through cellular respiration, which powers most activity inside a cell.",
    "Ribosomes translate messenger RNA into chains of amino acids that fold into working proteins.",
    "The nucleus stores DNA and controls gene expression by regulating which genes are transcribed.",
    "Photosynthesis in chloroplasts converts light energy, water and carbon dioxide into glucose.",
    "The Treaty of Westphalia in 1648 ended the Thirty Years' War and shaped modern state sovereignty.",
    "Newton's second law states that force equals mass times acceleration for a constant mass.",
    "Supply and demand curves meet at an equilibrium price where buyers and sellers agree on quantity.",
    "Plate tectonics explains earthquakes and mountain ranges as rigid plates slide over the mantle.",
    "The Krebs cycle oxidizes acetyl groups and releases carbon dioxide as a waste product.",
    "Enzymes lower activation energy so reactions happen faster at body temperature.",
    "Osmosis moves water across a membrane from lower solute concentration to higher concentration.",
    "The Magna Carta of 1215 limited royal power and influenced later constitutional law.",
    "Igneous rock forms when magma cools, either slowly underground or quickly at the surface.",
    "Inflation measures how fast the general price level rises and erodes purchasing power.",
    "The French Revolution began in 1789 and overturned the absolute monarchy of Louis XVI.",
    "Kinetic energy depends on an object's mass and the square of its velocity.",
    "Natural selection favours heritable traits that improve survival and reproduction.",
    "The water cycle moves water through evaporation, condensation, precipitation and runoff.",
    "Antibodies bind specific antigens and mark pathogens for destruction by immune cells.",
    "The Renaissance revived classical learning in Italian city-states such as Florence."
].enumerated().map { index, sentence in
    "Section \(index + 1). \(sentence) Students often review this idea with worked examples and short quizzes."
}.joined(separator: "\n\n")

/// A valid question for the first `validCount` drafts, then questions whose correct answer repeats a wrong one.
private func draftsValid(upTo validCount: Int) -> (Int) -> GeneratedQuizQuestionDraft {
    { number in
        let draft = MockQuizGenerationService.sampleDraft(number)
        guard number > validCount else { return draft }
        return GeneratedQuizQuestionDraft(
            question: draft.question,
            correctAnswer: draft.correctAnswer,
            wrongAnswers: [draft.correctAnswer] + draft.wrongAnswers.dropFirst(),
            explanation: draft.explanation
        )
    }
}

private struct GenerationOutcome {
    let quiz: GeneratedQuiz?
    let error: QuizGenerationError?
    let progress: [QuizGenerationProgress]
}

@Suite("QuizGenerationManager")
@MainActor
struct QuizGenerationManagerTests {

    private func makeManager(
        service: MockQuizGenerationService? = nil,
        mockLog: MockLogService? = nil
    ) -> (QuizGenerationManager, MockLogService) {
        let service = service ?? MockQuizGenerationService()
        let mockLog = mockLog ?? MockLogService()
        let manager = QuizGenerationManager(service: service, logManager: LogManager(services: [mockLog]))
        return (manager, mockLog)
    }

    private func generate(
        _ manager: QuizGenerationManager,
        text: String = quizSourceText,
        deckName: String = "Biology",
        count: Int = 10,
        avoiding: [String] = []
    ) async -> GenerationOutcome {
        var progress: [QuizGenerationProgress] = []
        do {
            let quiz = try await manager.generateQuiz(from: text, deckName: deckName, count: count, avoiding: avoiding) {
                progress.append($0)
            }
            return GenerationOutcome(quiz: quiz, error: nil, progress: progress)
        } catch {
            return GenerationOutcome(quiz: nil, error: error as? QuizGenerationError, progress: progress)
        }
    }

    @Test("Generates the requested questions with UUID ids and a generated title, and tracks start and success")
    func generatesQuiz() async throws {
        let service = MockQuizGenerationService()
        let (manager, mockLog) = makeManager(service: service)

        let result = await generate(manager)
        let quiz = try #require(result.quiz)

        #expect(quiz.questions.count == 10)
        #expect(quiz.questions.allSatisfy { UUID(uuidString: $0.id) != nil })
        #expect(Set(quiz.questions.map(\.id)).count == 10)
        #expect(quiz.questions.allSatisfy { $0.wrongAnswers.count == 3 })
        #expect(quiz.title == "Sample Concepts")
        #expect(!quiz.usedFallbackTitle)
        #expect(service.titlePrompts.count == 1)
        #expect(mockLog.hasEvent(named: "QuizGenMan_Generate_Start"))
        #expect(mockLog.hasEvent(named: "QuizGenMan_Generate_Success"))
        #expect(mockLog.hasEvent(named: "QuizGenMan_Title_Start"))
        #expect(mockLog.hasEvent(named: "QuizGenMan_Title_Success"))
    }

    @Test("Progress counts up to the total without going backwards")
    func progressCounts() async {
        let (manager, _) = makeManager()

        let result = await generate(manager)
        let counts = result.progress.map(\.generatedCount)

        #expect(result.progress.allSatisfy { $0.totalCount == 10 })
        #expect(counts.first == 0)
        #expect(counts.last == 10)
        #expect(counts == counts.sorted())
    }

    @Test("Analytics events never carry question, answer or explanation text")
    func eventsCarryNoQuestionText() async throws {
        let (manager, mockLog) = makeManager()

        let quiz = try #require(await generate(manager).quiz)
        let texts = quiz.questions.flatMap { [$0.question, $0.correctAnswer, $0.explanation] + $0.wrongAnswers }
        let parameterValues = mockLog.events
            .flatMap { ($0.parameters ?? [:]).values }
            .map { String(describing: $0) }

        #expect(!parameterValues.isEmpty)
        for text in texts {
            #expect(!parameterValues.contains { $0.contains(text) })
        }
    }

    @Test("Filtered-out questions are topped up once")
    func topUp() async throws {
        // Drafts 1 and 2 are malformed, so the five planned calls leave the run two short.
        let service = MockQuizGenerationService(makeDraft: { number in
            number <= 2
                ? GeneratedQuizQuestionDraft(question: "Which term is repeated?", correctAnswer: "Repeat",
                                             wrongAnswers: ["Echo", "Echo", "Copy"], explanation: "It repeats.")
                : MockQuizGenerationService.sampleDraft(number)
        })
        let (manager, _) = makeManager(service: service)

        let quiz = try #require(await generate(manager).quiz)

        #expect(quiz.questions.count == 10)
        #expect(service.prompts.count == 6)
        #expect(service.prompts.last?.contains("Generate exactly 2 multiple-choice questions") == true)
    }

    @Test("Five valid questions after the top-up are enough to make a quiz")
    func minimumOfFivePasses() async throws {
        let service = MockQuizGenerationService(makeDraft: draftsValid(upTo: 5))
        let (manager, mockLog) = makeManager(service: service)

        let quiz = try #require(await generate(manager).quiz)

        #expect(quiz.questions.count == 5)
        #expect(mockLog.hasEvent(named: "QuizGenMan_Generate_Success"))
    }

    @Test("Fewer than five valid questions after the top-up fails the run")
    func minimumOfFiveFails() async {
        let service = MockQuizGenerationService(makeDraft: draftsValid(upTo: 4))
        let (manager, mockLog) = makeManager(service: service)

        let result = await generate(manager)

        #expect(result.quiz == nil)
        #expect(result.error == .tooFewQuestions(generated: 4))
        #expect(service.titlePrompts.isEmpty)
        #expect(mockLog.hasEvent(named: "QuizGenMan_Generate_Fail"))
        #expect(!mockLog.hasEvent(named: "QuizGenMan_Generate_Success"))
    }

    @Test("A failed title call falls back to the deck name plus Quiz")
    func titleFallsBackOnFailure() async throws {
        let service = MockQuizGenerationService(title: .failure(GenerationFailure.modelUnavailable))
        let (manager, mockLog) = makeManager(service: service)

        let quiz = try #require(await generate(manager, deckName: "Cell Biology").quiz)

        #expect(quiz.title == "Cell Biology Quiz")
        #expect(quiz.usedFallbackTitle)
        #expect(mockLog.hasEvent(named: "QuizGenMan_Title_Fallback"))
        #expect(mockLog.hasEvent(named: "QuizGenMan_Generate_Success"))
    }

    @Test("An unusable generated title falls back to the deck name plus Quiz")
    func titleFallsBackWhenUnusable() async throws {
        let service = MockQuizGenerationService(title: .success("   "))
        let (manager, _) = makeManager(service: service)

        let quiz = try #require(await generate(manager, deckName: "Cell Biology").quiz)

        #expect(quiz.title == "Cell Biology Quiz")
        #expect(quiz.usedFallbackTitle)
    }

    @Test("Source text under 1,500 characters fails before any model call")
    func notEnoughSourceText() async {
        let service = MockQuizGenerationService()
        let (manager, mockLog) = makeManager(service: service)

        let result = await generate(manager, text: String(quizSourceText.prefix(1_499)))

        #expect(result.error == .notEnoughSourceText)
        #expect(service.prompts.isEmpty)
        #expect(mockLog.hasEvent(named: "QuizGenMan_Generate_Fail"))
    }

    @Test("A count above what the source allows is clamped")
    func clampsCount() async throws {
        let (manager, _) = makeManager()

        let quiz = try #require(await generate(manager, count: 50).quiz)

        #expect(quiz.questions.count == QuizQuestionCount.maximum(sourceLength: quizSourceText.count))
    }

    @Test("Every call lists the deck's earlier questions, newest first within a third of the source room, and skips them")
    func avoidsEarlierQuestionsInEveryCall() async throws {
        let service = MockQuizGenerationService()
        let (manager, _) = makeManager(service: service)
        let old = (1...400).map { "Earlier question number \($0) about an older part of the deck?" }
        let repeated = MockQuizGenerationService.sampleDraft(1).question

        let quiz = try #require(await generate(manager, avoiding: old + [repeated]).quiz)

        #expect(!quiz.questions.map(\.question).contains(repeated))
        #expect(service.prompts.count > 1)
        for prompt in service.prompts {
            #expect(prompt.contains("Do NOT repeat or rephrase"))
            #expect(prompt.contains(repeated))
            #expect(!prompt.contains("Earlier question number 1 about"))
        }
    }

    @Test("Cancelling stops the run and tracks a cancel instead of a failure")
    func cancelStopsRun() async {
        let service = MockQuizGenerationService(delayPerQuestion: .milliseconds(50))
        let (manager, mockLog) = makeManager(service: service)

        let task = Task { await generate(manager) }
        try? await Task.sleep(for: .milliseconds(120))
        task.cancel()
        let result = await task.value

        #expect(result.quiz == nil)
        #expect(result.error == .generation(.cancelled))
        #expect(mockLog.hasEvent(named: "QuizGenMan_Generate_Cancelled"))
        #expect(!mockLog.hasEvent(named: "QuizGenMan_Generate_Fail"))
        #expect(!mockLog.hasEvent(named: "QuizGenMan_Generate_Success"))
    }
}

// MARK: - Saving through the interactor

private struct InteractorHarness {
    let interactor: CoreInteractor
    let quizManager: QuizManager
    let mockLog: MockLogService
}

@Suite("CoreInteractor quiz generation")
@MainActor
struct CoreInteractorQuizGenerationTests {

    private func makeInteractor(
        service: MockQuizGenerationService,
        quizzes: [QuizModel] = []
    ) -> InteractorHarness {
        let mockLog = MockLogService()
        let logManager = LogManager(services: [mockLog])
        let quizManager = QuizManager(services: MockQuizServices(quizzes: quizzes), logManager: logManager)
        quizManager.loadQuizzes()
        let container = DevPreview(isSignedIn: true).container()
        container.register(QuizManager.self, service: quizManager)
        container.register(QuizGenerationManager.self, service: QuizGenerationManager(service: service, logManager: logManager))
        return InteractorHarness(interactor: CoreInteractor(container: container), quizManager: quizManager, mockLog: mockLog)
    }

    private let deck = DeckModel(name: "Biology", sourceText: quizSourceText)

    @Test("A generated quiz is saved on the deck with its title and questions")
    func savesGeneratedQuiz() async throws {
        let harness = makeInteractor(service: MockQuizGenerationService())

        let quiz = try await harness.interactor.generateQuiz(for: deck, questionCount: 10) { _ in }

        #expect(quiz.deckId == deck.deckId)
        #expect(quiz.title == "Sample Concepts")
        #expect(quiz.questions.count == 10)
        #expect(harness.quizManager.quizzes(forDeckId: deck.deckId).map(\.id) == [quiz.id])
        #expect(harness.mockLog.hasEvent(named: "QuizMan_CreateQuiz_Success"))
    }

    @Test("A new quiz avoids the questions of the deck's other quizzes")
    func avoidsOtherQuizzes() async throws {
        let earlier = QuizModel(deckId: deck.deckId, title: "Earlier", questions: [
            QuizQuestionModel(question: MockQuizGenerationService.sampleDraft(1).question,
                              correctAnswer: "Concept 1", wrongAnswers: ["Idea 1", "Notion 1", "Theory 1"],
                              explanation: "From an earlier quiz.")
        ])
        let service = MockQuizGenerationService()
        let harness = makeInteractor(service: service, quizzes: [earlier])

        let quiz = try await harness.interactor.generateQuiz(for: deck, questionCount: 10) { _ in }

        #expect(!quiz.questions.map(\.question).contains(earlier.questions[0].question))
        #expect(service.prompts.allSatisfy { $0.contains(earlier.questions[0].question) })
    }

    @Test("Cancelling generation saves nothing")
    func cancelSavesNothing() async {
        let service = MockQuizGenerationService(delayPerQuestion: .milliseconds(50))
        let harness = makeInteractor(service: service)

        let task = Task {
            try await harness.interactor.generateQuiz(for: deck, questionCount: 10) { _ in }
        }
        try? await Task.sleep(for: .milliseconds(120))
        task.cancel()
        let result = await task.result

        #expect(throws: QuizGenerationError.generation(.cancelled)) { try result.get() }
        #expect(harness.quizManager.quizzes(forDeckId: deck.deckId).isEmpty)
        #expect(!harness.mockLog.hasEvent(named: "QuizMan_CreateQuiz_Start"))
    }
}
