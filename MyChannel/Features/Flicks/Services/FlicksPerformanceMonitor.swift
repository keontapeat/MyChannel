//
//  FlicksPerformanceMonitor.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI
import UIKit
import os

// MARK: - 📊 Advanced Performance Monitor for Flicks
@MainActor
class FlicksPerformanceMonitor: ObservableObject {
    @Published var memoryUsage: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var batteryLevel: Float = 1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var performanceScore: Double = 100.0
    
    private var videoSwitchCount = 0
    private var lastSwitchTime = Date()
    private var averageSwitchTime: TimeInterval = 0.0
    private var performanceTimer: Timer?
    
    // Performance thresholds
    private let memoryThreshold: Double = 0.8
    private let cpuThreshold: Double = 0.7
    private let batteryThreshold: Float = 0.2
    
    enum PerformanceLevel: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .excellent: return "bolt.fill"
            case .good: return "bolt"
            case .fair: return "bolt.slash"
            case .poor: return "tortoise.fill"
            }
        }
    }
    
    var currentPerformanceLevel: PerformanceLevel {
        if performanceScore >= 80 {
            return .excellent
        } else if performanceScore >= 60 {
            return .good
        } else if performanceScore >= 40 {
            return .fair
        } else {
            return .poor
        }
    }
    
    init() {
        setupPerformanceMonitoring()
        startMonitoring()
    }
    
    deinit {
        performanceTimer?.invalidate()
    }
    
    private func setupPerformanceMonitoring() {
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Setup thermal state notifications
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.thermalState = ProcessInfo.processInfo.thermalState
            self?.updatePerformanceScore()
        }
        
        // Setup battery state notifications
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.batteryState = UIDevice.current.batteryState
            self?.updatePerformanceScore()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.batteryLevel = UIDevice.current.batteryLevel
            self?.updatePerformanceScore()
        }
    }
    
    private func startMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }
    
    private func updateMetrics() {
        // Update thermal state
        thermalState = ProcessInfo.processInfo.thermalState
        
        // Update battery metrics
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        
        // Update memory usage (simplified simulation)
        memoryUsage = getMemoryUsage()
        
        // Update CPU usage (simplified simulation)
        cpuUsage = getCPUUsage()
        
        // Update overall performance score
        updatePerformanceScore()
    }
    
    private func getMemoryUsage() -> Double {
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
            let usedBytes = Double(info.resident_size)
            let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
            return usedBytes / totalBytes
        } else {
            // Fallback to simulation
            return Double.random(in: 0.3...0.7)
        }
    }
    
    private func getCPUUsage() -> Double {
        // Simplified CPU usage simulation
        // In a real implementation, you'd use proper CPU monitoring APIs
        var usage = Double.random(in: 0.1...0.6)
        
        // Adjust based on video switch frequency
        let timeSinceLastSwitch = Date().timeIntervalSince(lastSwitchTime)
        if timeSinceLastSwitch < 1.0 {
            usage += 0.2 // Higher CPU during transitions
        }
        
        return min(usage, 1.0)
    }
    
    private func updatePerformanceScore() {
        var score: Double = 100.0
        
        // Memory impact
        if memoryUsage > memoryThreshold {
            score -= (memoryUsage - memoryThreshold) * 100
        }
        
        // CPU impact
        if cpuUsage > cpuThreshold {
            score -= (cpuUsage - cpuThreshold) * 80
        }
        
        // Thermal impact
        switch thermalState {
        case .nominal:
            break
        case .fair:
            score -= 10
        case .serious:
            score -= 25
        case .critical:
            score -= 50
        @unknown default:
            break
        }
        
        // Battery impact
        if batteryLevel < batteryThreshold {
            score -= (Double(batteryThreshold) - Double(batteryLevel)) * 60
        }
        
        // Battery state impact
        if batteryState == .charging {
            score += 5 // Slight boost when charging
        }
        
        performanceScore = max(0, min(100, score))
    }
    
    func trackVideoSwitch() {
        let now = Date()
        let switchTime = now.timeIntervalSince(lastSwitchTime)
        
        if videoSwitchCount > 0 {
            averageSwitchTime = (averageSwitchTime * Double(videoSwitchCount) + switchTime) / Double(videoSwitchCount + 1)
        } else {
            averageSwitchTime = switchTime
        }
        
        videoSwitchCount += 1
        lastSwitchTime = now
        
        // Update metrics after switch
        updateMetrics()
    }
    
    func shouldPreloadVideos() -> Bool {
        let hasGoodPerformance = performanceScore > 60
        let hasGoodMemory = memoryUsage < memoryThreshold
        let hasGoodThermal = thermalState == .nominal || thermalState == .fair
        let hasGoodBattery = batteryLevel > batteryThreshold
        
        return hasGoodPerformance && hasGoodMemory && hasGoodThermal && hasGoodBattery
    }
    
    func shouldReduceQuality() -> Bool {
        return performanceScore < 40 || thermalState == .serious || thermalState == .critical
    }
    
    func getRecommendedPreloadCount() -> Int {
        switch currentPerformanceLevel {
        case .excellent:
            return 5
        case .good:
            return 3
        case .fair:
            return 2
        case .poor:
            return 1
        }
    }
    
    func getOptimizationRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if memoryUsage > memoryThreshold {
            recommendations.append("High memory usage detected - reducing preload count")
        }
        
        if cpuUsage > cpuThreshold {
            recommendations.append("High CPU usage - optimizing video processing")
        }
        
        if thermalState != .nominal {
            recommendations.append("Device heating detected - reducing quality")
        }
        
        if batteryLevel < batteryThreshold {
            recommendations.append("Low battery - enabling power saving mode")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Performance is optimal")
        }
        
        return recommendations
    }
}

