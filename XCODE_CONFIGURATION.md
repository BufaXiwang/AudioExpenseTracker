# Xcode 项目配置指南

## 解决 Info.plist 冲突问题

我已经删除了手动创建的 `Info.plist` 文件。现在需要在 Xcode 项目设置中添加必要的权限和配置。

## 配置步骤

### 1. 添加权限描述

在 Xcode 中：

1. 选择项目 `AudioExpenseTracker`
2. 选择 Target `AudioExpenseTracker`
3. 进入 `Info` 标签页
4. 在 `Custom iOS Target Properties` 中添加以下键值对：

| Key | Value |
|-----|-------|
| `NSMicrophoneUsageDescription` | `需要访问麦克风来录制语音，以便进行费用记录` |
| `NSSpeechRecognitionUsageDescription` | `需要使用语音识别功能将您的语音转换为文字，以便自动识别费用信息` |

### 2. 设置应用信息

在同一个 Info 标签页中设置：

| Key | Value |
|-----|-------|
| `CFBundleDisplayName` | `语音记账` |
| `CFBundleShortVersionString` | `1.0` |
| `CFBundleVersion` | `1` |

### 3. 验证配置

确认 Build Settings 中：
- `Generate Info.plist File` 设置为 `YES`
- 没有设置 `Info.plist File` 路径

## 手动配置方法（如果上述步骤不起作用）

如果你熟悉编辑 `.pbxproj` 文件，可以直接在项目配置中添加这些设置。

## 验证

配置完成后，尝试重新构建项目。错误应该消失。

如果仍有问题，请清理项目：
1. 在 Xcode 中：Product → Clean Build Folder (Cmd+Shift+K)
2. 删除 DerivedData：Xcode → Preferences → Locations → Derived Data → 点击箭头图标打开文件夹，删除你的项目文件夹
3. 重新构建项目 