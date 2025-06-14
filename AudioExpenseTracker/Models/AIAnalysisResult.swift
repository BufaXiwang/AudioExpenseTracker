//
//  AIAnalysisResult.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation

struct AIAnalysisResult: Codable {
    let originalText: String
    let extractedAmount: Decimal?
    let suggestedCategory: ExpenseCategory
    let suggestedTitle: String
    let suggestedDescription: String
    let confidence: Double
    let suggestedTags: [String]
    let alternativeInterpretations: [AlternativeInterpretation]
    let processingTime: TimeInterval
    let timestamp: Date
    
    init(
        originalText: String,
        extractedAmount: Decimal? = nil,
        suggestedCategory: ExpenseCategory = .other,
        suggestedTitle: String = "",
        suggestedDescription: String = "",
        confidence: Double = 0.0,
        suggestedTags: [String] = [],
        alternativeInterpretations: [AlternativeInterpretation] = [],
        processingTime: TimeInterval = 0,
        timestamp: Date = Date()
    ) {
        self.originalText = originalText
        self.extractedAmount = extractedAmount
        self.suggestedCategory = suggestedCategory
        self.suggestedTitle = suggestedTitle
        self.suggestedDescription = suggestedDescription
        self.confidence = confidence
        self.suggestedTags = suggestedTags
        self.alternativeInterpretations = alternativeInterpretations
        self.processingTime = processingTime
        self.timestamp = timestamp
    }
    
    var isValid: Bool {
        return extractedAmount != nil && 
               extractedAmount! > 0 && 
               !suggestedTitle.isEmpty &&
               confidence > 0.3
    }
    
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
    
    var formattedAmount: String? {
        guard let amount = extractedAmount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }
}

struct AlternativeInterpretation: Codable {
    let amount: Decimal?
    let category: ExpenseCategory
    let title: String
    let confidence: Double
    
    var formattedAmount: String? {
        guard let amount = amount else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }
}

struct AIAnalysisRequest: Codable {
    let voiceText: String
    let context: String?
    let userPreferences: UserPreferences?
    let requestId: UUID
    let timestamp: Date
    
    init(
        voiceText: String,
        context: String? = nil,
        userPreferences: UserPreferences? = nil
    ) {
        self.voiceText = voiceText
        self.context = context
        self.userPreferences = userPreferences
        self.requestId = UUID()
        self.timestamp = Date()
    }
}

struct UserPreferences: Codable {
    let defaultCurrency: String
    let preferredCategories: [ExpenseCategory]
    let commonMerchants: [String]
    let budgetLimits: [ExpenseCategory: Decimal]
    
    init(
        defaultCurrency: String = "CNY",
        preferredCategories: [ExpenseCategory] = [],
        commonMerchants: [String] = [],
        budgetLimits: [ExpenseCategory: Decimal] = [:]
    ) {
        self.defaultCurrency = defaultCurrency
        self.preferredCategories = preferredCategories
        self.commonMerchants = commonMerchants
        self.budgetLimits = budgetLimits
    }
} 