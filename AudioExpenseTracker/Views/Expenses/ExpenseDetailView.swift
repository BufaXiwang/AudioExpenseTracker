//
//  ExpenseDetailView.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI
import SwiftData

struct ExpenseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \ExpenseRecord.date,
        order: .reverse
    ) private var expenses: [ExpenseRecord]
    
    @State private var showingDeleteAlert = false
    @State private var expenseToDelete: ExpenseRecord?
    @State private var expenseToEdit: ExpenseRecord?
    
    // 接收录制ViewModel
    @EnvironmentObject private var recordingViewModel: ExpenseRecordingViewModel
    
    var body: some View {
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
                            onEdit: {
                                expenseToEdit = expense
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
        // 编辑费用弹窗
        .sheet(item: $expenseToEdit) { expense in
            ExpenseEditView(expense: expense) { editedExpense in
                updateExpense(editedExpense)
            }
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
        expense.isVerified = true
        expense.updatedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("确认费用失败: \(error)")
        }
    }
    
    private func updateExpense(_ expense: ExpenseRecord) {
        expense.updatedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("更新费用失败: \(error)")
        }
    }
    
    private func deleteExpense(_ expense: ExpenseRecord) {
        modelContext.delete(expense)
        
        do {
            try modelContext.save()
        } catch {
            print("删除费用失败: \(error)")
        }
    }
}

// MARK: - 费用行视图（增强版）
struct ExpenseRowView: View {
    let expense: ExpenseRecord
    let onConfirm: () -> Void
    let onEdit: () -> Void
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
                
                // 备注信息（如果有）
                if !expense.descriptionText.isEmpty {
                    Text(expense.descriptionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // 操作按钮
            VStack(spacing: 8) {
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
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
            
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

// MARK: - 费用编辑视图
struct ExpenseEditView: View {
    @Environment(\.dismiss) private var dismiss
    let expense: ExpenseRecord
    let onSave: (ExpenseRecord) -> Void
    
    @State private var title: String
    @State private var amount: String
    @State private var category: ExpenseCategory
    @State private var notes: String
    @State private var date: Date
    
    init(expense: ExpenseRecord, onSave: @escaping (ExpenseRecord) -> Void) {
        self.expense = expense
        self.onSave = onSave
        
        _title = State(initialValue: expense.title)
        _amount = State(initialValue: String(format: "%.2f", NSDecimalNumber(decimal: expense.amount).doubleValue))
        _category = State(initialValue: expense.category)
        _notes = State(initialValue: expense.descriptionText)
        _date = State(initialValue: expense.date)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    
                    HStack {
                        Text("金额")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("分类", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.iconName)
                                .tag(category)
                        }
                    }
                    
                    DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("编辑费用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveExpense()
                    }
                    .disabled(title.isEmpty || amount.isEmpty)
                }
            }
        }
    }
    
    private func saveExpense() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }
        
        expense.title = title
        expense.amount = Decimal(amountValue)
        expense.category = category
        expense.descriptionText = notes
        expense.date = date
        
        onSave(expense)
        dismiss()
    }
}

// MARK: - 今日统计卡片
struct TodayStatsCard: View {
    let expenses: [ExpenseRecord]
    
    private var todayTotal: Double {
        NSDecimalNumber(decimal: expenses.reduce(Decimal(0)) { $0 + $1.amount }).doubleValue
    }
    
    private var pendingCount: Int {
        expenses.filter { !$0.isVerified }.count
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日支出")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("¥\(todayTotal, format: .number.precision(.fractionLength(2)))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            if pendingCount > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("待确认")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("\(pendingCount)条")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("还没有费用记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击底部录音按钮开始记录")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ExpenseDetailView()
        .modelContainer(for: ExpenseRecord.self, inMemory: true)
} 