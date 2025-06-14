//
//  MainTabView.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var recordingViewModel: ExpenseRecordingViewModel
    @StateObject private var settingsManager = SettingsManager()
    @State private var isCurrentlyLongPressing = false
    
    init() {
        // 创建服务实例
        let voiceService = VoiceRecognitionService()
        let aiService = AIAnalysisService()
        let dataService = DataStorageService()
        
        // 创建ViewModel
        self._recordingViewModel = StateObject(wrappedValue: ExpenseRecordingViewModel(
            voiceService: voiceService,
            aiService: aiService,
            dataService: dataService
        ))
    }
    
    var body: some View {
        ZStack {
            // 主内容
            ExpenseListView()
                .environmentObject(recordingViewModel)
            
            // 录制状态覆盖层
            if recordingViewModel.currentStep != .idle && recordingViewModel.currentStep != .completed {
                RecordingOverlayView(isLongPressing: isCurrentlyLongPressing)
                    .environmentObject(recordingViewModel)
                    .environmentObject(settingsManager)
            }
            
            // 底部录制按钮和模式切换
            VStack {
                Spacer()
                
                // 简化提示文字（第一次使用时显示）
                if settingsManager.showRecordingInstructions && recordingViewModel.currentStep == .idle {
                    VStack(spacing: 8) {
                        Text("智能录制")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Text("点击开始录音，或长按持续录音")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            settingsManager.showRecordingInstructions = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 8)
                }
                
                // 智能录制按钮 - 居中显示
                SmartRecordButton(isLongPressing: $isCurrentlyLongPressing)
                    .environmentObject(recordingViewModel)
                    .environmentObject(settingsManager)
                    .padding(.bottom, 30)
                .padding(.horizontal)
            }
        }
    }
}



// MARK: - 智能录制按钮
struct SmartRecordButton: View {
    @EnvironmentObject private var recordingViewModel: ExpenseRecordingViewModel
    @EnvironmentObject private var settingsManager: SettingsManager
    @Binding var isLongPressing: Bool
    @State private var isPressed = false
    @State private var pressStartTime: Date?
    @State private var longPressTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // 外圈阴影
            Circle()
                .fill(buttonColor)
                .frame(width: 70, height: 70)
                .shadow(color: buttonColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // 内圈
            Circle()
                .fill(buttonColor)
                .frame(width: 60, height: 60)
            
            // 静态图标
            Image(systemName: buttonIcon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
        }
        .scaleEffect(buttonScale)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: 0.3), value: recordingViewModel.voiceService.isRecording)
        .disabled(recordingViewModel.currentStep == .processing || recordingViewModel.currentStep.isAnalyzing)
        .gesture(
            // 统一的手势处理，避免条件分支导致的冲突
            createUnifiedGesture()
        )
    }
    
    private var buttonScale: CGFloat {
        if isPressed {
            return 0.95
        } else if recordingViewModel.voiceService.isRecording {
            return 1.1
        } else {
            return 1.0
        }
    }
    
    private var buttonColor: Color {
        switch recordingViewModel.currentStep {
        case .idle, .completed:
            return .blue
        case .recording:
            return .red
        case .processing:
            return .orange
        case .analyzing(_):
            return .orange
        case .error:
            return .red
        default:
            return .gray
        }
    }
    
    private var buttonIcon: String {
        switch recordingViewModel.currentStep {
        case .idle, .completed:
            return "mic.fill"
        case .recording:
            // 长按录制时显示麦克风图标，短按录制时显示停止图标
            return isLongPressing ? "mic.fill" : "stop.fill"
        case .processing:
            return "waveform"
        case .analyzing(_):
            return "brain"
        case .error:
            return "exclamationmark.triangle.fill"
        default:
            return "mic.fill"
        }
    }
    
    // MARK: - 智能手势处理（同时支持单击和长按）
    private func createUnifiedGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isPressed {
                    isPressed = true
                    pressStartTime = Date()
                    
                    // 触觉反馈
                    if settingsManager.vibrationFeedback {
                        HapticFeedback.impact(.light)
                    }
                    
                    // 延迟启动长按录制，给短按留出时间
                    longPressTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒后判定为长按
                        
                        await MainActor.run {
                            // 如果仍在按压且没有被取消，开始长按录制
                            if isPressed && !Task.isCancelled {
                                handleLongPressStart()
                            }
                        }
                    }
                }
            }
            .onEnded { _ in
                let pressDuration = Date().timeIntervalSince(pressStartTime ?? Date())
                isPressed = false
                
                // 取消长按任务
                longPressTask?.cancel()
                longPressTask = nil
                
                // 根据按压时长判断操作类型
                if pressDuration < 0.5 && !isLongPressing {
                    // 短按：切换录制状态
                    handleShortPress()
                } else if isLongPressing {
                    // 长按结束：停止录制
                    handleLongPressEnd()
                }
            }
    }

    // MARK: - 智能手势处理方法
    private func handleLongPressStart() {
        guard !isLongPressing && (recordingViewModel.currentStep == .idle || recordingViewModel.currentStep == .completed) else {
            return
        }
        
        isLongPressing = true
        
        // 长按开始触觉反馈
        if settingsManager.vibrationFeedback {
            HapticFeedback.longPressStart()
        }
        
        // 在后台任务中启动录制，避免阻塞手势
        Task { @MainActor in
            await recordingViewModel.startRecording()
        }
    }
    
    private func handleLongPressEnd() {
        guard isLongPressing else {
            return
        }
        
        isLongPressing = false
        
        // 只有在录制中时才停止
        if recordingViewModel.voiceService.isRecording {
            // 长按结束触觉反馈
            if settingsManager.vibrationFeedback {
                HapticFeedback.longPressEnd()
            }
            
            recordingViewModel.stopRecording()
        }
    }
    
    private func handleShortPress() {
        // 短按：切换录制状态
        Task { @MainActor in
            switch recordingViewModel.currentStep {
            case .idle, .completed:
                await recordingViewModel.startRecording()
            case .recording:
                recordingViewModel.stopRecording()
            case .error:
                await recordingViewModel.resetFlow()
            default:
                break
            }
        }
    }
}

