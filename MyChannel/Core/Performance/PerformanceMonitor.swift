//
//  PerformanceMonitor.swift
//  MyChannel
//
//  Real-time performance monitoring and analytics
//

import SwiftUI
import Combine
import Foundation
import os.log
#if canImport(FirebasePerformance)
import FirebasePerformance
#endif

// MARK: - Performance Monitor
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var currentMetrics = PerformanceMetrics()
    @Published var isMonitoring = false
    @Published var alerts: [PerformanceAlert] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.mychannel.performance", category: "monitoring")
    
    // Monitoring components
    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let renderingMonitor = RenderingMonitor()
    private let batteryMonitor = BatteryMonitor()
    
    // Performance thresholds
    private let thresholds = PerformanceThresholds()
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - Monitoring Setup
    private func setupMonitoring() {
        // CPU monitoring
        cpuMonitor.$usage
            .sink { [weak self] usage in
                self?.currentMetrics.cpuUsage = usage
                self?.checkCPUThreshold(usage)
            }
            .store(in: &cancellables)
        
        // Memory monitoring
        memoryMonitor.$usage
            .sink { [weak self] usage in
                self?.currentMetrics.memoryUsage = usage
                self?.checkMemoryThreshold(usage)
            }
            .store(in: &cancellables)
        
        // Network monitoring
        networkMonitor.$latency
            .sink { [weak self] latency in
                self?.currentMetrics.networkLatency = latency
                self?.checkNetworkThreshold(latency)
            }
            .store(in: &cancellables)
        
        // Rendering monitoring
        renderingMonitor.$frameRate
            .sink { [weak self] frameRate in
                self?.currentMetrics.frameRate = frameRate
                self?.checkFrameRateThreshold(frameRate)
            }
            .store(in: &cancellables)
        
        // Battery monitoring
        batteryMonitor.$drainRate
            .sink { [weak self] drainRate in
                self?.currentMetrics.batteryDrainRate = drainRate
                self?.checkBatteryThreshold(drainRate)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("🔍 Performance monitoring started")
        
        cpuMonitor.start()
        memoryMonitor.start()
        networkMonitor.start()
        renderingMonitor.start()
        batteryMonitor.start()
        
        #if canImport(FirebasePerformance)
        // Start Firebase Performance monitoring
        let trace = Performance.startTrace(name: "app_performance_session")
        trace?.start()
        #endif
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        logger.info("⏹️ Performance monitoring stopped")
        
        cpuMonitor.stop()
        memoryMonitor.stop()
        networkMonitor.stop()
        renderingMonitor.stop()
        batteryMonitor.stop()
    }
    
    // MARK: - Threshold Checking
    private func checkCPUThreshold(_ usage: Double) {
        if usage > thresholds.cpuWarning {
            addAlert(.cpuHigh(usage))
        }
    }
    
    private func checkMemoryThreshold(_ usage: Double) {
        if usage > thresholds.memoryWarning {
            addAlert(.memoryHigh(usage))
        }
    }
    
    private func checkNetworkThreshold(_ latency: TimeInterval) {
        if latency > thresholds.networkLatencyWarning {
            addAlert(.networkSlow(latency))
        }
    }
    
    private func checkFrameRateThreshold(_ frameRate: Double) {
        if frameRate < thresholds.frameRateWarning {
            addAlert(.frameRateLow(frameRate))
        }
    }
    
    private func checkBatteryThreshold(_ drainRate: Double) {
        if drainRate > thresholds.batteryDrainWarning {
            addAlert(.batteryDrainHigh(drainRate))
        }
    }
    
    private func addAlert(_ alert: PerformanceAlert) {
        // Avoid duplicate alerts
        if !alerts.contains(where: { $0.type == alert.type }) {
            alerts.append(alert)
            logger.warning("⚠️ Performance alert: \(alert.message)")
            
            // Auto-dismiss after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.dismissAlert(alert)
            }
        }
    }
    
    func dismissAlert(_ alert: PerformanceAlert) {
        alerts.removeAll { $0.id == alert.id }
    }
    
    // MARK: - Performance Traces
    func startTrace(_ name: String) -> PerformanceTrace {
        let trace = PerformanceTrace(name: name)
        trace.start()
        
        #if canImport(FirebasePerformance)
        let firebaseTrace = Performance.startTrace(name: name)
        firebaseTrace?.start()
        trace.firebaseTrace = firebaseTrace
        #endif
        
        return trace
    }
    
    // MARK: - Custom Metrics
    func recordCustomMetric(_ name: String, value: Double) {
        logger.info("📊 Custom metric: \(name) = \(value)")
        
        #if canImport(FirebasePerformance)
        // Record to Firebase Performance
        #endif
    }
    
    func recordUserAction(_ action: String, duration: TimeInterval) {
        logger.info("👆 User action: \(action) took \(String(format: "%.3f", duration))s")
        
        if duration > 1.0 {
            addAlert(.slowUserAction(action, duration))
        }
    }
    
    // MARK: - Performance Report
    func generateReport() -> PerformanceReport {
        return PerformanceReport(
            timestamp: Date(),
            metrics: currentMetrics,
            alerts: alerts,
            recommendations: generateRecommendations()
        )
    }
    
    private func generateRecommendations() -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        if currentMetrics.cpuUsage > thresholds.cpuWarning {
            recommendations.append(.reduceCPUUsage)
        }
        
        if currentMetrics.memoryUsage > thresholds.memoryWarning {
            recommendations.append(.optimizeMemory)
        }
        
        if currentMetrics.frameRate < thresholds.frameRateWarning {
            recommendations.append(.improveRendering)
        }
        
        if currentMetrics.networkLatency > thresholds.networkLatencyWarning {
            recommendations.append(.optimizeNetwork)
        }
        
        return recommendations
    }
}

