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
    // 初始化数据存储服务
    @StateObject private var dataService = DataStorageService()
    @StateObject private var voiceService = VoiceRecognitionService()
    @StateObject private var aiService = AIAnalysisService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataService)
                .environmentObject(voiceService)
                .environmentObject(aiService)
                .modelContainer(dataService.getModelContainer())
        }
    }
}
