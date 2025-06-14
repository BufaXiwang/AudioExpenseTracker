//
//  VoiceRecognitionService.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class VoiceRecognitionService: NSObject, ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var recognizedText: String = ""
    @Published var currentRecording: VoiceRecording?
    @Published var audioLevel: Float = 0.0
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioSession = AVAudioSession.sharedInstance()
    private var recordingStartTime: Date?
    
    // 添加状态跟踪
    private var isEngineRunning = false
    private var hasTapInstalled = false
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    deinit {
        // 确保资源被正确清理
        Task { @MainActor in
            cleanupResources()
        }
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        speechRecognizer?.delegate = self
    }
    
    // MARK: - 资源清理
    private func cleanupResourcesGracefully() {
        // 停止音频引擎
        if isEngineRunning {
            audioEngine.stop()
            isEngineRunning = false
        }
        
        // 移除音频tap
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }
        
        // 清理请求但不取消任务，让它自然完成
        recognitionRequest = nil
        recognitionTask = nil
        
        // 重置音频会话
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("音频会话重置失败: \(error)")
        }
    }
    
    private func cleanupResources() {
        // 停止音频引擎
        if isEngineRunning {
            audioEngine.stop()
            isEngineRunning = false
        }
        
        // 移除音频tap
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }
        
        // 清理识别请求（如果还没有被结束）
        if let request = recognitionRequest {
            // 只在必要时调用 endAudio()
            request.endAudio()
        }
        recognitionRequest = nil
        
        // 取消识别任务（只有在强制清理时才取消）
        if let task = recognitionTask {
            task.cancel()
        }
        recognitionTask = nil
        
        // 重置音频会话
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("音频会话重置失败: \(error)")
        }
    }
    
    // MARK: - 权限管理
    func requestPermissions() async -> Bool {
        let speechPermission = await requestSpeechRecognitionPermission()
        let microphonePermission = await requestMicrophonePermission()
        return speechPermission && microphonePermission
    }
    
    private func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - 录制控制
    func startRecording() async throws {
        // 如果正在录制，先停止
        if isRecording {
            stopRecording()
            // 等待一小段时间确保资源被清理
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        }
        
        guard await requestPermissions() else {
            throw VoiceRecognitionError.permissionDenied
        }
        
        guard speechRecognizer?.isAvailable == true else {
            throw VoiceRecognitionError.speechRecognitionUnavailable
        }
        
        // 确保之前的资源被清理
        cleanupResources()
        
        do {
            try await configureAudioSession()
            try await startSpeechRecognition()
            
            recordingState = .recording
            recordingStartTime = Date()
            recognizedText = ""
        } catch {
            // 如果启动失败，清理资源
            cleanupResources()
            throw error
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        recordingState = .processing
        
        // 先优雅地结束语音识别请求
        recognitionRequest?.endAudio()
        
        // 给语音识别一点时间完成处理
        Task {
            // 等待短暂时间让语音识别完成
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
            
            await MainActor.run {
                // 使用优雅的清理方式
                cleanupResourcesGracefully()
                
                // 创建录制记录
                if let startTime = recordingStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    currentRecording = VoiceRecording(
                        transcribedText: recognizedText,
                        duration: duration,
                        recordingDate: startTime,
                        isProcessing: false
                    )
                }
                
                recordingState = .completed
            }
        }
    }
    
    private func configureAudioSession() async throws {
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw VoiceRecognitionError.audioEngineError
        }
    }
    
    private func startSpeechRecognition() async throws {
        // 确保之前的任务被清理
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 创建新的识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceRecognitionError.failedToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 如果可用，使用设备上的识别
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        let inputNode = audioEngine.inputNode
        
        // 创建识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    // 忽略特定的系统错误
                    let nsError = error as NSError
                    
                    // 忽略正常停止录音时的取消错误
                    if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                        // 301: "Recognition request was canceled" - 手动停止录音时的正常现象
                        print("忽略录音停止错误 (Code: \(nsError.code)): \(error.localizedDescription)")
                        return
                    }
                    
                    if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 1101 || nsError.code == 1110) {
                        // 1101: 系统内部错误，可以忽略
                        // 1110: "No speech detected" - 录音结束后的正常现象
                        print("忽略系统语音识别错误 (Code: \(nsError.code)): \(error.localizedDescription)")
                        return
                    }
                    
                    self.handleError(error)
                }
            }
        }
        
        // 安装音频tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 确保没有已安装的tap
        if hasTapInstalled {
            inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            
            // 计算音频电平
            self?.calculateAudioLevel(from: buffer)
        }
        hasTapInstalled = true
        
        // 启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()
        isEngineRunning = true
    }
    
    nonisolated private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelData[$0] }
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataValueArray.count))
        
        Task { @MainActor in
            // 使用弱引用避免潜在的循环引用
            guard !Task.isCancelled else { return }
            
            let normalizedLevel = min(rms * 10, 1.0) // 限制在0-1范围内
            
            // 添加音频级别平滑处理
            let smoothingFactor: Float = 0.3
            self.audioLevel = self.audioLevel * (1 - smoothingFactor) + normalizedLevel * smoothingFactor
        }
    }
    
    nonisolated private func handleError(_ error: Error) {
        print("语音识别错误: \(error)")
        
        Task { @MainActor in
            guard !Task.isCancelled else { return }
            
            // 清理资源
            cleanupResources()
            
            // 创建更详细的错误信息
            let errorMessage = createUserFriendlyErrorMessage(error)
            recordingState = .error(errorMessage)
        }
    }
    
    @MainActor
    private func createUserFriendlyErrorMessage(_ error: Error) -> String {
        if let recognitionError = error as? VoiceRecognitionError {
            return recognitionError.localizedDescription
        }
        
        // 根据错误类型提供更友好的错误信息
        let nsError = error as NSError
        
        switch nsError.domain {
        case "kAFAssistantErrorDomain":
            switch nsError.code {
            case 1101:
                return "语音识别服务暂时不可用，请稍后重试"
            case 1110:
                return "未检测到语音，请重新录制"
            case 203:
                return "网络连接问题，请检查网络设置"
            default:
                return "语音识别失败，请重新尝试"
            }
        case NSURLErrorDomain:
            return "网络连接失败，请检查网络连接"
        default:
            return "录制过程中发生错误：\(error.localizedDescription)"
        }
    }
    
    // MARK: - 状态查询
    var isRecording: Bool {
        recordingState.isRecording
    }
    
    var canRecord: Bool {
        recordingState == .idle || recordingState == .completed
    }
    
    // MARK: - 资源监控
    
    @MainActor
    func getResourceStatus() -> ResourceStatus {
        return ResourceStatus(
            isEngineRunning: isEngineRunning,
            hasTapInstalled: hasTapInstalled,
            hasActiveTask: recognitionTask != nil,
            hasActiveRequest: recognitionRequest != nil,
            audioSessionActive: audioSession.isOtherAudioPlaying
        )
    }
    
    @MainActor
    func performHealthCheck() -> VoiceServiceHealthStatus {
        // 检查基本组件
        guard let recognizer = speechRecognizer else {
            return .critical("语音识别器未初始化")
        }
        
        guard recognizer.isAvailable else {
            return .degraded("语音识别服务不可用")
        }
        
        // 检查权限
        let speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneAuthStatus = AVAudioSession.sharedInstance().recordPermission
        
        if speechAuthStatus != .authorized {
            return .critical("语音识别权限未授权")
        }
        
        if microphoneAuthStatus != .granted {
            return .critical("麦克风权限未授权")
        }
        
        // 检查音频引擎状态
        if isRecording && !isEngineRunning {
            return .degraded("音频引擎状态异常")
        }
        
        return .healthy
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension VoiceRecognitionService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("语音识别可用性变化: \(available)")
        
        Task { @MainActor in
            if !available && isRecording {
                stopRecording()
            }
        }
    }
}

