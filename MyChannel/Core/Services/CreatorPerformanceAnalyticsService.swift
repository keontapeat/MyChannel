//
//  CreatorPerformanceAnalyticsService.swift
//  MyChannel
//
//  Phase 262: Creator Performance Analytics Deep Dive
//  Deep analytics on creator performance, engagement, growth, monetization
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class CreatorPerformanceAnalyticsService: ObservableObject {
    static let shared = CreatorPerformanceAnalyticsService()
    
    @Published private(set) var topPerformers: [CreatorPerformance] = []
    @Published private(set) var atRiskCreators: [CreatorPerformance] = []
    @Published private(set) var risingStars: [CreatorPerformance] = []
    @Published private(set) var avgEngagementRate: Double = 0
    @Published private(set) var avgGrowthRate: Double = 0
    
    struct CreatorPerformance: Identifiable, Codable {
        let id: String
        let creatorId: String
        let creatorName: String
        let profileImageURL: String?
        let subscriberCount: Int
        let totalViews: Double
        let avgWatchTime: Double
        let engagementRate: Double
        let uploadFrequency: Int
        let revenueThisMonth: Double
        let growthRate: Double
        let healthScore: Double
        let audienceRetention: Double
        let monetizationRate: Double
        let lastActiveDate: Date
        
        var tier: String {
            healthScore >= 90 ? "Platinum" : healthScore >= 75 ? "Gold" : healthScore >= 60 ? "Silver" : "Bronze"
        }
        
        var riskLevel: String {
            growthRate < -10 ? "High Risk" : growthRate < 0 ? "Declining" : growthRate > 20 ? "Rising" : "Stable"
        }
    }
    
    private init() {
        Task { await loadAnalytics() }
    }
    
    func loadAnalytics() async {
        guard AppConfig.Features.enableCreatorTokens else { return }
        
        struct Req: Encodable { let task: String }
        struct RawC: Decodable { let id: String; let creatorId: String; let creatorName: String; let profileImageURL: String?; let subscriberCount: Int; let totalViews: Double; let avgWatchTime: Double; let engagementRate: Double; let uploadFrequency: Int; let revenueThisMonth: Double; let growthRate: Double; let healthScore: Double; let audienceRetention: Double; let monetizationRate: Double; let lastActiveDate: String }
        struct Raw: Decodable { let topPerformers: [RawC]?; let atRiskCreators: [RawC]?; let risingStars: [RawC]?; let avgEngagementRate: Double?; let avgGrowthRate: Double? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_creator_performance_analytics"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            topPerformers = (r.topPerformers ?? []).map {
                CreatorPerformance(
                    id: $0.id,
                    creatorId: $0.creatorId,
                    creatorName: $0.creatorName,
                    profileImageURL: $0.profileImageURL,
                    subscriberCount: $0.subscriberCount,
                    totalViews: $0.totalViews,
                    avgWatchTime: $0.avgWatchTime,
                    engagementRate: $0.engagementRate,
                    uploadFrequency: $0.uploadFrequency,
                    revenueThisMonth: $0.revenueThisMonth,
                    growthRate: $0.growthRate,
                    healthScore: $0.healthScore,
                    audienceRetention: $0.audienceRetention,
                    monetizationRate: $0.monetizationRate,
                    lastActiveDate: decoder.date(from: $0.lastActiveDate) ?? Date()
                )
            }
            
            atRiskCreators = (r.atRiskCreators ?? []).map {
                CreatorPerformance(
                    id: $0.id,
                    creatorId: $0.creatorId,
                    creatorName: $0.creatorName,
                    profileImageURL: $0.profileImageURL,
                    subscriberCount: $0.subscriberCount,
                    totalViews: $0.totalViews,
                    avgWatchTime: $0.avgWatchTime,
                    engagementRate: $0.engagementRate,
                    uploadFrequency: $0.uploadFrequency,
                    revenueThisMonth: $0.revenueThisMonth,
                    growthRate: $0.growthRate,
                    healthScore: $0.healthScore,
                    audienceRetention: $0.audienceRetention,
                    monetizationRate: $0.monetizationRate,
                    lastActiveDate: decoder.date(from: $0.lastActiveDate) ?? Date()
                )
            }
            
            risingStars = (r.risingStars ?? []).map {
                CreatorPerformance(
                    id: $0.id,
                    creatorId: $0.creatorId,
                    creatorName: $0.creatorName,
                    profileImageURL: $0.profileImageURL,
                    subscriberCount: $0.subscriberCount,
                    totalViews: $0.totalViews,
                    avgWatchTime: $0.avgWatchTime,
                    engagementRate: $0.engagementRate,
                    uploadFrequency: $0.uploadFrequency,
                    revenueThisMonth: $0.revenueThisMonth,
                    growthRate: $0.growthRate,
                    healthScore: $0.healthScore,
                    audienceRetention: $0.audienceRetention,
                    monetizationRate: $0.monetizationRate,
                    lastActiveDate: decoder.date(from: $0.lastActiveDate) ?? Date()
                )
            }
            
            avgEngagementRate = r.avgEngagementRate ?? 0
            avgGrowthRate = r.avgGrowthRate ?? 0
            
        } catch {
            print("⚠️ [CreatorPerformanceAnalytics] Error: \(error)")
        }
    }
    
    func getCreatorDetails(creatorId: String) async throws -> CreatorPerformance {
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawC: Decodable { let id: String; let creatorId: String; let creatorName: String; let profileImageURL: String?; let subscriberCount: Int; let totalViews: Double; let avgWatchTime: Double; let engagementRate: Double; let uploadFrequency: Int; let revenueThisMonth: Double; let growthRate: Double; let healthScore: Double; let audienceRetention: Double; let monetizationRate: Double; let lastActiveDate: String }
        struct Raw: Decodable { let creator: RawC? }
        
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "get_creator_details", creatorId: creatorId), timeout: 30)
        
        guard let c = r.creator else { throw NSError(domain: "CreatorPerformance", code: -1, userInfo: nil) }
        
        return CreatorPerformance(
            id: c.id,
            creatorId: c.creatorId,
            creatorName: c.creatorName,
            profileImageURL: c.profileImageURL,
            subscriberCount: c.subscriberCount,
            totalViews: c.totalViews,
            avgWatchTime: c.avgWatchTime,
            engagementRate: c.engagementRate,
            uploadFrequency: c.uploadFrequency,
            revenueThisMonth: c.revenueThisMonth,
            growthRate: c.growthRate,
            healthScore: c.healthScore,
            audienceRetention: c.audienceRetention,
            monetizationRate: c.monetizationRate,
            lastActiveDate: ISO8601DateFormatter().date(from: c.lastActiveDate) ?? Date()
        )
    }
}
