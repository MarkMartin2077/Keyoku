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

    enum SourceInputMode: String, CaseIterable {
        case text = "Paste Text"
        case pdf = "Upload PDF"
    }
    
    private let interactor: CreateDeckInteractor
    private let router: CreateDeckRouter
    
    var creationMode: CreationMode = .generate
    var cardCount: Int = 10
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
    
    init(interactor: CreateDeckInteractor, router: CreateDeckRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: CreateDeckDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: CreateDeckDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
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
                let flashcards = try await generateFlashcards()
                interactor.trackEvent(event: Event.onGenerateSuccess(cardCount: flashcards.count))

                let savedImageUrl = try saveImageIfNeeded()

                try interactor.createDeck(
                    name: deckName.trimmingCharacters(in: .whitespacesAndNewlines),
                    color: selectedColor,
                    imageUrl: savedImageUrl,
                    sourceText: sourceText,
                    flashcards: flashcards
                )

                isGenerating = false
                router.dismiss()

            } catch {
                interactor.trackEvent(event: Event.onGenerateFail(error: error))
                isGenerating = false
            }
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
    
    // MARK: - Image Saving

    private func saveImageIfNeeded() throws -> String? {
        guard let selectedImage, let imageData = selectedImage.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        return try interactor.saveDeckImage(data: imageData)
    }

    // MARK: - PDF Extraction

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

    // MARK: - Text Splitting
    
    private func findBreak(in text: String, near target: String.Index, from start: String.Index) -> String.Index {
        let searchRadius = max(text.distance(from: start, to: target) / 3, 1)
        let searchStart = text.index(target, offsetBy: -searchRadius, limitedBy: start) ?? start
        let searchEnd = text.index(target, offsetBy: searchRadius, limitedBy: text.endIndex) ?? text.endIndex
        let window = text[searchStart..<searchEnd]
        
        // Best: paragraph break
        if let range = window.range(of: "\n\n", options: .backwards) {
            return range.upperBound
        }
        
        // Good: line break
        if let range = window.range(of: "\n", options: .backwards) {
            return range.upperBound
        }
        
        // Okay: sentence break
        for ender in [". ", "? ", "! "] {
            if let range = window.range(of: ender, options: .backwards) {
                return range.upperBound
            }
        }
        
        // Last resort: next whitespace after target
        return text[target...].firstIndex(where: \.isWhitespace) ?? target
    }
    
    private func splitText(_ text: String, into count: Int) -> [String] {
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
    
    private func makeBatches() -> [(text: String, cards: Int)] {
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
    
    // MARK: - Generation
    
    private func flashcardSchema(count: Int) throws -> GenerationSchema {
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
    
    private func generateFlashcards() async throws -> [FlashcardModel] {
        let batches = makeBatches()
        generationTotal = batches.count
        generationProgress = 0
        
        var allFlashcards: [FlashcardModel] = []
        
        for batch in batches {
            generationProgress += 1
            interactor.trackEvent(event: Event.onBatchStart(batchNumber: generationProgress, totalBatches: generationTotal, cardCount: batch.cards))
            
            let session = LanguageModelSession()
            let prompt = """
            Generate exactly \(batch.cards) flashcards from the following text. Create cards that help \
            students learn effectively using these techniques:
            - Key definitions and terminology
            - Cause and effect relationships
            - Compare and contrast important concepts
            - Important dates, timelines, or sequences
            - Formulas, rules, or principles
            - Key facts and their significance

            Each card should have a clear, specific question and a concise but \
            complete answer.

            Text:
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

extension CreateDeckPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: CreateDeckDelegate)
        case onDisappear(delegate: CreateDeckDelegate)
        case onColorSelected(color: DeckColor)
        case onCardCountChanged(count: Int)
        case onCreationModeChanged(mode: String)
        case onImageSelected
        case onImageRemoved
        case onSourceInputModeChanged(mode: String)
        case onPDFFileSelected(fileName: String)
        case onPDFExtractSuccess(fileName: String, pageCount: Int, textLength: Int)
        case onPDFExtractFail(error: Error)
        case onPDFPickerFail(error: Error)
        case onPDFCleared
        case onCancelPressed
        case onGeneratePressed(sourceTextLength: Int, cardCount: Int, sourceInputMode: String)
        case onBatchStart(batchNumber: Int, totalBatches: Int, cardCount: Int)
        case onGenerateSuccess(cardCount: Int)
        case onGenerateFail(error: Error)
        case onCreateEmptyPressed
        case onCreateEmptySuccess
        case onCreateEmptyFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                 return "CreateDeckView_Appear"
            case .onDisappear:              return "CreateDeckView_Disappear"
            case .onColorSelected:          return "CreateDeckView_ColorSelected"
            case .onCardCountChanged:       return "CreateDeckView_CardCount_Changed"
            case .onCreationModeChanged:    return "CreateDeckView_CreationMode_Changed"
            case .onImageSelected:          return "CreateDeckView_Image_Selected"
            case .onImageRemoved:           return "CreateDeckView_Image_Removed"
            case .onSourceInputModeChanged: return "CreateDeckView_SourceInputMode_Changed"
            case .onPDFFileSelected:        return "CreateDeckView_PDF_Selected"
            case .onPDFExtractSuccess:      return "CreateDeckView_PDF_Extract_Success"
            case .onPDFExtractFail:         return "CreateDeckView_PDF_Extract_Fail"
            case .onPDFPickerFail:          return "CreateDeckView_PDF_Picker_Fail"
            case .onPDFCleared:             return "CreateDeckView_PDF_Cleared"
            case .onCancelPressed:          return "CreateDeckView_Cancel"
            case .onGeneratePressed:        return "CreateDeckView_Generate_Pressed"
            case .onBatchStart:             return "CreateDeckView_Batch_Start"
            case .onGenerateSuccess:        return "CreateDeckView_Generate_Success"
            case .onGenerateFail:           return "CreateDeckView_Generate_Fail"
            case .onCreateEmptyPressed:     return "CreateDeckView_CreateEmpty_Pressed"
            case .onCreateEmptySuccess:     return "CreateDeckView_CreateEmpty_Success"
            case .onCreateEmptyFail:        return "CreateDeckView_CreateEmpty_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onColorSelected(color: let color):
                return ["color": color.rawValue]
            case .onCardCountChanged(count: let count):
                return ["card_count": count]
            case .onCreationModeChanged(mode: let mode):
                return ["creation_mode": mode]
            case .onSourceInputModeChanged(mode: let mode):
                return ["source_input_mode": mode]
            case .onPDFFileSelected(fileName: let name):
                return ["file_name": name]
            case .onPDFExtractSuccess(fileName: let name, pageCount: let pages, textLength: let length):
                return ["file_name": name, "page_count": pages, "text_length": length]
            case .onPDFExtractFail(error: let error):
                return error.eventParameters
            case .onPDFPickerFail(error: let error):
                return error.eventParameters
            case .onGeneratePressed(sourceTextLength: let length, cardCount: let count, sourceInputMode: let mode):
                return ["source_text_length": length, "card_count": count, "source_input_mode": mode]
            case .onBatchStart(batchNumber: let batch, totalBatches: let total, cardCount: let cards):
                return ["batch_number": batch, "total_batches": total, "batch_card_count": cards]
            case .onGenerateSuccess(cardCount: let count):
                return ["card_count": count]
            case .onGenerateFail(error: let error):
                return error.eventParameters
            case .onCreateEmptyFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .onGenerateFail, .onCreateEmptyFail, .onPDFExtractFail, .onPDFPickerFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