// MARK: - CPU Monitor
class CPUMonitor: ObservableObject {
    @Published var usage: Double = 0.0
    
    private var timer: Timer?
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateCPUUsage()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCPUUsage() {
        var info = task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info_data_t>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let cpuUsage = Double(info.resident_size) / Double(ProcessInfo.processInfo.physicalMemory) * 100
            DispatchQueue.main.async {
                self.usage = min(cpuUsage, 100.0)
            }
        }
    }
}

// MARK: - Memory Monitor
class MemoryMonitor: ObservableObject {
    @Published var usage: Double = 0.0
    
    private var timer: Timer?
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateMemoryUsage()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMemoryUsage() {
        let memoryUsage = getMemoryUsage()
        DispatchQueue.main.async {
            self.usage = memoryUsage
        }
    }
    
    private func getMemoryUsage() -> Double {
        var info = task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info_data_t>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageBytes = Double(info.resident_size)
            let memoryUsageMB = memoryUsageBytes / (1024 * 1024)
            return memoryUsageMB
        }
        
        return 0.0
    }
}

// MARK: - Network Monitor
class NetworkMonitor: ObservableObject {
    @Published var latency: TimeInterval = 0.0
    
    private var timer: Timer?
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.measureLatency()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func measureLatency() {
        let startTime = Date()
        
        Task {
            do {
                let url = URL(string: "https://www.google.com")!
                let (_, _) = try await URLSession.shared.data(from: url)
                
                let latency = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    self.latency = latency
                }
            } catch {
                await MainActor.run {
                    self.latency = 999.0 // High latency for errors
                }
            }
        }
    }
}

// MARK: - Rendering Monitor
class RenderingMonitor: ObservableObject {
    @Published var frameRate: Double = 60.0
    
    private var displayLink: CADisplayLink?
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0
    
    func start() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func displayLinkTick(_ displayLink: CADisplayLink) {
        frameCount += 1
        
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }
        
        let elapsed = displayLink.timestamp - lastTimestamp
        if elapsed >= 1.0 {
            let fps = Double(frameCount) / elapsed
            
            DispatchQueue.main.async {
                self.frameRate = fps
            }
            
            frameCount = 0
            lastTimestamp = displayLink.timestamp
        }
    }
}

// MARK: - Battery Monitor
class BatteryMonitor: ObservableObject {
    @Published var drainRate: Double = 0.0
    
    private var timer: Timer?
    private var previousBatteryLevel: Float = 0.0
    private var previousTimestamp: Date = Date()
    
    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        previousBatteryLevel = UIDevice.current.batteryLevel
        previousTimestamp = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.updateBatteryDrainRate()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        UIDevice.current.isBatteryMonitoringEnabled = false
    }
    
    private func updateBatteryDrainRate() {
        let currentLevel = UIDevice.current.batteryLevel
        let currentTime = Date()
        
        let levelDrop = previousBatteryLevel - currentLevel
        let timeElapsed = currentTime.timeIntervalSince(previousTimestamp) / 3600.0 // Convert to hours
        
        if timeElapsed > 0 && levelDrop > 0 {
            let drainRate = Double(levelDrop) / timeElapsed * 100 // Percentage per hour
            
            DispatchQueue.main.async {
                self.drainRate = drainRate
            }
        }
        
        previousBatteryLevel = currentLevel
        previousTimestamp = currentTime
    }
}

// MARK: - Performance Trace
class PerformanceTrace {
    let name: String
    let id = UUID()
    private var startTime: Date?
    
    #if canImport(FirebasePerformance)
    var firebaseTrace: Trace?
    #endif
    
    init(name: String) {
        self.name = name
    }
    
    func start() {
        startTime = Date()
    }
    
    func stop() -> TimeInterval {
        guard let startTime = startTime else { return 0 }
        
        let duration = Date().timeIntervalSince(startTime)
        
        #if canImport(FirebasePerformance)
        firebaseTrace?.stop()
        #endif
        
        return duration
    }
    
    func addMetric(_ name: String, value: Int64) {
        #if canImport(FirebasePerformance)
        firebaseTrace?.setValue(value, forMetric: name)
        #endif
    }
}

// MARK: - Supporting Types
struct PerformanceMetrics {
    var cpuUsage: Double = 0.0
    var memoryUsage: Double = 0.0
    var networkLatency: TimeInterval = 0.0
    var frameRate: Double = 60.0
    var batteryDrainRate: Double = 0.0
    var timestamp: Date = Date()
}

