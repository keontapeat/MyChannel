//
//  BotTrafficFilter.swift
//  MyChannel
//
//  BOT TRAFFIC FILTER
//  Filter out bots, crawlers, automated traffic
//

import Foundation

@MainActor
final class BotTrafficFilter: ObservableObject {
    static let shared = BotTrafficFilter()
    
    @Published var totalRequests: Int = 0
    @Published var botRequests: Int = 0
    @Published var humanRequests: Int = 0
    
    private let botUserAgents = [
        "bot", "crawler", "spider", "scraper",
        "googlebot", "bingbot", "slurp", "duckduckbot",
        "baiduspider", "yandexbot", "facebookexternalhit",
        "headless", "phantom", "selenium", "puppeteer"
    ]
    
    private init() {}
    
    /// Check if request is from a bot
    func isBot(userAgent: String, ipAddress: String) -> Bool {
        totalRequests += 1
        
        let userAgentLower = userAgent.lowercased()
        
        // Check user agent for bot signatures
        for botSignature in botUserAgents {
            if userAgentLower.contains(botSignature) {
                botRequests += 1
                print("🤖 [BotFilter] Bot detected: \(userAgent)")
                return true
            }
        }
        
        // Check for headless browser signatures
        if userAgentLower.contains("headless") || userAgentLower.isEmpty {
            botRequests += 1
            return true
        }
        
        // Check for datacenter IPs (common for bots)
        if isDatacenterIP(ipAddress) {
            botRequests += 1
            return true
        }
        
        humanRequests += 1
        return false
    }
    
    private func isDatacenterIP(_ ipAddress: String) -> Bool {
        // Check if IP belongs to known datacenter ranges
        // (In production, use IP geolocation service)
        let datacenterPrefixes = ["192.0.2", "198.51.100", "203.0.113"]
        return datacenterPrefixes.contains(where: { ipAddress.hasPrefix($0) })
    }
    
    /// Get bot detection rate
    func getBotRate() -> Double {
        guard totalRequests > 0 else { return 0 }
        return Double(botRequests) / Double(totalRequests)
    }
}

