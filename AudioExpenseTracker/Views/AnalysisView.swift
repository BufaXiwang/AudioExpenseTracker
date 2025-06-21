//
//  AnalysisView.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \ExpenseRecord.date,
        order: .reverse
    ) private var expenses: [ExpenseRecord]
    
    @EnvironmentObject private var recordingViewModel: ExpenseRecordingViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 本月支出标题
                    HStack {
                        Text("本月支出")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // 总览统计
                    OverviewStatsView(expenses: filteredExpenses)
                        .padding(.horizontal)
                    
                    // 分类图表
                    CategoryChartView(expenses: filteredExpenses)
                        .padding(.horizontal)
                    
                    Spacer(minLength: 100) // 为底部Tab留出空间
                }
                .padding(.top)
            }
            .navigationTitle("分析")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var filteredExpenses: [ExpenseRecord] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        return expenses.filter { $0.date >= startOfMonth }
    }
}



// MARK: - 总览统计
struct OverviewStatsView: View {
    let expenses: [ExpenseRecord]
    
    private var totalAmount: Double {
        NSDecimalNumber(decimal: expenses.reduce(Decimal(0)) { $0 + $1.amount }).doubleValue
    }
    
    private var averageAmount: Double {
        expenses.isEmpty ? 0 : totalAmount / Double(expenses.count)
    }
    
    private var maxAmount: Double {
        let maxDecimal = expenses.map(\.amount).max() ?? Decimal(0)
        return NSDecimalNumber(decimal: maxDecimal).doubleValue
    }
    
    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "总支出",
                value: String(format: "¥%.2f", totalAmount),
                icon: "creditcard.fill",
                color: .red
            )
            
            StatCard(
                title: "平均金额",
                value: String(format: "¥%.2f", averageAmount),
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )
            
            StatCard(
                title: "最高单笔",
                value: String(format: "¥%.2f", maxAmount),
                icon: "arrow.up.circle.fill",
                color: .orange
            )
        }
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 分类图表
struct CategoryChartView: View {
    let expenses: [ExpenseRecord]
    
    private var categoryData: [CategoryData] {
        Dictionary(grouping: expenses, by: \.category)
            .map { category, expenses in
                CategoryData(
                    category: category,
                    amount: expenses.reduce(Decimal(0)) { $0 + $1.amount },
                    count: expenses.count
                )
            }
            .sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("分类统计")
                .font(.headline)
                .fontWeight(.semibold)
            
            if categoryData.isEmpty {
                EmptyChartView(message: "暂无数据")
            } else {
                Chart(categoryData, id: \.category) { data in
                    BarMark(
                        x: .value("金额", NSDecimalNumber(decimal: data.amount).doubleValue),
                        y: .value("分类", data.category.displayName)
                    )
                    .foregroundStyle(by: .value("分类", data.category.displayName))
                }
                .frame(height: 200)
                
                // 分类详情列表
                LazyVStack(spacing: 8) {
                    ForEach(categoryData, id: \.category) { data in
                        CategoryDataRow(data: data)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 数据模型
struct CategoryData {
    let category: ExpenseCategory
    let amount: Decimal
    let count: Int
}



// MARK: - 辅助视图
struct EmptyChartView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

struct CategoryDataRow: View {
    let data: CategoryData
    
    var body: some View {
        HStack {
            Image(systemName: data.category.iconName)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(data.category.displayName)
                .font(.subheadline)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "¥%.2f", NSDecimalNumber(decimal: data.amount).doubleValue))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(data.count)笔")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AnalysisView()
        .modelContainer(for: ExpenseRecord.self, inMemory: true)
} 
