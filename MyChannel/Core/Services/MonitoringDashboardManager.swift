//
//  MonitoringDashboardManager.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation

// 📊 Monitoring Dashboard Manager
// Manages alerts, thresholds, and monitoring configuration
@MainActor
class MonitoringDashboardManager: ObservableObject {
    static let shared = MonitoringDashboardManager()
    
    @Published var alerts: [MonitoringAlert] = []
    @Published var metrics: [String: Double] = [:]
    @Published var thresholds: [String: MonitoringThreshold] = [:]
    
    private var alertHistory: [MonitoringAlert] = []
    private let maxAlertHistory = 1000
    
    private init() {
        setupDefaultThresholds()
        startMonitoring()
    }
    
    // MARK: - Configuration
    
    private func setupDefaultThresholds() {
        thresholds = [
            // Performance Thresholds
            "search_response_time": MonitoringThreshold(
                name: "Search Response Time",
                warningLevel: 2.0,
                criticalLevel: 5.0,
                unit: "seconds"
            ),
            "video_load_time": MonitoringThreshold(
                name: "Video Load Time",
                warningLevel: 3.0,
                criticalLevel: 8.0,
                unit: "seconds"
            ),
            "app_launch_time": MonitoringThreshold(
                name: "App Launch Time",
                warningLevel: 3.0,
                criticalLevel: 10.0,
                unit: "seconds"
            ),
            
            // Error Rate Thresholds
            "search_error_rate": MonitoringThreshold(
                name: "Search Error Rate",
                warningLevel: 0.05,
                criticalLevel: 0.15,
                unit: "percentage"
            ),
            "upload_error_rate": MonitoringThreshold(
                name: "Upload Error Rate",
                warningLevel: 0.03,
                criticalLevel: 0.10,
                unit: "percentage"
            ),
            "api_error_rate": MonitoringThreshold(
                name: "API Error Rate",
                warningLevel: 0.02,
                criticalLevel: 0.08,
                unit: "percentage"
            ),
            
            // Usage Thresholds
            "memory_usage": MonitoringThreshold(
                name: "Memory Usage",
                warningLevel: 0.80,
                criticalLevel: 0.95,
                unit: "percentage"
            ),
            "storage_usage": MonitoringThreshold(
                name: "Storage Usage",
                warningLevel: 0.85,
                criticalLevel: 0.95,
                unit: "percentage"
            ),
            
            // Business Metrics
            "user_engagement_rate": MonitoringThreshold(
                name: "User Engagement Rate",
                warningLevel: 0.30,
                criticalLevel: 0.20,
                unit: "percentage",
                isInverted: true // Lower values are worse
            ),
            "video_completion_rate": MonitoringThreshold(
                name: "Video Completion Rate",
                warningLevel: 0.40,
                criticalLevel: 0.25,
                unit: "percentage",
                isInverted: true
            ),
            
            // ML Service Thresholds
            "ml_service_response_time": MonitoringThreshold(
                name: "ML Service Response Time",
                warningLevel: 5.0,
                criticalLevel: 15.0,
                unit: "seconds"
            ),
            "recommendation_accuracy": MonitoringThreshold(
                name: "Recommendation Accuracy",
                warningLevel: 0.60,
                criticalLevel: 0.40,
                unit: "percentage",
                isInverted: true
            )
        ]
    }
    
