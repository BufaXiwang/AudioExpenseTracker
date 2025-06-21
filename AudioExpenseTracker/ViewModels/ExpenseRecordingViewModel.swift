//
//  ExpenseRecordingViewModel.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ExpenseRecordingViewModel: ObservableObject {
    @Published var currentStep: RecordingStep = .idle
    @Published var voiceRecording: VoiceRecording?
    @Published var analysisResult: AIAnalysisResult?
    @Published var pendingExpense: ExpenseRecord?
    @Published var showingConfirmation = false
    @Published var showingMultiExpenseSelection = false
    @Published var multiExpenseOptions: [AlternativeInterpretation] = []
    @Published var showingError = false
    @Published var errorMessage = ""
    
    let voiceService: VoiceRecognitionService
    private let aiService: AIAnalysisService
    private let dataService: DataStorageService
    
    init(
        voiceService: VoiceRecognitionService,
        aiService: AIAnalysisService,
        dataService: DataStorageService
    ) {
        self.voiceService = voiceService
        self.aiService = aiService
        self.dataService = dataService
        
        // 监听语音服务状态变化
        setupVoiceServiceObserver()
    }
    
    // MARK: - 语音录制流程
    
    func resetFlow() async {
        currentStep = .idle
        voiceRecording = nil
        analysisResult = nil
        pendingExpense = nil
        showingConfirmation = false
        showingMultiExpenseSelection = false
        multiExpenseOptions = []
        showingError = false
        errorMessage = ""
        
        // 清空语音服务状态
        voiceService.recognizedText = ""
        
        print("🔄 [DEBUG] 录制流程已重置")
    }
    
    func startRecording() async {
        do {
            currentStep = .recording
            // 清空之前的识别结果
            voiceService.recognizedText = ""
            try await voiceService.startRecording()
            
            // 触觉反馈
            HapticFeedback.recordingStart()
        } catch {
            await handleError(error)
        }
    }
    
    func stopRecording() {
        Task { @MainActor in
            voiceService.stopRecording()
            currentStep = .processing
            
            // 触觉反馈
            HapticFeedback.recordingStop()
        }
    }
    
    // MARK: - AI 分析流程
    
    func analyzeRecording() async {
        guard let recording = voiceService.currentRecording else {
            print("🔍 [DEBUG] 无法获取录音记录")
            await handleError(ExpenseRecordingError.noTranscriptionAvailable)
            return
        }
        
        print("🔍 [DEBUG] 开始分析录音:")
        print("🔍 [DEBUG] - 转录文本: '\(recording.transcribedText)'")
        print("🔍 [DEBUG] - 文本长度: \(recording.transcribedText.count)")
        print("🔍 [DEBUG] - 录音时长: \(recording.duration)秒")
        
        // 如果识别结果为空，直接重置流程（不显示错误）
        if recording.transcribedText.isEmpty {
            print("🔍 [DEBUG] ❌ 转录文本为空，直接重置流程")
            await resetFlow()
            return
        }
        
        // 开始AI分析流程
        currentStep = .analyzing(progress: "准备AI分析...")
        print("🔍 [DEBUG] ✅ 开始AI分析流程")
        
        // 模拟分析步骤，提供用户反馈
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        currentStep = .analyzing(progress: "连接AI服务...")
        
        do {
            let request = AIAnalysisRequest(voiceText: recording.transcribedText)
            print("🔍 [DEBUG] 创建AI分析请求: \(request.voiceText)")
            
            currentStep = .analyzing(progress: "分析语音内容...")
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
            
            currentStep = .analyzing(progress: "识别费用信息...")
            let result = try await aiService.analyzeExpense(request)
            
            print("🔍 [DEBUG] AI分析结果:")
            print("🔍 [DEBUG] - 提取金额: \(result.extractedAmount?.description ?? "nil")")
            print("🔍 [DEBUG] - 建议分类: \(result.suggestedCategory)")
            print("🔍 [DEBUG] - 建议标题: '\(result.suggestedTitle)'")
            print("🔍 [DEBUG] - 置信度: \(result.confidence)")
            print("🔍 [DEBUG] - 是否有效: \(result.isValid)")
            
            currentStep = .analyzing(progress: "处理分析结果...")
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
            
            analysisResult = result
            
            if result.isValid {
                print("🔍 [DEBUG] ✅ AI分析结果有效，创建费用记录")
                currentStep = .analyzing(progress: "生成费用记录...")
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
                await createPendingExpense(from: result)
            } else {
                print("🔍 [DEBUG] ❌ AI分析结果无效，显示错误")
                print("🔍 [DEBUG] 无效原因检查:")
                print("🔍 [DEBUG] - 金额存在: \(result.extractedAmount != nil)")
                print("🔍 [DEBUG] - 金额大于0: \(result.extractedAmount ?? 0 > 0)")
                print("🔍 [DEBUG] - 标题非空: \(!result.suggestedTitle.isEmpty)")
                print("🔍 [DEBUG] - 置信度>0.3: \(result.confidence > 0.3)")
                await handleError(ExpenseRecordingError.aiAnalysisFailed("AI未能从语音中识别出有效的费用信息，请重新录制并说得更清楚一些"))
            }
        } catch {
            print("🔍 [DEBUG] ❌ AI分析异常: \(error)")
            
            // 根据错误类型提供友好的错误信息
            let errorMessage: String
            if let aiError = error as? AIAnalysisError {
                switch aiError {
                case .missingAPIKey:
                    errorMessage = "AI分析服务未配置，请检查API密钥设置"
                case .invalidURL:
                    errorMessage = "AI服务地址配置错误"
                case .requestEncodingFailed:
                    errorMessage = "请求数据格式错误"
                case .networkError:
                    errorMessage = "网络连接失败，请检查网络连接"
                case .apiError(let code):
                    switch code {
                    case 401:
                        errorMessage = "API密钥无效，请检查配置"
                    case 429:
                        errorMessage = "请求过于频繁，请稍后重试"
                    case 500...599:
                        errorMessage = "AI服务暂时不可用，请稍后重试"
                    default:
                        errorMessage = "AI分析服务错误 (代码: \(code))"
                    }
                case .responseParsingFailed:
                    errorMessage = "AI分析结果解析失败"
                case .invalidResponse:
                    errorMessage = "AI服务返回无效响应"
                }
            } else {
                errorMessage = "AI分析过程中发生未知错误：\(error.localizedDescription)"
            }
            
            await handleError(ExpenseRecordingError.aiAnalysisFailed(errorMessage))
        }
    }
    
    // MARK: - 费用记录创建
    
    private func createPendingExpense(from result: AIAnalysisResult) async {
        // 检查是否有多个费用选项
        if !result.alternativeInterpretations.isEmpty {
            await handleMultipleExpenses(result)
            return
        }
        
        guard let amount = result.extractedAmount else {
            await handleError(ExpenseRecordingError.invalidAmount)
            return
        }
        
        do {
            // 使用新的验证构造器
            pendingExpense = try ExpenseRecord(
                amount: amount,
                category: result.suggestedCategory,
                title: result.suggestedTitle,
                description: result.suggestedDescription,
                originalVoiceText: result.originalText,
                confidence: result.confidence,
                tags: result.suggestedTags
            )
            
            currentStep = .confirmingExpense
            showingConfirmation = true
        } catch let error as ExpenseValidationError {
            await handleError(error)
        } catch {
            await handleError(ExpenseRecordingError.validationFailed(error.localizedDescription))
        }
    }
    
    // MARK: - 多费用处理
    
    private func handleMultipleExpenses(_ result: AIAnalysisResult) async {
        guard let amount = result.extractedAmount else {
            await handleError(ExpenseRecordingError.invalidAmount)
            return
        }
        
        do {
            // 创建主要费用记录
            pendingExpense = try ExpenseRecord(
                amount: amount,
                category: result.suggestedCategory,
                title: result.suggestedTitle,
                description: result.suggestedDescription,
                originalVoiceText: result.originalText,
                confidence: result.confidence,
                tags: result.suggestedTags
            )
            
            // 设置备选费用选项
            multiExpenseOptions = result.alternativeInterpretations
            
            currentStep = .selectingMultipleExpenses
            showingMultiExpenseSelection = true
        } catch let error as ExpenseValidationError {
            await handleError(error)
        } catch {
            await handleError(ExpenseRecordingError.validationFailed(error.localizedDescription))
        }
    }
    
    func confirmMultipleExpenses(_ expenses: [ExpenseRecord]) async {
        do {
            // 批量保存多个费用记录
            for expense in expenses {
                try expense.validate()
                expense.isVerified = true
                try dataService.saveExpense(expense)
            }
            
            // 成功触觉反馈
            HapticFeedback.recordingSuccess()
            
            // 重置状态
            await resetFlow()
            currentStep = .completed
        } catch let error as ExpenseValidationError {
            await handleError(error)
        } catch let error as DataStorageError {
            await handleError(ExpenseRecordingError.saveFailed(error.localizedDescription))
        } catch {
            await handleError(ExpenseRecordingError.saveFailed(error.localizedDescription))
        }
    }
    
    func confirmAndSaveExpense() async {
        guard let expense = pendingExpense else {
            await handleError(ExpenseRecordingError.noPendingExpense)
            return
        }
        
        do {
            // 在保存前再次验证数据
            try expense.validate()
            
            expense.isVerified = true
            try dataService.saveExpense(expense)
            
            // 成功触觉反馈
            HapticFeedback.recordingSuccess()
            
            // 重置状态
            await resetFlow()
            currentStep = .completed
        } catch let error as ExpenseValidationError {
            await handleError(error)
        } catch let error as DataStorageError {
            await handleError(ExpenseRecordingError.saveFailed(error.localizedDescription))
        } catch {
            await handleError(ExpenseRecordingError.saveFailed(error.localizedDescription))
        }
    }
    
    func editExpenseManually(_ expense: ExpenseRecord) async {
        do {
            // 验证手动编辑的费用数据
            try expense.validate()
            
            pendingExpense = expense
            currentStep = .confirmingExpense
            showingConfirmation = true
        } catch let error as ExpenseValidationError {
            await handleError(error)
        } catch {
            await handleError(ExpenseRecordingError.validationFailed(error.localizedDescription))
        }
    }
    
    // MARK: - 状态管理
    
    private func handleError(_ error: Error) async {
        currentStep = .error
        errorMessage = error.localizedDescription
        showingError = true
        
        // 错误触觉反馈
        HapticFeedback.recordingError()
        
        print("❌ [ERROR] \(error.localizedDescription)")
        
        // 5秒后自动重置状态，允许用户重新开始
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒
            await MainActor.run {
                if currentStep == .error {
                    Task { await resetFlow() }
                }
            }
        }
    }
    
    private func setupVoiceServiceObserver() {
        // 监听语音识别完成
        voiceService.$recordingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .completed:
                        self?.voiceRecording = self?.voiceService.currentRecording
                        await self?.analyzeRecording()
                    case .error(let message):
                        await self?.handleError(ExpenseRecordingError.voiceRecognitionFailed(message))
                    default:
                        break
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 便捷属性
    
    var canStartRecording: Bool {
        currentStep == .idle || currentStep == .completed || currentStep == .error
    }
    
    var isProcessing: Bool {
        currentStep == .processing || currentStep.isAnalyzing
    }
    
    var progressDescription: String {
        currentStep.description
    }
    
    // MARK: - 健康检查和监控
    
    func performHealthCheck() async -> ViewModelHealthStatus {
        var issues: [String] = []
        
        // 检查数据服务
        if !dataService.isHealthy {
            issues.append("数据存储服务异常")
        }
        
        // 检查语音服务
        let voiceHealthStatus = voiceService.performHealthCheck()
        if !voiceHealthStatus.isOperational {
            issues.append(voiceHealthStatus.description)
        }
        
        // 检查当前状态
        if currentStep == .error {
            issues.append("当前处于错误状态")
        }
        
        if issues.isEmpty {
            return .healthy
        } else if issues.count == 1 {
            return .degraded(issues.first!)
        } else {
            return .critical("多个组件异常: \(issues.joined(separator: ", "))")
        }
    }
    
    func getDetailedStatus() -> ViewModelStatus {
        return ViewModelStatus(
            currentStep: currentStep,
            hasVoiceRecording: voiceRecording != nil,
            hasAnalysisResult: analysisResult != nil,
            hasPendingExpense: pendingExpense != nil,
            dataServiceHealthy: dataService.isHealthy,
            voiceServiceHealthy: voiceService.performHealthCheck().isOperational,
            lastError: errorMessage.isEmpty ? nil : errorMessage
        )
    }
}

