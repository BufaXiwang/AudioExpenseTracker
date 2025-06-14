//
//  DataStorageService.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation
import SwiftData

@MainActor
class DataStorageService: ObservableObject {
    private var modelContext: ModelContext?
    private let modelContainer: ModelContainer
    
    init() {
        do {
            // 配置数据模型
            let schema = Schema([
                ExpenseRecord.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none // 暂时不使用 CloudKit
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("无法初始化数据存储：\(error)")
        }
    }
    
    // MARK: - 费用记录管理
    
    func saveExpense(_ expense: ExpenseRecord) throws {
        guard let context = modelContext else {
            throw DataStorageError.contextNotAvailable
        }
        
        expense.updatedAt = Date()
        context.insert(expense)
        
        do {
            try context.save()
        } catch {
            throw DataStorageError.saveFailed(error)
        }
    }
    
    func updateExpense(_ expense: ExpenseRecord) throws {
        guard let context = modelContext else {
            throw DataStorageError.contextNotAvailable
        }
        
        expense.updatedAt = Date()
        
        do {
            try context.save()
        } catch {
            throw DataStorageError.updateFailed(error)
        }
    }
    
    func deleteExpense(_ expense: ExpenseRecord) throws {
        guard let context = modelContext else {
            throw DataStorageError.contextNotAvailable
        }
        
        context.delete(expense)
        
        do {
            try context.save()
        } catch {
            throw DataStorageError.deleteFailed(error)
        }
    }
    
    func fetchAllExpenses() throws -> [ExpenseRecord] {
        guard let context = modelContext else {
            throw DataStorageError.contextNotAvailable
        }
        
        let descriptor = FetchDescriptor<ExpenseRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            throw DataStorageError.fetchFailed(error)
        }
    }
    
    func fetchExpenses(
        from startDate: Date,
        to endDate: Date,
        category: ExpenseCategory? = nil
    ) throws -> [ExpenseRecord] {
        guard let context = modelContext else {
            throw DataStorageError.contextNotAvailable
        }
        
        var predicate = #Predicate<ExpenseRecord> { expense in
            expense.date >= startDate && expense.date <= endDate
        }
        
        if let category = category {
            predicate = #Predicate<ExpenseRecord> { expense in
                expense.date >= startDate && 
                expense.date <= endDate && 
                expense.category == category
            }
        }
        
        let descriptor = FetchDescriptor<ExpenseRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            throw DataStorageError.fetchFailed(error)
        }
    }
    
    func searchExpenses(query: String) throws -> [ExpenseRecord] {
        guard let context = modelContext else {
            throw DataStorageError.contextNotAvailable
        }
        
        let predicate = #Predicate<ExpenseRecord> { expense in
            expense.title.contains(query) || 
            expense.descriptionText.contains(query) ||
            expense.originalVoiceText.contains(query)
        }
        
        let descriptor = FetchDescriptor<ExpenseRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            throw DataStorageError.fetchFailed(error)
        }
    }
    
    // MARK: - 统计功能
    
    func getTotalExpense(
        from startDate: Date,
        to endDate: Date,
        category: ExpenseCategory? = nil
    ) throws -> Decimal {
        let expenses = try fetchExpenses(from: startDate, to: endDate, category: category)
        return expenses.reduce(0) { $0 + $1.amount }
    }
    
    func getExpensesByCategory(
        from startDate: Date,
        to endDate: Date
    ) throws -> [ExpenseCategory: Decimal] {
        let expenses = try fetchExpenses(from: startDate, to: endDate)
        
        var categoryTotals: [ExpenseCategory: Decimal] = [:]
        
        for expense in expenses {
            categoryTotals[expense.category, default: 0] += expense.amount
        }
        
        return categoryTotals
    }
    
    func getDailyExpenses(
        from startDate: Date,
        to endDate: Date
    ) throws -> [Date: Decimal] {
        let expenses = try fetchExpenses(from: startDate, to: endDate)
        let calendar = Calendar.current
        
        var dailyTotals: [Date: Decimal] = [:]
        
        for expense in expenses {
            let day = calendar.startOfDay(for: expense.date)
            dailyTotals[day, default: 0] += expense.amount
        }
        
        return dailyTotals
    }
    
    // MARK: - 数据导出
    
    func exportToCSV(expenses: [ExpenseRecord]) throws -> String {
        var csvContent = "日期,金额,分类,标题,描述,置信度\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for expense in expenses {
            let row = [
                dateFormatter.string(from: expense.date),
                String(describing: expense.amount),
                expense.category.rawValue,
                expense.title.replacingOccurrences(of: ",", with: "，"),
                expense.descriptionText.replacingOccurrences(of: ",", with: "，"),
                String(expense.confidence)
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        return csvContent
    }
    
    // MARK: - 数据清理
    
    func deleteAllExpenses() throws {
        guard let context = modelContext else {
            throw DataStorageError.contextNotAvailable
        }
        
        let expenses = try fetchAllExpenses()
        
        for expense in expenses {
            context.delete(expense)
        }
        
        do {
            try context.save()
        } catch {
            throw DataStorageError.deleteFailed(error)
        }
    }
    
    func deleteExpensesOlderThan(days: Int) throws {
        guard let context = modelContext else {
            throw DataStorageError.contextNotAvailable
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let predicate = #Predicate<ExpenseRecord> { expense in
            expense.date < cutoffDate
        }
        
        let descriptor = FetchDescriptor<ExpenseRecord>(predicate: predicate)
        
        do {
            let expensesToDelete = try context.fetch(descriptor)
            
            for expense in expensesToDelete {
                context.delete(expense)
            }
            
            try context.save()
        } catch {
            throw DataStorageError.deleteFailed(error)
        }
    }
    
    // MARK: - 数据验证
    
    func validateData() throws -> DataValidationResult {
        let allExpenses = try fetchAllExpenses()
        
        var result = DataValidationResult()
        
        for expense in allExpenses {
            if expense.amount <= 0 {
                result.invalidAmountCount += 1
            }
            
            if expense.title.isEmpty {
                result.missingTitleCount += 1
            }
            
            if expense.confidence < 0.5 {
                result.lowConfidenceCount += 1
            }
        }
        
        result.totalCount = allExpenses.count
        
        return result
    }
    
    // MARK: - 获取 ModelContext (供 SwiftUI 视图使用)
    
    func getModelContext() -> ModelContext? {
        return modelContext
    }
    
    func getModelContainer() -> ModelContainer {
        return modelContainer
    }
}

// MARK: - 数据验证结果
struct DataValidationResult {
    var totalCount: Int = 0
    var invalidAmountCount: Int = 0
    var missingTitleCount: Int = 0
    var lowConfidenceCount: Int = 0
    
    var isValid: Bool {
        return invalidAmountCount == 0 && missingTitleCount == 0
    }
    
    var hasWarnings: Bool {
        return lowConfidenceCount > 0
    }
}

// MARK: - 错误定义
enum DataStorageError: LocalizedError {
    case contextNotAvailable
    case saveFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case fetchFailed(Error)
    case exportFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .contextNotAvailable:
            return "数据上下文不可用"
        case .saveFailed(let error):
            return "保存失败: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "更新失败: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "删除失败: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "获取数据失败: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "导出失败: \(error.localizedDescription)"
        }
    }
} 