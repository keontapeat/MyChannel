//
//  PersonalizationAlgorithmHealthService.swift
//  MyChannel
//
//  Phase 278: Personalization Algorithm Health
//  Monitors recommendation algorithm performance, diversity, fairness
//

import Foundation
import Combine

@MainActor
class PersonalizationAlgorithmHealthService: ObservableObject {
    static let shared = PersonalizationAlgorithmHealthService()
    
    @Published private(set) var algorithmMetrics: [AlgorithmMetric] = []
    @Published private(set) var overallHealthScore: Double = 0
    @Published private(set) var diversityScore: Double = 0
    @Published private(set) var fairnessScore: Double = 0
    
    struct AlgorithmMetric: Identifiable, Codable {
        let id: String
        let algorithmName: String
        let clickThroughRate: Double
        let watchTime: Double
        let diversity: Double
        let novelty: Double
        let serendipity: Double
        let coverage: Double
        let latency: Double
    }
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.refreshMetrics() }
        }
        Task { await refreshMetrics() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshMetrics() async {
        guard AppConfig.Features.enableAIRecommendations else { return }
        
        struct Req: Encodable { let task: String }
        struct RawMetric: Decodable { let id: String; let algorithmName: String; let clickThroughRate: Double; let watchTime: Double; let diversity: Double; let novelty: Double; let serendipity: Double; let coverage: Double; let latency: Double }
        struct Raw: Decodable { let algorithmMetrics: [RawMetric]?; let overallHealthScore: Double?; let diversityScore: Double?; let fairnessScore: Double? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.recommendations, path: "/predict",
                body: Req(task: "get_personalization_health"), timeout: 30)
            
            algorithmMetrics = (r.algorithmMetrics ?? []).map {
                AlgorithmMetric(
                    id: $0.id,
                    algorithmName: $0.algorithmName,
                    clickThroughRate: $0.clickThroughRate,
                    watchTime: $0.watchTime,
                    diversity: $0.diversity,
                    novelty: $0.novelty,
                    serendipity: $0.serendipity,
                    coverage: $0.coverage,
                    latency: $0.latency
                )
            }
            
            overallHealthScore = r.overallHealthScore ?? 0
            diversityScore = r.diversityScore ?? 0
            fairnessScore = r.fairnessScore ?? 0
            
        } catch {
            print("⚠️ [PersonalizationAlgorithmHealth] Error: \(error)")
        }
    }
}
