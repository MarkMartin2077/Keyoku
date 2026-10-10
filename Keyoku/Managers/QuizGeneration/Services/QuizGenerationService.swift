//
//  QuizGenerationService.swift
//  Keyoku
//

import Foundation

/// One quiz question as streamed by the model. While streaming, fields may be empty or still growing
/// and `wrongAnswers` may hold fewer than three answers.
struct GeneratedQuizQuestionDraft: Equatable, Sendable {
    let question: String
    let correctAnswer: String
    let wrongAnswers: [String]
    let explanation: String
}

@MainActor
protocol QuizGenerationService: GenerationModelService {
    /// Tokens the quiz response schema adds to each call.
    func schemaTokenCount() async -> Int

    /// Each element is every question generated so far in this call, not a delta.
    func streamQuizQuestions(prompt: String, instructions: String) -> AsyncThrowingStream<[GeneratedQuizQuestionDraft], Error>

    /// One small request on the on-device model, whatever model the run used. Throws when there is no on-device model.
    func generateQuizTitle(prompt: String, instructions: String) async throws -> String
}
