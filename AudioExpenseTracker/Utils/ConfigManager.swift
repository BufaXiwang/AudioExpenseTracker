//
//  ConfigManager.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation

class ConfigManager {
    static let shared = ConfigManager()
    private var config: [String: Any] = [:]
    
    private init() {
        loadConfig()
    }
    
    private func loadConfig() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("⚠️ 无法找到 Config.plist 文件")
            return
        }
        
        config = plist
        print("✅ 配置文件加载成功")
    }
    
    // MARK: - API 配置
    
    var deepseekAPIKey: String {
        return config["DEEPSEEK_API_KEY"] as? String ?? ""
    }
    
    var apiBaseURL: String {
        return config["API_BASE_URL"] as? String ?? "https://api.deepseek.com/v1/chat/completions"
    }
    
    // MARK: - 验证方法
    
    var isAPIKeyConfigured: Bool {
        return !deepseekAPIKey.isEmpty
    }
    
    func validateAPIKey() -> Bool {
        let apiKey = deepseekAPIKey
        
        // 基本验证：检查格式
        if apiKey.isEmpty {
            print("❌ API Key 未配置")
            return false
        }
        
        if !apiKey.hasPrefix("sk-") {
            print("❌ API Key 格式不正确，应该以 'sk-' 开头")
            return false
        }
        
        if apiKey.count < 20 {
            print("❌ API Key 长度不足")
            return false
        }
        
        print("✅ API Key 格式验证通过")
        return true
    }
    
    // MARK: - 调试信息
    
    func printConfigInfo() {
        print("=== 配置信息 ===")
        print("API Key 已配置: \(isAPIKeyConfigured)")
        print("API Base URL: \(apiBaseURL)")
        
        if isAPIKeyConfigured {
            let maskedKey = deepseekAPIKey.prefix(7) + "..." + deepseekAPIKey.suffix(4)
            print("API Key: \(maskedKey)")
        }
        print("===============")
    }
} 