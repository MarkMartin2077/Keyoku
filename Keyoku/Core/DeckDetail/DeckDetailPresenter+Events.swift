//
//  DeckDetailPresenter+Events.swift
//  Keyoku
//

import SwiftUI

// MARK: - Events

extension DeckDetailPresenter {

    enum Event: LoggableEvent {
        // Lifecycle
        case onAppear(delegate: DeckDetailDelegate)
        case onDisappear(delegate: DeckDetailDelegate)
        // Practice
        case onPracticePressed
        case onReviewDuePressed(dueCount: Int)
        case onResetLearnedStatus
        case onResetLearnedStatusSuccess(cardCount: Int)
        case onResetLearnedStatusFail(error: Error)
        // Manual card management
        case onAddCardPressed
        case onAddCardEmptyFields
        case onAddCardSuccess
        case onAddCardFail(error: Error)
        case onDeleteCardPressed(flashcard: FlashcardModel)
        case onDeleteCardSuccess(flashcardId: String)
        case onDeleteCardFail(error: Error)
        // Edit card
        case onEditCardPressed(flashcard: FlashcardModel)
        case onEditCardSaved(flashcardId: String)
        case onEditCardSaveFail(error: Error)
        case onEditCardCancelled
        // Edit deck
        case onEditDeckPressed
        case onEditDeckSaved
        case onEditDeckSaveFail(error: Error)
        case onEditDeckCancelled
        case onEditDeckColorChanged(color: String)
        case onEditDeckImageSelected
        case onEditDeckImageRemoved
        // Generation
        case onGenerateSheetOpened
        case onSourceInputModeChanged(mode: String)
        case onPDFFileSelected(fileName: String)
        case onPDFExtractSuccess(fileName: String, pageCount: Int, textLength: Int)
        case onPDFExtractFail(error: Error)
        case onPDFPickerFail(error: Error)
        case onPDFCleared
        case onCardCountChanged(count: Int)
        case onGenerateCardsPressed(sourceTextLength: Int, cardCount: Int, sourceInputMode: String)
        case onGenerateCardsBatchStart(batchNumber: Int, totalBatches: Int, cardCount: Int)
        case onGenerateCardsSuccess(count: Int)
        case onGenerateCardsFail(error: Error)
        case onGenerateCardsSuccessDismissed

