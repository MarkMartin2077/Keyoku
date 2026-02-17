//
//  CreateDeckPresenter+Event.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

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
        case onSuccessDismissPressed
        case onCreateEmptyPressed
        case onCreateEmptySuccess
        case onCreateEmptyFail(error: Error)
        case onFirstDeckCelebrationDismissed

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
            case .onSuccessDismissPressed:   return "CreateDeckView_SuccessDismiss_Pressed"
            case .onCreateEmptyPressed:     return "CreateDeckView_CreateEmpty_Pressed"
            case .onCreateEmptySuccess:     return "CreateDeckView_CreateEmpty_Success"
            case .onCreateEmptyFail:        return "CreateDeckView_CreateEmpty_Fail"
            case .onFirstDeckCelebrationDismissed: return "CreateDeckView_FirstDeckCelebration_Dismissed"
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
