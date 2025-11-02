//
//  MonitoringService.swift
//  MyChannel
//
//  COMPREHENSIVE MONITORING - Never fly blind again!
//  Crashlytics, Performance Monitoring, Analytics, Custom Metrics
//

import Foundation
import Combine
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
#if canImport(FirebasePerformance)
import FirebasePerformance
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

@MainActor
final class MonitoringService: ObservableObject {
    static let shared = MonitoringService()
    
    @Published var isMonitoringEnabled: Bool = true
    @Published var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published var errorLog: [ErrorEntry] = []
    
    private var performanceTraces: [String: Any] = [:]
    private let maxErrorLogSize = 100
    
    struct PerformanceMetrics {
        var appLaunchTime: TimeInterval = 0
        var videoLoadTime: TimeInterval = 0
        var apiResponseTime: TimeInterval = 0
        var memoryUsage: Double = 0 // MB
        var crashFreeRate: Double = 100.0
    }
    
    struct ErrorEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let domain: String
        let code: Int
        let message: String
        let userInfo: [String: Any]?
        let stackTrace: String?
    }
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupMonitoring() {
        #if canImport(FirebaseCrashlytics)
        setupCrashlytics()
        #endif
        
        #if canImport(FirebasePerformance)
        setupPerformanceMonitoring()
        #endif
        
        #if canImport(FirebaseAnalytics)
        setupAnalytics()
        #endif
        
        setupCustomMetrics()
        print("✅ Monitoring services initialized")
    }
    
    // MARK: - Crashlytics
    
    #if canImport(FirebaseCrashlytics)
    private func setupCrashlytics() {
        let crashlytics = Crashlytics.crashlytics()
        
        // Set custom keys for debugging
        if let userId = AuthenticationManager.shared.currentUser?.id {
            crashlytics.setUserID(userId)
        }
        
        crashlytics.setCustomValue("iOS", forKey: "platform")
        crashlytics.setCustomValue(UIDevice.current.systemVersion, forKey: "os_version")
        
        print("✅ Crashlytics configured")
    }
    
    func recordError(_ error: Error, additionalInfo: [String: Any]? = nil) {
        let crashlytics = Crashlytics.crashlytics()
        
        // Add custom keys
        if let info = additionalInfo {
            for (key, value) in info {
                crashlytics.setCustomValue(value, forKey: key)
            }
        }
        
        // Record error
        crashlytics.record(error: error)
        
        // Log to local error log
        logErrorLocally(error, additionalInfo: additionalInfo)
        
        print("🚨 Error recorded to Crashlytics: \(error.localizedDescription)")
    }
    
    func recordNonFatalError(_ domain: String, code: Int, message: String, userInfo: [String: Any]? = nil) {
        let nsError = NSError(domain: domain, code: code, userInfo: userInfo as? [String : Any])
        recordError(nsError, additionalInfo: userInfo)
    }
    
    func setUserIdentifier(_ userId: String) {
        Crashlytics.crashlytics().setUserID(userId)
    }
    
    func logCrashlytics(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
    #else
    func recordError(_ error: Error, additionalInfo: [String: Any]? = nil) {
        logErrorLocally(error, additionalInfo: additionalInfo)
    }
    
    func recordNonFatalError(_ domain: String, code: Int, message: String, userInfo: [String: Any]? = nil) {
        let nsError = NSError(domain: domain, code: code, userInfo: userInfo as? [String : Any])
        logErrorLocally(nsError, additionalInfo: userInfo)
    }
    
    func setUserIdentifier(_ userId: String) {}
    func logCrashlytics(_ message: String) {}
    #endif
    
    private func logErrorLocally(_ error: Error, additionalInfo: [String: Any]?) {
        let entry = ErrorEntry(
            timestamp: Date(),
            domain: (error as NSError).domain,
            code: (error as NSError).code,
            message: error.localizedDescription,
            userInfo: additionalInfo,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n")
        )
        
        errorLog.append(entry)
        
        // Keep log size under control
        if errorLog.count > maxErrorLogSize {
            errorLog.removeFirst(errorLog.count - maxErrorLogSize)
        }
    }
    
    // MARK: - Performance Monitoring
    
    #if canImport(FirebasePerformance)
    private func setupPerformanceMonitoring() {
        // Performance Monitoring is auto-configured
        print("✅ Performance Monitoring enabled")
    }
    
    func startTrace(_ traceName: String) {
        if let trace = Performance.startTrace(name: traceName) {
            performanceTraces[traceName] = trace
            print("📊 Started trace: \(traceName)")
        }
    }
    
    func stopTrace(_ traceName: String, metrics: [String: Int]? = nil) {
        #if canImport(FirebasePerformance)
        guard let trace = performanceTraces[traceName] as? Trace else { return }
        
        // Add custom metrics
        if let metrics = metrics {
            for (key, value) in metrics {
                trace.setValue(Int64(value), forMetric: key)
            }
        }
        
        trace.stop()
        performanceTraces.removeValue(forKey: traceName)
        print("📊 Stopped trace: \(traceName)")
        #endif
    }
    
    func recordHTTPMetric(url: URL, httpMethod: String, responseCode: Int, requestSize: Int64, responseSize: Int64, startTime: Date, endTime: Date) {
        #if canImport(FirebasePerformance)
        // Convert string to Firebase HTTPMethod
        let fbHttpMethod: FirebasePerformance.HTTPMethod
        switch httpMethod.uppercased() {
        case "GET": fbHttpMethod = .get
        case "POST": fbHttpMethod = .post
        case "PUT": fbHttpMethod = .put
        case "DELETE": fbHttpMethod = .delete
        case "HEAD": fbHttpMethod = .head
        case "PATCH": fbHttpMethod = .patch
        case "OPTIONS": fbHttpMethod = .options
        case "TRACE": fbHttpMethod = .trace
        case "CONNECT": fbHttpMethod = .connect
        default: fbHttpMethod = .get
        }
        let metric = HTTPMetric(url: url, httpMethod: fbHttpMethod)
        metric?.responseCode = responseCode
        metric?.requestPayloadSize = Int(requestSize)
        metric?.responsePayloadSize = Int(responseSize)
        
        // Calculate time
        let timeInterval = endTime.timeIntervalSince(startTime) * 1000 // ms
        
        // Note: Firebase Performance SDK handles timing internally
        // This is for custom tracking
        print("📊 HTTP Metric: \(httpMethod) \(url.path) - \(responseCode) - \(Int(timeInterval))ms")
        #endif
    }
    #else
    private func setupPerformanceMonitoring() {}
    func startTrace(_ traceName: String) {}
    func stopTrace(_ traceName: String, metrics: [String: Int]? = nil) {}
    func recordHTTPMetric(url: URL, httpMethod: String, responseCode: Int, requestSize: Int64, responseSize: Int64, startTime: Date, endTime: Date) {}
    #endif
    
    // MARK: - Firebase Analytics
    
    #if canImport(FirebaseAnalytics)
    private func setupAnalytics() {
        // Analytics is auto-configured
        print("✅ Firebase Analytics enabled")
    }
    
    func logEvent(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {
        Analytics.logEvent(event.rawValue, parameters: parameters)
        print("📈 Event logged: \(event.rawValue)")
    }
    
    func setUserProperty(_ value: String, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
    
    func setScreenName(_ screenName: String, screenClass: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass
        ])
    }
    #else
    private func setupAnalytics() {}
    func logEvent(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {}
    func setUserProperty(_ value: String, forName name: String) {}
    func setScreenName(_ screenName: String, screenClass: String) {}
    #endif
    
    // MARK: - Custom Metrics
    
    private func setupCustomMetrics() {
        // Track app launch time
        trackAppLaunchTime()
        
        // Monitor memory usage
        startMemoryMonitoring()
    }
    
    private func trackAppLaunchTime() {
        // Calculate time since app start
        let launchTime = ProcessInfo.processInfo.systemUptime
        performanceMetrics.appLaunchTime = launchTime
        
        logEvent(.appLaunch, parameters: [
            "launch_time": launchTime
        ])
    }
    
    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }
    }
    
    private func updateMemoryUsage() {
        var info = task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info_data_t>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
            performanceMetrics.memoryUsage = memoryUsageMB
            
            // Alert if memory usage is high
            if memoryUsageMB > 500 {
                print("⚠️ HIGH MEMORY USAGE: \(String(format: "%.2f", memoryUsageMB)) MB")
                logEvent(.highMemoryUsage, parameters: [
                    "memory_mb": memoryUsageMB
                ])
            }
        }
    }
    
    // MARK: - Video Performance Tracking
    
    func trackVideoLoad(videoId: String, loadTime: TimeInterval) {
        performanceMetrics.videoLoadTime = loadTime
        
        logEvent(.videoLoadComplete, parameters: [
            "video_id": videoId,
            "load_time_ms": Int(loadTime * 1000)
        ])
        
        // Alert if load time is slow
        if loadTime > 3.0 {
            recordNonFatalError(
                "VideoPerformance",
                code: 1001,
                message: "Slow video load: \(String(format: "%.2f", loadTime))s",
                userInfo: ["video_id": videoId, "load_time": loadTime]
            )
        }
    }
    
    func trackVideoPlayback(videoId: String, duration: TimeInterval, buffering: Int) {
        logEvent(.videoPlaybackComplete, parameters: [
            "video_id": videoId,
            "duration_seconds": Int(duration),
            "buffering_count": buffering
        ])
    }
    
    // MARK: - AI Performance Tracking
    
    func trackAIRequest(service: String, duration: TimeInterval, cached: Bool, cost: Double) {
        performanceMetrics.apiResponseTime = duration
        
        logEvent(.aiRequestComplete, parameters: [
            "service": service,
            "duration_ms": Int(duration * 1000),
            "cached": cached,
            "cost_dollars": cost
        ])
        
        // Alert if API is slow
        if duration > 5.0 && !cached {
            print("⚠️ SLOW AI REQUEST: \(service) took \(String(format: "%.2f", duration))s")
        }
    }
    
    // MARK: - Analytics Events
    
    enum AnalyticsEvent: String {
        case appLaunch = "app_launch"
        case userSignIn = "user_sign_in"
        case userSignOut = "user_sign_out"
        case videoUpload = "video_upload"
        case videoView = "video_view"
        case videoLike = "video_like"
        case videoShare = "video_share"
        case videoLoadComplete = "video_load_complete"
        case videoPlaybackComplete = "video_playback_complete"
        case subscribe = "subscribe"
        case unsubscribe = "unsubscribe"
        case aiRequestComplete = "ai_request_complete"
        case highMemoryUsage = "high_memory_usage"
        case purchaseComplete = "purchase_complete"
        case errorOccurred = "error_occurred"
    }
    
    // MARK: - Debug Tools
    
    func getErrorLog(limit: Int = 20) -> [ErrorEntry] {
        return Array(errorLog.suffix(limit))
    }
    
    func clearErrorLog() {
        errorLog.removeAll()
    }
    
    func generateDebugReport() -> String {
        var report = """
        🔍 MYCHANNEL DEBUG REPORT
        ========================
        Timestamp: \(Date())
        
        📊 PERFORMANCE METRICS:
        - App Launch Time: \(String(format: "%.2f", performanceMetrics.appLaunchTime))s
        - Video Load Time: \(String(format: "%.2f", performanceMetrics.videoLoadTime))s
        - API Response Time: \(String(format: "%.2f", performanceMetrics.apiResponseTime))s
        - Memory Usage: \(String(format: "%.2f", performanceMetrics.memoryUsage)) MB
        - Crash Free Rate: \(String(format: "%.1f", performanceMetrics.crashFreeRate))%
        
        🚨 RECENT ERRORS (\(errorLog.count) total):
        """
        
        for entry in errorLog.suffix(5) {
            report += "\n- [\(entry.timestamp)] \(entry.domain):\(entry.code) - \(entry.message)"
        }
        
        report += "\n\n========================\n"
        
        return report
    }
    
    func printDebugReport() {
        print(generateDebugReport())
    }
}

// MARK: - mach_task_basic_info (for memory monitoring)
import Darwin

struct mach_task_basic_info {
    var virtual_size: mach_vm_size_t
    var resident_size: mach_vm_size_t
    var resident_size_max: mach_vm_size_t
    var user_time: time_value_t
    var system_time: time_value_t
    var policy: policy_t
    var suspend_count: integer_t
}

