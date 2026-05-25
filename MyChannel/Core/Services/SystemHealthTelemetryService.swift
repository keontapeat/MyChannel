//
//  SystemHealthTelemetryService.swift
//  MyChannel
//
//  Phase 267: System Health Telemetry Dashboard
//  Monitors system health, latency, error rates, resource utilization
//

import Foundation
import Combine

@MainActor
class SystemHealthTelemetryService: ObservableObject {
    static let shared = SystemHealthTelemetryService()
    
    @Published private(set) var healthMetrics: [HealthMetric] = []
    @Published private(set) var systemStatus: SystemStatus = .healthy
    @Published private(set) var avgLatency: Double = 0
    @Published private(set) var errorRate: Double = 0
    @Published private(set) var uptime: Double = 99.9
    
    enum SystemStatus: String {
        case healthy = "HEALTHY"
        case degraded = "DEGRADED"
        case critical = "CRITICAL"
    }
    
    struct HealthMetric: Identifiable, Codable {
        let id: String
        let service: String
        let status: String
        let latency: Double
        let errorRate: Double
        let throughput: Double
        let cpuUsage: Double
        let memoryUsage: Double
    }
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.refreshMetrics() }
        }
        Task { await refreshMetrics() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshMetrics() async {
        guard AppConfig.Features.enableObservabilityPlatform else { return }
        
        struct Req: Encodable { let task: String }
        struct RawMetric: Decodable { let id: String; let service: String; let status: String; let latency: Double; let errorRate: Double; let throughput: Double; let cpuUsage: Double; let memoryUsage: Double }
        struct Raw: Decodable { let healthMetrics: [RawMetric]?; let avgLatency: Double?; let errorRate: Double?; let uptime: Double? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.autoScaler, path: "/predict",
                body: Req(task: "get_system_health_telemetry"), timeout: 15)
            
            healthMetrics = (r.healthMetrics ?? []).map {
                HealthMetric(
                    id: $0.id,
                    service: $0.service,
                    status: $0.status,
                    latency: $0.latency,
                    errorRate: $0.errorRate,
                    throughput: $0.throughput,
                    cpuUsage: $0.cpuUsage,
                    memoryUsage: $0.memoryUsage
                )
            }
            
            avgLatency = r.avgLatency ?? 0
            errorRate = r.errorRate ?? 0
            uptime = r.uptime ?? 99.9
            
            let criticalServices = healthMetrics.filter { $0.status == "critical" }.count
            let degradedServices = healthMetrics.filter { $0.status == "degraded" }.count
            
            systemStatus = criticalServices > 0 ? .critical : degradedServices > 0 ? .degraded : .healthy
            
        } catch {
            print("⚠️ [SystemHealthTelemetry] Error: \(error)")
        }
    }
}
