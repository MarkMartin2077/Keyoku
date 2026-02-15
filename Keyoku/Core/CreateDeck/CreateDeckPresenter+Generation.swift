//
//  CreateDeckPresenter+Generation.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI
import FoundationModels

// MARK: - Text Splitting

extension CreateDeckPresenter {

    func findBreak(in text: String, near target: String.Index, from start: String.Index) -> String.Index {
        let searchRadius = max(text.distance(from: start, to: target) / 3, 1)
        let searchStart = text.index(target, offsetBy: -searchRadius, limitedBy: start) ?? start
        let searchEnd = text.index(target, offsetBy: searchRadius, limitedBy: text.endIndex) ?? text.endIndex
        let window = text[searchStart..<searchEnd]

        if let range = window.range(of: "\n\n", options: .backwards) {
            return range.upperBound
        }

        if let range = window.range(of: "\n", options: .backwards) {
            return range.upperBound
        }

        for ender in [". ", "? ", "! "] {
            if let range = window.range(of: ender, options: .backwards) {
                return range.upperBound
            }
        }

        return text[target...].firstIndex(where: \.isWhitespace) ?? target
    }

    func splitText(_ text: String, into count: Int) -> [String] {
        guard count > 1 else { return [text] }

        let chunkSize = text.count / count
        var chunks = [String]()
        var startIndex = text.startIndex

        for index in 0..<count {
            if index == count - 1 {
                chunks.append(String(text[startIndex...]))
            } else {
                let targetEnd = text.index(startIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
                let breakIndex = findBreak(in: text, near: targetEnd, from: startIndex)
                chunks.append(String(text[startIndex..<breakIndex]))
                startIndex = breakIndex
            }
        }

        return chunks
    }

    /// Splits source text into chunks, ensuring at least `minBatches` chunks
    /// exist so every requested item has a batch slot.
    func makeChunks(maxTextPerBatch: Int, itemCount: Int, maxItemsPerBatch: Int) -> [String] {
        let minBatches = Int(ceil(Double(itemCount) / Double(maxItemsPerBatch)))
        let textChunks = splitTextByMaxSize(sourceText, maxChars: maxTextPerBatch)
        return textChunks.count < minBatches
            ? splitText(sourceText, into: minBatches)
            : textChunks
    }

    /// Splits text into chunks where no chunk exceeds maxChars.
    /// This guarantees every chunk stays within the context budget.
    func splitTextByMaxSize(_ text: String, maxChars: Int) -> [String] {
        guard text.count > maxChars else { return [text] }

        var chunks = [String]()
        var startIndex = text.startIndex

        while startIndex < text.endIndex {
            let remaining = text.distance(from: startIndex, to: text.endIndex)

            if remaining <= maxChars {
                chunks.append(String(text[startIndex...]))
                break
            }

            let targetEnd = text.index(startIndex, offsetBy: maxChars, limitedBy: text.endIndex) ?? text.endIndex
            let breakIndex = findBreak(in: text, near: targetEnd, from: startIndex)
            chunks.append(String(text[startIndex..<breakIndex]))
            startIndex = breakIndex
        }

        return chunks
    }
}

// MARK: - Time Estimation

extension CreateDeckPresenter {

    func updateTimeEstimate() {
        let totalProgress = flashcardProgress + quizProgress
        let totalBatches = flashcardTotal + quizTotal
        guard let startTime = generationStartTime, totalProgress > 0 else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let avgPerBatch = elapsed / Double(totalProgress)
        let remaining = totalBatches - totalProgress
        if remaining > 0 {
            estimatedSecondsRemaining = Int(ceil(avgPerBatch * Double(remaining)))
        } else {
            estimatedSecondsRemaining = nil
        }
    }
}

// MARK: - Session Configuration

extension CreateDeckPresenter {

