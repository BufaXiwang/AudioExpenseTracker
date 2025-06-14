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
    ) throws {
        // 数据验证
        try ExpenseRecord.validateAmount(amount)
        try ExpenseRecord.validateTitle(title)
        try ExpenseRecord.validateConfidence(confidence)
        try ExpenseRecord.validateDate(date)
        
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.category = category
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.descriptionText = description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.originalVoiceText = originalVoiceText
        self.confidence = confidence
        self.tags = tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.isVerified = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - 数据验证方法
    
    static func validateAmount(_ amount: Decimal) throws {
        let maxAmount = Decimal(999999.99) // 最大金额限制
        let minAmount = Decimal(0.01) // 最小金额限制
        
        guard amount >= minAmount else {
            throw ExpenseValidationError.invalidAmount("金额必须大于等于 ¥0.01")
        }
        
        guard amount <= maxAmount else {
            throw ExpenseValidationError.invalidAmount("金额不能超过 ¥999,999.99")
        }
        
        // 检查小数位数
        let decimalHandler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 2,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        
        let roundedAmount = NSDecimalNumber(decimal: amount).rounding(accordingToBehavior: decimalHandler)
        if roundedAmount.decimalValue != amount {
            throw ExpenseValidationError.invalidAmount("金额最多支持两位小数")
        }
    }
    
    static func validateTitle(_ title: String) throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            throw ExpenseValidationError.invalidTitle("标题不能为空")
        }
        
        guard trimmedTitle.count <= 100 else {
            throw ExpenseValidationError.invalidTitle("标题长度不能超过100个字符")
        }
        
        // 检查是否包含无效字符
        let invalidCharacters = CharacterSet(charactersIn: "<>|\\/:*?\"")
        if trimmedTitle.rangeOfCharacter(from: invalidCharacters) != nil {
            throw ExpenseValidationError.invalidTitle("标题包含无效字符")
        }
    }
    
    static func validateConfidence(_ confidence: Double) throws {
        guard confidence >= 0.0 && confidence <= 1.0 else {
            throw ExpenseValidationError.invalidConfidence("置信度必须在 0.0 到 1.0 之间")
        }
    }
    
    static func validateDate(_ date: Date) throws {
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
        
        guard date >= oneYearAgo else {
            throw ExpenseValidationError.invalidDate("日期不能早于一年前")
        }
        
        guard date <= oneYearFromNow else {
            throw ExpenseValidationError.invalidDate("日期不能晚于一年后")
        }
    }
    
    // MARK: - 实例验证
    
    func validate() throws {
        try ExpenseRecord.validateAmount(amount)
        try ExpenseRecord.validateTitle(title)
        try ExpenseRecord.validateConfidence(confidence)
        try ExpenseRecord.validateDate(date)
    }
    
    var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - 更新方法
    
    func updateAmount(_ newAmount: Decimal) throws {
        try ExpenseRecord.validateAmount(newAmount)
        amount = newAmount
        updatedAt = Date()
    }
    
    func updateTitle(_ newTitle: String) throws {
        try ExpenseRecord.validateTitle(newTitle)
        title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedAt = Date()
    }
    
    func updateDescription(_ newDescription: String) {
        descriptionText = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedAt = Date()
    }
    
    func updateCategory(_ newCategory: ExpenseCategory) {
        category = newCategory
        updatedAt = Date()
    }
    
    func updateDate(_ newDate: Date) throws {
        try ExpenseRecord.validateDate(newDate)
        date = newDate
        updatedAt = Date()
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

// MARK: - 验证错误定义
enum ExpenseValidationError: LocalizedError {
    case invalidAmount(String)
    case invalidTitle(String)
    case invalidConfidence(String)
    case invalidDate(String)
    case invalidDescription(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount(let message):
            return "金额验证失败: \(message)"
        case .invalidTitle(let message):
            return "标题验证失败: \(message)"
        case .invalidConfidence(let message):
            return "置信度验证失败: \(message)"
        case .invalidDate(let message):
            return "日期验证失败: \(message)"
        case .invalidDescription(let message):
            return "描述验证失败: \(message)"
        }
    }
} 