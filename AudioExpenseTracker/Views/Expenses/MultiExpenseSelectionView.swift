//
//  MultiExpenseSelectionView.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI

struct MultiExpenseSelectionView: View {
    let primaryExpense: ExpenseRecord
    let alternativeExpenses: [AlternativeInterpretation]
    let originalText: String
    let onConfirm: ([ExpenseRecord]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedExpenses: Set<Int> = [0] // 默认选中第一个
    @State private var showingEditSheet = false
    @State private var editingExpenseIndex: Int?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标题和说明
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI识别到多个费用")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("请选择要保存的费用项目，可以多选")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.regularMaterial)
                
                // 费用列表
                List {
                    // 主要费用（第一个）
                    ExpenseSelectionRow(
                        expense: convertToDisplayExpense(primaryExpense),
                        index: 0,
                        isSelected: selectedExpenses.contains(0),
                        onToggle: { toggleSelection(0) },
                        onEdit: { editingExpenseIndex = 0; showingEditSheet = true }
                    )
                    
                    // 备选费用
                    ForEach(Array(alternativeExpenses.enumerated()), id: \.offset) { index, alternative in
                        let expenseIndex = index + 1
                        ExpenseSelectionRow(
                            expense: convertToDisplayExpense(alternative),
                            index: expenseIndex,
                            isSelected: selectedExpenses.contains(expenseIndex),
                            onToggle: { toggleSelection(expenseIndex) },
                            onEdit: { editingExpenseIndex = expenseIndex; showingEditSheet = true }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("选择费用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认(\(selectedExpenses.count))") {
                        confirmSelection()
                    }
                    .disabled(selectedExpenses.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let index = editingExpenseIndex {
                ExpenseEditSheet(
                    expense: getExpenseForEdit(at: index),
                    onSave: { updatedExpense in
                        updateExpense(at: index, with: updatedExpense)
                    }
                )
            }
        }
    }
    
    private func toggleSelection(_ index: Int) {
        if selectedExpenses.contains(index) {
            selectedExpenses.remove(index)
        } else {
            selectedExpenses.insert(index)
        }
    }
    
    private func confirmSelection() {
        var selectedExpenseRecords: [ExpenseRecord] = []
        
        for index in selectedExpenses.sorted() {
            if index == 0 {
                selectedExpenseRecords.append(primaryExpense)
            } else {
                let alternative = alternativeExpenses[index - 1]
                do {
                    let expenseRecord = try ExpenseRecord(
                        amount: alternative.amount ?? 0,
                        category: alternative.category,
                        title: alternative.title,
                        description: "",
                        originalVoiceText: originalText,
                        confidence: alternative.confidence
                    )
                    selectedExpenseRecords.append(expenseRecord)
                } catch {
                    print("创建费用记录失败: \(error)")
                }
            }
        }
        
        onConfirm(selectedExpenseRecords)
    }
    
    private func convertToDisplayExpense(_ expense: ExpenseRecord) -> DisplayExpense {
        return DisplayExpense(
            amount: expense.amount,
            category: expense.category,
            title: expense.title,
            description: expense.descriptionText
        )
    }
    
    private func convertToDisplayExpense(_ alternative: AlternativeInterpretation) -> DisplayExpense {
        return DisplayExpense(
            amount: alternative.amount ?? 0,
            category: alternative.category,
            title: alternative.title,
            description: ""
        )
    }
    
    private func getExpenseForEdit(at index: Int) -> DisplayExpense {
        if index == 0 {
            return convertToDisplayExpense(primaryExpense)
        } else {
            return convertToDisplayExpense(alternativeExpenses[index - 1])
        }
    }
    
    private func updateExpense(at index: Int, with updatedExpense: DisplayExpense) {
        // 更新对应的费用数据
        if index == 0 {
            primaryExpense.amount = updatedExpense.amount
            primaryExpense.category = updatedExpense.category
            primaryExpense.title = updatedExpense.title
            primaryExpense.descriptionText = updatedExpense.description
        }
        // 对于备选项，我们不直接修改，而是在确认时重新创建
    }
}

// MARK: - 费用选择行
struct ExpenseSelectionRow: View {
    let expense: DisplayExpense
    let index: Int
    let isSelected: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 选择框
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
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
                    Label(expense.category.displayName, systemImage: expense.category.iconName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !expense.description.isEmpty {
                        Text(expense.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            // 编辑按钮
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 费用编辑表单
struct ExpenseEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let expense: DisplayExpense
    let onSave: (DisplayExpense) -> Void
    
    @State private var amount: String
    @State private var title: String
    @State private var description: String
    @State private var category: ExpenseCategory
    
    init(expense: DisplayExpense, onSave: @escaping (DisplayExpense) -> Void) {
        self.expense = expense
        self.onSave = onSave
        
        _amount = State(initialValue: String(format: "%.2f", NSDecimalNumber(decimal: expense.amount).doubleValue))
        _title = State(initialValue: expense.title)
        _description = State(initialValue: expense.description)
        _category = State(initialValue: expense.category)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    
                    HStack {
                        Text("金额")
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
                }
                
                Section("描述") {
                    TextField("费用描述（可选）", text: $description, axis: .vertical)
                        .lineLimit(3...6)
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
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { return }
        
        let updatedExpense = DisplayExpense(
            amount: amountValue,
            category: category,
            title: title,
            description: description
        )
        
        onSave(updatedExpense)
        dismiss()
    }
}

// MARK: - 显示用费用模型
struct DisplayExpense {
    var amount: Decimal
    var category: ExpenseCategory
    var title: String
    var description: String
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }
}

#Preview {
    let primaryExpense = try! ExpenseRecord(
        amount: 25.50,
        category: .food,
        title: "午餐",
        description: "公司附近的快餐",
        originalVoiceText: "今天中午花了25块5买了个快餐，然后打车回公司花了15块",
        confidence: 0.85
    )
    
            let alternatives = [
        AlternativeInterpretation(
            amount: 15.00,
            category: .transport,
            title: "打车费",
            confidence: 0.80
        )
    ]
    
    MultiExpenseSelectionView(
        primaryExpense: primaryExpense,
        alternativeExpenses: alternatives,
        originalText: "今天中午花了25块5买了个快餐，然后打车回公司花了15块",
        onConfirm: { _ in },
        onCancel: { }
    )
} 