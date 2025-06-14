//
//  SystemMonitor.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation
import Combine

@MainActor
class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()
    
    @Published var systemHealth: SystemHealthStatus = .unknown
    @Published var lastHealthCheck: Date?
    @Published var healthIssues: [HealthIssue] = []
    @Published var errorHistory: [SystemError] = []
    
    private var healthCheckTimer: Timer?
    private let maxErrorHistory = 50
    private let healthCheckInterval: TimeInterval = 30.0 // 30秒检查一次
    
    private init() {
        startPeriodicHealthCheck()
    }
    
    deinit {
        Task { @MainActor in
            stopPeriodicHealthCheck()
        }
    }
    
    // MARK: - 健康检查
    
    func performComprehensiveHealthCheck(
        dataService: DataStorageService,
        voiceService: VoiceRecognitionService,
        viewModel: ExpenseRecordingViewModel
    ) async {
        var issues: [HealthIssue] = []
        
                 // 检查数据服务
         let dataHealth = dataService.performHealthCheck()
         if !dataHealth.isOperational {
             let severity: Severity = {
                 switch dataHealth {
                 case .critical:
                     return .critical
                 default:
                     return .warning
                 }
             }()
             
             issues.append(HealthIssue(
                 component: .dataStorage,
                 severity: severity,
                 description: dataHealth.description,
                 timestamp: Date()
             ))
         }
        
                 // 检查语音服务
         let voiceHealth = voiceService.performHealthCheck()
         if !voiceHealth.isOperational {
             let severity: Severity = {
                 switch voiceHealth {
                 case .critical:
                     return .critical
                 default:
                     return .warning
                 }
             }()
             
             issues.append(HealthIssue(
                 component: .voiceRecognition,
                 severity: severity,
                 description: voiceHealth.description,
                 timestamp: Date()
             ))
         }
        
                 // 检查视图模型
         let viewModelHealth = await viewModel.performHealthCheck()
         if !viewModelHealth.isOperational {
             let severity: Severity = {
                 switch viewModelHealth {
                 case .critical:
                     return .critical
                 default:
                     return .warning
                 }
             }()
             
             issues.append(HealthIssue(
                 component: .viewModel,
                 severity: severity,
                 description: viewModelHealth.description,
                 timestamp: Date()
             ))
         }
        
        // 检查配置
        if !ConfigManager.shared.validateAPIKey() {
            issues.append(HealthIssue(
                component: .configuration,
                severity: .critical,
                description: "API Key 配置无效",
                timestamp: Date()
            ))
        }
        
        // 更新健康状态
        healthIssues = issues
        lastHealthCheck = Date()
        
        if issues.isEmpty {
            systemHealth = .healthy
        } else if issues.contains(where: { $0.severity == .critical }) {
            systemHealth = .critical
        } else {
            systemHealth = .degraded
        }
    }
    
    // MARK: - 错误记录和恢复
    
    func recordError(_ error: Error, component: SystemComponent, context: String? = nil) {
        let systemError = SystemError(
            error: error,
            component: component,
            context: context,
            timestamp: Date()
        )
        
        errorHistory.insert(systemError, at: 0)
        
        // 保持错误历史记录在合理范围内
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeLast()
        }
        
        // 尝试自动恢复
        Task {
            await attemptAutoRecovery(for: component, error: error)
        }
    }
    
    private func attemptAutoRecovery(for component: SystemComponent, error: Error) async {
        switch component {
        case .dataStorage:
            // 数据存储问题的自动恢复
            print("🔄 尝试数据存储自动恢复...")
            // 可以尝试重新初始化数据库连接等
            
        case .voiceRecognition:
            // 语音识别问题的自动恢复
            print("🔄 尝试语音识别自动恢复...")
            // 可以尝试重新初始化音频会话等
            
        case .aiAnalysis:
            // AI 分析问题的自动恢复
            print("🔄 尝试 AI 分析自动恢复...")
            // 可以尝试切换到备用 API 或本地处理
            
        case .viewModel:
            // 视图模型问题的自动恢复
            print("🔄 尝试视图模型自动恢复...")
            // 可以尝试重置状态等
            
        case .configuration:
            // 配置问题通常需要用户干预
            print("⚠️ 配置问题需要用户干预")
        }
    }
    
    // MARK: - 定期检查
    
    private func startPeriodicHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // 这里需要传入实际的服务实例
                // 在实际使用中，应该通过依赖注入获取这些实例
                print("🔍 执行定期健康检查...")
            }
        }
    }
    
    private func stopPeriodicHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    // MARK: - 统计信息
    
    func getSystemStats() -> SystemStats {
        let criticalIssues = healthIssues.filter { $0.severity == .critical }.count
        let warningIssues = healthIssues.filter { $0.severity == .warning }.count
        let recentErrors = errorHistory.filter { Date().timeIntervalSince($0.timestamp) < 3600 }.count // 最近1小时
        
        return SystemStats(
            totalIssues: healthIssues.count,
            criticalIssues: criticalIssues,
            warningIssues: warningIssues,
            recentErrors: recentErrors,
            lastHealthCheck: lastHealthCheck,
            uptimeDescription: getUptimeDescription()
        )
    }
    
    private func getUptimeDescription() -> String {
        guard let lastCheck = lastHealthCheck else {
            return "未知"
        }
        
        let interval = Date().timeIntervalSince(lastCheck)
        if interval < 60 {
            return "\(Int(interval)) 秒前检查"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) 分钟前检查"
        } else {
            return "\(Int(interval / 3600)) 小时前检查"
        }
    }
    
    // MARK: - 诊断信息
    
    func generateDiagnosticReport() -> String {
        var report = """
        === AudioExpenseTracker 诊断报告 ===
        生成时间: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))
        
        系统健康状态: \(systemHealth.description)
        
        """
        
        if !healthIssues.isEmpty {
            report += "当前问题:\n"
            for issue in healthIssues {
                report += "- [\(issue.severity.description)] \(issue.component.description): \(issue.description)\n"
            }
            report += "\n"
        }
        
        if !errorHistory.isEmpty {
            report += "最近错误记录:\n"
            for error in errorHistory.prefix(5) {
                report += "- \(error.component.description): \(error.error.localizedDescription)\n"
            }
            report += "\n"
        }
        
        let stats = getSystemStats()
        report += """
        统计信息:
        - 总问题数: \(stats.totalIssues)
        - 严重问题: \(stats.criticalIssues)
        - 警告问题: \(stats.warningIssues)
        - 最近错误: \(stats.recentErrors)
        - 最后检查: \(stats.uptimeDescription)
        
        配置信息:
        - API Key 配置: \(ConfigManager.shared.isAPIKeyConfigured ? "已配置" : "未配置")
        - API Base URL: \(ConfigManager.shared.apiBaseURL)
        """
        
        return report
    }
}

