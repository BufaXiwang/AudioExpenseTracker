//
//  AudioExpenseTrackerApp.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI
import SwiftData

@main
struct AudioExpenseTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: ExpenseRecord.self)
        }
    }
}