        var eventName: String {
            switch self {
            case .onAppear:                     return "DeckDetailView_Appear"
            case .onDisappear:                  return "DeckDetailView_Disappear"
            case .onPracticePressed:            return "DeckDetailView_Practice_Pressed"
            case .onReviewDuePressed:           return "DeckDetailView_ReviewDue_Pressed"
            case .onResetLearnedStatus:         return "DeckDetailView_ResetLearned_Pressed"
            case .onResetLearnedStatusSuccess:  return "DeckDetailView_ResetLearned_Success"
            case .onResetLearnedStatusFail:     return "DeckDetailView_ResetLearned_Fail"
            case .onAddCardPressed:             return "DeckDetailView_AddCard_Pressed"
            case .onAddCardEmptyFields:         return "DeckDetailView_AddCard_EmptyFields"
            case .onAddCardSuccess:             return "DeckDetailView_AddCard_Success"
            case .onAddCardFail:                return "DeckDetailView_AddCard_Fail"
            case .onDeleteCardPressed:          return "DeckDetailView_DeleteCard_Pressed"
            case .onDeleteCardSuccess:          return "DeckDetailView_DeleteCard_Success"
            case .onDeleteCardFail:             return "DeckDetailView_DeleteCard_Fail"
            case .onEditCardPressed:             return "DeckDetailView_EditCard_Pressed"
            case .onEditCardSaved:               return "DeckDetailView_EditCard_Saved"
            case .onEditCardSaveFail:            return "DeckDetailView_EditCard_SaveFail"
            case .onEditCardCancelled:           return "DeckDetailView_EditCard_Cancelled"
            case .onEditDeckPressed:             return "DeckDetailView_EditDeck_Pressed"
            case .onEditDeckSaved:               return "DeckDetailView_EditDeck_Saved"
            case .onEditDeckSaveFail:            return "DeckDetailView_EditDeck_SaveFail"
            case .onEditDeckCancelled:           return "DeckDetailView_EditDeck_Cancelled"
            case .onEditDeckColorChanged:        return "DeckDetailView_EditDeck_ColorChanged"
            case .onEditDeckImageSelected:       return "DeckDetailView_EditDeck_ImageSelected"
            case .onEditDeckImageRemoved:        return "DeckDetailView_EditDeck_ImageRemoved"
            case .onGenerateSheetOpened:        return "DeckDetailView_GenerateSheet_Opened"
            case .onSourceInputModeChanged:     return "DeckDetailView_SourceInputMode_Changed"
            case .onPDFFileSelected:            return "DeckDetailView_PDF_Selected"
            case .onPDFExtractSuccess:          return "DeckDetailView_PDF_Extract_Success"
            case .onPDFExtractFail:             return "DeckDetailView_PDF_Extract_Fail"
            case .onPDFPickerFail:              return "DeckDetailView_PDF_Picker_Fail"
            case .onPDFCleared:                 return "DeckDetailView_PDF_Cleared"
            case .onCardCountChanged:           return "DeckDetailView_CardCount_Changed"
            case .onGenerateCardsPressed:       return "DeckDetailView_GenerateCards_Pressed"
            case .onGenerateCardsBatchStart:    return "DeckDetailView_GenerateCards_Batch_Start"
            case .onGenerateCardsSuccess:       return "DeckDetailView_GenerateCards_Success"
            case .onGenerateCardsFail:          return "DeckDetailView_GenerateCards_Fail"
            case .onGenerateCardsSuccessDismissed: return "DeckDetailView_GenerateCards_SuccessDismissed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onReviewDuePressed(dueCount: let count):
                return ["due_count": count]
            case .onDeleteCardPressed(flashcard: let flashcard):
                return flashcard.eventParameters
            case .onDeleteCardSuccess(flashcardId: let id):
                return ["flashcard_id": id]
            case .onEditCardPressed(flashcard: let flashcard):
                return flashcard.eventParameters
            case .onEditCardSaved(flashcardId: let id):
                return ["flashcard_id": id]
            case .onEditDeckColorChanged(color: let color):
                return ["color": color]
            case .onResetLearnedStatusSuccess(cardCount: let count):
                return ["card_count": count]
            case .onAddCardFail(error: let error), .onDeleteCardFail(error: let error), .onEditCardSaveFail(error: let error),
                 .onEditDeckSaveFail(error: let error), .onPDFExtractFail(error: let error), .onPDFPickerFail(error: let error),
                 .onGenerateCardsFail(error: let error), .onResetLearnedStatusFail(error: let error):
                return error.eventParameters
            case .onSourceInputModeChanged(mode: let mode):
                return ["source_input_mode": mode]
            case .onPDFFileSelected(fileName: let name):
                return ["file_name": name]
            case .onPDFExtractSuccess(fileName: let name, pageCount: let pages, textLength: let length):
                return ["file_name": name, "page_count": pages, "text_length": length]
            case .onCardCountChanged(count: let count):
                return ["card_count": count]
            case .onGenerateCardsPressed(sourceTextLength: let length, cardCount: let count, sourceInputMode: let mode):
                return ["source_text_length": length, "card_count": count, "source_input_mode": mode]
            case .onGenerateCardsBatchStart(batchNumber: let batch, totalBatches: let total, cardCount: let cards):
                return ["batch_number": batch, "total_batches": total, "batch_card_count": cards]
            case .onGenerateCardsSuccess(count: let count):
                return ["card_count": count]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onAddCardFail, .onDeleteCardFail, .onEditCardSaveFail, .onEditDeckSaveFail,
                 .onPDFExtractFail, .onPDFPickerFail, .onGenerateCardsFail, .onResetLearnedStatusFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
