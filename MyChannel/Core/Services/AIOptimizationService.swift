//
//  AIOptimizationService.swift
//  MyChannel
//
//  AI API OPTIMIZATION - Rate limiting, caching, cost monitoring
//  Prevents budget drain, ensures AI services stay online
//

import Foundation
import Combine

@MainActor
final class AIOptimizationService: ObservableObject {
    static let shared = AIOptimizationService()
    
    @Published var totalCost: Double = 0.0
    @Published var dailyCost: Double = 0.0
    @Published var monthlyBudget: Double = 5000.0 // $5K/month budget
    @Published var isOverBudget: Bool = false
    
    // Rate limiting
    private var requestCounts: [String: [Date]] = [:] // userId -> timestamps
    private let maxRequestsPerHour = 100
    private let maxRequestsPerDay = 500
    
    // Response caching
    private var cache: [String: CachedResponse] = [:]
    private let cacheLifetime: TimeInterval = 3600 // 1 hour
    private let maxCacheSize = 1000
    
    // Cost tracking
    private struct AICall {
        let service: AIService
        let userId: String
        let timestamp: Date
        let cost: Double
        let cached: Bool
    }
    
    private var callHistory: [AICall] = []
    
    enum AIService: String {
        case claude = "Anthropic Claude"
        case gemini = "Google Gemini"
        case gpt4 = "OpenAI GPT-4"
        case dalle = "OpenAI DALL-E"
        
        var costPerRequest: Double {
            switch self {
            case .claude: return 0.015 // $0.015 per request (estimate)
            case .gemini: return 0.001 // $0.001 per request (cheaper!)
            case .gpt4: return 0.03 // $0.03 per request (most expensive)
            case .dalle: return 0.04 // $0.04 per image
            }
        }
    }
    
    struct CachedResponse: Codable {
        let response: String
        let timestamp: Date
        let ttl: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }
    
    private init() {
        setupCostMonitoring()
        loadCostHistory()
    }
    
    // MARK: - Rate Limiting
    
    func canMakeRequest(userId: String) -> Bool {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let oneDayAgo = now.addingTimeInterval(-86400)
        
        // Clean up old timestamps
        if var timestamps = requestCounts[userId] {
            timestamps = timestamps.filter { $0 > oneDayAgo }
            requestCounts[userId] = timestamps
            
            // Check hourly limit
            let recentRequests = timestamps.filter { $0 > oneHourAgo }
            if recentRequests.count >= maxRequestsPerHour {
                print("⚠️ Rate limit exceeded (hourly) for user \(userId)")
                return false
            }
            
            // Check daily limit
            if timestamps.count >= maxRequestsPerDay {
                print("⚠️ Rate limit exceeded (daily) for user \(userId)")
                return false
            }
        }
        
        return true
    }
    
    private func recordRequest(userId: String) {
        let now = Date()
        if requestCounts[userId] != nil {
            requestCounts[userId]?.append(now)
        } else {
            requestCounts[userId] = [now]
        }
    }
    
    // MARK: - Response Caching
    
    func getCachedResponse(cacheKey: String) -> String? {
        guard let cached = cache[cacheKey], !cached.isExpired else {
            // Remove expired cache
            cache.removeValue(forKey: cacheKey)
            return nil
        }
        
        print("✅ Cache HIT for \(cacheKey)")
        return cached.response
    }
    
    func cacheResponse(_ response: String, cacheKey: String, ttl: TimeInterval? = nil) {
        let lifetime = ttl ?? cacheLifetime
        cache[cacheKey] = CachedResponse(response: response, timestamp: Date(), ttl: lifetime)
        
        // Limit cache size
        if cache.count > maxCacheSize {
            // Remove oldest entries
            let sortedKeys = cache.sorted { $0.value.timestamp < $1.value.timestamp }.map { $0.key }
            for key in sortedKeys.prefix(cache.count - maxCacheSize) {
                cache.removeValue(forKey: key)
            }
        }
        
        print("💾 Cached response for \(cacheKey) (TTL: \(lifetime)s)")
    }
    
