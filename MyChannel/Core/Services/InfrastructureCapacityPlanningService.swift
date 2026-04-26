//
//  InfrastructureCapacityPlanningService.swift
//  MyChannel
//
//  Infrastructure Capacity Planning - Predict needs, cost forecasting, auto-scaling
//

import Foundation
import Combine

@MainActor
class InfrastructureCapacityPlanningService: ObservableObject {
    static let shared = InfrastructureCapacityPlanningService()
    
    @Published private(set) var capacityForecast: CapacityForecast?
    @Published private(set) var resourceUtilization: [ResourceUtilization] = []
    @Published private(set) var scalingRecommendations: [ScalingRecommendation] = []
    
    struct CapacityForecast: Codable {
        let currentUsers: Int
        let projectedUsers: [Int]
        let timeframe: String
        let confidence: Double
    }
    
    struct ResourceUtilization: Identifiable, Codable {
        let id: String
        let resource: String
        let currentUsage: Double
        let capacity: Double
        let utilizationPercentage: Double
        let trend: String
    }
    
    struct ScalingRecommendation: Identifiable, Codable {
        let id: String
        let resource: String
        let action: String
        let reason: String
        let urgency: String
        let estimatedCost: Double
    }
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { await self?.refreshForecast() }
        }
        Task { await refreshForecast() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshForecast() async {
        guard AppConfig.Features.enableCapacityAutoscalingV2 else { return }
        
        struct Req: Encodable { let task: String }
        struct RawUtil: Decodable { let id: String; let resource: String; let currentUsage: Double; let capacity: Double; let utilizationPercentage: Double; let trend: String }
        struct RawRec: Decodable { let id: String; let resource: String; let action: String; let reason: String; let urgency: String; let estimatedCost: Double }
        struct RawForecast: Decodable { let currentUsers: Int; let projectedUsers: [Int]; let timeframe: String; let confidence: Double }
        struct Raw: Decodable { let capacityForecast: RawForecast?; let resourceUtilization: [RawUtil]?; let scalingRecommendations: [RawRec]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.autoScaler, path: "/predict",
                body: Req(task: "get_capacity_forecast"), timeout: 30)
            
            if let rawForecast = r.capacityForecast {
                capacityForecast = CapacityForecast(
                    currentUsers: rawForecast.currentUsers,
                    projectedUsers: rawForecast.projectedUsers,
                    timeframe: rawForecast.timeframe,
                    confidence: rawForecast.confidence
                )
            }
            
            resourceUtilization = (r.resourceUtilization ?? []).map {
                ResourceUtilization(
                    id: $0.id,
                    resource: $0.resource,
                    currentUsage: $0.currentUsage,
                    capacity: $0.capacity,
                    utilizationPercentage: $0.utilizationPercentage,
                    trend: $0.trend
                )
            }.sorted { $0.utilizationPercentage > $1.utilizationPercentage }
            
            scalingRecommendations = (r.scalingRecommendations ?? []).map {
                ScalingRecommendation(
                    id: $0.id,
                    resource: $0.resource,
                    action: $0.action,
                    reason: $0.reason,
                    urgency: $0.urgency,
                    estimatedCost: $0.estimatedCost
                )
            }.sorted { $0.urgency == "critical" && $1.urgency != "critical" }
            
        } catch {
            print("⚠️ [InfrastructureCapacityPlanning] Error: \(error)")
        }
    }
}