    private func startMonitoring() {
        // Start periodic monitoring
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkMetrics()
            }
        }
    }
    
    // MARK: - Metric Tracking
    
    func updateMetric(_ key: String, value: Double) {
        metrics[key] = value
        checkThreshold(key, value: value)
    }
    
    func incrementCounter(_ key: String, by amount: Double = 1.0) {
        let currentValue = metrics[key] ?? 0.0
        updateMetric(key, value: currentValue + amount)
    }
    
    func recordLatency(_ key: String, latency: Double) {
        // Use exponential moving average for latency metrics
        let currentAvg = metrics[key] ?? latency
        let alpha = 0.1 // Smoothing factor
        let newAvg = alpha * latency + (1 - alpha) * currentAvg
        updateMetric(key, value: newAvg)
    }
    
    // MARK: - Alert Management
    
    private func checkThreshold(_ key: String, value: Double) {
        guard let threshold = thresholds[key] else { return }
        
        let alertLevel = threshold.getAlertLevel(for: value)
        
        if alertLevel != .normal {
            createAlert(
                title: "\(threshold.name) Alert",
                message: "\(threshold.name) is \(alertLevel.rawValue): \(value) \(threshold.unit)",
                level: alertLevel,
                metricKey: key,
                value: value
            )
        }
    }
    
    private func createAlert(title: String, message: String, level: AlertLevel, metricKey: String, value: Double) {
        let alert = MonitoringAlert(
            id: UUID().uuidString,
            title: title,
            message: message,
            level: level,
            metricKey: metricKey,
            value: value,
            timestamp: Date()
        )
        
        // Check if we already have a recent alert for this metric
        let recentAlerts = alerts.filter { 
            $0.metricKey == metricKey && 
            $0.timestamp.timeIntervalSinceNow > -300 // 5 minutes
        }
        
        if recentAlerts.isEmpty {
            alerts.append(alert)
            alertHistory.append(alert)
            
            // Maintain history size
            if alertHistory.count > maxAlertHistory {
                alertHistory.removeFirst()
            }
            
            // Log alert
            print("🚨 [Monitoring] \(level.rawValue.uppercased()) ALERT: \(title) - \(message)")
            
            // Send to error reporting for critical alerts
            if level == .critical {
                ErrorReportingManager.shared.reportCustomError(
                    message: message,
                    context: "MonitoringAlert",
                    severity: .critical,
                    metadata: [
                        "metric_key": metricKey,
                        "value": value,
                        "alert_level": level.rawValue
                    ]
                )
            }
            
            // Track in analytics
            EnhancedAnalyticsManager.shared.logEvent("monitoring_alert", parameters: [
                "alert_title": title,
                "alert_level": level.rawValue,
                "metric_key": metricKey,
                "metric_value": value
            ])
        }
    }
    
    func dismissAlert(_ alertId: String) {
        alerts.removeAll { $0.id == alertId }
    }
    
    func dismissAllAlerts() {
        alerts.removeAll()
    }
    
    // MARK: - Periodic Checks
    
    private func checkMetrics() {
        checkPerformanceMetrics()
        checkErrorRates()
        checkResourceUsage()
        checkBusinessMetrics()
    }
    
    private func checkPerformanceMetrics() {
        // Check search performance
        if let searchTime = metrics["search_response_time"], searchTime > 0 {
            checkThreshold("search_response_time", value: searchTime)
        }
        
        // Check video load performance
        if let videoLoadTime = metrics["video_load_time"], videoLoadTime > 0 {
            checkThreshold("video_load_time", value: videoLoadTime)
        }
        
        // Check ML service performance
        if let mlResponseTime = metrics["ml_service_response_time"], mlResponseTime > 0 {
            checkThreshold("ml_service_response_time", value: mlResponseTime)
        }
    }
    
    private func checkErrorRates() {
        // Calculate error rates from counters
        let searchRequests = metrics["search_requests"] ?? 0
        let searchErrors = metrics["search_errors"] ?? 0
        
        if searchRequests > 0 {
            let errorRate = searchErrors / searchRequests
            updateMetric("search_error_rate", value: errorRate)
        }
        
        let uploadAttempts = metrics["upload_attempts"] ?? 0
        let uploadErrors = metrics["upload_errors"] ?? 0
        
        if uploadAttempts > 0 {
            let errorRate = uploadErrors / uploadAttempts
            updateMetric("upload_error_rate", value: errorRate)
        }
    }
    
    private func checkResourceUsage() {
        // Check memory usage
        let memoryInfo = getMemoryUsage()
        updateMetric("memory_usage", value: memoryInfo.usagePercentage)
        
        // Check storage usage
        let storageInfo = getStorageUsage()
        updateMetric("storage_usage", value: storageInfo.usagePercentage)
    }
    
    private func checkBusinessMetrics() {
        // Calculate engagement rate
        let totalSessions = metrics["total_sessions"] ?? 0
        let engagedSessions = metrics["engaged_sessions"] ?? 0
        
        if totalSessions > 0 {
            let engagementRate = engagedSessions / totalSessions
            updateMetric("user_engagement_rate", value: engagementRate)
        }
        
        // Calculate video completion rate
        let videoStarts = metrics["video_starts"] ?? 0
        let videoCompletions = metrics["video_completions"] ?? 0
        
        if videoStarts > 0 {
            let completionRate = videoCompletions / videoStarts
            updateMetric("video_completion_rate", value: completionRate)
        }
    }
    
    // MARK: - System Information
    
    private func getMemoryUsage() -> (used: Int64, total: Int64, usagePercentage: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let used = Int64(info.resident_size)
            let total = Int64(ProcessInfo.processInfo.physicalMemory)
            let percentage = Double(used) / Double(total)
            return (used, total, percentage)
        }
        
        return (0, 0, 0.0)
    }
    
    private func getStorageUsage() -> (used: Int64, total: Int64, usagePercentage: Double) {
        do {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let values = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = Int64(values.volumeAvailableCapacity ?? 0)
            let used = total - available
            let percentage = total > 0 ? Double(used) / Double(total) : 0.0
            
            return (used, total, percentage)
        } catch {
            return (0, 0, 0.0)
        }
    }
    
    // MARK: - Dashboard Data
    
    func getDashboardData() -> DashboardData {
        return DashboardData(
            activeAlerts: alerts,
            recentAlerts: Array(alertHistory.suffix(10)),
            metrics: metrics,
            thresholds: thresholds,
            systemInfo: getSystemInfo()
        )
    }
    
    private func getSystemInfo() -> SystemInfo {
        let memoryInfo = getMemoryUsage()
        let storageInfo = getStorageUsage()
        
        return SystemInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            deviceModel: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            memoryUsage: memoryInfo,
            storageUsage: storageInfo,
            uptime: ProcessInfo.processInfo.systemUptime
        )
    }
    
    // MARK: - Configuration
    
    func updateThreshold(_ key: String, threshold: MonitoringThreshold) {
        thresholds[key] = threshold
    }
    
    func getAlertHistory(limit: Int = 100) -> [MonitoringAlert] {
        return Array(alertHistory.suffix(limit))
    }
    
    func exportMetrics() -> [String: Any] {
        return [
            "metrics": metrics,
            "alerts": alerts.map { $0.toDictionary() },
            "thresholds": thresholds.mapValues { $0.toDictionary() },
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - Supporting Types

struct MonitoringAlert: Identifiable {
    let id: String
    let title: String
    let message: String
    let level: AlertLevel
    let metricKey: String
    let value: Double
    let timestamp: Date
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "title": title,
            "message": message,
            "level": level.rawValue,
            "metric_key": metricKey,
            "value": value,
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }
}

struct MonitoringThreshold {
    let name: String
    let warningLevel: Double
    let criticalLevel: Double
    let unit: String
    let isInverted: Bool // For metrics where lower values are worse
    
    init(name: String, warningLevel: Double, criticalLevel: Double, unit: String, isInverted: Bool = false) {
        self.name = name
        self.warningLevel = warningLevel
        self.criticalLevel = criticalLevel
        self.unit = unit
        self.isInverted = isInverted
    }
    
    func getAlertLevel(for value: Double) -> AlertLevel {
        if isInverted {
            if value <= criticalLevel {
                return .critical
            } else if value <= warningLevel {
                return .warning
            } else {
                return .normal
            }
        } else {
            if value >= criticalLevel {
                return .critical
            } else if value >= warningLevel {
                return .warning
            } else {
                return .normal
            }
        }
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "warning_level": warningLevel,
            "critical_level": criticalLevel,
            "unit": unit,
            "is_inverted": isInverted
        ]
    }
}

enum AlertLevel: String, CaseIterable {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
}

struct DashboardData {
    let activeAlerts: [MonitoringAlert]
    let recentAlerts: [MonitoringAlert]
    let metrics: [String: Double]
    let thresholds: [String: MonitoringThreshold]
    let systemInfo: SystemInfo
}

struct SystemInfo {
    let appVersion: String
    let deviceModel: String
    let systemVersion: String
    let memoryUsage: (used: Int64, total: Int64, usagePercentage: Double)
    let storageUsage: (used: Int64, total: Int64, usagePercentage: Double)
    let uptime: TimeInterval
}
