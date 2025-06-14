//
//  ExpenseConfirmationView.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI

struct ExpenseConfirmationView: View {
    @Binding var expense: ExpenseRecord
    let analysisResult: AIAnalysisResult?
    let onConfirm: () -> Void
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
                    // AI 分析信息
                    if let result = analysisResult {
                        AnalysisResultCard(result: result)
                    }
                    
                    // 费用信息编辑区域
                    ExpenseEditForm(
                        amount: $editingAmount,
                        title: $editingTitle,
                        description: $editingDescription,
                        category: $selectedCategory,
                        isEditing: $isEditing
                    )
                    
                    // 置信度指示器
                    if let result = analysisResult {
                        ConfidenceIndicator(level: result.confidenceLevel)
                    }
                    
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
                        saveChanges()
                        onConfirm()
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
    
    private func saveChanges() {
        if let amount = Decimal(string: editingAmount) {
            expense.amount = amount
        }
        expense.title = editingTitle
        expense.descriptionText = editingDescription
        expense.category = selectedCategory
    }
}

// MARK: - AI 分析结果卡片
struct AnalysisResultCard: View {
    let result: AIAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("AI 分析结果")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if let amount = result.formattedAmount {
                    HStack {
                        Text("识别金额:")
                            .foregroundColor(.secondary)
                        Text(amount)
                            .fontWeight(.semibold)
                    }
                }
                
                HStack {
                    Text("建议分类:")
                        .foregroundColor(.secondary)
                    Label(result.suggestedCategory.rawValue, systemImage: result.suggestedCategory.icon)
                        .foregroundColor(.primary)
                }
                
                if !result.suggestedTags.isEmpty {
                    HStack {
                        Text("标签:")
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(result.suggestedTags, id: \.self) { tag in
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
                                Label(category.rawValue, systemImage: category.icon)
                                    .tag(category)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    } else {
                        Label(category.rawValue, systemImage: category.icon)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
                
                // 描述输入
                HStack(alignment: .top) {
                    Text("描述:")
                        .frame(width: 60, alignment: .leading)
                        .padding(.top, 8)
                    
                    if isEditing {
                        TextEditor(text: $description)
                            .frame(minHeight: 60)
                            .padding(4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        Text(description.isEmpty ? "无描述" : description)
                            .foregroundColor(description.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - 置信度指示器
struct ConfidenceIndicator: View {
    let level: ConfidenceLevel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gauge")
                    .foregroundColor(.secondary)
                Text("识别置信度")
                    .font(.headline)
                Spacer()
                Text(level.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(level.color))
            }
            
            ProgressView(value: confidenceValue)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(level.color)))
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var confidenceValue: Double {
        switch level {
        case .high: return 0.9
        case .medium: return 0.6
        case .low: return 0.3
        }
    }
}

// MARK: - 原始文本卡片
struct OriginalTextCard: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "quote.bubble")
                    .foregroundColor(.secondary)
                Text("原始语音")
                    .font(.headline)
                Spacer()
            }
            
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    let sampleExpense = ExpenseRecord(
        amount: 25.50,
        category: .food,
        title: "午餐",
        description: "在公司楼下吃了一顿午餐",
        originalVoiceText: "今天中午花了二十五块五吃午饭"
    )
    
    let sampleResult = AIAnalysisResult(
        originalText: "今天中午花了二十五块五吃午饭",
        extractedAmount: 25.50,
        suggestedCategory: .food,
        suggestedTitle: "午餐",
        suggestedDescription: "餐饮支出",
        confidence: 0.9,
        suggestedTags: ["午餐", "工作日"]
    )
    
    return ExpenseConfirmationView(
        expense: .constant(sampleExpense),
        analysisResult: sampleResult,
        onConfirm: {},
        onCancel: {}
    )
} 