struct PerformanceThresholds {
    let cpuWarning: Double = 80.0
    let memoryWarning: Double = 500.0 // MB
    let networkLatencyWarning: TimeInterval = 2.0
    let frameRateWarning: Double = 30.0
    let batteryDrainWarning: Double = 20.0 // % per hour
}

struct PerformanceAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let message: String
    let timestamp: Date = Date()
    
    enum AlertType: Equatable {
        case cpuHigh(Double)
        case memoryHigh(Double)
        case networkSlow(TimeInterval)
        case frameRateLow(Double)
        case batteryDrainHigh(Double)
        case slowUserAction(String, TimeInterval)
    }
    
    static func cpuHigh(_ usage: Double) -> PerformanceAlert {
        PerformanceAlert(
            type: .cpuHigh(usage),
            message: "High CPU usage: \(String(format: "%.1f", usage))%"
        )
    }
    
    static func memoryHigh(_ usage: Double) -> PerformanceAlert {
        PerformanceAlert(
            type: .memoryHigh(usage),
            message: "High memory usage: \(String(format: "%.1f", usage))MB"
        )
    }
    
    static func networkSlow(_ latency: TimeInterval) -> PerformanceAlert {
        PerformanceAlert(
            type: .networkSlow(latency),
            message: "Slow network: \(String(format: "%.2f", latency))s latency"
        )
    }
    
    static func frameRateLow(_ frameRate: Double) -> PerformanceAlert {
        PerformanceAlert(
            type: .frameRateLow(frameRate),
            message: "Low frame rate: \(String(format: "%.1f", frameRate)) FPS"
        )
    }
    
    static func batteryDrainHigh(_ drainRate: Double) -> PerformanceAlert {
        PerformanceAlert(
            type: .batteryDrainHigh(drainRate),
            message: "High battery drain: \(String(format: "%.1f", drainRate))%/hour"
        )
    }
    
    static func slowUserAction(_ action: String, _ duration: TimeInterval) -> PerformanceAlert {
        PerformanceAlert(
            type: .slowUserAction(action, duration),
            message: "Slow \(action): \(String(format: "%.2f", duration))s"
        )
    }
}

enum PerformanceRecommendation {
    case reduceCPUUsage
    case optimizeMemory
    case improveRendering
    case optimizeNetwork
    
    var message: String {
        switch self {
        case .reduceCPUUsage:
            return "Consider reducing background processing or optimizing algorithms"
        case .optimizeMemory:
            return "Clear caches or reduce memory-intensive operations"
        case .improveRendering:
            return "Simplify UI or reduce animation complexity"
        case .optimizeNetwork:
            return "Check network connection or optimize API calls"
        }
    }
}

struct PerformanceReport {
    let timestamp: Date
    let metrics: PerformanceMetrics
    let alerts: [PerformanceAlert]
    let recommendations: [PerformanceRecommendation]
}

// MARK: - Performance Monitoring View
struct PerformanceMonitorView: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Performance Monitor")
                    .font(.title2.bold())
                
                Spacer()
                
                Button(monitor.isMonitoring ? "Stop" : "Start") {
                    if monitor.isMonitoring {
                        monitor.stopMonitoring()
                    } else {
                        monitor.startMonitoring()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            if monitor.isMonitoring {
                VStack(spacing: 16) {
                    MetricRow(title: "CPU Usage", value: "\(String(format: "%.1f", monitor.currentMetrics.cpuUsage))%")
                    MetricRow(title: "Memory Usage", value: "\(String(format: "%.1f", monitor.currentMetrics.memoryUsage))MB")
                    MetricRow(title: "Frame Rate", value: "\(String(format: "%.1f", monitor.currentMetrics.frameRate)) FPS")
                    MetricRow(title: "Network Latency", value: "\(String(format: "%.2f", monitor.currentMetrics.networkLatency))s")
                    MetricRow(title: "Battery Drain", value: "\(String(format: "%.1f", monitor.currentMetrics.batteryDrainRate))%/h")
                }
                
                if !monitor.alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alerts")
                            .font(.headline)
                        
                        ForEach(monitor.alerts) { alert in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                
                                Text(alert.message)
                                    .font(.caption)
                                
                                Spacer()
                                
                                Button("Dismiss") {
                                    monitor.dismissAlert(alert)
                                }
                                .font(.caption)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption.monospacedDigit())
                .fontWeight(.medium)
        }
    }
}

// MARK: - Performance Tracking Extensions
extension View {
    func trackPerformance(_ actionName: String) -> some View {
        self.onTapGesture {
            let startTime = Date()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let duration = Date().timeIntervalSince(startTime)
                PerformanceMonitor.shared.recordUserAction(actionName, duration: duration)
            }
        }
    }
    
    func measureRenderTime(_ viewName: String) -> some View {
        self.onAppear {
            let trace = PerformanceMonitor.shared.startTrace("render_\(viewName)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let duration = trace.stop()
                if duration > 0.5 {
                    print("⚠️ Slow render: \(viewName) took \(String(format: "%.3f", duration))s")
                }
            }
        }
    }
}

