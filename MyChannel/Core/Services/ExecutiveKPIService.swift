//
//  ExecutiveKPIService.swift
//  MyChannel
//
//  Phase 280: Executive KPI Summary Dashboard
//  High-level KPI dashboard for executive overview
//

import Foundation
import Combine

@MainActor
class ExecutiveKPIService: ObservableObject {
    static let shared = ExecutiveKPIService()
    
    @Published private(set) var kpiMetrics: [KPIMetric] = []
    @Published private(set) var overallScore: Double = 0
    @Published private(set) var quarterlyTargets: [QuarterlyTarget] = []
    @Published private(set) var alerts: [KPIAlert] = []
    
    struct KPIMetric: Identifiable, Codable {
        let id: String
        let category: String
        let name: String
        let currentValue: Double
        let target: Double
        let percentage: Double
        let trend: String
        let status: String
    }
    
    struct QuarterlyTarget: Identifiable, Codable {
        let id: String
        let metric: String
        let q1Target: Double
        let q1Actual: Double
        let q2Target: Double
        let q2Actual: Double?
        let q3Target: Double
        let q3Actual: Double?
        let q4Target: Double
        let q4Actual: Double?
    }
    
    struct KPIAlert: Identifiable, Codable {
        let id: String
        let severity: String
        let metric: String
        let message: String
        let triggeredAt: Date
    }
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { await self?.refreshMetrics() }
        }
        Task { await refreshMetrics() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshMetrics() async {
        guard AppConfig.Features.enableAnalyticsPredictor else { return }
        
        struct Req: Encodable { let task: String }
        struct RawKPI: Decodable { let id: String; let category: String; let name: String; let currentValue: Double; let target: Double; let percentage: Double; let trend: String; let status: String }
        struct RawTarget: Decodable { let id: String; let metric: String; let q1Target: Double; let q1Actual: Double; let q2Target: Double; let q2Actual: Double?; let q3Target: Double; let q3Actual: Double?; let q4Target: Double; let q4Actual: Double? }
        struct RawAlert: Decodable { let id: String; let severity: String; let metric: String; let message: String; let triggeredAt: String }
        struct Raw: Decodable { let kpiMetrics: [RawKPI]?; let overallScore: Double?; let quarterlyTargets: [RawTarget]?; let alerts: [RawAlert]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_executive_kpi"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            kpiMetrics = (r.kpiMetrics ?? []).map {
                KPIMetric(
                    id: $0.id,
                    category: $0.category,
                    name: $0.name,
                    currentValue: $0.currentValue,
                    target: $0.target,
                    percentage: $0.percentage,
                    trend: $0.trend,
                    status: $0.status
                )
            }
            
            overallScore = r.overallScore ?? 0
            
            quarterlyTargets = (r.quarterlyTargets ?? []).map {
                QuarterlyTarget(
                    id: $0.id,
                    metric: $0.metric,
                    q1Target: $0.q1Target,
                    q1Actual: $0.q1Actual,
                    q2Target: $0.q2Target,
                    q2Actual: $0.q2Actual,
                    q3Target: $0.q3Target,
                    q3Actual: $0.q3Actual,
                    q4Target: $0.q4Target,
                    q4Actual: $0.q4Actual
                )
            }
            
            alerts = (r.alerts ?? []).map {
                KPIAlert(
                    id: $0.id,
                    severity: $0.severity,
                    metric: $0.metric,
                    message: $0.message,
                    triggeredAt: decoder.date(from: $0.triggeredAt) ?? Date()
                )
            }.sorted { $0.severity == "critical" && $1.severity != "critical" }
            
        } catch {
            print("⚠️ [ExecutiveKPI] Error: \(error)")
        }
    }
}
