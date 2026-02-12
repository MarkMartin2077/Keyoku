//
//  CreateDeckPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import UIKit
import PDFKit
import FoundationModels

@Observable
@MainActor
class CreateDeckPresenter {

    enum CreationMode: String, CaseIterable {
        case generate = "Generate with AI"
        case empty = "Start Empty"
    }

    enum ContentType: String, CaseIterable {
        case flashcards = "Flashcards"
        case quiz = "Quiz"
        case both = "Both"
    }

    enum QuizQuestionType: String, CaseIterable {
        case multipleChoice = "Multiple Choice"
        case trueFalse = "True & False"
        case both = "Both"
    }

    enum SourceInputMode: String, CaseIterable {
        case text = "Paste Text"
        case pdf = "Upload PDF"
    }

    let interactor: CreateDeckInteractor
    private let router: CreateDeckRouter

    var creationMode: CreationMode = .generate
    var contentType: ContentType = .flashcards
    var cardCount: Int = 10
    var questionCount: Int = 10
    var quizQuestionType: QuizQuestionType = .both
    var deckName: String = ""
    var selectedColor: DeckColor = .blue
    var selectedImage: UIImage?
    var sourceText: String = ""
    var isGenerating: Bool = false
    var generationProgress: Int = 0
    var generationTotal: Int = 0

    var sourceInputMode: SourceInputMode = .text
    var pdfFileName: String?
    var pdfPageCount: Int?
    var isExtractingPDF: Bool = false
    var pdfError: String?

    var canGenerate: Bool {
        !deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isGenerating
    }

