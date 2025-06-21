//
//  ExpenseConfirmationView.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI

struct ExpenseConfirmationView: View {
    let expense: ExpenseRecord
    let onConfirm: (ExpenseRecord) -> Void
    let onCancel: () -> Void
    
    @State private var editingAmount: String = ""
    @State private var editingTitle: String = ""
    @State private var editingDescription: String = ""
    @State private var selectedCategory: ExpenseCategory = .other
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 费用信息编辑区域
                    ExpenseEditForm(
                        amount: $editingAmount,
                        title: $editingTitle,
                        description: $editingDescription,
                        category: $selectedCategory,
                        isEditing: $isEditing
                    )
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("确认费用")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let updatedExpense = createUpdatedExpense()
                        onConfirm(updatedExpense)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            setupEditingValues()
        }
    }
    
    private func setupEditingValues() {
        editingAmount = String(describing: expense.amount)
        editingTitle = expense.title
        editingDescription = expense.descriptionText
        selectedCategory = expense.category
    }
    
    private func createUpdatedExpense() -> ExpenseRecord {
        // 更新费用信息
        if let amount = Decimal(string: editingAmount) {
            expense.amount = amount
        }
        expense.title = editingTitle
        expense.descriptionText = editingDescription
        expense.category = selectedCategory
        expense.updatedAt = Date()
        
        return expense
    }
}



// MARK: - 费用编辑表单
struct ExpenseEditForm: View {
    @Binding var amount: String
    @Binding var title: String
    @Binding var description: String
    @Binding var category: ExpenseCategory
    @Binding var isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("费用信息")
                    .font(.headline)
                Spacer()
                Button(isEditing ? "完成" : "编辑") {
                    isEditing.toggle()
                }
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                // 金额输入
                HStack {
                    Text("金额:")
                        .frame(width: 60, alignment: .leading)
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(!isEditing)
                }
                
                // 标题输入
                HStack {
                    Text("标题:")
                        .frame(width: 60, alignment: .leading)
                    TextField("费用标题", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(!isEditing)
                }
                
                // 分类选择
                HStack {
                    Text("分类:")
                        .frame(width: 60, alignment: .leading)
                    
                    if isEditing {
                        Picker("分类", selection: $category) {
                            ForEach(ExpenseCategory.allCases, id: \.self) { category in
                                Label(category.displayName, systemImage: category.iconName)
                                    .tag(category)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    } else {
                        Label(category.displayName, systemImage: category.iconName)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                
                // 描述输入
                VStack(alignment: .leading) {
                    Text("描述:")
                    TextField("费用描述（可选）", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(!isEditing)
                        .lineLimit(3...6)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}





#Preview {
    let sampleExpense = try! ExpenseRecord(
        amount: 25.50,
        category: .food,
        title: "午餐",
        description: "公司附近的快餐",
        originalVoiceText: "今天中午花了25块5买了个快餐",
        confidence: 0.85
    )
    
    return ExpenseConfirmationView(
        expense: sampleExpense,
        onConfirm: { _ in },
        onCancel: { }
    )
} 