// MARK: - 录制步骤枚举
enum RecordingStep: Equatable {
    case idle
    case recording
    case processing
    case analyzing(progress: String)
    case selectingMultipleExpenses
    case confirmingExpense
    case completed
    case error
    
    var description: String {
        switch self {
        case .idle:
            return "准备开始"
        case .recording:
            return "正在录音..."
        case .processing:
            return "处理录音..."
        case .analyzing(let progress):
            return progress
        case .selectingMultipleExpenses:
            return "选择费用项目"
        case .confirmingExpense:
            return "确认费用信息"
        case .completed:
            return "记录完成"
        case .error:
            return "发生错误"
        }
    }
    
    var isAnalyzing: Bool {
        if case .analyzing = self {
            return true
        }
        return false
    }
}

// MARK: - 健康状态监控
enum ViewModelHealthStatus: Equatable {
    case healthy
    case degraded(String)
    case critical(String)
    
    var isOperational: Bool {
        switch self {
        case .healthy, .degraded:
            return true
        case .critical:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .healthy:
            return "视图模型状态正常"
        case .degraded(let message):
            return "视图模型状态异常: \(message)"
        case .critical(let message):
            return "视图模型不可用: \(message)"
        }
    }
}

struct ViewModelStatus {
    let currentStep: RecordingStep
    let hasVoiceRecording: Bool
    let hasAnalysisResult: Bool
    let hasPendingExpense: Bool
    let dataServiceHealthy: Bool
    let voiceServiceHealthy: Bool
    let lastError: String?
    
