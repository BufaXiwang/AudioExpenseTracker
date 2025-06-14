//
//  ExpenseRecordingViewModel.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation
import SwiftUI

@MainActor
class ExpenseRecordingViewModel: ObservableObject {
    @Published var currentStep: RecordingStep = .idle
    @Published var voiceRecording: VoiceRecording?
    @Published var analysisResult: AIAnalysisResult?
    @Published var pendingExpense: ExpenseRecord?
    @Published var showingConfirmation = false
    @Published var showingError = false
    @Published var errorMessage = ""
    
    private let voiceService: VoiceRecognitionService
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
    
    func startRecording() async {
        do {
            currentStep = .recording
            try await voiceService.startRecording()
        } catch {
            await handleError(error)
        }
    }
    
    func stopRecording() {
        Task { @MainActor in
            voiceService.stopRecording()
            currentStep = .processing
        }
    }
    
    // MARK: - AI 分析流程
    
    func analyzeRecording() async {
        guard let recording = voiceService.currentRecording,
              !recording.transcribedText.isEmpty else {
            await handleError(ExpenseRecordingError.noTranscriptionAvailable)
            return
        }
        
        currentStep = .analyzing
        
        do {
            let request = AIAnalysisRequest(voiceText: recording.transcribedText)
            let result = try await aiService.analyzeExpense(request)
            
            analysisResult = result
            
            if result.isValid {
                await createPendingExpense(from: result)
            } else {
                currentStep = .needsManualInput
            }
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - 费用记录创建
    
    private func createPendingExpense(from result: AIAnalysisResult) async {
        guard let amount = result.extractedAmount else {
            await handleError(ExpenseRecordingError.invalidAmount)
            return
        }
        
        pendingExpense = ExpenseRecord(
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
    }
    
    func confirmAndSaveExpense() async {
        guard let expense = pendingExpense else {
            await handleError(ExpenseRecordingError.noPendingExpense)
            return
        }
        
        do {
            expense.isVerified = true
            try dataService.saveExpense(expense)
            
            // 重置状态
            await resetFlow()
            currentStep = .completed
        } catch {
            await handleError(error)
        }
    }
    
    func editExpenseManually(_ expense: ExpenseRecord) async {
        pendingExpense = expense
        currentStep = .confirmingExpense
        showingConfirmation = true
    }
    
    // MARK: - 状态管理
    
    func resetFlow() async {
        currentStep = .idle
        voiceRecording = nil
        analysisResult = nil
        pendingExpense = nil
        showingConfirmation = false
        showingError = false
        errorMessage = ""
    }
    
    private func handleError(_ error: Error) async {
        currentStep = .error
        errorMessage = error.localizedDescription
        showingError = true
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
        currentStep == .processing || currentStep == .analyzing
    }
    
    var progressDescription: String {
        currentStep.description
    }
}

// MARK: - 录制步骤枚举
enum RecordingStep {
    case idle
    case recording
    case processing
    case analyzing
    case needsManualInput
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
        case .analyzing:
            return "AI 分析中..."
        case .needsManualInput:
            return "需要手动输入"
        case .confirmingExpense:
            return "确认费用信息"
        case .completed:
            return "记录完成"
        case .error:
            return "发生错误"
        }
    }
}

// MARK: - 错误定义
enum ExpenseRecordingError: LocalizedError {
    case noTranscriptionAvailable
    case invalidAmount
    case noPendingExpense
    case voiceRecognitionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noTranscriptionAvailable:
            return "无法获取语音转录结果"
        case .invalidAmount:
            return "无法识别有效的金额"
        case .noPendingExpense:
            return "没有待确认的费用记录"
        case .voiceRecognitionFailed(let message):
            return "语音识别失败: \(message)"
        }
    }
}

import Combine 