import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct SLO: Identifiable, Codable {
    let id: String
    let name: String
    let service: String
    let metric: SLOMetric
    let target: Double // e.g., 99.9 for 99.9% availability
    let window: TimeWindow
    let errorBudget: ErrorBudget
    let alerting: AlertingConfig
    let autoRollback: AutoRollbackConfig
    let isActive: Bool
    
    enum SLOMetric: String, Codable, CaseIterable {
        case availability, latency, errorRate, throughput
        
        var displayName: String {
            switch self {
            case .availability: return "Availability"
            case .latency: return "Latency (P95)"
            case .errorRate: return "Error Rate"
            case .throughput: return "Throughput"
            }
        }
    }
    
    enum TimeWindow: String, Codable, CaseIterable {
        case rolling1h, rolling24h, rolling7d, rolling28d, calendar
        
        var seconds: TimeInterval {
            switch self {
            case .rolling1h: return 3600
            case .rolling24h: return 86400
            case .rolling7d: return 604800
            case .rolling28d: return 2419200
            case .calendar: return 2419200 // Default to 28d
            }
        }
    }
    
    struct ErrorBudget: Codable {
        let totalBudget: Double
        var consumedBudget: Double
        var remainingBudget: Double
        var burnRate: Double
        var projectedExhaustion: Date?
        
        var isExhausted: Bool {
            remainingBudget <= 0
        }
        
        var isAtRisk: Bool {
            remainingBudget < totalBudget * 0.1 // Less than 10% remaining
        }
    }
    
    struct AlertingConfig: Codable {
        let enabled: Bool
        let burnRateThresholds: [BurnRateThreshold]
        let notificationChannels: [String]
        
        struct BurnRateThreshold: Codable {
            let multiplier: Double // e.g., 14.4x for 1 hour window
            let window: TimeInterval
            let severity: AlertSeverity
            
            enum AlertSeverity: String, Codable {
                case warning, critical, emergency
            }
        }
    }
    
    struct AutoRollbackConfig: Codable {
        let enabled: Bool
        let trigger: RollbackTrigger
        let maxRollbacks: Int
        let cooldownPeriod: TimeInterval
        let rollbackStrategy: RollbackStrategy
        
        enum RollbackTrigger: String, Codable {
            case errorBudgetExhausted, burnRateExceeded, manualTrigger
        }
        
        enum RollbackStrategy: String, Codable {
            case immediate, gradual, canary
        }
    }
}

struct SLOBreach: Identifiable, Codable {
    let id: String
    let sloId: String
    let service: String
    let severity: AlertSeverity
    let currentValue: Double
    let targetValue: Double
    let window: String
    let errorBudgetConsumed: Double
    let breachStartTime: Date
    let resolvedAt: Date?
    var rollbackTriggered: Bool
    var rollbackId: String?
    
    enum AlertSeverity: String, Codable {
        case warning, critical, emergency
        
        var color: String {
            switch self {
            case .warning: return "#FF9F0A"
            case .critical: return "#FF3B30"
            case .emergency: return "#8B0000"
            }
        }
    }
}

@MainActor
final class SLOMonitoringService: ObservableObject {
    static let shared = SLOMonitoringService()
    private init() {}
    
    @Published var slos: [SLO] = []
    @Published var activeBreaches: [SLOBreach] = []
    @Published var recentRollbacks: [RollbackEvent] = []
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var breachesListener: ListenerRegistration?
    #endif
    
