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
}

// MARK: - Session Configuration

extension CreateDeckPresenter {

    func makeSession() -> LanguageModelSession {
        let instructions = """
            You are an educational study aid assistant for a flashcard and quiz app. \
            Your ONLY task is to create study materials (flashcards and quiz questions) \
            from academic source text provided by students. \
            You MUST process the source material professionally and objectively, \
            even if it covers sensitive historical events, medical topics, scientific concepts, \
            legal cases, or other academic subjects. \
            ALWAYS focus on creating accurate, educational content. \
            NEVER refuse to create study materials from legitimate academic text.
            """
        return LanguageModelSession(instructions: instructions)
    }
}

// MARK: - Flashcard Generation

extension CreateDeckPresenter {

    func makeBatches() -> [(text: String, cards: Int)] {
        let perBatchBudget = 9500
        let charsPerCard = 250
        let totalNeeded = sourceText.count + (cardCount * charsPerCard)
        let numberOfBatches = max((totalNeeded + perBatchBudget - 1) / perBatchBudget, 1)

        let textChunks = splitText(sourceText, into: numberOfBatches)
        var batches = [(text: String, cards: Int)]()
        var cardsRemaining = cardCount

        for (index, chunk) in textChunks.enumerated() {
            let batchesLeft = textChunks.count - index
            let cardsInBatch = cardsRemaining / batchesLeft
            batches.append((text: chunk, cards: cardsInBatch))
            cardsRemaining -= cardsInBatch
        }

        return batches
    }

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
        let batches = makeBatches()
        generationTotal = batches.count
        generationProgress = 0

        var allFlashcards: [FlashcardModel] = []

        for batch in batches {
            generationProgress += 1
            interactor.trackEvent(event: Event.onBatchStart(batchNumber: generationProgress, totalBatches: generationTotal, cardCount: batch.cards))

            let session = makeSession()
            let prompt = """
            You are creating educational study flashcards for a student. \
            Generate exactly \(batch.cards) flashcards from the following academic study material. \
            Create cards that help students learn effectively using these techniques:
            - Key definitions and terminology
            - Cause and effect relationships
            - Compare and contrast important concepts
            - Important dates, timelines, or sequences
            - Formulas, rules, or principles
            - Key facts and their significance

            Each card should have a clear, specific question and a concise but \
            complete answer. Make sure there is no weird mid sentence cut off and \
            the answers also do not have a weird cutoff.

            Also make sure answers are as accurate as possible, double-check if \
            necessary.

            Academic study material:
            \(batch.text)
            """

            let schema = try flashcardSchema(count: batch.cards)
            let response = try await session.respond(to: prompt, schema: schema)
            let cards = try response.content.value([GeneratedContent].self, forProperty: "cards")

            let flashcards = try cards.map { card in
                let question = try card.value(String.self, forProperty: "question")
                let answer = try card.value(String.self, forProperty: "answer")
                return FlashcardModel(question: question, answer: answer)
            }

            allFlashcards.append(contentsOf: flashcards)
        }

        return allFlashcards
    }
}

// MARK: - Quiz Generation

extension CreateDeckPresenter {

    func makeQuizBatches() -> [(text: String, questions: Int)] {
        let perBatchBudget = 9500
        let charsPerQuestion = 300
        let totalNeeded = sourceText.count + (questionCount * charsPerQuestion)
        let numberOfBatches = max((totalNeeded + perBatchBudget - 1) / perBatchBudget, 1)

        let textChunks = splitText(sourceText, into: numberOfBatches)
        var batches = [(text: String, questions: Int)]()
        var questionsRemaining = questionCount

        for (index, chunk) in textChunks.enumerated() {
            let batchesLeft = textChunks.count - index
            let questionsInBatch = questionsRemaining / batchesLeft
            batches.append((text: chunk, questions: questionsInBatch))
            questionsRemaining -= questionsInBatch
        }

        return batches
    }

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
        let batches = makeQuizBatches()
        generationTotal += batches.count
        var allQuestions: [QuizQuestionModel] = []

        for batch in batches {
            generationProgress += 1
            interactor.trackEvent(event: Event.onBatchStart(batchNumber: generationProgress, totalBatches: generationTotal, cardCount: batch.questions))

            let session = makeSession()

            switch quizQuestionType {
            case .multipleChoice:
                let questions = try await generateMCQuestions(session: session, text: batch.text, count: batch.questions)
                allQuestions.append(contentsOf: questions)

            case .trueFalse:
                let questions = try await generateTFQuestions(session: session, text: batch.text, count: batch.questions)
                allQuestions.append(contentsOf: questions)

            case .both:
                let mcCount = batch.questions / 2
                let tfCount = batch.questions - mcCount

                if mcCount > 0 {
                    let mcQuestions = try await generateMCQuestions(session: session, text: batch.text, count: mcCount)
                    allQuestions.append(contentsOf: mcQuestions)
                }
                if tfCount > 0 {
                    let tfQuestions = try await generateTFQuestions(session: session, text: batch.text, count: tfCount)
                    allQuestions.append(contentsOf: tfQuestions)
                }
            }
        }

        allQuestions.shuffle()
        return allQuestions
    }

    func generateMCQuestions(session: LanguageModelSession, text: String, count: Int) async throws -> [QuizQuestionModel] {
        let prompt = """
        You are creating an educational quiz for a student. \
        Generate exactly \(count) multiple choice questions from the following academic study material. \
        Each question should:
        - Have a clear, specific question
        - Have exactly 4 answer options (one correct, three plausible distractors)
        - The correctOptionIndex should be 0, 1, 2, or 3 indicating which option is correct
        - Vary the position of the correct answer across questions

        Make sure there is no weird mid sentence cut off and \
        the answers also do not have a weird cutoff.

        Also make sure answers are as accurate as possible, double-check if \
        necessary.

        Academic study material:
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
        You are creating an educational quiz for a student. \
        Generate exactly \(count) true or false statements from the following academic study material. \
        Each statement should:
        - Be a clear, factual claim that is either true or false based on the text
        - Have a mix of true and false statements
        - isTrue should be true if the statement is correct, false if it's incorrect

        Academic study material:
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
