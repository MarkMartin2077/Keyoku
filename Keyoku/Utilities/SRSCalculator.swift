//
//  SRSCalculator.swift
//  Keyoku
//

import Foundation

struct SRSResult {
    let repetitions: Int
    let interval: Int      // days until next review
    let easeFactor: Double
    let dueDate: Date
}

enum SRSRating {
    case again  // swipe left (still learning)
    case good   // swipe right (learned)
}

struct SRSCalculator {

    static func calculate(card: FlashcardModel, rating: SRSRating) -> SRSResult {
        let calendar = Calendar.current
        let now = Date()

        switch rating {
        case .again:
            let newEaseFactor = max(1.3, card.easeFactor - 0.2)
            let dueDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return SRSResult(repetitions: 0, interval: 1, easeFactor: newEaseFactor, dueDate: dueDate)

        case .good:
            switch card.repetitions {
            case 0:
                let dueDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
                return SRSResult(repetitions: 1, interval: 1, easeFactor: card.easeFactor, dueDate: dueDate)
            case 1:
                let dueDate = calendar.date(byAdding: .day, value: 6, to: now) ?? now
                return SRSResult(repetitions: 2, interval: 6, easeFactor: card.easeFactor, dueDate: dueDate)
            default:
                let newInterval = max(1, Int((Double(card.interval) * card.easeFactor).rounded()))
                let newEaseFactor = min(2.5, card.easeFactor + 0.1)
                let dueDate = calendar.date(byAdding: .day, value: newInterval, to: now) ?? now
                return SRSResult(repetitions: card.repetitions + 1, interval: newInterval, easeFactor: newEaseFactor, dueDate: dueDate)
            }
        }
    }
}
