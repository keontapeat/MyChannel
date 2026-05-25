//
//  ABTestingExperimentService.swift
//  MyChannel
//
//  Phase 268: A/B Testing Experiment Results Panel
//  Manages and displays A/B testing experiments, statistical significance
//

import Foundation
import Combine

@MainActor
class ABTestingExperimentService: ObservableObject {
    static let shared = ABTestingExperimentService()
    
    @Published private(set) var activeExperiments: [ABExperiment] = []
    @Published private(set) var completedExperiments: [ABExperiment] = []
    @Published private(set) var totalExperiments: Int = 0
    @Published private(set) var winningVariants: Int = 0
    
    struct ABExperiment: Identifiable, Codable {
        let id: String
        let name: String
        let description: String
        let status: String
        let startDate: Date
        let endDate: Date?
        let variants: [Variant]
        let sampleSize: Int
        let statisticalSignificance: Double
        let winner: String?
        let liftPercentage: Double?
    }
    
    struct Variant: Codable {
        let id: String
        let name: String
        let conversionRate: Double
        let sampleSize: Int
        let confidenceInterval: String
    }
    
    private init() {
        Task { await loadExperiments() }
    }
    
    func loadExperiments() async {
        guard AppConfig.Features.enableAnalyticsPredictor else { return }
        
        struct Req: Encodable { let task: String }
        struct RawVar: Decodable { let id: String; let name: String; let conversionRate: Double; let sampleSize: Int; let confidenceInterval: String }
        struct RawExp: Decodable { let id: String; let name: String; let description: String; let status: String; let startDate: String; let endDate: String?; let variants: [RawVar]; let sampleSize: Int; let statisticalSignificance: Double; let winner: String?; let liftPercentage: Double? }
        struct Raw: Decodable { let activeExperiments: [RawExp]?; let completedExperiments: [RawExp]?; let totalExperiments: Int?; let winningVariants: Int? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_ab_experiments"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            activeExperiments = (r.activeExperiments ?? []).map {
                ABExperiment(
                    id: $0.id,
                    name: $0.name,
                    description: $0.description,
                    status: $0.status,
                    startDate: decoder.date(from: $0.startDate) ?? Date(),
                    endDate: $0.endDate != nil ? decoder.date(from: $0.endDate!) : nil,
                    variants: $0.variants.map { Variant(id: $0.id, name: $0.name, conversionRate: $0.conversionRate, sampleSize: $0.sampleSize, confidenceInterval: $0.confidenceInterval) },
                    sampleSize: $0.sampleSize,
                    statisticalSignificance: $0.statisticalSignificance,
                    winner: $0.winner,
                    liftPercentage: $0.liftPercentage
                )
            }
            
            completedExperiments = (r.completedExperiments ?? []).map {
                ABExperiment(
                    id: $0.id,
                    name: $0.name,
                    description: $0.description,
                    status: $0.status,
                    startDate: decoder.date(from: $0.startDate) ?? Date(),
                    endDate: $0.endDate != nil ? decoder.date(from: $0.endDate!) : nil,
                    variants: $0.variants.map { Variant(id: $0.id, name: $0.name, conversionRate: $0.conversionRate, sampleSize: $0.sampleSize, confidenceInterval: $0.confidenceInterval) },
                    sampleSize: $0.sampleSize,
                    statisticalSignificance: $0.statisticalSignificance,
                    winner: $0.winner,
                    liftPercentage: $0.liftPercentage
                )
            }
            
            totalExperiments = r.totalExperiments ?? 0
            winningVariants = r.winningVariants ?? 0
            
        } catch {
            print("⚠️ [ABTestingExperiment] Error: \(error)")
        }
    }
    
    func concludeExperiment(experimentId: String, winner: String) async throws {
        struct Req: Encodable { let task: String; let experimentId: String; let winner: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "conclude_experiment", experimentId: experimentId, winner: winner), timeout: 20)
        guard r.success == true else { throw NSError(domain: "ABTesting", code: -1, userInfo: nil) }
        await loadExperiments()
    }
}