// MARK: - 资源状态监控
struct ResourceStatus {
    let isEngineRunning: Bool
    let hasTapInstalled: Bool
    let hasActiveTask: Bool
    let hasActiveRequest: Bool
    let audioSessionActive: Bool
    
    var isHealthy: Bool {
        // 如果正在录制，应该有活跃的组件
        return !(isEngineRunning && !hasActiveTask)
    }
    
    var description: String {
        var components: [String] = []
        if isEngineRunning { components.append("引擎运行中") }
        if hasTapInstalled { components.append("音频监听") }
        if hasActiveTask { components.append("识别任务") }
        if hasActiveRequest { components.append("识别请求") }
        if audioSessionActive { components.append("音频会话") }
        
        return components.isEmpty ? "空闲状态" : components.joined(separator: ", ")
    }
}

enum VoiceServiceHealthStatus: Equatable {
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
            return "语音服务正常"
        case .degraded(let message):
            return "语音服务异常: \(message)"
        case .critical(let message):
            return "语音服务不可用: \(message)"
        }
    }
}

// MARK: - 错误定义
enum VoiceRecognitionError: LocalizedError {
    case permissionDenied
    case speechRecognitionUnavailable
    case failedToCreateRequest
    case audioEngineError
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要麦克风和语音识别权限"
        case .speechRecognitionUnavailable:
            return "语音识别服务不可用"
        case .failedToCreateRequest:
            return "无法创建语音识别请求"
        case .audioEngineError:
            return "音频引擎配置失败"
        }
    }
} 
