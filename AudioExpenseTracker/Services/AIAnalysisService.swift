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
    
    private let apiKey: String
    private let baseURL: String
    private let session = URLSession.shared
    
    init() {
        self.apiKey = ConfigManager.shared.deepseekAPIKey
        self.baseURL = ConfigManager.shared.apiBaseURL
        
        // 启动时验证配置
        if !ConfigManager.shared.validateAPIKey() {
            print("⚠️ API Key 配置有问题，AI 分析功能可能无法正常工作")
        }
        
        // 打印配置信息（用于调试）
        ConfigManager.shared.printConfigInfo()
    }
    
    // MARK: - 主要分析方法
    func analyzeExpense(_ request: AIAnalysisRequest) async throws -> AIAnalysisResult {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let startTime = Date()
        
        do {
            let prompt = buildAnalysisPrompt(from: request)
            let response = try await sendChatRequest(prompt: prompt)
            let result = parseAnalysisResponse(response, originalText: request.voiceText)
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            return AIAnalysisResult(
                originalText: request.voiceText,
                extractedAmount: result.extractedAmount,
                suggestedCategory: result.suggestedCategory,
                suggestedTitle: result.suggestedTitle,
                suggestedDescription: result.suggestedDescription,
                confidence: result.confidence,
                suggestedTags: result.suggestedTags,
                alternativeInterpretations: result.alternativeInterpretations,
                processingTime: processingTime,
                timestamp: Date()
            )
        } catch {
            lastError = error
            throw error
        }
    }
    
    // MARK: - 提示词构建
    private func buildAnalysisPrompt(from request: AIAnalysisRequest) -> String {
        let basePrompt = """
        你是一个专业的费用记录分析助手。请分析以下语音转文本的内容，提取费用信息并分类。
        
        语音内容："\(request.voiceText)"
        
        请按照以下 JSON 格式返回分析结果：
        {
            "amount": 金额数字（仅数字，不含货币符号）,
            "category": "分类（从以下选项中选择：餐饮、交通、购物、娱乐、医疗、住房、教育、水电费、服装、礼品、旅行、其他）",
            "title": "简短的费用标题",
            "description": "详细描述",
            "confidence": 置信度（0-1之间的小数）,
            "tags": ["相关标签数组"],
            "alternatives": [
                {
                    "amount": 备选金额,
                    "category": "备选分类",
                    "title": "备选标题",
                    "confidence": 备选置信度
                }
            ]
        }
        
        分析要求：
        1. 准确识别金额，支持各种表达方式（如"五十块"、"50元"、"半百"等）
        2. 根据语境智能推断费用类别
        3. 生成简洁明了的标题
        4. 提供详细的描述信息
        5. 给出分析的置信度评估
        6. 如果语音内容模糊，提供可能的备选解释
        
        请仅返回 JSON 格式的结果，不要包含其他文字。
        """
        
        // 如果有用户偏好，添加到提示词中
        if let preferences = request.userPreferences {
            return basePrompt + buildPreferencesContext(preferences)
        }
        
        return basePrompt
    }
    
    private func buildPreferencesContext(_ preferences: UserPreferences) -> String {
        var context = "\n\n用户偏好信息：\n"
        
        if !preferences.preferredCategories.isEmpty {
            context += "常用分类：\(preferences.preferredCategories.map(\.rawValue).joined(separator: "、"))\n"
        }
        
        if !preferences.commonMerchants.isEmpty {
            context += "常去商家：\(preferences.commonMerchants.joined(separator: "、"))\n"
        }
        
        context += "默认货币：\(preferences.defaultCurrency)\n"
        
        return context
    }
    
    // MARK: - API 请求
    private func sendChatRequest(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIAnalysisError.missingAPIKey
        }
        
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.1,
            "max_tokens": 1000
        ]
        
        guard let url = URL(string: baseURL) else {
            throw AIAnalysisError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AIAnalysisError.requestEncodingFailed
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIAnalysisError.apiError(httpResponse.statusCode)
        }
        
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let choices = jsonResponse?["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            let content = message?["content"] as? String
            
            return content ?? ""
        } catch {
            throw AIAnalysisError.responseParsingFailed
        }
    }
    
    // MARK: - 响应解析
    private func parseAnalysisResponse(_ response: String, originalText: String) -> AIAnalysisResult {
        // 尝试解析 JSON 响应
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return createFallbackResult(originalText: originalText)
        }
        
        let amount = extractDecimal(from: json["amount"])
        let categoryString = json["category"] as? String ?? "其他"
        let category = ExpenseCategory.allCases.first { $0.rawValue == categoryString } ?? .other
        let title = json["title"] as? String ?? "未知费用"
        let description = json["description"] as? String ?? ""
        let confidence = json["confidence"] as? Double ?? 0.3
        let tags = json["tags"] as? [String] ?? []
        
        // 解析备选项
        let alternativesArray = json["alternatives"] as? [[String: Any]] ?? []
        let alternatives = alternativesArray.compactMap { alt -> AlternativeInterpretation? in
            guard let altAmount = extractDecimal(from: alt["amount"]),
                  let altCategoryString = alt["category"] as? String,
                  let altCategory = ExpenseCategory.allCases.first(where: { $0.rawValue == altCategoryString }),
                  let altTitle = alt["title"] as? String,
                  let altConfidence = alt["confidence"] as? Double else {
                return nil
            }
            
            return AlternativeInterpretation(
                amount: altAmount,
                category: altCategory,
                title: altTitle,
                confidence: altConfidence
            )
        }
        
        return AIAnalysisResult(
            originalText: originalText,
            extractedAmount: amount,
            suggestedCategory: category,
            suggestedTitle: title,
            suggestedDescription: description,
            confidence: confidence,
            suggestedTags: tags,
            alternativeInterpretations: alternatives,
            processingTime: 0,
            timestamp: Date()
        )
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
        return AIAnalysisResult(
            originalText: originalText,
            extractedAmount: nil,
            suggestedCategory: .other,
            suggestedTitle: "解析失败",
            suggestedDescription: "无法解析语音内容，请手动输入",
            confidence: 0.1,
            suggestedTags: [],
            alternativeInterpretations: [],
            processingTime: 0,
            timestamp: Date()
        )
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