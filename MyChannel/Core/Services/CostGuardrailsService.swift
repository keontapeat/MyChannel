import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct CostBudget: Identifiable, Codable {
    let id: String
    let name: String
    let service: String
    let budgetType: BudgetType
    let amount: Double
    let currency: String
    let period: BudgetPeriod
    let alertThresholds: [AlertThreshold]
    let enforcements: [Enforcement]
    var currentSpend: Double
    var projectedSpend: Double
    let isActive: Bool
    let createdAt: Date
    
    enum BudgetType: String, Codable, CaseIterable {
        case monthly, weekly, daily, project, feature
        
        var displayName: String {
            switch self {
            case .monthly: return "Monthly Budget"
            case .weekly: return "Weekly Budget"
            case .daily: return "Daily Budget"
            case .project: return "Project Budget"
            case .feature: return "Feature Budget"
            }
        }
    }
    
    enum BudgetPeriod: String, Codable {
        case currentMonth, currentWeek, currentDay, lifetime
        
        var seconds: TimeInterval {
            switch self {
            case .currentMonth: return 2592000 // 30 days
            case .currentWeek: return 604800   // 7 days
            case .currentDay: return 86400     // 1 day
            case .lifetime: return .infinity
            }
        }
    }
    
    struct AlertThreshold: Codable {
        let percentage: Double // e.g., 50.0 for 50%
        let channels: [String] // notification channels
        let action: AlertAction
        
        enum AlertAction: String, Codable {
            case notify, warn, throttle, stop
        }
    }
    
    struct Enforcement: Codable {
        let triggerPercentage: Double
        let action: EnforcementAction
        let isEnabled: Bool
        
        enum EnforcementAction: String, Codable {
            case throttleRequests, disableFeature, stopService, requireApproval
            
            var displayName: String {
                switch self {
                case .throttleRequests: return "Throttle Requests"
                case .disableFeature: return "Disable Feature"
                case .stopService: return "Stop Service"
                case .requireApproval: return "Require Approval"
                }
            }
        }
    }
    
    var percentageUsed: Double {
        amount > 0 ? (currentSpend / amount) * 100 : 0
    }
    
    var isOverBudget: Bool {
        currentSpend > amount
    }
    
    var projectedOverage: Double {
        max(0, projectedSpend - amount)
    }
}

struct CostAlert: Identifiable, Codable {
    let id: String
    let budgetId: String
    let service: String
    let alertType: AlertType
    let threshold: Double
    let currentSpend: Double
    let projectedSpend: Double
    let triggeredAt: Date
    let resolvedAt: Date?
    let notificationsSent: [String]
    
    enum AlertType: String, Codable {
        case approaching, exceeded, projected
        
        var severity: String {
            switch self {
            case .approaching: return "warning"
            case .exceeded: return "critical"
            case .projected: return "info"
            }
        }
    }
}

struct CostOptimization: Identifiable, Codable {
    let id: String
    let service: String
    let optimization: OptimizationType
    let potentialSavings: Double
    let effort: EffortLevel
    let impact: ImpactLevel
    let status: OptimizationStatus
    let implementedAt: Date?
    
    enum OptimizationType: String, Codable, CaseIterable {
        case rightSizing, scheduledShutdown, compressionTuning, cachingOptimization, storageClass
        
        var displayName: String {
            switch self {
            case .rightSizing: return "Right-size Resources"
            case .scheduledShutdown: return "Scheduled Shutdown"
            case .compressionTuning: return "Compression Tuning"
            case .cachingOptimization: return "Caching Optimization"
            case .storageClass: return "Storage Class Optimization"
            }
        }
    }
    
    enum EffortLevel: String, Codable {
        case low, medium, high
    }
    
    enum ImpactLevel: String, Codable {
        case low, medium, high
    }
    
    enum OptimizationStatus: String, Codable {
        case recommended, planned, implementing, completed, rejected
    }
}

@MainActor
final class CostGuardrailsService: ObservableObject {
    static let shared = CostGuardrailsService()
    private init() {}
    
    @Published var budgets: [CostBudget] = []
    @Published var alerts: [CostAlert] = []
    @Published var optimizations: [CostOptimization] = []
    @Published var totalMonthlySpend: Double = 0
    @Published var forecastedSpend: Double = 0
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var budgetsListener: ListenerRegistration?
    #endif
    
