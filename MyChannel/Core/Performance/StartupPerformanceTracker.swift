//
//  StartupPerformanceTracker.swift
//  MyChannel
//
//  📊 STARTUP PERFORMANCE MONITORING
//  Track app launch metrics with Firebase Performance
//

import Foundation
import SwiftUI
#if canImport(FirebasePerformance)
import FirebasePerformance
#endif

// MARK: - Startup Performance Tracker
@MainActor
class StartupPerformanceTracker: ObservableObject {
    static let shared = StartupPerformanceTracker()
    
    @Published var metrics = StartupMetrics()
    
    private var appLaunchTrace: Any?
    private var initStartTime: Date?
    private var firstFrameTime: Date?
    
    struct StartupMetrics {
        var coldStartTime: TimeInterval = 0
        var timeToFirstFrame: TimeInterval = 0
        var timeToInteractive: TimeInterval = 0
        var criticalServicesTime: TimeInterval = 0
        var totalServicesLoaded: Int = 0
        var memoryAtLaunch: Int64 = 0
    }
    
    private init() {}
    
    // MARK: - Launch Tracking
    
    func trackAppLaunch() {
        initStartTime = Date()
        
        #if canImport(FirebasePerformance)
        appLaunchTrace = Performance.startTrace(name: "app_cold_start")
        #endif
        
        print("📊 [StartupTracker] App launch tracking started")
    }
    
    func trackFirstFrame() {
        guard let start = initStartTime else { return }
        firstFrameTime = Date()
        
        let timeToFirstFrame = Date().timeIntervalSince(start)
        metrics.timeToFirstFrame = timeToFirstFrame
        
        #if canImport(FirebasePerformance)
        if let trace = appLaunchTrace as? Trace {
            trace.setValue(Int64(timeToFirstFrame * 1000), forMetric: "time_to_first_frame_ms")
        }
        #endif
        
        print("📊 [StartupTracker] First frame rendered in \(Int(timeToFirstFrame * 1000))ms")
    }
    
    func trackInteractive() {
        guard let start = initStartTime else { return }
        
        let timeToInteractive = Date().timeIntervalSince(start)
        metrics.timeToInteractive = timeToInteractive
        
        #if canImport(FirebasePerformance)
        if let trace = appLaunchTrace as? Trace {
            trace.setValue(Int64(timeToInteractive * 1000), forMetric: "time_to_interactive_ms")
        }
        #endif
        
        print("📊 [StartupTracker] App interactive in \(Int(timeToInteractive * 1000))ms")
    }
    
    func trackColdStartComplete() {
        guard let start = initStartTime else { return }
        
        let coldStartTime = Date().timeIntervalSince(start)
        metrics.coldStartTime = coldStartTime
        metrics.memoryAtLaunch = getMemoryUsage()
        
        #if canImport(FirebasePerformance)
        if let trace = appLaunchTrace as? Trace {
            trace.setValue(Int64(coldStartTime * 1000), forMetric: "cold_start_ms")
            trace.setValue(metrics.memoryAtLaunch / 1_000_000, forMetric: "memory_at_launch_mb")
            trace.stop()
        }
        #endif
        
        printSummary()
    }
    
    // MARK: - Service Tracking
    
    func trackCriticalServicesLoaded(duration: TimeInterval) {
        metrics.criticalServicesTime = duration
        
        #if canImport(FirebasePerformance)
        if let trace = appLaunchTrace as? Trace {
            trace.setValue(Int64(duration * 1000), forMetric: "critical_services_ms")
        }
        #endif
    }
    
    func trackServicesLoaded(count: Int) {
        metrics.totalServicesLoaded = count
        
        #if canImport(FirebasePerformance)
        if let trace = appLaunchTrace as? Trace {
            trace.setValue(Int64(count), forMetric: "services_loaded")
        }
        #endif
    }
    
    // MARK: - Memory Tracking
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info(
            virtual_size: 0,
            resident_size: 0,
            resident_size_max: 0,
            user_time: time_value_t(seconds: 0, microseconds: 0),
            system_time: time_value_t(seconds: 0, microseconds: 0),
            policy: 0,
            suspend_count: 0
        )
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0 }
        return Int64(info.resident_size)
    }
    
    // MARK: - Summary
    
    func printSummary() {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🚀 STARTUP PERFORMANCE SUMMARY")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Cold Start Time:       \(Int(metrics.coldStartTime * 1000))ms")
        print("Time to First Frame:   \(Int(metrics.timeToFirstFrame * 1000))ms")
        print("Time to Interactive:   \(Int(metrics.timeToInteractive * 1000))ms")
        print("Critical Services:     \(Int(metrics.criticalServicesTime * 1000))ms")
        print("Services Loaded:       \(metrics.totalServicesLoaded)")
        print("Memory at Launch:      \(metrics.memoryAtLaunch / 1_000_000)MB")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Performance assessment
        if metrics.coldStartTime < 2.0 {
            print("✅ EXCELLENT: Cold start < 2 seconds (YouTube parity achieved!)")
        } else if metrics.coldStartTime < 3.0 {
            print("⚠️  GOOD: Cold start < 3 seconds (room for improvement)")
        } else {
            print("❌ NEEDS WORK: Cold start > 3 seconds (optimization required)")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    
    // MARK: - Custom Traces
    
    func trace<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        #if canImport(FirebasePerformance)
        let trace = Performance.startTrace(name: name)
        #endif
        
        let startTime = Date()
        defer {
            let duration = Date().timeIntervalSince(startTime)
            #if canImport(FirebasePerformance)
            trace?.setValue(Int64(duration * 1000), forMetric: "duration_ms")
            trace?.stop()
            #endif
            print("📊 [\(name)] completed in \(Int(duration * 1000))ms")
        }
        
        return try await operation()
    }
}

// MARK: - View Modifier for Performance Tracking

struct PerformanceTracked: ViewModifier {
    let name: String
    @State private var renderTime: TimeInterval = 0
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                let start = Date()
                DispatchQueue.main.async {
                    let duration = Date().timeIntervalSince(start)
                    renderTime = duration
                    PerformanceMonitor.shared.measureViewRender(name, duration: duration)
                }
            }
    }
}

extension View {
    func trackPerformance(_ name: String) -> some View {
        modifier(PerformanceTracked(name: name))
    }
}
