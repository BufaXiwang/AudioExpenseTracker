//
//  ConfigManager.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation
import Security

class ConfigManager {
    static let shared = ConfigManager()
    private var config: [String: Any] = [:]
    
    // Keychain 相关常量
    private let keychainService = "AudioExpenseTracker"
    private let apiKeyAccount = "DeepSeekAPIKey"
    
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
        
        // 如果 plist 中有 API Key，迁移到 Keychain 并从 plist 中删除
        if let apiKey = config["DEEPSEEK_API_KEY"] as? String, !apiKey.isEmpty {
            storeAPIKeyInKeychain(apiKey)
            config.removeValue(forKey: "DEEPSEEK_API_KEY") // 从内存中移除
            print("✅ API Key 已迁移到 Keychain")
        }
        
        print("✅ 配置文件加载成功")
    }
    
    // MARK: - Keychain 操作
    
    private func storeAPIKeyInKeychain(_ apiKey: String) {
        let data = apiKey.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data
        ]
        
        // 删除现有项目
        SecItemDelete(query as CFDictionary)
        
        // 添加新项目
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("❌ Keychain 存储失败: \(status)")
        }
    }
    
    private func retrieveAPIKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return apiKey
    }
    
    func deleteAPIKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyAccount
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - API 配置
    
    var deepseekAPIKey: String {
        // 优先从 Keychain 读取
        if let keychainKey = retrieveAPIKeyFromKeychain() {
            return keychainKey
        }
        
        // 如果 Keychain 中没有，返回空字符串
        return ""
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
    
    // MARK: - API Key 管理
    
    func updateAPIKey(_ newKey: String) throws {
        guard !newKey.isEmpty else {
            throw ConfigError.invalidAPIKey("API Key 不能为空")
        }
        
        guard newKey.hasPrefix("sk-") else {
            throw ConfigError.invalidAPIKey("API Key 格式不正确")
        }
        
        guard newKey.count >= 20 else {
            throw ConfigError.invalidAPIKey("API Key 长度不足")
        }
        
        storeAPIKeyInKeychain(newKey)
    }
    
    // MARK: - 调试信息
    
    func printConfigInfo() {
        print("=== 配置信息 ===")
        print("API Key 已配置: \(isAPIKeyConfigured)")
        print("API Base URL: \(apiBaseURL)")
        
        if isAPIKeyConfigured {
            let maskedKey = String(deepseekAPIKey.prefix(7)) + "..." + String(deepseekAPIKey.suffix(4))
            print("API Key: \(maskedKey)")
        }
        print("===============")
    }
}

// MARK: - 错误定义
enum ConfigError: LocalizedError {
    case invalidAPIKey(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey(let message):
            return message
        }
    }
} 