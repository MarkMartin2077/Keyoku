//
//  DeckDetailInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol DeckDetailInteractor: GlobalInteractor {
    func getDeck(id: String) -> DeckModel?
    func addFlashcard(question: String, answer: String, toDeckId: String) throws
    func deleteFlashcard(id: String, fromDeckId: String) throws
}

extension CoreInteractor: DeckDetailInteractor { }
