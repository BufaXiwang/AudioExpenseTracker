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
                    // AI 分析信息卡片
                    AIAnalysisCard(expense: expense)
                    
                    // 费用信息编辑区域
                    ExpenseEditForm(
                        amount: $editingAmount,
                        title: $editingTitle,
                        description: $editingDescription,
                        category: $selectedCategory,
                        isEditing: $isEditing
                    )
                    
                    // 置信度指示器
                    ConfidenceIndicator(level: expense.confidenceLevel)
                    
                    // 原始语音文本
                    if !expense.originalVoiceText.isEmpty {
                        OriginalTextCard(text: expense.originalVoiceText)
                    }
                    
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

// MARK: - AI 分析信息卡片
struct AIAnalysisCard: View {
    let expense: ExpenseRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("AI 分析结果")
                    .font(.headline)
                Spacer()
                
                // 置信度标签
                Text("置信度: \(expense.confidenceLevel.description)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(confidenceColor.opacity(0.2))
                    .foregroundColor(confidenceColor)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("识别金额:")
                        .foregroundColor(.secondary)
                    Text(expense.formattedAmount)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("建议分类:")
                        .foregroundColor(.secondary)
                    Label(expense.category.displayName, systemImage: expense.category.iconName)
                        .foregroundColor(.primary)
                }
                
                if !expense.tags.isEmpty {
                    HStack {
                        Text("标签:")
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(expense.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var confidenceColor: Color {
        switch expense.confidenceLevel {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .red
        }
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

// MARK: - 置信度指示器
struct ConfidenceIndicator: View {
    let level: ConfidenceLevel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI 识别置信度")
                .font(.headline)
            
            HStack {
                Text("置信度:")
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index < confidenceValue ? confidenceColor : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
                
                Text(level.description)
                    .foregroundColor(confidenceColor)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Text(confidenceDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(confidenceColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var confidenceValue: Int {
        switch level {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    private var confidenceColor: Color {
        switch level {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
    
    private var confidenceDescription: String {
        switch level {
        case .high:
            return "AI 对此次识别结果很有信心，建议直接保存"
        case .medium:
            return "AI 识别结果较为准确，建议检查后保存"
        case .low:
            return "AI 识别结果可能不准确，建议仔细检查并修改"
        }
    }
}

// MARK: - 原始文本卡片
struct OriginalTextCard: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("原始语音内容")
                .font(.headline)
            
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
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