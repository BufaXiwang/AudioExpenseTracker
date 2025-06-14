//
//  RecordingMode.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation

enum RecordingMode: String, CaseIterable, Codable {
    case tap = "点击录音"
    case holdToRecord = "长按录音"
    
    var description: String {
        return self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .tap:
            return "hand.tap.fill"
        case .holdToRecord:
            return "hand.point.up.left.fill"
        }
    }
    
    var instructionText: String {
        switch self {
        case .tap:
            return "点击开始录音，再次点击停止"
        case .holdToRecord:
            return "长按录音，松开停止"
        }
    }
} 