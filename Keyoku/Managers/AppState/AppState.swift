//
//  AppState.swift
//  Keyoku
//
//  
//
import SwiftUI
import SwiftfulRouting

@MainActor
@Observable
class AppState {
    
    let startingModuleId: String
    
    init(startingModuleId: String? = nil) {
        self.startingModuleId = startingModuleId ?? UserDefaults.lastModuleId
    }
    
}