    var summary: String {
        var components: [String] = []
        components.append("步骤: \(currentStep.description)")
        
        if hasVoiceRecording { components.append("有录音") }
        if hasAnalysisResult { components.append("有分析结果") }
        if hasPendingExpense { components.append("有待确认费用") }
        
        let serviceStatus: [String] = [
            dataServiceHealthy ? "数据✓" : "数据✗",
            voiceServiceHealthy ? "语音✓" : "语音✗"
        ]
        components.append("服务: \(serviceStatus.joined(separator: " "))")
        
        if let error = lastError {
            components.append("错误: \(error)")
        }
        
        return components.joined(separator: " | ")
    }
}

// MARK: - 错误定义
enum ExpenseRecordingError: LocalizedError {
    case noTranscriptionAvailable
    case invalidAmount
    case noPendingExpense
    case voiceRecognitionFailed(String)
    case validationFailed(String)
    case saveFailed(String)
    case aiAnalysisFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noTranscriptionAvailable:
            return "无法获取语音转录结果"
        case .invalidAmount:
            return "无法识别有效金额"
        case .noPendingExpense:
            return "没有待确认的费用记录"
        case .voiceRecognitionFailed(let message):
            return "语音识别失败：\(message)"
        case .validationFailed(let message):
            return "数据验证失败：\(message)"
        case .saveFailed(let message):
            return "数据保存失败：\(message)"
        case .aiAnalysisFailed(let message):
            return "AI分析失败：\(message)"
        }
    }
} 