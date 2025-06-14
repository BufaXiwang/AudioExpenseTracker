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
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    deinit {
        // 在deinit中直接清理资源，不需要通过MainActor
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        speechRecognizer?.delegate = self
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
        guard await requestPermissions() else {
            throw VoiceRecognitionError.permissionDenied
        }
        
        guard speechRecognizer?.isAvailable == true else {
            throw VoiceRecognitionError.speechRecognitionUnavailable
        }
        
        try await configureAudioSession()
        try startSpeechRecognition()
        
        recordingState = .recording
        recordingStartTime = Date()
        recognizedText = ""
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        Task { @MainActor in
            recordingState = .processing
            
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
    
    private func configureAudioSession() async throws {
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func startSpeechRecognition() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceRecognitionError.failedToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.recognizedText = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    self?.handleError(error)
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
            
            // 计算音频电平
            let channelData = buffer.floatChannelData?[0]
            let channelDataValue = channelData?.pointee ?? 0
            let rms = sqrt(channelDataValue * channelDataValue)
            
            Task { @MainActor in
                self.audioLevel = rms
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func handleError(_ error: Error) {
        recordingState = .error(error.localizedDescription)
        // 已经在MainActor上下文中，可以直接调用
        stopRecording()
    }
    
    // MARK: - 状态查询
    var isRecording: Bool {
        recordingState.isRecording
    }
    
    var canRecord: Bool {
        recordingState == .idle || recordingState == .completed
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension VoiceRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available && isRecording {
            Task { @MainActor in
                stopRecording()
            }
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
            return "音频引擎错误"
        }
    }
} 
