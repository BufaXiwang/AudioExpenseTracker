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
    @State private var selectedTab: Int = 0
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
            // 主要内容区域
            TabView(selection: $selectedTab) {
                // 明细Tab
                ExpenseDetailView()
                    .environmentObject(recordingViewModel)
                    .tag(0)
                
                // 分析Tab
                AnalysisView()
                    .environmentObject(recordingViewModel)
                    .tag(1)
            }
            
            // 自定义底部Tab栏
            VStack {
                Spacer()
                
                // 录音状态显示区域
                if recordingViewModel.currentStep != .idle && recordingViewModel.currentStep != .completed {
                    RecordingStatusOverlay()
                        .environmentObject(recordingViewModel)
                        .padding(.bottom, 10)
                }
                
                CustomTabBar(
                    selectedTab: $selectedTab,
                    isLongPressing: $isCurrentlyLongPressing
                )
                .environmentObject(recordingViewModel)
                .environmentObject(settingsManager)
            }
        }
        // 监听录音状态变化，自动跳转Tab
        .onChange(of: recordingViewModel.currentStep) { newStep in
            switch newStep {
            case .confirmingExpense, .selectingMultipleExpenses, .completed:
                // 需要确认或完成时，跳转到明细Tab
                selectedTab = 0
            default:
                break
            }
        }
        // 显示多费用选择界面
        .sheet(isPresented: $recordingViewModel.showingMultiExpenseSelection) {
            if let primaryExpense = recordingViewModel.pendingExpense {
                MultiExpenseSelectionView(
                    primaryExpense: primaryExpense,
                    alternativeExpenses: recordingViewModel.multiExpenseOptions,
                    originalText: primaryExpense.originalVoiceText,
                    onConfirm: { expenses in
                        Task {
                            await recordingViewModel.confirmMultipleExpenses(expenses)
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
    }
}

// MARK: - 自定义Tab栏
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var isLongPressing: Bool
    @EnvironmentObject private var recordingViewModel: ExpenseRecordingViewModel
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        HStack {
            // 明细Tab
            TabBarButton(
                icon: "list.bullet",
                title: "明细",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            
            Spacer()
            
            // 大型圆形录音按钮
            VoiceRecordButton()
                .environmentObject(recordingViewModel)
                .environmentObject(settingsManager)
                .scaleEffect(0.8) // 适当缩小以适配底部栏
            
            Spacer()
            
            // 分析Tab
            TabBarButton(
                icon: "chart.bar.fill",
                title: "分析",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
}

// MARK: - Tab栏按钮
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var iconColor: Color? = nil
    var isRecording: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor ?? (isSelected ? .blue : .gray))
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isRecording)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(iconColor ?? (isSelected ? .blue : .gray))
            }
        }
        .frame(width: 60)
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

// MARK: - 语音录音按钮
struct VoiceRecordButton: View {
    @EnvironmentObject private var recordingViewModel: ExpenseRecordingViewModel
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var scale: CGFloat = 1.0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: handleTap) {
            ZStack {
                // 外圈 - 状态指示
                Circle()
                    .strokeBorder(buttonColor, lineWidth: 3)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(buttonColor.opacity(0.1)))
                    .scaleEffect(pulseScale)
                    .animation(pulseAnimation, value: pulseScale)
                
                // 内圈 - 主按钮
                Circle()
                    .fill(buttonColor)
                    .frame(width: 60, height: 60)
                    .scaleEffect(scale)
                
                // 图标或内容
                Group {
                    if recordingViewModel.currentStep == .recording {
                        // 录音时显示小型音频指示器
                        AudioLevelMiniIndicator()
                            .environmentObject(recordingViewModel)
                    } else {
                        Image(systemName: buttonIcon)
                            .font(.system(size: iconSize, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(scale)
            }
        }
        .onAppear {
            updateAnimations()
        }
        .onChange(of: recordingViewModel.currentStep) { _, _ in
            updateAnimations()
        }
        .onLongPressGesture(
            minimumDuration: 0.1,
            maximumDistance: 50,
            perform: {},
            onPressingChanged: { pressing in
                if pressing && recordingViewModel.currentStep == .idle {
                    // 开始长按录音
                    handleLongPressStart()
                } else if !pressing && recordingViewModel.currentStep == .recording {
                    // 结束长按录音
                    handleLongPressEnd()
                }
            }
        )
    }
    
    private var buttonColor: Color {
        switch recordingViewModel.currentStep {
        case .idle, .completed:
            return .blue
        case .recording:
            return .red
        case .processing, .analyzing(_):
            return .orange
        case .error:
            return .red
        default:
            return .blue
        }
    }
    
    private var buttonIcon: String {
        switch recordingViewModel.currentStep {
        case .idle, .completed:
            return "mic.fill"
        case .recording:
            return "stop.fill"
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
    
    private var iconSize: CGFloat {
        switch recordingViewModel.currentStep {
        case .recording:
            return 16
        case .processing, .analyzing(_):
            return 18
        default:
            return 20
        }
    }
    
    private var pulseAnimation: Animation? {
        switch recordingViewModel.currentStep {
        case .recording:
            return .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
        case .processing, .analyzing(_):
            return .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
        default:
            return .easeInOut(duration: 0.3)
        }
    }
    
    private func updateAnimations() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch recordingViewModel.currentStep {
            case .recording:
                scale = 1.1
                pulseScale = 1.2
            case .processing, .analyzing(_):
                scale = 1.0
                pulseScale = 1.1
            case .error:
                scale = 0.95
                pulseScale = 1.0
            default:
                scale = 1.0
                pulseScale = 1.0
            }
        }
        
        // 错误状态自动重置
        if case .error = recordingViewModel.currentStep {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                Task {
                    await recordingViewModel.resetFlow()
                }
            }
        }
    }
    
    private func handleTap() {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        
        switch recordingViewModel.currentStep {
        case .idle, .completed:
            // 点击录音模式
            if settingsManager.recordingMode == .tap {
                Task {
                    await recordingViewModel.startRecording()
                }
            }
        case .recording:
            // 停止录音
            recordingViewModel.stopRecording()
        default:
            break
        }
    }
    
    private func handleLongPressStart() {
        // 长按录音模式
        if settingsManager.recordingMode == .holdToRecord {
            let haptic = UIImpactFeedbackGenerator(style: .heavy)
            haptic.impactOccurred()
            Task {
                await recordingViewModel.startRecording()
            }
        }
    }
    
    private func handleLongPressEnd() {
        // 长按结束
        if settingsManager.recordingMode == .holdToRecord {
            recordingViewModel.stopRecording()
        }
    }
}

// MARK: - 录音状态悬浮层
struct RecordingStatusOverlay: View {
    @EnvironmentObject private var recordingViewModel: ExpenseRecordingViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // 状态图标
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(statusColor)
                
                // 状态文本
                Text(statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusColor)
                
                Spacer()
                
                // 取消按钮（仅在可取消的状态下显示）
                if canCancel {
                    Button("取消") {
                        Task {
                            await recordingViewModel.resetFlow()
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                }
            }
            
            // 进度指示器
            if recordingViewModel.currentStep == .processing || recordingViewModel.currentStep.isAnalyzing {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: statusColor))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }
    
    private var statusIcon: String {
        switch recordingViewModel.currentStep {
        case .recording:
            return "waveform"
        case .processing:
            return "gear"
        case .analyzing(_):
            return "brain"
        case .error:
            return "exclamationmark.triangle.fill"
        default:
            return "checkmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch recordingViewModel.currentStep {
        case .recording:
            return .red
        case .processing, .analyzing(_):
            return .orange
        case .error:
            return .red
        default:
            return .green
        }
    }
    
    private var statusText: String {
        switch recordingViewModel.currentStep {
        case .recording:
            return "正在录音..."
        case .processing:
            return "处理语音中..."
        case .analyzing(_):
            return "AI智能分析中..."
        case .error:
            return "操作失败，请重试"
        default:
            return ""
        }
    }
    
    private var canCancel: Bool {
        switch recordingViewModel.currentStep {
        case .processing, .analyzing(_):
            return true
        default:
            return false
        }
    }
}

// MARK: - 迷你音频电平指示器
struct AudioLevelMiniIndicator: View {
    @EnvironmentObject private var recordingViewModel: ExpenseRecordingViewModel
    @State private var animationPhase: Double = 0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            animationPhase = 1.0
        }
        .onDisappear {
            animationPhase = 0.0
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 20
        
        // 基于音频电平和动画相位计算高度
        let audioLevel = recordingViewModel.voiceService.audioLevel
        let animatedLevel = Double(audioLevel) * (0.5 + 0.5 * sin(animationPhase * .pi + Double(index) * 0.5))
        
        return baseHeight + (maxHeight - baseHeight) * CGFloat(animatedLevel)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: ExpenseRecord.self, inMemory: true)
} 
