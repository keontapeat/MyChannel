//
//  AdTechCommandService.swift
//  MyChannel
//
//  Phase 893: Ad Tech Command Dashboard
//  Fill rate trends, CPM analysis, brand safety, yield optimization, advertiser health
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class AdTechCommandService: ObservableObject {
    static let shared = AdTechCommandService()

    // MARK: - Domain Models

    struct FillRateTrend: Identifiable, Codable {
        let id: String
        let date: Date
        let geo: String
        let adType: String
        let fillRate: Double
        let ecpm: Double
        let impressions: Int
        let requests: Int
        let revenue: Double
    }

    struct CPMAnalysis: Identifiable, Codable {
        let id: String
        let segment: String
        let avgCPM: Double
        let trendDirection: String
        let weekOverWeek: Double
        let topCPM: Double
        let bottomCPM: Double
    }

    struct BrandSafetyScore: Identifiable, Codable {
        let id: String
        let category: String
        let safetyScore: Double
        let suitabilityScore: Double
        let flaggedContent: Int
        let autoResolved: Int
        let humanReviewed: Int
    }

    struct AdvertiserHealth: Identifiable, Codable {
        let id: String
        let advertiserId: String
        let advertiserName: String
        let spendLast30d: Double
        let campaignCount: Int
        let avgCPM: Double
        let satisfactionScore: Double
        let churnRisk: Double
        let topCategory: String
    }

    struct YieldRecommendation: Identifiable, Codable {
        let id: String
        let recommendation: String
        let expectedRevenueImpact: Double
        let confidence: Double
        let category: String
        let priority: String
    }

    // MARK: - Published State

    @Published private(set) var fillRateTrends: [FillRateTrend] = []
    @Published private(set) var cpmAnalysis: [CPMAnalysis] = []
    @Published private(set) var brandSafety: [BrandSafetyScore] = []
    @Published private(set) var advertiserHealth: [AdvertiserHealth] = []
    @Published private(set) var yieldRecommendations: [YieldRecommendation] = []
    @Published private(set) var programmaticVsDirect: Double = 0
    @Published private(set) var adExperienceQuality: Double = 0
    @Published private(set) var overallFillRate: Double = 0
    @Published private(set) var overallECPM: Double = 0

    private var db = Firestore.firestore()

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://ad-tech-command-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableAdTechCommand else { return nil }
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableAdTechCommand else { return }

        // Load fill rate trends
        let fillSnap = try? await db.collection("adFillTrends")
            .order(by: "date", descending: true)
            .limit(to: 30)
            .getDocuments()
        fillRateTrends = fillSnap?.documents.compactMap { doc in
            let d = doc.data()
            return FillRateTrend(
                id: doc.documentID,
                date: (d["date"] as? Timestamp)?.dateValue() ?? Date(),
                geo: d["geo"] as? String ?? "global",
                adType: d["adType"] as? String ?? "all",
                fillRate: d["fillRate"] as? Double ?? 0,
                ecpm: d["ecpm"] as? Double ?? 0,
                impressions: d["impressions"] as? Int ?? 0,
                requests: d["requests"] as? Int ?? 0,
                revenue: d["revenue"] as? Double ?? 0
            )
        } ?? []

        if let latest = fillRateTrends.first {
            overallFillRate = latest.fillRate
            overallECPM = latest.ecpm
        }

        // Cloud Run for deeper analytics
        if let result = await callCloudRun(endpoint: "dashboard") {
            if let cpm = result["cpmAnalysis"] as? [[String: Any]] {
                cpmAnalysis = cpm.compactMap { d in
                    CPMAnalysis(
                        id: UUID().uuidString,
                        segment: d["segment"] as? String ?? "",
                        avgCPM: d["avgCPM"] as? Double ?? 0,
                        trendDirection: d["trendDirection"] as? String ?? "stable",
                        weekOverWeek: d["weekOverWeek"] as? Double ?? 0,
                        topCPM: d["topCPM"] as? Double ?? 0,
                        bottomCPM: d["bottomCPM"] as? Double ?? 0
                    )
                }
            }
            if let safety = result["brandSafety"] as? [[String: Any]] {
                brandSafety = safety.compactMap { d in
                    BrandSafetyScore(
                        id: UUID().uuidString,
                        category: d["category"] as? String ?? "",
                        safetyScore: d["safetyScore"] as? Double ?? 100,
                        suitabilityScore: d["suitabilityScore"] as? Double ?? 100,
                        flaggedContent: d["flaggedContent"] as? Int ?? 0,
                        autoResolved: d["autoResolved"] as? Int ?? 0,
                        humanReviewed: d["humanReviewed"] as? Int ?? 0
                    )
                }
            }
            if let adv = result["advertiserHealth"] as? [[String: Any]] {
                advertiserHealth = adv.compactMap { d in
                    AdvertiserHealth(
                        id: UUID().uuidString,
                        advertiserId: d["advertiserId"] as? String ?? "",
                        advertiserName: d["advertiserName"] as? String ?? "",
                        spendLast30d: d["spendLast30d"] as? Double ?? 0,
                        campaignCount: d["campaignCount"] as? Int ?? 0,
                        avgCPM: d["avgCPM"] as? Double ?? 0,
                        satisfactionScore: d["satisfactionScore"] as? Double ?? 0,
                        churnRisk: d["churnRisk"] as? Double ?? 0,
                        topCategory: d["topCategory"] as? String ?? ""
                    )
                }
            }
            if let yield = result["yieldRecommendations"] as? [[String: Any]] {
                yieldRecommendations = yield.compactMap { d in
                    YieldRecommendation(
                        id: UUID().uuidString,
                        recommendation: d["recommendation"] as? String ?? "",
                        expectedRevenueImpact: d["expectedRevenueImpact"] as? Double ?? 0,
                        confidence: d["confidence"] as? Double ?? 0,
                        category: d["category"] as? String ?? "",
                        priority: d["priority"] as? String ?? "MEDIUM"
                    )
                }
            }
            programmaticVsDirect = result["programmaticVsDirect"] as? Double ?? 0
            adExperienceQuality = result["adExperienceQuality"] as? Double ?? 0
        }
    }
}
