//
//  AIAnalysisService.swift
//  AudioExpenseTracker
//
//  Created by Zhigang Yang on 13/06/2025.
//

import Foundation

@MainActor
class AIAnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var lastError: Error?
    
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    private let maxRetryAttempts = 3
    private let requestTimeout: TimeInterval = 30.0
    
    init() {
        self.baseURL = ConfigManager.shared.apiBaseURL
        self.apiKey = ConfigManager.shared.deepseekAPIKey
        
        // 配置 URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout * 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil // 禁用缓存以确保隐私
        
        self.session = URLSession(configuration: config)
        
        // 验证配置
        if !ConfigManager.shared.validateAPIKey() {
            print("⚠️ AI 服务初始化时 API Key 验证失败")
        }
        
        // 打印配置信息（用于调试）
        ConfigManager.shared.printConfigInfo()
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    // MARK: - 公共接口
    
    func analyzeExpense(_ request: AIAnalysisRequest) async throws -> AIAnalysisResult {
        let startTime = Date()
        
        // API Key 检查
        if apiKey.isEmpty {
            throw AIAnalysisError.missingAPIKey
        }
        
        print("🤖 [AI DEBUG] 开始AI分析: '\(request.voiceText)'")
        
        do {
            let result = try await performAnalysisWithRetry(request)
            let processingTime = Date().timeIntervalSince(startTime)
            
            print("🤖 [AI DEBUG] AI分析成功完成")
            print("🤖 [AI DEBUG] - 提取金额: \(result.extractedAmount?.description ?? "nil")")
            print("🤖 [AI DEBUG] - 建议分类: \(result.suggestedCategory)")
            print("🤖 [AI DEBUG] - 建议标题: '\(result.suggestedTitle)'")
            print("🤖 [AI DEBUG] - 置信度: \(result.confidence)")
            print("🤖 [AI DEBUG] - 处理时间: \(processingTime)秒")
            
            // 添加处理时间到结果中
            return AIAnalysisResult(
                originalText: result.originalText,
                extractedAmount: result.extractedAmount,
                suggestedCategory: result.suggestedCategory,
                suggestedTitle: result.suggestedTitle,
                suggestedDescription: result.suggestedDescription,
                confidence: result.confidence,
                suggestedTags: result.suggestedTags,
                alternativeInterpretations: result.alternativeInterpretations,
                processingTime: processingTime,
                timestamp: result.timestamp
            )
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            print("🤖 [AI DEBUG] ❌ AI分析失败: \(error.localizedDescription)")
            print("🤖 [AI DEBUG] - 处理时间: \(processingTime)秒")
            
            // 直接抛出错误，不使用降级策略
            throw error
        }
    }
    
    // MARK: - 重试机制
    
    private func performAnalysisWithRetry(_ request: AIAnalysisRequest) async throws -> AIAnalysisResult {
        var lastError: Error?
        
        for attempt in 1...maxRetryAttempts {
            do {
                return try await performSingleAnalysis(request)
            } catch let error as AIAnalysisError {
                lastError = error
                
                // 某些错误不需要重试
                switch error {
                case .missingAPIKey, .invalidURL, .requestEncodingFailed:
                    throw error
                case .apiError(let code) where code == 401 || code == 403:
                    throw error // 认证错误不重试
                default:
                    if attempt < maxRetryAttempts {
                        let delay = calculateRetryDelay(attempt: attempt)
                        print("⚠️ AI 分析第 \(attempt) 次尝试失败，\(delay) 秒后重试: \(error.localizedDescription)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            } catch {
                lastError = error
                if attempt < maxRetryAttempts {
                    let delay = calculateRetryDelay(attempt: attempt)
                    print("⚠️ 网络请求第 \(attempt) 次尝试失败，\(delay) 秒后重试: \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? AIAnalysisError.networkError(NSError(domain: "Unknown", code: -1))
    }
    
    private func calculateRetryDelay(attempt: Int) -> Double {
        // 指数退避算法
        return min(pow(2.0, Double(attempt - 1)), 8.0) // 最大延迟 8 秒
    }
    
    // MARK: - 核心分析逻辑
    
    private func performSingleAnalysis(_ request: AIAnalysisRequest) async throws -> AIAnalysisResult {
        // API Key 验证
        guard !apiKey.isEmpty else {
            throw AIAnalysisError.missingAPIKey
        }
        
        // URL 验证
        guard let url = URL(string: baseURL) else {
            throw AIAnalysisError.invalidURL
        }
        
        // 构建提示词
        let prompt = buildPrompt(
            voiceText: request.voiceText,
            context: request.context,
            preferences: request.userPreferences
        )
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.3,
            "stream": false
        ]
        
        // 序列化请求
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw AIAnalysisError.requestEncodingFailed
        }
        
        // 创建请求
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("AudioExpenseTracker/1.0", forHTTPHeaderField: "User-Agent")
        urlRequest.httpBody = jsonData
        
        // 执行请求
        let (data, response) = try await session.data(for: urlRequest)
        
        // 验证响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisError.invalidResponse
        }
        
        // 检查状态码
        guard httpResponse.statusCode == 200 else {
            throw AIAnalysisError.apiError(httpResponse.statusCode)
        }
        
        // 解析响应
        return try parseResponse(data)
    }
    
    // MARK: - 提示词构建
    private func buildPrompt(voiceText: String, context: String?, preferences: UserPreferences?) -> String {
        let basePrompt = """
        你是一个贴心的个人财务助手，帮助用户记录日常消费。请分析以下语音内容，以人性化的方式整理费用信息。

        语音内容："\(voiceText)"

        请按照以下 JSON 格式返回分析结果：
        {
            "expenses": [
                {
                    "amount": 金额数字（仅数字，不含货币符号）,
                    "category": "分类（从以下选项中选择：餐饮、交通、购物、娱乐、医疗、住房、教育、水电费、服装、礼品、旅行、其他）",
                    "title": "生活化的费用标题",
                    "description": "温馨的费用描述"
                }
            ]
        }

        人性化分析要求：
        1. 💰 金额识别：
           - 准确识别各种口语表达："五十块"→50、"一百二"→120、"三块五"→3.5
           - 理解模糊表达："差不多十块钱"→10、"小二十"→20左右
           
        2. 🏷️ 标题生成：
           - 使用简洁明了的表达，避免过于装饰性的词汇
           - 直接描述消费内容：如"午餐"、"打车"、"买咖啡"
           - 优先使用具体物品或服务名称，保持简单直接
           
        3. 📝 描述优化：
           - 用温暖的语调描述消费体验
           - 适当添加生活气息和情感色彩
           - 简洁但有温度的表达
           
        4. 🎯 场景理解：
           - 餐饮：使用具体食物名称或用餐类型
           - 交通：直接使用交通方式名称
           - 购物：使用商品名称或购物类型
           - 娱乐：使用具体娱乐活动名称
           
        5. 💡 智能推理：
           - 根据时间推测消费场景（早上→早餐，晚上→晚餐）
           - 结合金额判断消费档次
           - 考虑地点和商家特色

        示例转换：
        "买了杯咖啡25块" → 
        title: "咖啡", description: "一杯香浓咖啡，为忙碌生活添点温暖"
        
        "打车回家花了30" → 
        title: "打车", description: "舒适的回家路程，结束美好的一天"

        请仅返回 JSON 格式的结果，不要包含其他文字。
        """
        
        // 如果有用户偏好，添加到提示词中
        if let preferences = preferences {
            return basePrompt + buildPreferencesContext(preferences)
        }
        
        return basePrompt
    }
    
    private func buildPreferencesContext(_ preferences: UserPreferences) -> String {
        var context = "\n\n📊 用户生活习惯参考：\n"
        
        if !preferences.preferredCategories.isEmpty {
            context += "💝 常关注的消费类型：\(preferences.preferredCategories.map(\.rawValue).joined(separator: "、"))\n"
            context += "💡 优先考虑这些分类，让记录更贴合用户习惯\n"
        }
        
        if !preferences.commonMerchants.isEmpty {
            context += "🏪 经常光顾的地方：\(preferences.commonMerchants.joined(separator: "、"))\n"
            context += "💡 如果提到这些地方，可以在描述中体现熟悉感\n"
        }
        
        context += "默认货币：\(preferences.defaultCurrency)\n"
        
        return context
    }
    
    // MARK: - 响应解析
    private func parseResponse(_ data: Data) throws -> AIAnalysisResult {
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = jsonResponse?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        guard let data = content?.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return createFallbackResult(originalText: content ?? "")
        }
        
        // 解析新的多费用格式
        if let expensesArray = json["expenses"] as? [[String: Any]], 
           let firstExpense = expensesArray.first {
            // 使用第一个费用项作为主结果
            let amount = extractDecimal(from: firstExpense["amount"])
            let categoryString = firstExpense["category"] as? String ?? "其他"
            let category = ExpenseCategory.allCases.first { $0.rawValue == categoryString } ?? .other
            let title = firstExpense["title"] as? String ?? "未知费用"
            let description = firstExpense["description"] as? String ?? ""
            
            // 将其他费用项作为备选项
            let alternatives = expensesArray.dropFirst().compactMap { expense -> AlternativeInterpretation? in
                guard let altAmount = extractDecimal(from: expense["amount"]),
                      let altCategoryString = expense["category"] as? String,
                      let altCategory = ExpenseCategory.allCases.first(where: { $0.rawValue == altCategoryString }),
                      let altTitle = expense["title"] as? String else {
                    return nil
                }
                
                return AlternativeInterpretation(
                    amount: altAmount,
                    category: altCategory,
                    title: altTitle,
                    confidence: 0.8 // 简化置信度
                )
            }
            
            return AIAnalysisResult(
                originalText: content ?? "",
                extractedAmount: amount,
                suggestedCategory: category,
                suggestedTitle: title,
                suggestedDescription: description,
                confidence: 0.8, // 简化置信度
                suggestedTags: [],
                alternativeInterpretations: alternatives,
                processingTime: 0,
                timestamp: Date()
            )
        } else {
            // 兼容旧格式
            let amount = extractDecimal(from: json["amount"])
            let categoryString = json["category"] as? String ?? "其他"
            let category = ExpenseCategory.allCases.first { $0.rawValue == categoryString } ?? .other
            let title = json["title"] as? String ?? "未知费用"
            let description = json["description"] as? String ?? ""
            
            return AIAnalysisResult(
                originalText: content ?? "",
                extractedAmount: amount,
                suggestedCategory: category,
                suggestedTitle: title,
                suggestedDescription: description,
                confidence: 0.8,
                suggestedTags: [],
                alternativeInterpretations: [],
                processingTime: 0,
                timestamp: Date()
            )
        }
    }
    
    private func extractDecimal(from value: Any?) -> Decimal? {
        if let number = value as? NSNumber {
            return number.decimalValue
        } else if let string = value as? String,
                  let double = Double(string) {
            return Decimal(double)
        }
        return nil
    }
    
    private func createFallbackResult(originalText: String) -> AIAnalysisResult {
        // 根据当前时间推测可能的消费场景
        let hour = Calendar.current.component(.hour, from: Date())
        let (title, description) = generateFallbackContent(for: hour, originalText: originalText)
        
        return AIAnalysisResult(
            originalText: originalText,
            extractedAmount: nil,
            suggestedCategory: .other,
            suggestedTitle: title,
            suggestedDescription: description,
            confidence: 0.5,
            suggestedTags: [],
            alternativeInterpretations: [],
            processingTime: 0,
            timestamp: Date()
        )
    }
    
    private func generateFallbackContent(for hour: Int, originalText: String) -> (title: String, description: String) {
        if originalText.isEmpty {
            // 根据时间生成简洁的默认内容
            switch hour {
            case 6...9:
                return ("早餐", "新的一天，记录一笔美好的开始")
            case 11...14:
                return ("午餐", "忙碌中的小憩，值得记录的时刻")
            case 17...20:
                return ("晚餐", "一天辛苦后的小小花费")
            case 21...23:
                return ("夜宵", "夜深了，不忘记录今天的点滴")
            default:
                return ("消费记录", "夜已深，但记账的习惯值得坚持")
            }
        } else {
            // 有语音内容但AI无法解析时的简洁提示
            return ("未知消费", "请手动完善这笔费用的详细信息")
        }
    }
    
    // MARK: - 配置管理
    func updateAPIKey(_ newKey: String) {
        // 在实际应用中，应该将 API Key 安全存储在 Keychain 中
        // 这里为了简化，暂时使用内存存储
    }
}

// MARK: - 错误定义
enum AIAnalysisError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case requestEncodingFailed
    case invalidResponse
    case apiError(Int)
    case responseParsingFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "缺少 API 密钥"
        case .invalidURL:
            return "无效的 API 地址"
        case .requestEncodingFailed:
            return "请求编码失败"
        case .invalidResponse:
            return "无效的服务器响应"
        case .apiError(let code):
            return "API 错误 (代码: \(code))"
        case .responseParsingFailed:
            return "响应解析失败"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
} 