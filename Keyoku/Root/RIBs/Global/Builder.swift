//
//  Builder.swift
//  Keyoku
//
//  
//
import SwiftUI

@MainActor
protocol Builder {
    func build() -> AnyView
}
