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
        case onSessionStarted(limit: Int?, totalCards: Int)
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
        case onGenerateCardsSuccess(count: Int)
        case onGenerateCardsFail(failure: GenerationFailure)
        case onGenerateCardsSuccessDismissed
        case onCancelGenerationPressed(cardsSoFar: Int)
        case onSaveGeneratedCardsFail(error: Error)
        case onOpenSettingsPressed
        // Quizzes
        case onQuizPressed(quiz: QuizModel)
        case onQuizDeletePressed(quiz: QuizModel)
        case onQuizDeleteConfirmed(quiz: QuizModel)
        case onQuizDeleteSuccess(quizId: String)
        case onQuizDeleteFail(error: Error)
        case onQuizNewCardPressed(status: NewQuizCardStatus)
        case onQuizNewSheetCancelled
        case onQuizCountChanged(count: Int)
        case onQuizMakePressed(questionCount: Int, sourceLength: Int)
        case onQuizMakeSuccess(quiz: QuizModel, requestedCount: Int)
        case onQuizMakeFail(error: Error)
        case onQuizMakeCancelled(questionsSoFar: Int)
        case onQuizCancelCleanupFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                     return "DeckDetailView_Appear"
            case .onDisappear:                  return "DeckDetailView_Disappear"
            case .onPracticePressed:            return "DeckDetailView_Practice_Pressed"
            case .onSessionStarted:             return "DeckDetailView_Session_Started"
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
            case .onGenerateCardsSuccess:       return "DeckDetailView_GenerateCards_Success"
            case .onGenerateCardsFail:          return "DeckDetailView_GenerateCards_Fail"
            case .onGenerateCardsSuccessDismissed: return "DeckDetailView_GenerateCards_SuccessDismissed"
            case .onCancelGenerationPressed:    return "DeckDetailView_CancelGeneration_Pressed"
            case .onSaveGeneratedCardsFail:     return "DeckDetailView_SaveGeneratedCards_Fail"
            case .onOpenSettingsPressed:        return "DeckDetailView_OpenSettings_Pressed"
            case .onQuizPressed:                return "DeckDetailView_Quiz_Pressed"
            case .onQuizDeletePressed:          return "DeckDetailView_QuizDelete_Pressed"
            case .onQuizDeleteConfirmed:        return "DeckDetailView_QuizDelete_Confirmed"
            case .onQuizDeleteSuccess:          return "DeckDetailView_QuizDelete_Success"
            case .onQuizDeleteFail:             return "DeckDetailView_QuizDelete_Fail"
            case .onQuizNewCardPressed:         return "DeckDetailView_QuizNewCard_Pressed"
            case .onQuizNewSheetCancelled:      return "DeckDetailView_QuizNewSheet_Cancelled"
            case .onQuizCountChanged:           return "DeckDetailView_QuizCount_Changed"
            case .onQuizMakePressed:            return "DeckDetailView_QuizMake_Pressed"
            case .onQuizMakeSuccess:            return "DeckDetailView_QuizMake_Success"
            case .onQuizMakeFail:               return "DeckDetailView_QuizMake_Fail"
            case .onQuizMakeCancelled:          return "DeckDetailView_QuizMake_Cancelled"
            case .onQuizCancelCleanupFail:      return "DeckDetailView_QuizCancelCleanup_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onSessionStarted(limit: let limit, totalCards: let total):
                return ["card_limit": limit as Any, "total_cards": total]
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
                 .onSaveGeneratedCardsFail(error: let error), .onResetLearnedStatusFail(error: let error):
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
            case .onGenerateCardsFail(failure: let failure):
                return ["failure": failure.analyticsName]
            case .onCancelGenerationPressed(cardsSoFar: let count):
                return ["cards_so_far": count]
            case .onGenerateCardsSuccess(count: let count):
                return ["card_count": count]
            case .onQuizPressed(quiz: let quiz), .onQuizDeletePressed(quiz: let quiz), .onQuizDeleteConfirmed(quiz: let quiz):
                return quiz.eventParameters
            case .onQuizDeleteSuccess(quizId: let id):
                return ["quiz_id": id]
            case .onQuizDeleteFail(error: let error), .onQuizCancelCleanupFail(error: let error):
                return error.eventParameters
            case .onQuizNewCardPressed(status: let status):
                return ["new_quiz_card_status": status.analyticsName]
            case .onQuizCountChanged(count: let count):
                return ["question_count": count]
            case .onQuizMakePressed(questionCount: let count, sourceLength: let length):
                return ["question_count": count, "source_text_length": length]
            case .onQuizMakeSuccess(quiz: let quiz, requestedCount: let requested):
                var params = quiz.eventParameters
                params["requested_question_count"] = requested
                return params
            case .onQuizMakeFail(error: let error):
                if let quizError = error as? QuizGenerationError {
                    return ["failure": quizError.analyticsName]
                }
                return error.eventParameters
            case .onQuizMakeCancelled(questionsSoFar: let count):
                return ["questions_so_far": count]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onAddCardFail, .onDeleteCardFail, .onEditCardSaveFail, .onEditDeckSaveFail,
                 .onPDFExtractFail, .onPDFPickerFail, .onGenerateCardsFail, .onSaveGeneratedCardsFail, .onResetLearnedStatusFail,
                 .onQuizDeleteFail, .onQuizMakeFail, .onQuizCancelCleanupFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