// MARK: - 录制状态覆盖层
struct RecordingOverlayView: View {
    @EnvironmentObject private var recordingViewModel: ExpenseRecordingViewModel
    @EnvironmentObject private var settingsManager: SettingsManager
    let isLongPressing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            // 状态卡片
            VStack(spacing: 16) {
                // 状态指示器
                HStack(spacing: 12) {
                    // 状态图标
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: statusIcon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(statusColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recordingViewModel.progressDescription)
                            .font(.headline)
                            .foregroundColor(statusColor)
                        
                        // 显示录音模式提示或处理状态
                        if recordingViewModel.currentStep == .recording {
                            Text(recordingModeHint)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if recordingViewModel.currentStep == .processing {
                            Text("正在处理录音文件...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if recordingViewModel.currentStep.isAnalyzing {
                            Text("AI正在智能分析费用信息")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 进度指示器
                    if recordingViewModel.isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                // 音频波形指示器（录制时显示）
                if recordingViewModel.voiceService.isRecording {
                    AudioLevelIndicator(level: recordingViewModel.voiceService.audioLevel)
                        .frame(height: 40)
                }
                
                // AI分析进度指示器
                if recordingViewModel.currentStep.isAnalyzing {
                    AIAnalysisProgressView()
                        .frame(height: 60)
                }
                
                // 移除识别结果显示，直接进行分析
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.bottom, 120) // 为底部按钮留出空间
        }
    }
    
    private var recordingModeHint: String {
        // 根据当前是否是长按状态提供智能提示
        if recordingViewModel.voiceService.isRecording {
            // 正在录制时的提示
            if isLongPressing {
                return "松开按钮停止录音"
            } else {
                return "再次点击停止录音"
            }
        } else {
            return "点击开始录音，或长按持续录音"
        }
    }
    

    
    private var statusColor: Color {
        switch recordingViewModel.currentStep {
        case .idle:
            return .blue
        case .recording:
            return .red
        case .processing:
            return .orange
        case .analyzing(_):
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        default:
            return .blue
        }
    }
    
    private var statusIcon: String {
        switch recordingViewModel.currentStep {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .processing:
            return "waveform"
        case .analyzing(_):
            return "brain"
        case .completed:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        default:
            return "mic"
        }
    }
}

// MARK: - AI分析进度视图
struct AIAnalysisProgressView: View {
    @State private var animationOffset: CGFloat = -200
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 12) {
            // 动画进度条
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.orange)
                                .frame(width: 40, height: 4)
                                .offset(x: animationOffset)
                                .clipped()
                        )
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.1),
                            value: animationOffset
                        )
                }
            }
            
            // AI图标动画
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.orange)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                
                Text("AI智能分析中")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                    .opacity(0.7)
            }
        }
        .onAppear {
            animationOffset = 200
            pulseScale = 1.2
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: ExpenseRecord.self, inMemory: true)
} 