    func configureSLOs() async {
        let defaultSLOs = [
            SLO(
                id: "availability-api",
                name: "API Availability",
                service: "mychannel-api",
                metric: .availability,
                target: 99.9,
                window: .rolling28d,
                errorBudget: SLO.ErrorBudget(
                    totalBudget: 43.2, // 43.2 minutes in 28 days for 99.9%
                    consumedBudget: 12.5,
                    remainingBudget: 30.7,
                    burnRate: 0.5,
                    projectedExhaustion: nil
                ),
                alerting: SLO.AlertingConfig(
                    enabled: true,
                    burnRateThresholds: [
                        SLO.AlertingConfig.BurnRateThreshold(multiplier: 14.4, window: 3600, severity: .critical),
                        SLO.AlertingConfig.BurnRateThreshold(multiplier: 6.0, window: 21600, severity: .warning)
                    ],
                    notificationChannels: ["slack-alerts", "pagerduty", "email-oncall"]
                ),
                autoRollback: SLO.AutoRollbackConfig(
                    enabled: true,
                    trigger: .burnRateExceeded,
                    maxRollbacks: 3,
                    cooldownPeriod: 3600,
                    rollbackStrategy: .gradual
                ),
                isActive: true
            ),
            SLO(
                id: "latency-upload",
                name: "Upload Service Latency",
                service: "mychannel-upload",
                metric: .latency,
                target: 95.0, // 95th percentile under 5s
                window: .rolling24h,
                errorBudget: SLO.ErrorBudget(
                    totalBudget: 1440, // minutes in 24h where p95 can exceed 5s
                    consumedBudget: 245,
                    remainingBudget: 1195,
                    burnRate: 1.2,
                    projectedExhaustion: Date().addingTimeInterval(86400 * 20)
                ),
                alerting: SLO.AlertingConfig(
                    enabled: true,
                    burnRateThresholds: [
                        SLO.AlertingConfig.BurnRateThreshold(multiplier: 10.0, window: 3600, severity: .critical)
                    ],
                    notificationChannels: ["slack-performance"]
                ),
                autoRollback: SLO.AutoRollbackConfig(
                    enabled: true,
                    trigger: .errorBudgetExhausted,
                    maxRollbacks: 2,
                    cooldownPeriod: 7200,
                    rollbackStrategy: .canary
                ),
                isActive: true
            )
        ]
        
        for slo in defaultSLOs {
            await storeSLO(slo)
        }
        
        await MainActor.run {
            self.slos = defaultSLOs
        }
    }
    
    func checkSLOCompliance() async -> [SLOBreach] {
        var breaches: [SLOBreach] = []
        
        for slo in slos {
            let currentValue = await getCurrentSLOValue(slo: slo)
            
            if currentValue < slo.target {
                var breach = SLOBreach(
                    id: UUID().uuidString,
                    sloId: slo.id,
                    service: slo.service,
                    severity: determineSeverity(slo: slo, currentValue: currentValue),
                    currentValue: currentValue,
                    targetValue: slo.target,
                    window: slo.window.rawValue,
                    errorBudgetConsumed: calculateErrorBudgetConsumed(slo: slo, currentValue: currentValue),
                    breachStartTime: Date(),
                    resolvedAt: nil,
                    rollbackTriggered: false,
                    rollbackId: nil
                )
                
                // Check if auto-rollback should be triggered
                if slo.autoRollback.enabled && shouldTriggerRollback(slo: slo, breach: breach) {
                    let rollbackId = await triggerAutoRollback(slo: slo, breach: breach)
                    breach.rollbackTriggered = rollbackId != nil
                    breach.rollbackId = rollbackId
                }
                
                breaches.append(breach)
            }
        }
        
        await MainActor.run {
            self.activeBreaches = breaches
        }
        
        return breaches
    }
    
    private func getCurrentSLOValue(slo: SLO) async -> Double {
        // Query monitoring system for current SLO value
        switch slo.metric {
        case .availability:
            return await getAvailabilityMetric(service: slo.service, window: slo.window)
        case .latency:
            return await getLatencyMetric(service: slo.service, window: slo.window)
        case .errorRate:
            return await getErrorRateMetric(service: slo.service, window: slo.window)
        case .throughput:
            return await getThroughputMetric(service: slo.service, window: slo.window)
        }
    }
    
    private func shouldTriggerRollback(slo: SLO, breach: SLOBreach) -> Bool {
        switch slo.autoRollback.trigger {
        case .errorBudgetExhausted:
            return slo.errorBudget.isExhausted
        case .burnRateExceeded:
            return slo.errorBudget.burnRate > 10.0 // High burn rate
        case .manualTrigger:
            return false
        }
    }
    
