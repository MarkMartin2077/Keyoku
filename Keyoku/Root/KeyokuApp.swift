//
//  KeyokuApp.swift
//  Keyoku
//
//  
//

import SwiftUI
import SwiftfulRouting

@main
struct AppEntryPoint {
    
    /// Entry point is either (1) empty build for Unit Testing or (2) actual app.
    static func main() {
        if Utilities.isUnitTesting {
            AppViewForUnitTesting.main()
        } else {
            KeyokuApp.main()
        }
    }
}

struct KeyokuApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            Group {
                if Utilities.isUITesting {
                    AppViewForUITesting(container: delegate.dependencies.container)
                } else {
                    delegate.builder.build()
                }
            }
        }
    }
}
