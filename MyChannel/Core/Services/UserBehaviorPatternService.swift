//
//  UserBehaviorPatternService.swift
//  MyChannel
//
//  Phase 266: User Behavior Pattern Analysis
//  Analyzes user behavior patterns, session flows, engagement patterns
//

import Foundation
import Combine

@MainActor
class UserBehaviorPatternService: ObservableObject {
    static let shared = UserBehaviorPatternService()
    
    @Published private(set) var behaviorPatterns: [BehaviorPattern] = []
    @Published private(set) var sessionFlows: [SessionFlow] = []
    @Published private(set) var engagementClusters: [EngagementCluster] = []
    @Published private(set) var churnRisks: [ChurnRisk] = []
    
    struct BehaviorPattern: Identifiable, Codable {
        let id: String
        let patternType: String
        let frequency: Int
        let avgDuration: Double
        let conversionRate: Double
        let description: String
        let usersAffected: Int
    }
    
    struct SessionFlow: Identifiable, Codable {
        let id: String
        let entryPoint: String
        let steps: [String]
        let dropoffRate: Double
        let completionRate: Double
        let avgSessionLength: Double
    }
    
    struct EngagementCluster: Identifiable, Codable {
        let id: String
        let clusterName: String
        let userCount: Int
        let characteristics: [String]
        let avgSessionTime: Double
        let retentionRate: Double
    }
    
    struct ChurnRisk: Identifiable, Codable {
        let id: String
        let userId: String
        let riskScore: Double
        let riskFactors: [String]
        let lastActiveDate: Date
        let predictedChurnDate: Date?
    }
    
    private init() {
        Task { await loadBehaviorData() }
    }
    
    func loadBehaviorData() async {
        guard AppConfig.Features.enableAnalyticsPredictor else { return }
        
        struct Req: Encodable { let task: String }
        struct RawPattern: Decodable { let id: String; let patternType: String; let frequency: Int; let avgDuration: Double; let conversionRate: Double; let description: String; let usersAffected: Int }
        struct RawFlow: Decodable { let id: String; let entryPoint: String; let steps: [String]; let dropoffRate: Double; let completionRate: Double; let avgSessionLength: Double }
        struct RawCluster: Decodable { let id: String; let clusterName: String; let userCount: Int; let characteristics: [String]; let avgSessionTime: Double; let retentionRate: Double }
        struct RawChurn: Decodable { let id: String; let userId: String; let riskScore: Double; let riskFactors: [String]; let lastActiveDate: String; let predictedChurnDate: String? }
        struct Raw: Decodable { let behaviorPatterns: [RawPattern]?; let sessionFlows: [RawFlow]?; let engagementClusters: [RawCluster]?; let churnRisks: [RawChurn]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_user_behavior_patterns"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            behaviorPatterns = (r.behaviorPatterns ?? []).map {
                BehaviorPattern(
                    id: $0.id,
                    patternType: $0.patternType,
                    frequency: $0.frequency,
                    avgDuration: $0.avgDuration,
                    conversionRate: $0.conversionRate,
                    description: $0.description,
                    usersAffected: $0.usersAffected
                )
            }
            
            sessionFlows = (r.sessionFlows ?? []).map {
                SessionFlow(
                    id: $0.id,
                    entryPoint: $0.entryPoint,
                    steps: $0.steps,
                    dropoffRate: $0.dropoffRate,
                    completionRate: $0.completionRate,
                    avgSessionLength: $0.avgSessionLength
                )
            }
            
            engagementClusters = (r.engagementClusters ?? []).map {
                EngagementCluster(
                    id: $0.id,
                    clusterName: $0.clusterName,
                    userCount: $0.userCount,
                    characteristics: $0.characteristics,
                    avgSessionTime: $0.avgSessionTime,
                    retentionRate: $0.retentionRate
                )
            }
            
            churnRisks = (r.churnRisks ?? []).map {
                ChurnRisk(
                    id: $0.id,
                    userId: $0.userId,
                    riskScore: $0.riskScore,
                    riskFactors: $0.riskFactors,
                    lastActiveDate: decoder.date(from: $0.lastActiveDate) ?? Date(),
                    predictedChurnDate: $0.predictedChurnDate != nil ? decoder.date(from: $0.predictedChurnDate!) : nil
                )
            }.sorted { $0.riskScore > $1.riskScore }
            
        } catch {
            print("⚠️ [UserBehaviorPattern] Error: \(error)")
        }
    }
}