    // MARK: - Optimized AI Calls
    
    /// Make AI request with rate limiting, caching, and cost tracking
    func makeOptimizedRequest(
        service: AIService,
        userId: String,
        prompt: String,
        cacheKey: String? = nil,
        cacheTTL: TimeInterval? = nil,
        forceFresh: Bool = false
    ) async throws -> String {
        
        // 1. Check rate limit
        guard canMakeRequest(userId: userId) else {
            throw NSError(domain: "AIOptimization", code: 429, userInfo: [
                NSLocalizedDescriptionKey: "Rate limit exceeded. Please try again later."
            ])
        }
        
        // 2. Check cache (if not forcing fresh)
        if !forceFresh, let cacheKey = cacheKey, let cached = getCachedResponse(cacheKey: cacheKey) {
            recordRequest(userId: userId)
            recordCost(service: service, userId: userId, cached: true)
            return cached
        }
        
        // 3. Check budget
        guard !isOverBudget else {
            throw NSError(domain: "AIOptimization", code: 402, userInfo: [
                NSLocalizedDescriptionKey: "Monthly AI budget exceeded. Using fallback responses."
            ])
        }
        
        // 4. Make actual AI call
        let response: String
        switch service {
        case .claude:
            response = try await AnthropicService.shared.sendMessage(prompt)
        case .gemini:
            response = try await VertexAIService.shared.generateContent(prompt: prompt)
        case .gpt4:
            response = try await OpenAIService.shared.chat(messages: [
                .init(role: "user", content: prompt)
            ])
        case .dalle:
            // DALL-E returns image URL, not text
            response = try await OpenAIService.shared.generateThumbnail(prompt: prompt, style: "vivid")
        }
        
        // 5. Cache response
        if let cacheKey = cacheKey {
            cacheResponse(response, cacheKey: cacheKey, ttl: cacheTTL)
        }
        
        // 6. Track cost and rate limit
        recordRequest(userId: userId)
        recordCost(service: service, userId: userId, cached: false)
        
        return response
    }
    
    // MARK: - Cost Tracking
    
    private func recordCost(service: AIService, userId: String, cached: Bool) {
        let cost = cached ? 0.0 : service.costPerRequest
        
        let call = AICall(
            service: service,
            userId: userId,
            timestamp: Date(),
            cost: cost,
            cached: cached
        )
        
        callHistory.append(call)
        totalCost += cost
        
        // Update daily cost
        updateDailyCost()
        
        // Check budget
        if dailyCost > monthlyBudget / 30 { // Daily budget is monthly / 30
            isOverBudget = true
            print("🚨 DAILY BUDGET EXCEEDED! Daily: $\(String(format: "%.2f", dailyCost)), Limit: $\(String(format: "%.2f", monthlyBudget / 30))")
        }
        
        print("💰 AI Cost: \(service.rawValue) = $\(String(format: "%.4f", cost)) | Total Today: $\(String(format: "%.2f", dailyCost)) | Total Month: $\(String(format: "%.2f", totalCost))")
    }
    
    private func updateDailyCost() {
        let today = Calendar.current.startOfDay(for: Date())
        dailyCost = callHistory
            .filter { Calendar.current.isDate($0.timestamp, inSameDayAs: today) }
            .reduce(0) { $0 + $1.cost }
    }
    