    func makeSession() -> LanguageModelSession {
        let instructions = """
            You are an educational study aid assistant for a flashcard and quiz app. \
            Your ONLY task is to create study materials (flashcards and quiz questions) \
            EXCLUSIVELY from the source text provided by the user. \
            EVERY question, answer, and flashcard you generate MUST be directly \
            based on information found in the provided source text. \
            NEVER use outside knowledge, general trivia, or unrelated facts. \
            If a concept is not mentioned in the source text, do NOT create \
            a question about it. \
            You MUST process the source material professionally and objectively, \
            even if it covers sensitive historical events, medical topics, scientific concepts, \
            legal cases, or other academic subjects. \
            Source text may also come from fiction or fantasy books. Treat this content \
            neutrally — users study these to track characters, events, plot points, \
            and world-building details as learning material. \
            ALWAYS focus on creating accurate, educational content. \
            NEVER refuse to create study materials from legitimate text.
            """
        return LanguageModelSession(instructions: instructions)
    }

    /// Validates a single chunk by asking the model a minimal question.
    /// Returns true if the chunk is safe to generate from.
    func validateChunk(_ text: String) async -> Bool {
        let session = makeSession()
        let prompt = "Identify the main topic of this text in a few words.\n\nText:\n\(text)"

        let validationSchema = DynamicGenerationSchema(
            name: "TopicCheck",
            properties: [
                .init(name: "topic", schema: .init(type: String.self))
            ]
        )

        do {
            let schema = try GenerationSchema(root: validationSchema, dependencies: [])
            _ = try await session.respond(to: prompt, schema: schema)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Flashcard Generation

extension CreateDeckPresenter {

    func flashcardSchema(count: Int) throws -> GenerationSchema {
        let cardSchema = DynamicGenerationSchema(
            name: "Card",
            properties: [
                .init(name: "question", schema: .init(type: String.self)),
                .init(name: "answer", schema: .init(type: String.self))
            ]
        )

        let deckSchema = DynamicGenerationSchema(
            name: "Flashcards",
            properties: [
                .init(
                    name: "cards",
                    schema: .init(
                        arrayOf: cardSchema,
                        minimumElements: count,
                        maximumElements: count
                    )
                )
            ]
        )

        return try GenerationSchema(root: deckSchema, dependencies: [cardSchema])
    }

    func generateFlashcards() async throws -> [FlashcardModel] {
        let maxCardsPerBatch = 5
        let chunks = makeChunks(maxTextPerBatch: 5000, itemCount: cardCount, maxItemsPerBatch: maxCardsPerBatch)

        flashcardTotal = chunks.count
        flashcardProgress = 0
        flashcardSkippedBatches = 0
        var allFlashcards: [FlashcardModel] = []

        for chunk in chunks {
            flashcardProgress += 1

            let cardsStillNeeded = cardCount - allFlashcards.count
            guard cardsStillNeeded > 0 else { break }
            let batchCards = min(cardsStillNeeded, maxCardsPerBatch)

            flashcardStatusText = "Validating..."
            guard await validateChunk(chunk) else {
                flashcardSkippedBatches += 1
                flashcardStatusText = "Skipped"
                continue
            }

            flashcardStatusText = "Generating..."
            interactor.trackEvent(event: Event.onBatchStart(batchNumber: flashcardProgress, totalBatches: flashcardTotal, cardCount: batchCards))

            do {
                let flashcards = try await generateFlashcardBatch(text: chunk, count: batchCards)
                allFlashcards.append(contentsOf: flashcards)
                flashcardItemsGenerated = allFlashcards.count
            } catch {
                flashcardSkippedBatches += 1
                flashcardStatusText = "Skipped"
                continue
            }

            updateTimeEstimate()
        }

        return allFlashcards
    }

    private func generateFlashcardBatch(text: String, count: Int) async throws -> [FlashcardModel] {
        let session = makeSession()
        let prompt = """
        Generate exactly \(count) flashcards ONLY from the source text below. \
        Every question and answer MUST come directly from information in this text. \
        Do NOT include any questions about topics, events, or facts not explicitly \
        covered in the source text. \
        Create cards that help students learn effectively using these techniques:
        - Key definitions and terminology from the text
        - Cause and effect relationships described in the text
        - Compare and contrast concepts mentioned in the text
        - Important dates, timelines, or sequences from the text
        - Formulas, rules, or principles stated in the text
        - Key facts and their significance as presented in the text

        Each card should have a clear, specific question and a concise but \
        complete answer. Make sure there is no weird mid sentence cut off and \
        the answers also do not have a weird cutoff.

        Also make sure answers are as accurate as possible, double-check if \
        necessary.

        Source text:
        \(text)
        """

        let schema = try flashcardSchema(count: count)
        let response = try await session.respond(to: prompt, schema: schema)
        let cards = try response.content.value([GeneratedContent].self, forProperty: "cards")

        return try cards.map { card in
            let question = try card.value(String.self, forProperty: "question")
            let answer = try card.value(String.self, forProperty: "answer")
            return FlashcardModel(question: question, answer: answer)
        }
    }
}

// MARK: - Quiz Generation

extension CreateDeckPresenter {

    func multipleChoiceSchema(count: Int) throws -> GenerationSchema {
        let questionSchema = DynamicGenerationSchema(
            name: "MCQuestion",
            properties: [
                .init(name: "questionText", schema: .init(type: String.self)),
                .init(name: "option1", schema: .init(type: String.self)),
                .init(name: "option2", schema: .init(type: String.self)),
                .init(name: "option3", schema: .init(type: String.self)),
                .init(name: "option4", schema: .init(type: String.self)),
                .init(name: "correctOptionIndex", schema: .init(type: Int.self))
            ]
        )

        let rootSchema = DynamicGenerationSchema(
            name: "MCQuestions",
            properties: [
                .init(
                    name: "questions",
                    schema: .init(
                        arrayOf: questionSchema,
                        minimumElements: count,
                        maximumElements: count
                    )
                )
            ]
        )

        return try GenerationSchema(root: rootSchema, dependencies: [questionSchema])
    }

    func trueFalseSchema(count: Int) throws -> GenerationSchema {
        let statementSchema = DynamicGenerationSchema(
            name: "TFStatement",
            properties: [
                .init(name: "statement", schema: .init(type: String.self)),
                .init(name: "isTrue", schema: .init(type: Bool.self))
            ]
        )

        let rootSchema = DynamicGenerationSchema(
            name: "TFStatements",
            properties: [
                .init(
                    name: "statements",
                    schema: .init(
                        arrayOf: statementSchema,
                        minimumElements: count,
                        maximumElements: count
                    )
                )
            ]
        )

        return try GenerationSchema(root: rootSchema, dependencies: [statementSchema])
    }

    func generateQuizQuestions() async throws -> [QuizQuestionModel] {
        let maxQuestionsPerBatch = 3
        let chunks = makeChunks(maxTextPerBatch: 3000, itemCount: questionCount, maxItemsPerBatch: maxQuestionsPerBatch)

        quizTotal = chunks.count
        quizProgress = 0
        quizSkippedBatches = 0
        var allQuestions: [QuizQuestionModel] = []

        for chunk in chunks {
            quizProgress += 1

            let questionsStillNeeded = questionCount - allQuestions.count
            guard questionsStillNeeded > 0 else { break }
            let batchQuestions = min(questionsStillNeeded, maxQuestionsPerBatch)

            quizStatusText = "Validating..."
            guard await validateChunk(chunk) else {
                quizSkippedBatches += 1
                quizStatusText = "Skipped"
                continue
            }

            quizStatusText = "Generating..."
            interactor.trackEvent(event: Event.onBatchStart(batchNumber: quizProgress, totalBatches: quizTotal, cardCount: batchQuestions))

            let result = await generateQuizBatch(text: chunk, count: batchQuestions)
            allQuestions.append(contentsOf: result.questions)

            if result.skipped {
                quizSkippedBatches += 1
                quizStatusText = "Skipped"
            }

            quizItemsGenerated = allQuestions.count
            updateTimeEstimate()
        }

        allQuestions.shuffle()
        return allQuestions
    }

    private func generateQuizBatch(text: String, count: Int) async -> (questions: [QuizQuestionModel], skipped: Bool) {
        switch quizQuestionType {
        case .multipleChoice:
            do {
                let session = makeSession()
                let questions = try await generateMCQuestions(session: session, text: text, count: count)
                return (questions, false)
            } catch {
                return ([], true)
            }

        case .trueFalse:
            do {
                let session = makeSession()
                let questions = try await generateTFQuestions(session: session, text: text, count: count)
                return (questions, false)
            } catch {
                return ([], true)
            }

        case .both:
            return await generateMixedQuizBatch(text: text, count: count)
        }
    }

    private func generateMixedQuizBatch(text: String, count: Int) async -> (questions: [QuizQuestionModel], skipped: Bool) {
        let mcCount: Int
        let tfCount: Int

        if count <= 1 {
            let preferMC = quizProgress % 2 == 1
            mcCount = preferMC ? 1 : 0
            tfCount = preferMC ? 0 : 1
        } else {
            mcCount = count / 2
            tfCount = count - mcCount
        }

        var questions: [QuizQuestionModel] = []
        var succeeded = false

        if mcCount > 0 {
            do {
                let mcSession = makeSession()
                let mcQuestions = try await generateMCQuestions(session: mcSession, text: text, count: mcCount)
                questions.append(contentsOf: mcQuestions)
                succeeded = true
            } catch {
                // MC failed, continue to TF
            }
        }

        if tfCount > 0 {
            do {
                let tfSession = makeSession()
                let tfQuestions = try await generateTFQuestions(session: tfSession, text: text, count: tfCount)
                questions.append(contentsOf: tfQuestions)
                succeeded = true
            } catch {
                // TF failed
            }
        }

        return (questions, !succeeded)
    }

    func generateMCQuestions(session: LanguageModelSession, text: String, count: Int) async throws -> [QuizQuestionModel] {
        let prompt = """
        Generate exactly \(count) multiple choice questions ONLY from the source text below. \
        Every question MUST be about a topic, fact, or concept explicitly mentioned in this text. \
        Do NOT generate questions about anything not covered in the source text. \
        Each question should:
        - Have a clear, specific question derived from the text
        - Have exactly 4 answer options (one correct, three plausible distractors)
        - The correctOptionIndex should be 0, 1, 2, or 3 indicating which option is correct
        - Vary the position of the correct answer across questions

        Make sure there is no weird mid sentence cut off and \
        the answers also do not have a weird cutoff.

        Also make sure answers are as accurate as possible, double-check if \
        necessary.

        Source text:
        \(text)
        """

        let schema = try multipleChoiceSchema(count: count)
        let response = try await session.respond(to: prompt, schema: schema)
        let items = try response.content.value([GeneratedContent].self, forProperty: "questions")

        return try items.map { item in
            let questionText = try item.value(String.self, forProperty: "questionText")
            let opt1 = try item.value(String.self, forProperty: "option1")
            let opt2 = try item.value(String.self, forProperty: "option2")
            let opt3 = try item.value(String.self, forProperty: "option3")
            let opt4 = try item.value(String.self, forProperty: "option4")
            let correctIndex = try item.value(Int.self, forProperty: "correctOptionIndex")

            return QuizQuestionModel(
                questionType: .multipleChoice,
                questionText: questionText,
                options: [opt1, opt2, opt3, opt4],
                correctAnswerIndex: min(max(correctIndex, 0), 3)
            )
        }
    }

    func generateTFQuestions(session: LanguageModelSession, text: String, count: Int) async throws -> [QuizQuestionModel] {
        let prompt = """
        Generate exactly \(count) true or false statements ONLY from the source text below. \
        Every statement MUST be about a topic, fact, or concept explicitly mentioned in this text. \
        Do NOT generate statements about anything not covered in the source text. \
        Each statement should:
        - Be a clear, factual claim that is either true or false based on the text
        - Have a mix of true and false statements
        - isTrue should be true if the statement is correct, false if it's incorrect

        Source text:
        \(text)
        """

        let schema = try trueFalseSchema(count: count)
        let response = try await session.respond(to: prompt, schema: schema)
        let items = try response.content.value([GeneratedContent].self, forProperty: "statements")

        return try items.map { item in
            let statement = try item.value(String.self, forProperty: "statement")
            let isTrue = try item.value(Bool.self, forProperty: "isTrue")

            return QuizQuestionModel(
                questionType: .trueFalse,
                questionText: statement,
                options: ["True", "False"],
                correctAnswerIndex: isTrue ? 0 : 1
            )
        }
    }
}
