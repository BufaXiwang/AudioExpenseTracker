//
//  ContentView.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var voiceService: VoiceRecognitionService
    @EnvironmentObject private var dataService: DataStorageService
    @EnvironmentObject private var aiService: AIAnalysisService
    
    @StateObject private var recordingVM: ExpenseRecordingViewModel
    
    init() {
        // 注意：这里我们需要在视图初始化时创建 ViewModel
        // 实际的依赖注入会在 onAppear 中处理
        self._recordingVM = StateObject(wrappedValue: ExpenseRecordingViewModel(
            voiceService: VoiceRecognitionService(),
            aiService: AIAnalysisService(),
            dataService: DataStorageService()
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 应用标题
                headerView
                
                // 当前状态指示器
                if recordingVM.isProcessing {
                    processingIndicator
                }
                
                // 语音录制区域
                VoiceRecordingView()
                
                // 状态信息
                statusView
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $recordingVM.showingConfirmation) {
                confirmationSheet
            }
            .alert("错误", isPresented: $recordingVM.showingError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(recordingVM.errorMessage)
            }
        }
        .onAppear {
            // 在这里注入正确的依赖
            setupViewModel()
        }
    }
    
    // MARK: - 视图组件
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.and.signal.meter")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("语音记账")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("用语音轻松记录每一笔费用")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
    
    private var processingIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(recordingVM.progressDescription)
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var statusView: some View {
        Group {
            switch recordingVM.currentStep {
            case .completed:
                successView
            case .needsManualInput:
                manualInputPrompt
            case .error:
                errorView
            default:
                EmptyView()
            }
        }
    }
    
    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("记录完成")
                .font(.headline)
                .foregroundColor(.green)
            
            Button("继续记录") {
                Task {
                    await recordingVM.resetFlow()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var manualInputPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("需要手动输入")
                .font(.headline)
                .foregroundColor(.orange)
            
            Text("AI 无法准确识别，请手动输入费用信息")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("手动输入") {
                // 创建基础费用记录供用户编辑
                let expense = ExpenseRecord(
                    amount: 0,
                    category: .other,
                    title: "",
                    originalVoiceText: voiceService.recognizedText
                )
                
                Task {
                    await recordingVM.editExpenseManually(expense)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("出现错误")
                .font(.headline)
                .foregroundColor(.red)
            
            Button("重试") {
                Task {
                    await recordingVM.resetFlow()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var confirmationSheet: some View {
        Group {
            if let expense = recordingVM.pendingExpense {
                ExpenseConfirmationView(
                    expense: .constant(expense),
                    analysisResult: recordingVM.analysisResult,
                    onConfirm: {
                        Task {
                            await recordingVM.confirmAndSaveExpense()
                        }
                    },
                    onCancel: {
                        Task {
                            await recordingVM.resetFlow()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func setupViewModel() {
        // 由于 SwiftUI 的限制，我们需要重新创建 ViewModel 或者使用环境对象
        // 这里暂时保持现状，在实际使用中应该优化这部分代码
    }
}

#Preview {
    ContentView()
        .environmentObject(VoiceRecognitionService())
        .environmentObject(DataStorageService()) 
        .environmentObject(AIAnalysisService())
}
