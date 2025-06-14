//
//  ExpenseListView.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \ExpenseRecord.date,
        order: .reverse
    ) private var expenses: [ExpenseRecord]
    
    @StateObject private var dataService = DataStorageService()
    @State private var showingDeleteAlert = false
    @State private var expenseToDelete: ExpenseRecord?
    
    // 接收录制ViewModel
    @EnvironmentObject private var recordingViewModel: ExpenseRecordingViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 今日统计卡片
                TodayStatsCard(expenses: todayExpenses)
                    .padding(.horizontal)
                    .padding(.top)
                
                // 费用列表
                if expenses.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(expenses) { expense in
                            ExpenseRowView(
                                expense: expense,
                                onConfirm: {
                                    confirmExpense(expense)
                                },
                                onDelete: {
                                    expenseToDelete = expense
                                    showingDeleteAlert = true
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .navigationTitle("费用记录")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("删除费用", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let expense = expenseToDelete {
                    deleteExpense(expense)
                }
            }
        } message: {
            Text("确定要删除这条费用记录吗？")
        }
        // 监听录制完成，显示确认界面
        .sheet(isPresented: $recordingViewModel.showingConfirmation) {
            if let expense = recordingViewModel.pendingExpense {
                ExpenseConfirmationView(
                    expense: expense,
                    onConfirm: { confirmedExpense in
                        Task {
                            await recordingViewModel.confirmAndSaveExpense()
                        }
                    },
                    onCancel: {
                        Task {
                            await recordingViewModel.resetFlow()
                        }
                    }
                )
            }
        }
        // 显示错误信息
        .alert("错误", isPresented: $recordingViewModel.showingError) {
            Button("确定", role: .cancel) {
                Task {
                    await recordingViewModel.resetFlow()
                }
            }
        } message: {
            Text(recordingViewModel.errorMessage)
        }
    }
    
    private var todayExpenses: [ExpenseRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return expenses.filter { expense in
            expense.date >= today && expense.date < tomorrow
        }
    }
    
    private func confirmExpense(_ expense: ExpenseRecord) {
        do {
            expense.isVerified = true
            try dataService.updateExpense(expense)
        } catch {
            print("确认费用失败: \(error)")
        }
    }
    
    private func deleteExpense(_ expense: ExpenseRecord) {
        do {
            try dataService.deleteExpense(expense)
        } catch {
            print("删除费用失败: \(error)")
        }
    }
}

// MARK: - 费用行视图
struct ExpenseRowView: View {
    let expense: ExpenseRecord
    let onConfirm: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 分类图标
            CategoryIconView(category: expense.category)
            
            // 费用信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(expense.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(expense.formattedAmount)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text(expense.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(expense.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 置信度指示器（仅对未确认的显示）
                if !expense.isVerified {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("AI识别 · 置信度: \(expense.confidenceLevel.description)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // 待确认按钮
            if !expense.isVerified {
                Button(action: onConfirm) {
                    Text("确认")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - 分类图标视图
struct CategoryIconView: View {
    let category: ExpenseCategory
    
    var body: some View {
        ZStack {
            Circle()
                .fill(category.color.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: category.iconName)
                .foregroundColor(category.color)
                .font(.system(size: 18, weight: .medium))
        }
    }
}

// MARK: - 今日统计卡片
struct TodayStatsCard: View {
    let expenses: [ExpenseRecord]
    
    private var todayTotal: Decimal {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    private var pendingCount: Int {
        expenses.filter { !$0.isVerified }.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("今日消费")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if pendingCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("\(pendingCount)条待确认")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总金额")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatAmount(todayTotal))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("记录数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(expenses.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("还没有费用记录")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("点击底部的录音按钮开始记录你的第一笔费用")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ExpenseListView()
        .modelContainer(for: ExpenseRecord.self, inMemory: true)
} 