    var canCreateEmpty: Bool {
        !deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(interactor: CreateDeckInteractor, router: CreateDeckRouter, defaultContentType: CreateDeckPresenter.ContentType? = nil) {
        self.interactor = interactor
        self.router = router
        if let defaultContentType {
            self.contentType = defaultContentType
        }
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: CreateDeckDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: CreateDeckDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    // MARK: - Settings Actions

    func onColorSelected(_ color: DeckColor) {
        interactor.trackEvent(event: Event.onColorSelected(color: color))
        selectedColor = color
    }

    func onCardCountChanged(_ count: Int) {
        interactor.trackEvent(event: Event.onCardCountChanged(count: count))
        cardCount = count
    }

    func onCreationModeChanged(_ mode: CreationMode) {
        interactor.trackEvent(event: Event.onCreationModeChanged(mode: mode.rawValue))
        creationMode = mode
    }

    func onContentTypeChanged(_ type: ContentType) {
        interactor.trackEvent(event: Event.onContentTypeChanged(contentType: type.rawValue))
        contentType = type
    }

    func onQuestionCountChanged(_ count: Int) {
        interactor.trackEvent(event: Event.onQuestionCountChanged(count: count))
        questionCount = count
    }

    func onQuizQuestionTypeChanged(_ type: QuizQuestionType) {
        interactor.trackEvent(event: Event.onQuizQuestionTypeChanged(questionType: type.rawValue))
        quizQuestionType = type
    }

    // MARK: - Image Actions

    func onImageDataLoaded(_ data: Data) {
        interactor.trackEvent(event: Event.onImageSelected)
        if let image = UIImage(data: data) {
            selectedImage = image
        }
    }

    func onRemoveImage() {
        interactor.trackEvent(event: Event.onImageRemoved)
        selectedImage = nil
    }

    // MARK: - Source Input Actions

    func onSourceInputModeChanged(_ mode: SourceInputMode) {
        interactor.trackEvent(event: Event.onSourceInputModeChanged(mode: mode.rawValue))
        sourceInputMode = mode
        pdfError = nil

        if mode == .text {
            pdfFileName = nil
            pdfPageCount = nil
            sourceText = ""
        }
    }

    func onPDFFileSelected(result: Result<URL, Error>) {
        pdfError = nil

        switch result {
        case .success(let url):
            let fileName = url.lastPathComponent
            interactor.trackEvent(event: Event.onPDFFileSelected(fileName: fileName))
            isExtractingPDF = true

            do {
                let text = try extractText(from: url)
                sourceText = text
                pdfFileName = fileName
                isExtractingPDF = false
                interactor.trackEvent(event: Event.onPDFExtractSuccess(fileName: fileName, pageCount: pdfPageCount ?? 0, textLength: text.count))
            } catch {
                isExtractingPDF = false
                pdfError = error.localizedDescription
                interactor.trackEvent(event: Event.onPDFExtractFail(error: error))
            }

        case .failure(let error):
            pdfError = error.localizedDescription
            interactor.trackEvent(event: Event.onPDFPickerFail(error: error))
        }
    }

    func onClearPDF() {
        interactor.trackEvent(event: Event.onPDFCleared)
        sourceText = ""
        pdfFileName = nil
        pdfPageCount = nil
        pdfError = nil
    }

    // MARK: - Primary Actions

    func onCancelPressed() {
        interactor.trackEvent(event: Event.onCancelPressed)
        router.dismiss()
    }

    func onGeneratePressed() {
        interactor.trackEvent(event: Event.onGeneratePressed(sourceTextLength: sourceText.count, cardCount: cardCount, sourceInputMode: sourceInputMode.rawValue))

        guard canGenerate else { return }

        isGenerating = true

        Task {
            do {
                try await performGeneration()
                isGenerating = false
                router.dismiss()
            } catch {
                interactor.trackEvent(event: Event.onGenerateFail(error: error))
                isGenerating = false
            }
        }
    }

    private func performGeneration() async throws {
        let trimmedName = deckName.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedImageUrl = try saveImageIfNeeded()

        if contentType == .flashcards || contentType == .both {
            let flashcards = try await generateFlashcards()
            interactor.trackEvent(event: Event.onGenerateSuccess(cardCount: flashcards.count))

            try interactor.createDeck(
                name: trimmedName,
                color: selectedColor,
                imageUrl: savedImageUrl,
                sourceText: sourceText,
                flashcards: flashcards
            )
        }

        if contentType == .quiz || contentType == .both {
            let questions = try await generateQuizQuestions()
            interactor.trackEvent(event: Event.onQuizGenerateSuccess(questionCount: questions.count))

            try interactor.createQuiz(
                name: trimmedName,
                color: selectedColor,
                sourceText: sourceText,
                questions: questions
            )
        }
    }

    func onCreateEmptyPressed() {
        interactor.trackEvent(event: Event.onCreateEmptyPressed)

        guard canCreateEmpty else { return }

        do {
            let savedImageUrl = try saveImageIfNeeded()

            try interactor.createDeck(
                name: deckName.trimmingCharacters(in: .whitespacesAndNewlines),
                color: selectedColor,
                imageUrl: savedImageUrl,
                sourceText: ""
            )

            interactor.trackEvent(event: Event.onCreateEmptySuccess)
            router.dismiss()
        } catch {
            interactor.trackEvent(event: Event.onCreateEmptyFail(error: error))
        }
    }

    // MARK: - Helpers

    private func saveImageIfNeeded() throws -> String? {
        guard let selectedImage, let imageData = selectedImage.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        return try interactor.saveDeckImage(data: imageData)
    }

    private func extractText(from url: URL) throws -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: url) else {
            throw AppError("Could not read the PDF. The file may be damaged or password-protected.")
        }

        guard document.pageCount > 0 else {
            throw AppError("The PDF has no pages.")
        }

        pdfPageCount = document.pageCount

        var pages: [String] = []
        for index in 0..<document.pageCount {
            if let page = document.page(at: index), let text = page.string, !text.isEmpty {
                pages.append(text)
            }
        }

        let fullText = pages.joined(separator: "\n\n")

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError("No readable text found in the PDF. It may contain only images or scanned content.")
        }

        return fullText
    }
}
