//
//  VoiceRecording.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation

struct VoiceRecording: Identifiable, Codable {
    let id = UUID()
    let fileURL: URL?
    let transcribedText: String
    let duration: TimeInterval
    let recordingDate: Date
    let isProcessing: Bool
    let hasError: Bool
    let errorMessage: String?
    
    init(
        fileURL: URL? = nil,
        transcribedText: String = "",
        duration: TimeInterval = 0,
        recordingDate: Date = Date(),
        isProcessing: Bool = false,
        hasError: Bool = false,
        errorMessage: String? = nil
    ) {
        self.fileURL = fileURL
        self.transcribedText = transcribedText
        self.duration = duration
        self.recordingDate = recordingDate
        self.isProcessing = isProcessing
        self.hasError = hasError
        self.errorMessage = errorMessage
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isEmpty: Bool {
        return transcribedText.isEmpty && fileURL == nil
    }
}

enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case completed
    case error(String)
    
    var isRecording: Bool {
        switch self {
        case .recording:
            return true
        default:
            return false
        }
    }
    
    var isProcessing: Bool {
        switch self {
        case .processing:
            return true
        default:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .idle:
            return "准备录制"
        case .recording:
            return "正在录制..."
        case .processing:
            return "正在处理..."
        case .completed:
            return "录制完成"
        case .error(let message):
            return "错误: \(message)"
        }
    }
} 