//
//  BotTrafficFilter.swift
//  MyChannel
//
//  Bot traffic filtering: request fingerprinting, behavioral analysis,
//  CAPTCHA integration, IP reputation. Uses `trust-safety-ai` Cloud Run.
//

import Foundation

struct BotDetection: Codable, Identifiable {
    let id: String
    let ipAddress: String
    let userAgent: String
    let fingerprint: String
    let isBot: Bool
    let confidence: Double
    let reason: String
    let detectedAt: Date
}

struct IPReputation: Codable {
    let ip: String
    let score: Double
    let category: String
    let lastChecked: Date
}

@MainActor
final class BotTrafficFilter: ObservableObject {
    static let shared = BotTrafficFilter()
    private init() {}
    @Published private(set) var recentDetections: [BotDetection] = []
    private var blockedIPs: Set<String> = []

    func analyzeRequest(ip: String, userAgent: String, path: String, headers: [String: String]) -> BotDetection {
        let fp = fingerprint(userAgent: userAgent, headers: headers)
        let score = computeBotScore(ip: ip, userAgent: userAgent, path: path)
        let isBot = score > 0.6
        let reason = isBot ? (score > 0.8 ? "Known bot pattern" : "Suspicious behavior") : "Human"
        let det = BotDetection(id: UUID().uuidString, ipAddress: ip, userAgent: userAgent, fingerprint: fp,
            isBot: isBot, confidence: score, reason: reason, detectedAt: Date())
        if isBot { recentDetections.append(det); if recentDetections.count > 200 { recentDetections = Array(recentDetections.suffix(100)) } }
        return det
    }

    func checkIPReputation(ip: String) async throws -> IPReputation {
        struct Req: Encodable { let task: String; let ip: String }
        struct Raw: Decodable { let score: Double?; let category: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "check_ip_reputation", ip: ip))
        return IPReputation(ip: ip, score: r.score ?? 0, category: r.category ?? "unknown", lastChecked: Date())
    }

    func blockIP(ip: String) { blockedIPs.insert(ip) }
    func unblockIP(ip: String) { blockedIPs.remove(ip) }
    func isBlocked(ip: String) -> Bool { blockedIPs.contains(ip) }

    private func fingerprint(userAgent: String, headers: [String: String]) -> String {
        let raw = "\(userAgent)|\(headers["Accept-Language"] ?? "")|\(headers["Accept-Encoding"] ?? "")"
        return raw.data(using: .utf8)?.base64EncodedString() ?? ""
    }

    private func computeBotScore(ip: String, userAgent: String, path: String) -> Double {
        var score = 0.0
        if userAgent.lowercased().contains("bot") { score += 0.5 }
        if userAgent.lowercased().contains("crawler") { score += 0.4 }
        if userAgent.lowercased().contains("spider") { score += 0.4 }
        if blockedIPs.contains(ip) { score += 0.3 }
        if path.contains("/api/") && userAgent.isEmpty { score += 0.3 }
        return min(1.0, score)
    }
}
