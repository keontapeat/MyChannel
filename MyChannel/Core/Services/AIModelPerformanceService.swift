//
//  AIModelPerformanceService.swift
//  MyChannel
//
//  Phase 270: AI Model Performance Monitoring
//  Monitors AI model accuracy, latency, drift, performance across all ML services
//

import Foundation
import Combine

@MainActor
class AIModelPerformanceService: ObservableObject {
    static let shared = AIModelPerformanceService()
    
    @Published private(set) var modelMetrics: [AIModelMetric] = []
    @Published private(set) var overallHealth: Double = 0
    @Published private(set) var modelsRequiringRetraining: Int = 0
    
    struct AIModelMetric: Identifiable, Codable {
        let id: String
        let modelName: String
        let modelType: String
        let accuracy: Double
        let precision: Double
        let recall: Double
        let f1Score: Double
        let latency: Double
        let throughput: Double
        let lastTrained: Date
        let driftScore: Double
        let requiresRetraining: Bool
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
        guard AppConfig.Features.enableAIAudioDescription else { return }
        
        struct Req: Encodable { let task: String }
        struct RawModel: Decodable { let id: String; let modelName: String; let modelType: String; let accuracy: Double; let precision: Double; let recall: Double; let f1Score: Double; let latency: Double; let throughput: Double; let lastTrained: String; let driftScore: Double; let requiresRetraining: Bool }
        struct Raw: Decodable { let modelMetrics: [RawModel]?; let overallHealth: Double? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
                body: Req(task: "get_ai_model_performance"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            modelMetrics = (r.modelMetrics ?? []).map {
                AIModelMetric(
                    id: $0.id,
                    modelName: $0.modelName,
                    modelType: $0.modelType,
                    accuracy: $0.accuracy,
                    precision: $0.precision,
                    recall: $0.recall,
                    f1Score: $0.f1Score,
                    latency: $0.latency,
                    throughput: $0.throughput,
                    lastTrained: decoder.date(from: $0.lastTrained) ?? Date(),
                    driftScore: $0.driftScore,
                    requiresRetraining: $0.requiresRetraining
                )
            }
            
            overallHealth = r.overallHealth ?? 0
            modelsRequiringRetraining = modelMetrics.filter { $0.requiresRetraining }.count
            
        } catch {
            print("⚠️ [AIModelPerformance] Error: \(error)")
        }
    }
    
    func triggerRetraining(modelId: String) async throws {
        struct Req: Encodable { let task: String; let modelId: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
            body: Req(task: "trigger_retraining", modelId: modelId), timeout: 60)
        guard r.success == true else { throw NSError(domain: "AIModelPerformance", code: -1, userInfo: nil) }
        await refreshMetrics()
    }
}
