//
//  FunnelAnalyticsService.swift
//  MyChannel
//
//  Funnel Analytics - Multi-step conversion funnels with dropoff analysis
//

import Foundation
import Combine

@MainActor
class FunnelAnalyticsService: ObservableObject {
    static let shared = FunnelAnalyticsService()
    
    @Published private(set) var funnels: [ConversionFunnel] = []
    @Published private(set) var funnelSteps: [FunnelStep] = []
    
    struct ConversionFunnel: Identifiable, Codable {
        let id: String
        let name: String
        let description: String
        let steps: [FunnelStep]
        let overallConversionRate: Double
        let totalUsers: Int
        let topDropoffStep: String?
    }
    
    struct FunnelStep: Identifiable, Codable {
        let id: String
        let name: String
        let userCount: Int
        let conversionRate: Double
        let dropoffRate: Double
        let avgTimeInStep: Double
    }
    
    private init() {
        Task { await loadFunnelData() }
    }
    
    func loadFunnelData() async {
        guard AppConfig.Features.enableAnalytics else { return }
        
        struct Req: Encodable { let task: String }
        struct RawStep: Decodable { let id: String; let name: String; let userCount: Int; let conversionRate: Double; let dropoffRate: Double; let avgTimeInStep: Double }
        struct RawFunnel: Decodable { let id: String; let name: String; let description: String; let steps: [RawStep]; let overallConversionRate: Double; let totalUsers: Int; let topDropoffStep: String? }
        struct Raw: Decodable { let funnels: [RawFunnel]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_funnel_analytics"), timeout: 30)
            
            funnels = (r.funnels ?? []).map {
                ConversionFunnel(
                    id: $0.id,
                    name: $0.name,
                    description: $0.description,
                    steps: $0.steps.map {
                        FunnelStep(
                            id: $0.id,
                            name: $0.name,
                            userCount: $0.userCount,
                            conversionRate: $0.conversionRate,
                            dropoffRate: $0.dropoffRate,
                            avgTimeInStep: $0.avgTimeInStep
                        )
                    },
                    overallConversionRate: $0.overallConversionRate,
                    totalUsers: $0.totalUsers,
                    topDropoffStep: $0.topDropoffStep
                )
            }
            
            if let mainFunnel = funnels.first {
                funnelSteps = mainFunnel.steps
            }
            
        } catch {
            print("⚠️ [FunnelAnalytics] Error: \(error)")
        }
    }
    
    func createCustomFunnel(name: String, description: String, steps: [String]) async throws -> String {
        struct Req: Encodable { let task: String; let name: String; let description: String; let steps: [String] }
        struct Raw: Decodable { let funnelId: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "create_custom_funnel", name: name, description: description, steps: steps), timeout: 30)
        guard let funnelId = r.funnelId else { throw NSError(domain: "FunnelAnalytics", code: -1, userInfo: nil) }
        await loadFunnelData()
        return funnelId
    }
}