    private func triggerAutoRollback(slo: SLO, breach: SLOBreach) async -> String? {
        let rollbackId = UUID().uuidString
        
        do {
            // Get current Cloud Run revision
            let currentRevision = await getCurrentRevision(service: slo.service)
            let previousRevision = await getPreviousStableRevision(service: slo.service)
            
            guard let prevRevision = previousRevision else {
                print("❌ No previous stable revision found for \(slo.service)")
                return nil
            }
            
            // Perform rollback
            let success = await rollbackToRevision(
                service: slo.service,
                targetRevision: prevRevision,
                strategy: slo.autoRollback.rollbackStrategy
            )
            
            if success {
                let rollbackEvent = RollbackEvent(
                    id: rollbackId,
                    sloId: slo.id,
                    service: slo.service,
                    fromRevision: currentRevision ?? "unknown",
                    toRevision: prevRevision,
                    trigger: slo.autoRollback.trigger,
                    strategy: slo.autoRollback.rollbackStrategy,
                    startedAt: Date(),
                    completedAt: Date(),
                    status: .completed,
                    reason: "SLO breach: \(breach.currentValue) < \(breach.targetValue)"
                )
                
                await storeRollbackEvent(rollbackEvent)
                
                await MainActor.run {
                    self.recentRollbacks.append(rollbackEvent)
                }
                
                return rollbackId
            }
        } catch {
            print("❌ Rollback failed: \(error)")
        }
        
        return nil
    }
    
    private func getCurrentRevision(service: String) async -> String? {
        // Get current Cloud Run revision
        return "revision-\(service)-\(UUID().uuidString.prefix(8))"
    }
    
    private func getPreviousStableRevision(service: String) async -> String? {
        // Get the last known stable revision
        return "revision-\(service)-stable"
    }
    
    private func rollbackToRevision(service: String, targetRevision: String, strategy: SLO.AutoRollbackConfig.RollbackStrategy) async -> Bool {
        switch strategy {
        case .immediate:
            return await performImmediateRollback(service: service, revision: targetRevision)
        case .gradual:
            return await performGradualRollback(service: service, revision: targetRevision)
        case .canary:
            return await performCanaryRollback(service: service, revision: targetRevision)
        }
    }
    
    private func performImmediateRollback(service: String, revision: String) async -> Bool {
        // Immediately switch 100% of traffic to previous revision
        print("🔄 Immediate rollback: \(service) -> \(revision)")
        return true
    }
    
    private func performGradualRollback(service: String, revision: String) async -> Bool {
        // Gradually shift traffic: 25% -> 50% -> 75% -> 100%
        let steps = [25, 50, 75, 100]
        
        for step in steps {
            print("🔄 Gradual rollback: \(service) -> \(step)% to \(revision)")
            try? await Task.sleep(nanoseconds: 60_000_000_000) // 1 minute between steps
            
            // Check if SLO is recovering
            let currentSLO = await getCurrentSLOValue(slo: slos.first { $0.service == service }!)
            if currentSLO >= slos.first { $0.service == service }!.target {
                print("✅ SLO recovered at \(step)% traffic shift")
                break
            }
        }
        
        return true
    }
    
    private func performCanaryRollback(service: String, revision: String) async -> Bool {
        // Send small percentage of traffic to previous revision, monitor, then scale up
        print("🔄 Canary rollback: \(service) -> 5% to \(revision)")
        
        // Wait and monitor
        try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
        
        // If stable, complete rollback
        print("🔄 Canary rollback: \(service) -> 100% to \(revision)")
        return true
    }
    
    private func getAvailabilityMetric(service: String, window: SLO.TimeWindow) async -> Double {
        // Query Cloud Monitoring for availability
        return Double.random(in: 99.5...99.95) // Mock
    }
    
    private func getLatencyMetric(service: String, window: SLO.TimeWindow) async -> Double {
        // Query Cloud Monitoring for P95 latency
        return Double.random(in: 92.0...98.5) // Mock P95 percentage
    }
    
    private func getErrorRateMetric(service: String, window: SLO.TimeWindow) async -> Double {
        // Query Cloud Monitoring for error rate
        return Double.random(in: 99.0...99.99) // Mock success rate
    }
    
    private func getThroughputMetric(service: String, window: SLO.TimeWindow) async -> Double {
        // Query Cloud Monitoring for throughput
        return Double.random(in: 95.0...99.9) // Mock throughput percentage
    }
    
