//
//  CreatorOnboardingFunnelService.swift
//  MyChannel
//
//  Phase 271: Creator Onboarding Funnel Analysis
//  Analyzes creator onboarding funnel, dropoff points, conversion rates
//

import Foundation
import Combine

@MainActor
class CreatorOnboardingFunnelService: ObservableObject {
    static let shared = CreatorOnboardingFunnelService()
    
    @Published private(set) var funnelStages: [FunnelStage] = []
    @Published private(set) var dropoffPoints: [DropoffPoint] = []
    @Published private(set) var conversionRate: Double = 0
    @Published private(set) var avgTimeToFirstUpload: Double = 0
    
    struct FunnelStage: Identifiable, Codable {
        let id: String
        let stageName: String
        let users: Int
        let conversionRate: Double
        let avgTimeInStage: Double
    }
    
    struct DropoffPoint: Identifiable, Codable {
        let id: String
        let stage: String
        let dropoffRate: Double
        let commonReasons: [String]
        let suggestedFixes: [String]
    }
    
    private init() {
        Task { await loadFunnelData() }
    }
    
    func loadFunnelData() async {
        guard AppConfig.Features.enableCreatorTokens else { return }
        
        struct Req: Encodable { let task: String }
        struct RawStage: Decodable { let id: String; let stageName: String; let users: Int; let conversionRate: Double; let avgTimeInStage: Double }
        struct RawDrop: Decodable { let id: String; let stage: String; let dropoffRate: Double; let commonReasons: [String]; let suggestedFixes: [String] }
        struct Raw: Decodable { let funnelStages: [RawStage]?; let dropoffPoints: [RawDrop]?; let conversionRate: Double?; let avgTimeToFirstUpload: Double? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_creator_onboarding_funnel"), timeout: 30)
            
            funnelStages = (r.funnelStages ?? []).map {
                FunnelStage(
                    id: $0.id,
                    stageName: $0.stageName,
                    users: $0.users,
                    conversionRate: $0.conversionRate,
                    avgTimeInStage: $0.avgTimeInStage
                )
            }
            
            dropoffPoints = (r.dropoffPoints ?? []).map {
                DropoffPoint(
                    id: $0.id,
                    stage: $0.stage,
                    dropoffRate: $0.dropoffRate,
                    commonReasons: $0.commonReasons,
                    suggestedFixes: $0.suggestedFixes
                )
            }.sorted { $0.dropoffRate > $1.dropoffRate }
            
            conversionRate = r.conversionRate ?? 0
            avgTimeToFirstUpload = r.avgTimeToFirstUpload ?? 0
            
        } catch {
            print("⚠️ [CreatorOnboardingFunnel] Error: \(error)")
        }
    }
}