    func createBudget(name: String, service: String, amount: Double, period: CostBudget.BudgetPeriod) async -> String? {
        let budget = CostBudget(
            id: UUID().uuidString,
            name: name,
            service: service,
            budgetType: period == .currentMonth ? .monthly : .daily,
            amount: amount,
            currency: "USD",
            period: period,
            alertThresholds: [
                CostBudget.AlertThreshold(percentage: 50.0, channels: ["slack-finops"], action: .notify),
                CostBudget.AlertThreshold(percentage: 80.0, channels: ["slack-finops", "email-oncall"], action: .warn),
                CostBudget.AlertThreshold(percentage: 100.0, channels: ["slack-finops", "pagerduty"], action: .throttle)
            ],
            enforcements: [
                CostBudget.Enforcement(triggerPercentage: 120.0, action: .requireApproval, isEnabled: true),
                CostBudget.Enforcement(triggerPercentage: 150.0, action: .stopService, isEnabled: false)
            ],
            currentSpend: 0,
            projectedSpend: 0,
            isActive: true,
            createdAt: Date()
        )
        
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("cost_budgets").document(budget.id).setData([
                "name": budget.name,
                "service": budget.service,
                "budgetType": budget.budgetType.rawValue,
                "amount": budget.amount,
                "currency": budget.currency,
                "period": budget.period.rawValue,
                "alertThresholds": budget.alertThresholds.map { threshold in
                    [
                        "percentage": threshold.percentage,
                        "channels": threshold.channels,
                        "action": threshold.action.rawValue
                    ]
                },
                "enforcements": budget.enforcements.map { enforcement in
                    [
                        "triggerPercentage": enforcement.triggerPercentage,
                        "action": enforcement.action.rawValue,
                        "isEnabled": enforcement.isEnabled
                    ]
                },
                "isActive": budget.isActive,
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            await MainActor.run {
                self.budgets.append(budget)
            }
            
            return budget.id
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func monitorBudgets() async -> [CostAlert] {
        var newAlerts: [CostAlert] = []
        
        for var budget in budgets {
            // Get current spend for budget period
            let currentSpend = await getCurrentSpend(service: budget.service, period: budget.period)
            let projectedSpend = await getProjectedSpend(service: budget.service, period: budget.period)
            
            budget.currentSpend = currentSpend
            budget.projectedSpend = projectedSpend
            
            // Check alert thresholds
            for threshold in budget.alertThresholds {
                if budget.percentageUsed >= threshold.percentage {
                    let existingAlert = alerts.first { $0.budgetId == budget.id && $0.threshold == threshold.percentage }
                    
                    if existingAlert == nil {
                        let alert = CostAlert(
                            id: UUID().uuidString,
                            budgetId: budget.id,
                            service: budget.service,
                            alertType: budget.isOverBudget ? .exceeded : .approaching,
                            threshold: threshold.percentage,
                            currentSpend: currentSpend,
                            projectedSpend: projectedSpend,
                            triggeredAt: Date(),
                            resolvedAt: nil,
                            notificationsSent: []
                        )
                        
                        newAlerts.append(alert)
                        await sendCostAlert(alert: alert, threshold: threshold)
                    }
                }
            }
            
            // Check enforcements
            for enforcement in budget.enforcements where enforcement.isEnabled {
                if budget.percentageUsed >= enforcement.triggerPercentage {
                    await triggerEnforcement(budget: budget, enforcement: enforcement)
                }
            }
            
            // Update budget in memory
            if let index = budgets.firstIndex(where: { $0.id == budget.id }) {
                budgets[index] = budget
            }
        }
        
        await MainActor.run {
            self.alerts.append(contentsOf: newAlerts)
        }
        
        return newAlerts
    }
    
    func generateCostOptimizations() async -> [CostOptimization] {
        var optimizations: [CostOptimization] = []
        
        // Analyze usage patterns and generate recommendations
        for budget in budgets {
            let usage = await analyzeServiceUsage(service: budget.service)
            
            // Right-sizing recommendation
            if usage.avgUtilization < 0.5 {
                optimizations.append(CostOptimization(
                    id: UUID().uuidString,
                    service: budget.service,
                    optimization: .rightSizing,
                    potentialSavings: budget.currentSpend * 0.3,
                    effort: .medium,
                    impact: .high,
                    status: .recommended,
                    implementedAt: nil
                ))
            }
            
            // Compression optimization
            if usage.storageGB > 1000 {
                optimizations.append(CostOptimization(
                    id: UUID().uuidString,
                    service: budget.service,
                    optimization: .compressionTuning,
                    potentialSavings: usage.storageGB * 0.02, // $0.02/GB savings
                    effort: .low,
                    impact: .medium,
                    status: .recommended,
                    implementedAt: nil
                ))
            }
        }
        
        await MainActor.run {
            self.optimizations = optimizations
        }
        
        return optimizations
    }
    
    private func getCurrentSpend(service: String, period: CostBudget.BudgetPeriod) async -> Double {
        // Query Cloud Billing API for current spend
        return Double.random(in: 100...500) // Mock
    }
    
    private func getProjectedSpend(service: String, period: CostBudget.BudgetPeriod) async -> Double {
        // Calculate projected spend based on trends
        let current = await getCurrentSpend(service: service, period: period)
        return current * Double.random(in: 1.1...1.3) // 10-30% increase projection
    }
    
    private func analyzeServiceUsage(service: String) async -> ServiceUsage {
        // Analyze service metrics for optimization opportunities
        return ServiceUsage(
            avgUtilization: Double.random(in: 0.2...0.8),
            peakUtilization: Double.random(in: 0.7...1.0),
            storageGB: Double.random(in: 100...5000),
            networkGB: Double.random(in: 50...1000),
            computeHours: Double.random(in: 100...2000)
        )
    }
    
    private func sendCostAlert(alert: CostAlert, threshold: CostBudget.AlertThreshold) async {
        // Send notifications via configured channels
        for channel in threshold.channels {
            await sendNotification(
                channel: channel,
                title: "💰 Budget Alert: \(alert.service)",
                message: "Current spend: $\(String(format: "%.2f", alert.currentSpend)) (\(String(format: "%.1f", threshold.percentage))% of budget)",
                severity: alert.alertType.severity
            )
        }
    }
    
    private func triggerEnforcement(budget: CostBudget, enforcement: CostBudget.Enforcement) async {
        switch enforcement.action {
        case .throttleRequests:
            await throttleServiceRequests(service: budget.service, percentage: 0.5)
        case .disableFeature:
            await disableNonEssentialFeatures(service: budget.service)
        case .stopService:
            await stopService(service: budget.service)
        case .requireApproval:
            await requireApprovalForSpend(service: budget.service)
        }
    }
    
    private func throttleServiceRequests(service: String, percentage: Double) async {
        print("🚦 Throttling \(service) to \(percentage * 100)% capacity")
        
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("service_configs").document(service).setData([
                "throttleEnabled": true,
                "throttlePercentage": percentage,
                "throttledAt": FieldValue.serverTimestamp(),
                "reason": "Cost budget enforcement"
            ], merge: true)
        } catch { }
        #endif
    }
    
    private func disableNonEssentialFeatures(service: String) async {
        print("⏸️ Disabling non-essential features for \(service)")
        
        let featuresToDisable = [
            "transcoding_4k",
            "ai_recommendations", 
            "advanced_analytics",
            "background_processing"
        ]
        
        #if canImport(FirebaseFirestore)
        do {
            for feature in featuresToDisable {
                try await db.collection("feature_flags").document("\(service)_\(feature)").setData([
                    "enabled": false,
                    "disabledReason": "Cost budget enforcement",
                    "disabledAt": FieldValue.serverTimestamp()
                ], merge: true)
            }
        } catch { }
        #endif
    }
    
    private func stopService(service: String) async {
        print("🛑 Emergency stop for \(service)")
        
        // This would integrate with Cloud Run API to scale to 0
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("emergency_stops").document(service).setData([
                "stoppedAt": FieldValue.serverTimestamp(),
                "reason": "Cost budget exceeded",
                "autoRestart": false
            ])
        } catch { }
        #endif
    }
    
    private func requireApprovalForSpend(service: String) async {
        print("✋ Requiring approval for additional spend on \(service)")
        
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("approval_required").document(service).setData([
                "requiredAt": FieldValue.serverTimestamp(),
                "reason": "Budget threshold exceeded",
                "approver": "finops-team",
                "status": "pending"
            ])
        } catch { }
        #endif
    }
    
