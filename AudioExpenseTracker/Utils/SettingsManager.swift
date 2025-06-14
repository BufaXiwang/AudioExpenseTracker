//
//  SettingsManager.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation
import Combine

@MainActor
class SettingsManager: ObservableObject {
    @Published var recordingMode: RecordingMode = .tap
    @Published var showRecordingInstructions: Bool = true
    @Published var autoSaveAfterRecording: Bool = false
    @Published var vibrationFeedback: Bool = true
    
    private let userDefaults = UserDefaults.standard
    
    // UserDefaults keys
    private enum Keys {
        static let recordingMode = "recordingMode"
        static let showRecordingInstructions = "showRecordingInstructions"
        static let autoSaveAfterRecording = "autoSaveAfterRecording"
        static let vibrationFeedback = "vibrationFeedback"
    }
    
    init() {
        loadSettings()
        setupObservers()
    }
    
    private func loadSettings() {
        // 加载录音模式
        if let modeString = userDefaults.string(forKey: Keys.recordingMode),
           let mode = RecordingMode(rawValue: modeString) {
            recordingMode = mode
        }
        
        // 加载其他设置
        showRecordingInstructions = userDefaults.bool(forKey: Keys.showRecordingInstructions)
        autoSaveAfterRecording = userDefaults.bool(forKey: Keys.autoSaveAfterRecording)
        vibrationFeedback = userDefaults.bool(forKey: Keys.vibrationFeedback)
        
        // 设置默认值（首次启动）
        if !userDefaults.bool(forKey: "hasLaunchedBefore") {
            showRecordingInstructions = true
            vibrationFeedback = true
            userDefaults.set(true, forKey: "hasLaunchedBefore")
        }
    }
    
    private func setupObservers() {
        // 监听设置变化并自动保存
        $recordingMode
            .sink { [weak self] mode in
                self?.userDefaults.set(mode.rawValue, forKey: Keys.recordingMode)
            }
            .store(in: &cancellables)
        
        $showRecordingInstructions
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: Keys.showRecordingInstructions)
            }
            .store(in: &cancellables)
        
        $autoSaveAfterRecording
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: Keys.autoSaveAfterRecording)
            }
            .store(in: &cancellables)
        
        $vibrationFeedback
            .sink { [weak self] value in
                self?.userDefaults.set(value, forKey: Keys.vibrationFeedback)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 便捷方法
    
    func resetToDefaults() {
        recordingMode = .tap
        showRecordingInstructions = true
        autoSaveAfterRecording = false
        vibrationFeedback = true
    }
    
    func toggleRecordingMode() {
        recordingMode = recordingMode == .tap ? .holdToRecord : .tap
    }
} 