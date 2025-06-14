//
//  HapticFeedback.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import UIKit

struct HapticFeedback {
    
    // MARK: - 冲击反馈
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // MARK: - 通知反馈
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    // MARK: - 选择反馈
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - 录音相关反馈
    static func recordingStart() {
        impact(.medium)
    }
    
    static func recordingStop() {
        impact(.light)
    }
    
    static func recordingError() {
        notification(.error)
    }
    
    static func recordingSuccess() {
        notification(.success)
    }
    
    static func modeSwitch() {
        selection()
    }
    
    // MARK: - 长按反馈序列
    static func longPressStart() {
        impact(.heavy)
    }
    
    static func longPressEnd() {
        impact(.light)
    }
} 