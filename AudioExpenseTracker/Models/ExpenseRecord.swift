//
//  ExpenseRecord.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation
import SwiftData

@Model
class ExpenseRecord {
    var id: UUID
    var date: Date
    var amount: Decimal
    var category: ExpenseCategory
    var title: String
    var descriptionText: String
    var originalVoiceText: String
    var confidence: Double
    var tags: [String]
    var isVerified: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        amount: Decimal,
        category: ExpenseCategory,
        title: String,
        description: String = "",
        originalVoiceText: String = "",
        confidence: Double = 1.0,
        tags: [String] = [],
        date: Date = Date()
    ) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.category = category
        self.title = title
        self.descriptionText = description
        self.originalVoiceText = originalVoiceText
        self.confidence = confidence
        self.tags = tags
        self.isVerified = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // 格式化金额显示
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }
    
    // 格式化日期显示
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    // 置信度等级
    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.8...1.0:
            return .high
        case 0.6..<0.8:
            return .medium
        default:
            return .low
        }
    }
}

enum ConfidenceLevel {
    case high, medium, low
    
    var description: String {
        switch self {
        case .high:
            return "高"
        case .medium:
            return "中"
        case .low:
            return "低"
        }
    }
    
    var color: String {
        switch self {
        case .high:
            return "green"
        case .medium:
            return "orange"
        case .low:
            return "red"
        }
    }
} 