//
//  VoiceRecordingView.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import SwiftUI

struct VoiceRecordingView: View {
    @EnvironmentObject private var voiceService: VoiceRecognitionService
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            // 状态指示器
            VStack(spacing: 10) {
                Text(voiceService.recordingState.description)
                    .font(.headline)
                    .foregroundColor(statusColor)
                
                if voiceService.isRecording {
                    // 音频波形指示器
                    AudioLevelIndicator(level: voiceService.audioLevel)
                        .frame(height: 60)
                }
            }
            
            // 录制按钮
            RecordButton(
                isRecording: voiceService.isRecording,
                canRecord: voiceService.canRecord
            ) {
                await handleRecordButtonTap()
            }
            
            // 识别的文本
            if !voiceService.recognizedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("识别结果:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(voiceService.recognizedText)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .alert("录制错误", isPresented: $showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var statusColor: Color {
        switch voiceService.recordingState {
        case .idle:
            return .primary
        case .recording:
            return .red
        case .processing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
    
    private func handleRecordButtonTap() async {
        do {
            if voiceService.isRecording {
                await MainActor.run {
                    voiceService.stopRecording()
                }
            } else {
                try await voiceService.startRecording()
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - 录制按钮
struct RecordButton: View {
    let isRecording: Bool
    let canRecord: Bool
    let action: () async -> Void
    
    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 120, height: 120)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isRecording)
                
                Image(systemName: buttonIcon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .disabled(!canRecord && !isRecording)
        .shadow(color: buttonColor.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    private var buttonColor: Color {
        if isRecording {
            return .red
        } else if canRecord {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var buttonIcon: String {
        isRecording ? "stop.fill" : "mic.fill"
    }
}

// MARK: - 音频电平指示器
struct AudioLevelIndicator: View {
    let level: Float
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4)
                    .scaleEffect(y: barScale(for: index))
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }
    
    private func barScale(for index: Int) -> CGFloat {
        let normalizedLevel = CGFloat(level) * 10
        let threshold = CGFloat(index)
        return normalizedLevel > threshold ? min(normalizedLevel - threshold, 1.0) : 0.1
    }
    
    private func barColor(for index: Int) -> Color {
        let normalizedLevel = CGFloat(level) * 10
        let threshold = CGFloat(index)
        
        if normalizedLevel > threshold {
            if index < 12 {
                return .green
            } else if index < 16 {
                return .yellow
            } else {
                return .red
            }
        } else {
            return .gray.opacity(0.3)
        }
    }
}

#Preview {
    VoiceRecordingView()
        .environmentObject(VoiceRecognitionService())
} 