// MARK: - 数据结构

enum SystemHealthStatus {
    case unknown
    case healthy
    case degraded
    case critical
    
    var description: String {
        switch self {
        case .unknown:
            return "未知"
        case .healthy:
            return "正常"
        case .degraded:
            return "异常"
        case .critical:
            return "严重"
        }
    }
    
    var color: String {
        switch self {
        case .unknown:
            return "gray"
        case .healthy:
            return "green"
        case .degraded:
            return "orange"
        case .critical:
            return "red"
        }
    }
}

enum SystemComponent {
    case dataStorage
    case voiceRecognition
    case aiAnalysis
    case viewModel
    case configuration
    
    var description: String {
        switch self {
        case .dataStorage:
            return "数据存储"
        case .voiceRecognition:
            return "语音识别"
        case .aiAnalysis:
            return "AI 分析"
        case .viewModel:
            return "视图模型"
        case .configuration:
            return "配置管理"
        }
    }
}

enum Severity {
    case info
    case warning
    case critical
    
    var description: String {
        switch self {
        case .info:
            return "信息"
        case .warning:
            return "警告"
        case .critical:
            return "严重"
        }
    }
}

struct HealthIssue: Identifiable {
    let id = UUID()
    let component: SystemComponent
    let severity: Severity
    let description: String
    let timestamp: Date
}

struct SystemError: Identifiable {
    let id = UUID()
    let error: Error
    let component: SystemComponent
    let context: String?
    let timestamp: Date
}

struct SystemStats {
    let totalIssues: Int
    let criticalIssues: Int
    let warningIssues: Int
    let recentErrors: Int
    let lastHealthCheck: Date?
    let uptimeDescription: String
} 