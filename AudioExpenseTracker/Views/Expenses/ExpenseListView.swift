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
    
    @State private var showingDeleteAlert = false
    @State private var expenseToDelete: ExpenseRecord?
    @State private var selectedExpense: ExpenseRecord?
    @State private var showEditSheet = false
    
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
                                onEdit: {
                                    selectedExpense = expense
                                    showEditSheet = true
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
        // 显示编辑界面
        .sheet(isPresented: $showEditSheet) {
            if let expense = selectedExpense {
                ExpenseEditView(expense: expense) { _ in
                    selectedExpense = nil
                }
            }
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
    
    private func deleteExpense(_ expense: ExpenseRecord) {
        modelContext.delete(expense)
        
        do {
            try modelContext.save()
        } catch {
            print("删除费用失败: \(error)")
        }
    }
}

// ExpenseRowView 已在 ExpenseDetailView.swift 中定义



// TodayStatsCard 已在 ExpenseDetailView.swift 中定义

// EmptyStateView 已在 ExpenseDetailView.swift 中定义

#Preview {
    ExpenseListView()
        .modelContainer(for: ExpenseRecord.self, inMemory: true)
} 