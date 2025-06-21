//
//  HapticFeedback.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import UIKit

struct HapticFeedback {
    
    /// 轻量冲击反馈
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// 通知反馈
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    /// 选择反馈
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    /// 长按开始反馈
    static func longPressStart() {
        impact(.medium)
    }
    
    /// 长按结束反馈
    static func longPressEnd() {
        impact(.light)
    }
    
    /// 录制开始反馈
    static func recordingStart() {
        impact(.heavy)
    }
    
    /// 录制结束反馈
    static func recordingEnd() {
        impact(.medium)
    }
    
    /// 成功反馈
    static func success() {
        notification(.success)
    }
    
    /// 错误反馈
    static func error() {
        notification(.error)
    }
    
    /// 警告反馈
    static func warning() {
        notification(.warning)
    }
    
    /// 录制停止反馈
    static func recordingStop() {
        recordingEnd()
    }
    
    /// 录制成功反馈
    static func recordingSuccess() {
        success()
    }
    
    /// 录制错误反馈
    static func recordingError() {
        error()
    }
} 