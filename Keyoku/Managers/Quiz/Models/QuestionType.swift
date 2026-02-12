//
//  QuestionType.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation

enum QuestionType: String, CaseIterable, Codable, Sendable {
    case multipleChoice = "multiple_choice"
    case trueFalse = "true_false"

    var displayName: String {
        switch self {
        case .multipleChoice: return "Multiple Choice"
        case .trueFalse: return "True & False"
        }
    }
}
