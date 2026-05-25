//
//  ABTestManagementService.swift
//  MyChannel
//
//  A/B Test Management - Create experiments, statistical significance, auto rollout
//

import Foundation
import Combine

@MainActor
class ABTestManagementService: ObservableObject {
    static let shared = ABTestManagementService()
    
    @Published private(set) var activeExperiments: [ABTestExperiment] = []
    @Published private(set) var draftExperiments: [ABTestExperiment] = []
    @Published private(set) var completedExperiments: [ABTestExperiment] = []
    
    struct ABTestExperiment: Identifiable, Codable {
        let id: String
        let name: String
        let description: String
        let hypothesis: String
        let variants: [Variant]
        let status: String
        let startDate: Date?
        let endDate: Date?
        let sampleSize: Int
        let statisticalSignificance: Double
        let winner: String?
        let liftPercentage: Double?
        let autoRolloutEnabled: Bool
    }
    
    struct Variant: Codable {
        let id: String
        let name: String
        let trafficPercentage: Double
        let conversionRate: Double
        let sampleSize: Int
        let confidenceInterval: [Double]
    }
    
    private init() {
        Task { await loadExperiments() }
    }
    
    func loadExperiments() async {
        guard AppConfig.Features.enableAnalyticsPredictor else { return }
        
        struct Req: Encodable { let task: String }
        struct RawVar: Decodable { let id: String; let name: String; let trafficPercentage: Double; let conversionRate: Double; let sampleSize: Int; let confidenceInterval: [Double] }
        struct RawExp: Decodable { let id: String; let name: String; let description: String; let hypothesis: String; let variants: [RawVar]; let status: String; let startDate: String?; let endDate: String?; let sampleSize: Int; let statisticalSignificance: Double; let winner: String?; let liftPercentage: Double?; let autoRolloutEnabled: Bool }
        struct Raw: Decodable { let activeExperiments: [RawExp]?; let draftExperiments: [RawExp]?; let completedExperiments: [RawExp]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_ab_experiments"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            let decodeExp = { (raw: RawExp) -> ABTestExperiment in
                ABTestExperiment(
                    id: raw.id,
                    name: raw.name,
                    description: raw.description,
                    hypothesis: raw.hypothesis,
                    variants: raw.variants.map { Variant(id: $0.id, name: $0.name, trafficPercentage: $0.trafficPercentage, conversionRate: $0.conversionRate, sampleSize: $0.sampleSize, confidenceInterval: $0.confidenceInterval) },
                    status: raw.status,
                    startDate: raw.startDate != nil ? decoder.date(from: raw.startDate!) : nil,
                    endDate: raw.endDate != nil ? decoder.date(from: raw.endDate!) : nil,
                    sampleSize: raw.sampleSize,
                    statisticalSignificance: raw.statisticalSignificance,
                    winner: raw.winner,
                    liftPercentage: raw.liftPercentage,
                    autoRolloutEnabled: raw.autoRolloutEnabled
                )
            }
            
            activeExperiments = (r.activeExperiments ?? []).map(decodeExp)
            draftExperiments = (r.draftExperiments ?? []).map(decodeExp)
            completedExperiments = (r.completedExperiments ?? []).map(decodeExp)
            
        } catch {
            print("⚠️ [ABTestManagement] Error: \(error)")
        }
    }
    
    func createExperiment(name: String, description: String, hypothesis: String, variants: [String], autoRollout: Bool) async throws -> String {
        struct Req: Encodable { let task: String; let name: String; let description: String; let hypothesis: String; let variants: [String]; let autoRollout: Bool }
        struct Raw: Decodable { let experimentId: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "create_ab_experiment", name: name, description: description, hypothesis: hypothesis, variants: variants, autoRollout: autoRollout), timeout: 30)
        guard let expId = r.experimentId else { throw NSError(domain: "ABTest", code: -1, userInfo: nil) }
        await loadExperiments()
        return expId
    }
    
    func startExperiment(experimentId: String) async throws {
        struct Req: Encodable { let task: String; let experimentId: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "start_ab_experiment", experimentId: experimentId), timeout: 20)
        guard r.success == true else { throw NSError(domain: "ABTest", code: -1, userInfo: nil) }
        await loadExperiments()
    }
    
    func concludeExperiment(experimentId: String, winner: String) async throws {
        struct Req: Encodable { let task: String; let experimentId: String; let winner: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "conclude_ab_experiment", experimentId: experimentId, winner: winner), timeout: 20)
        guard r.success == true else { throw NSError(domain: "ABTest", code: -1, userInfo: nil) }
        await loadExperiments()
    }
}