    private func sendNotification(channel: String, title: String, message: String, severity: String) async {
        switch channel {
        case "slack-finops":
            await sendSlackNotification(title: title, message: message, severity: severity)
        case "email-oncall":
            await sendEmailAlert(title: title, message: message, severity: severity)
        case "pagerduty":
            await triggerPagerDutyAlert(title: title, message: message, severity: severity)
        default:
            print("📢 \(channel): \(title) - \(message)")
        }
    }
    
    private func sendSlackNotification(title: String, message: String, severity: String) async {
        // Send to Slack webhook
        let payload: [String: Any] = [
            "text": title,
            "attachments": [[
                "color": severity == "critical" ? "danger" : "warning",
                "fields": [[
                    "title": "Details",
                    "value": message,
                    "short": false
                ]]
            ]]
        ]
        
        // Would send to actual Slack webhook
        print("📱 Slack: \(payload)")
    }
    
    private func sendEmailAlert(title: String, message: String, severity: String) async {
        // Send via email service
        print("📧 Email: \(title) - \(message)")
    }
    
    private func triggerPagerDutyAlert(title: String, message: String, severity: String) async {
        // Trigger PagerDuty incident
        print("🚨 PagerDuty: \(title) - \(message)")
    }
    
    func startCostMonitoring() {
        // Monitor costs every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                let _ = await self.monitorBudgets()
                await self.updateSpendForecasts()
            }
        }
    }
    
    func updateSpendForecasts() async {
        // Calculate total monthly and forecasted spend
        let currentMonthSpend = budgets.filter { $0.period == .currentMonth }.reduce(0) { $0 + $1.currentSpend }
        let monthlyForecast = budgets.filter { $0.period == .currentMonth }.reduce(0) { $0 + $1.projectedSpend }
        
        await MainActor.run {
            self.totalMonthlySpend = currentMonthSpend
            self.forecastedSpend = monthlyForecast
        }
    }
    
    func stopMonitoring() {
        #if canImport(FirebaseFirestore)
        budgetsListener?.remove()
        #endif
    }
}

struct ServiceUsage: Codable {
    let avgUtilization: Double
    let peakUtilization: Double
    let storageGB: Double
    let networkGB: Double
    let computeHours: Double
}
