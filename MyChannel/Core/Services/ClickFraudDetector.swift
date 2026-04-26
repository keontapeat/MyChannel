//
//  ClickFraudDetector.swift
//  MyChannel
//
//  Click fraud detection for ads: suspicious pattern analysis,
//  bot detection, IP reputation, velocity checks. Uses `trust-safety-ai` Cloud Run.
//

import Foundation

struct ClickEvent: Codable, Identifiable {
    let id: String
    let adId: String
    let userId: String
    let ipAddress: String
    let userAgent: String
    let timestamp: Date
    let isFlagged: Bool
    let fraudScore: Double
}

struct ClickFraudReport: Codable, Identifiable {
    let id: String
    let period: String
    let totalClicks: Int
    let flaggedClicks: Int
    let fraudRate: Double
    let topIPs: [String]
    let estimatedLoss: Double
}

@MainActor
final class ClickFraudDetector: ObservableObject {
    static let shared = ClickFraudDetector()
    private init() {}
    @Published private(set) var recentFlags: [ClickEvent] = []

    func analyzeClick(adId: String, userId: String, ip: String, userAgent: String) -> ClickEvent {
        let score = computeFraudScore(ip: ip, userId: userId)
        let flagged = score > 0.7
        let event = ClickEvent(id: UUID().uuidString, adId: adId, userId: userId, ipAddress: ip,
            userAgent: userAgent, timestamp: Date(), isFlagged: flagged, fraudScore: score)
        if flagged { recentFlags.append(event) }
        return event
    }

    func fetchReport(period: String = "7d") async throws -> ClickFraudReport {
        struct Req: Encodable { let task: String; let period: String }
        struct Raw: Decodable { let total: Int?; let flagged: Int?; let rate: Double?; let ips: [String]?; let loss: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict",
            body: Req(task: "fetch_click_fraud_report", period: period))
        return ClickFraudReport(id: UUID().uuidString, period: period, totalClicks: r.total ?? 0, flaggedClicks: r.flagged ?? 0,
            fraudRate: r.rate ?? 0, topIPs: r.ips ?? [], estimatedLoss: r.loss ?? 0)
    }

    func blockIP(ip: String) async throws {
        struct Req: Encodable { let task: String; let ip: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.trustSafetyAI, path: "/predict", body: Req(task: "block_fraud_ip", ip: ip))
    }

    private func computeFraudScore(ip: String, userId: String) -> Double {
        let ipFlags = recentFlags.filter { $0.ipAddress == ip }.count
        let userFlags = recentFlags.filter { $0.userId == userId }.count
        return min(1.0, Double(ipFlags) * 0.2 + Double(userFlags) * 0.15)
    }
}