    private func setupCostMonitoring() {
        // Reset daily cost at midnight
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDailyReset()
            }
        }
    }
    
    private func checkDailyReset() {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's a new day
        if let lastCall = callHistory.last, !calendar.isDate(lastCall.timestamp, inSameDayAs: now) {
            print("🌅 New day - resetting daily cost")
            isOverBudget = false
        }
        
        updateDailyCost()
        saveCostHistory()
    }
    
    // MARK: - Persistence
    
    private func saveCostHistory() {
        // Save last 1000 calls only
        let recentCalls = callHistory.suffix(1000)
        let callData = recentCalls.map { call in
            [
                "service": call.service.rawValue,
                "userId": call.userId,
                "timestamp": call.timestamp.timeIntervalSince1970,
                "cost": call.cost,
                "cached": call.cached
            ] as [String : Any]
        }
        
        UserDefaults.standard.set(callData, forKey: "ai_call_history")
        UserDefaults.standard.set(totalCost, forKey: "ai_total_cost")
    }
    
    private func loadCostHistory() {
        // Load from UserDefaults
        if let savedCalls = UserDefaults.standard.array(forKey: "ai_call_history") as? [[String: Any]] {
            callHistory = savedCalls.compactMap { dict in
                guard let serviceStr = dict["service"] as? String,
                      let service = AIService(rawValue: serviceStr),
                      let userId = dict["userId"] as? String,
                      let timestampInterval = dict["timestamp"] as? TimeInterval,
                      let cost = dict["cost"] as? Double,
                      let cached = dict["cached"] as? Bool else {
                    return nil
                }
                
                return AICall(
                    service: service,
                    userId: userId,
                    timestamp: Date(timeIntervalSince1970: timestampInterval),
                    cost: cost,
                    cached: cached
                )
            }
        }
        
        if let savedTotal = UserDefaults.standard.object(forKey: "ai_total_cost") as? Double {
            totalCost = savedTotal
        }
        
        updateDailyCost()
    }
    
    // MARK: - Analytics
    
    func getServiceBreakdown() -> [AIService: (calls: Int, cost: Double, cacheHitRate: Double)] {
        var breakdown: [AIService: (calls: Int, cost: Double, cacheHitRate: Double)] = [:]
        
        for service in [AIService.claude, .gemini, .gpt4, .dalle] {
            let serviceCalls = callHistory.filter { $0.service == service }
            let totalCalls = serviceCalls.count
            let cachedCalls = serviceCalls.filter { $0.cached }.count
            let totalCost = serviceCalls.reduce(0) { $0 + $1.cost }
            let cacheHitRate = totalCalls > 0 ? Double(cachedCalls) / Double(totalCalls) * 100 : 0
            
            breakdown[service] = (calls: totalCalls, cost: totalCost, cacheHitRate: cacheHitRate)
        }
        
        return breakdown
    }
    
    func printCostReport() {
        print("\n💰 AI COST REPORT")
        print("================")
        print("Daily Cost: $\(String(format: "%.2f", dailyCost))")
        print("Monthly Total: $\(String(format: "%.2f", totalCost))")
        print("Budget: $\(String(format: "%.2f", monthlyBudget))")
        print("Usage: \(String(format: "%.1f", (totalCost / monthlyBudget) * 100))%")
        print("\nBreakdown by Service:")
        
        let breakdown = getServiceBreakdown()
        for (service, stats) in breakdown.sorted(by: { $0.value.cost > $1.value.cost }) {
            print("- \(service.rawValue): \(stats.calls) calls, $\(String(format: "%.2f", stats.cost)), \(String(format: "%.1f", stats.cacheHitRate))% cache hit")
        }
        
        print("================\n")
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cache.removeAll()
        print("🗑️ AI response cache cleared")
    }
    
    func clearExpiredCache() {
        let expiredKeys = cache.filter { $0.value.isExpired }.map { $0.key }
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
        print("🗑️ Removed \(expiredKeys.count) expired cache entries")
    }
    
    func getCacheStats() -> (size: Int, hitRate: Double, avgAge: TimeInterval) {
        let size = cache.count
        
        // Calculate average age
        let now = Date()
        let ages = cache.values.map { now.timeIntervalSince($0.timestamp) }
        let avgAge = ages.isEmpty ? 0 : ages.reduce(0, +) / Double(ages.count)
        
        // Calculate hit rate from recent calls
        let recentCalls = callHistory.suffix(100)
        let cachedCalls = recentCalls.filter { $0.cached }.count
        let hitRate = recentCalls.isEmpty ? 0 : Double(cachedCalls) / Double(recentCalls.count) * 100
        
        return (size: size, hitRate: hitRate, avgAge: avgAge)
    }
}

