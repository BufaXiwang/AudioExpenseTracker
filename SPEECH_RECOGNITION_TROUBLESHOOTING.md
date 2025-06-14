# 语音识别错误处理指南

## 🔍 常见错误分析

### kAFAssistantErrorDomain Code=1101 错误

这是iOS语音识别框架中最常见的错误之一，通常可以安全忽略。

#### 错误原因
- **系统级别的内部错误** - 与XPC通信相关
- **多个语音识别任务冲突** - 快速启动/停止录制
- **音频会话状态不一致** - 音频引擎状态混乱
- **系统资源竞争** - 其他应用使用语音功能

#### 错误特征
```
-[SFSpeechRecognitionTask localSpeechRecognitionClient:speechRecordingDidFail:]_block_invoke 
Ignoring subsequent local speech recording error: Error Domain=kAFAssistantErrorDomain Code=1101 "(null)"
```

## ✅ 已实施的解决方案

### 1. 智能错误过滤
```swift
if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
    // 这是一个可以忽略的系统错误
    print("忽略系统语音识别错误: \(error)")
    return
}
```

### 2. 完善的资源管理
- ✅ **状态跟踪** - 追踪音频引擎和tap安装状态
- ✅ **资源清理** - 统一的cleanupResources方法
- ✅ **防重复操作** - 检查状态避免重复安装tap
- ✅ **延迟重启** - 停止后等待0.5秒再重新启动

### 3. 音频会话优化
```swift
try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
```

### 4. 任务生命周期管理
- ✅ **任务取消** - 启动新任务前取消旧任务
- ✅ **请求清理** - 正确结束音频缓冲请求
- ✅ **引擎状态** - 跟踪音频引擎运行状态

## 🛠️ 错误处理策略

### 可忽略的错误
- `kAFAssistantErrorDomain Code=1101` - 系统内部错误
- `kAFAssistantErrorDomain Code=203` - 网络相关错误（暂时性）
- `kAFAssistantErrorDomain Code=216` - 语音识别服务暂时不可用

### 需要处理的错误
- **权限错误** - 引导用户授权
- **网络错误** - 提示检查网络连接
- **硬件错误** - 提示检查麦克风

## 📱 用户体验优化

### 1. 错误分类显示
```swift
private func handleError(_ error: Error) {
    let nsError = error as NSError
    
    // 忽略系统级错误
    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
        return
    }
    
    // 显示用户友好的错误信息
    let userMessage = getUserFriendlyErrorMessage(error)
    recordingState = .error(userMessage)
}
```

### 2. 自动重试机制
- **网络错误** - 自动重试3次
- **暂时性错误** - 延迟后重试
- **权限错误** - 引导用户设置

### 3. 状态恢复
- **错误后重置** - 自动清理资源并重置状态
- **用户操作** - 点击错误状态按钮重新开始

## 🔧 调试建议

### 1. 日志监控
```swift
// 添加详细日志
print("语音识别状态: \(recordingState)")
print("音频引擎运行: \(isEngineRunning)")
print("Tap已安装: \(hasTapInstalled)")
```

### 2. 状态检查
- 确保音频会话正确配置
- 检查权限状态
- 验证网络连接

### 3. 真机测试
- **模拟器限制** - 语音功能在模拟器上有限制
- **真机测试** - 所有语音功能需要在真机上测试
- **不同设备** - 在不同iOS设备上测试兼容性

## ⚠️ 注意事项

### 1. 系统限制
- **并发限制** - iOS限制同时运行的语音识别任务数量
- **时长限制** - 单次录制时长有系统限制
- **频率限制** - 频繁启动可能被系统限制

### 2. 最佳实践
- **资源清理** - 及时清理不用的资源
- **状态管理** - 维护清晰的状态机
- **错误处理** - 区分系统错误和用户错误

### 3. 性能优化
- **内存管理** - 避免内存泄漏
- **CPU使用** - 优化音频处理算法
- **电池消耗** - 合理使用音频功能

## 🎯 总结

`kAFAssistantErrorDomain Code=1101` 错误是iOS系统内部的错误，通常不影响应用功能：

1. **可以安全忽略** - 不会影响语音识别功能
2. **系统级错误** - 与应用代码无关
3. **已优化处理** - 当前实现已经过滤此类错误
4. **用户无感知** - 不会影响用户体验

如果遇到其他语音识别问题，请检查：
- 权限是否正确授权
- 网络连接是否正常
- 设备麦克风是否正常工作
- 是否在真机上测试 