    private func determineSeverity(slo: SLO, currentValue: Double) -> SLOBreach.AlertSeverity {
        let deviation = slo.target - currentValue
        
        if deviation > 1.0 { // More than 1% below target
            return .emergency
        } else if deviation > 0.5 {
            return .critical
        } else {
            return .warning
        }
    }
    
    private func calculateErrorBudgetConsumed(slo: SLO, currentValue: Double) -> Double {
        let errorRate = (slo.target - currentValue) / 100.0
        return errorRate * slo.window.seconds / 60.0 // Convert to minutes
    }
    
    private func storeSLO(_ slo: SLO) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("slos").document(slo.id).setData([
                "name": slo.name,
                "service": slo.service,
                "metric": slo.metric.rawValue,
                "target": slo.target,
                "window": slo.window.rawValue,
                "alerting": [
                    "enabled": slo.alerting.enabled,
                    "notificationChannels": slo.alerting.notificationChannels
                ],
                "autoRollback": [
                    "enabled": slo.autoRollback.enabled,
                    "trigger": slo.autoRollback.trigger.rawValue,
                    "strategy": slo.autoRollback.rollbackStrategy.rawValue,
                    "maxRollbacks": slo.autoRollback.maxRollbacks,
                    "cooldownPeriod": slo.autoRollback.cooldownPeriod
                ],
                "isActive": slo.isActive,
                "createdAt": FieldValue.serverTimestamp()
            ])
        } catch { }
        #endif
    }
    
    private func storeRollbackEvent(_ event: RollbackEvent) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("rollback_events").document(event.id).setData([
                "sloId": event.sloId,
                "service": event.service,
                "fromRevision": event.fromRevision,
                "toRevision": event.toRevision,
                "trigger": event.trigger.rawValue,
                "strategy": event.strategy.rawValue,
                "startedAt": Timestamp(date: event.startedAt),
                "completedAt": Timestamp(date: event.completedAt),
                "status": event.status.rawValue,
                "reason": event.reason
            ])
        } catch { }
        #endif
    }
    
    func monitorErrorBudgets() async {
        for slo in slos {
            let currentValue = await getCurrentSLOValue(slo: slo)
            let errorBudgetConsumed = calculateErrorBudgetConsumed(slo: slo, currentValue: currentValue)
            
            // Update error budget
            let burnRate = errorBudgetConsumed / (slo.window.seconds / 3600.0) // Per hour
            let remainingBudget = slo.errorBudget.totalBudget - errorBudgetConsumed
            let projectedExhaustion = burnRate > 0 ? Date().addingTimeInterval((remainingBudget / burnRate) * 3600) : nil
            
            let updatedErrorBudget = SLO.ErrorBudget(
                totalBudget: slo.errorBudget.totalBudget,
                consumedBudget: errorBudgetConsumed,
                remainingBudget: remainingBudget,
                burnRate: burnRate,
                projectedExhaustion: projectedExhaustion
            )
            
            var updatedSLO = SLO(
                id: slo.id,
                name: slo.name,
                service: slo.service,
                metric: slo.metric,
                target: slo.target,
                window: slo.window,
                errorBudget: updatedErrorBudget,
                alerting: slo.alerting,
                autoRollback: slo.autoRollback,
                isActive: slo.isActive
            )
            
            // Update in-memory SLO
            if let index = slos.firstIndex(where: { $0.id == slo.id }) {
                slos[index] = updatedSLO
            }
        }
    }
    
    func startMonitoring() {
        // Start continuous SLO monitoring
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task {
                await self.monitorErrorBudgets()
                let _ = await self.checkSLOCompliance()
            }
        }
    }
    
    func stopMonitoring() {
        #if canImport(FirebaseFirestore)
        breachesListener?.remove()
        #endif
    }
}

struct RollbackEvent: Identifiable, Codable {
    let id: String
    let sloId: String
    let service: String
    let fromRevision: String
    let toRevision: String
    let trigger: SLO.AutoRollbackConfig.RollbackTrigger
    let strategy: SLO.AutoRollbackConfig.RollbackStrategy
    let startedAt: Date
    let completedAt: Date
    let status: RollbackStatus
    let reason: String
    
    enum RollbackStatus: String, Codable {
        case inProgress, completed, failed, cancelled
    }
}