#Preview {
    @StateObject var performanceMonitor = FlicksPerformanceMonitor()
    
    ScrollView {
        VStack(spacing: 20) {
            Text("Performance Monitor")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Performance Score
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: performanceMonitor.currentPerformanceLevel.icon)
                        .foregroundColor(performanceMonitor.currentPerformanceLevel.color)
                        .font(.title)
                    
                    VStack(alignment: .leading) {
                        Text("Performance: \(performanceMonitor.currentPerformanceLevel.rawValue)")
                            .font(.headline)
                        Text("Score: \(String(format: "%.0f", performanceMonitor.performanceScore))/100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Performance bar
                ProgressView(value: performanceMonitor.performanceScore, total: 100)
                    .tint(performanceMonitor.currentPerformanceLevel.color)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Metrics
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "Memory",
                    value: String(format: "%.1f%%", performanceMonitor.memoryUsage * 100),
                    icon: "memorychip",
                    color: performanceMonitor.memoryUsage > 0.8 ? .red : .blue
                )
                
                MetricCard(
                    title: "CPU",
                    value: String(format: "%.1f%%", performanceMonitor.cpuUsage * 100),
                    icon: "cpu",
                    color: performanceMonitor.cpuUsage > 0.7 ? .red : .green
                )
                
                MetricCard(
                    title: "Battery",
                    value: String(format: "%.0f%%", performanceMonitor.batteryLevel * 100),
                    icon: "battery.100",
                    color: performanceMonitor.batteryLevel < 0.2 ? .red : .green
                )
                
                MetricCard(
                    title: "Thermal",
                    value: performanceMonitor.thermalState.displayName,
                    icon: "thermometer",
                    color: performanceMonitor.thermalState == .nominal ? .green : .orange
                )
            }
            
            // Recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Optimization Recommendations")
                    .font(.headline)
                
                ForEach(performanceMonitor.getOptimizationRecommendations(), id: \.self) { recommendation in
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text(recommendation)
                            .font(.caption)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }
    .environmentObject(performanceMonitor)
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

extension ProcessInfo.ThermalState {
    var displayName: String {
        switch self {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}