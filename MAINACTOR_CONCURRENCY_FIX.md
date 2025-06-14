# MainActor 并发问题修复

## 🐛 问题描述

在实现双录音模式功能后，出现了MainActor隔离相关的编译错误：

```
Call to main actor-isolated instance method 'cleanupResources()' in a synchronous nonisolated context
```

## 🔍 问题分析

### 根本原因
`VoiceRecognitionService` 类被标记为 `@MainActor`，这意味着：
- 所有实例方法默认在主线程上执行
- 从非主线程调用这些方法会导致编译错误
- 某些回调方法（如音频tap回调、delegate方法）在后台线程执行

### 问题位置
1. **`deinit` 方法** - 可能在任意线程被调用
2. **`handleError` 方法** - 在语音识别回调中被调用
3. **`calculateAudioLevel` 方法** - 在音频tap回调中被调用
4. **`speechRecognizer:availabilityDidChange:` 方法** - delegate回调方法

## 🔧 修复方案

### 1. 标记非隔离方法
对于需要在后台线程调用的方法，使用 `nonisolated` 关键字：

```swift
// 音频电平计算 - 在音频tap回调中调用
nonisolated private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
    // 计算逻辑...
    Task { @MainActor in
        self.audioLevel = min(rms * 10, 1.0)
    }
}

// 错误处理 - 在语音识别回调中调用
nonisolated private func handleError(_ error: Error) {
    print("语音识别错误: \(error)")
    
    Task { @MainActor in
        cleanupResources()
        recordingState = .error(error.localizedDescription)
    }
}

// Delegate方法 - 系统回调
nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
    print("语音识别可用性变化: \(available)")
    
    Task { @MainActor in
        if !available && isRecording {
            stopRecording()
        }
    }
}
```

### 2. 异步调用主线程方法
在 `deinit` 中使用 `Task { @MainActor in }` 确保资源清理在主线程执行：

```swift
deinit {
    // 确保资源被正确清理
    Task { @MainActor in
        cleanupResources()
    }
}
```

### 3. 简化同步方法
移除不必要的 `Task { @MainActor in }` 包装：

```swift
func stopRecording() {
    guard isRecording else { return }
    
    recordingState = .processing
    cleanupResources()
    
    // 直接在主线程执行，无需Task包装
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
```

## ✅ 修复结果

### 修复的方法
1. ✅ `deinit` - 使用 `Task { @MainActor in }`
2. ✅ `handleError` - 标记为 `nonisolated`
3. ✅ `calculateAudioLevel` - 标记为 `nonisolated`
4. ✅ `speechRecognizer:availabilityDidChange:` - 标记为 `nonisolated`
5. ✅ `stopRecording` - 移除不必要的Task包装

### 并发安全保证
- **主线程操作**: UI更新和状态变更在主线程执行
- **后台线程操作**: 音频处理和系统回调在后台线程执行
- **线程安全**: 使用 `Task { @MainActor in }` 确保线程安全的状态更新

## 🎯 最佳实践

### MainActor 使用原则
1. **UI相关类**: 标记为 `@MainActor`
2. **系统回调**: 使用 `nonisolated` 标记
3. **状态更新**: 在 `Task { @MainActor in }` 中执行
4. **资源清理**: 确保在正确的线程执行

### 并发编程建议
1. **明确线程需求**: 区分哪些操作需要在主线程，哪些可以在后台
2. **最小化跨线程调用**: 减少不必要的线程切换
3. **使用类型安全**: 利用Swift的并发系统确保类型安全
4. **测试并发场景**: 确保在各种并发情况下的正确性

## 🔮 未来考虑

### 性能优化
- 考虑将音频处理移到专门的后台队列
- 优化状态更新的频率和时机
- 减少主线程的工作负载

### 架构改进
- 考虑分离UI状态管理和音频处理逻辑
- 使用更细粒度的并发控制
- 实现更好的错误恢复机制

## 📝 总结

通过正确使用 `@MainActor`、`nonisolated` 和 `Task { @MainActor in }`，成功解决了并发相关的编译错误。这次修复不仅解决了immediate问题，还提高了代码的并发安全性和可维护性。

修复后的代码遵循了Swift并发编程的最佳实践，确保了UI更新在主线程执行，同时允许音频处理和系统回调在适当的线程执行。 