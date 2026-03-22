//
//  PerformanceMonitoringManager.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation

#if canImport(FirebasePerformance)
import FirebasePerformance
#endif

// 📊 Firebase Performance Monitoring Manager
// Tracks app performance, network requests, and custom traces
@MainActor
class PerformanceMonitoringManager {
    static let shared = PerformanceMonitoringManager()
    
    private var activeTraces: [String: Trace] = [:]
    private var isEnabled = true
    
    private init() {
        configure()
    }
    
    // MARK: - Configuration
    
    func configure() {
        #if canImport(FirebasePerformance)
        Performance.sharedInstance().isDataCollectionEnabled = isEnabled
        Performance.sharedInstance().isInstrumentationEnabled = true
        #endif
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        #if canImport(FirebasePerformance)
        Performance.sharedInstance().isDataCollectionEnabled = enabled
        #endif
    }
    
    // MARK: - Custom Traces
    
    func startTrace(name: String, attributes: [String: String] = [:]) {
        #if canImport(FirebasePerformance)
        let trace = Performance.startTrace(name: name)
        
        // Add custom attributes
        for (key, value) in attributes {
            trace?.setValue(value, forAttribute: key)
        }
        
        activeTraces[name] = trace
        #endif
    }
    
    func stopTrace(name: String, metrics: [String: Int64] = [:]) {
        #if canImport(FirebasePerformance)
        guard let trace = activeTraces[name] else { return }
        
        // Add custom metrics
        for (key, value) in metrics {
            trace.setValue(value, forMetric: key)
        }
        
        trace.stop()
        activeTraces.removeValue(forKey: name)
        #endif
    }
    
    func addTraceAttribute(traceName: String, key: String, value: String) {
        #if canImport(FirebasePerformance)
        activeTraces[traceName]?.setValue(value, forAttribute: key)
        #endif
    }
    
    func addTraceMetric(traceName: String, key: String, value: Int64) {
        #if canImport(FirebasePerformance)
        activeTraces[traceName]?.setValue(value, forMetric: key)
        #endif
    }
    
    // MARK: - Search Performance Tracking
    
    func trackSearchPerformance(query: String, resultCount: Int, duration: TimeInterval) {
        let traceName = "search_query"
        startTrace(name: traceName, attributes: [
            "query_length": String(query.count),
            "has_filters": "false", // Will be updated by caller
            "search_scope": "all"   // Will be updated by caller
        ])
        
        // Add metrics
        addTraceMetric(traceName: traceName, key: "result_count", value: Int64(resultCount))
        addTraceMetric(traceName: traceName, key: "duration_ms", value: Int64(duration * 1000))
        
        stopTrace(name: traceName)
    }
    
    func trackVideoLoad(videoId: String, loadTime: TimeInterval, quality: String) {
        let traceName = "video_load_\(videoId)"
        startTrace(name: traceName, attributes: [
            "video_id": videoId,
            "quality": quality
        ])
        
        addTraceMetric(traceName: traceName, key: "load_time_ms", value: Int64(loadTime * 1000))
        stopTrace(name: traceName)
    }
    
    func trackStoryLoad(storyId: String, loadTime: TimeInterval, mediaType: String) {
        let traceName = "story_load"
        startTrace(name: traceName, attributes: [
            "story_id": storyId,
            "media_type": mediaType
        ])
        
        addTraceMetric(traceName: traceName, key: "load_time_ms", value: Int64(loadTime * 1000))
        stopTrace(name: traceName)
    }
    
    func trackUploadPerformance(fileSize: Int64, uploadTime: TimeInterval, contentType: String) {
        let traceName = "content_upload"
        startTrace(name: traceName, attributes: [
            "content_type": contentType,
            "file_size_category": fileSizeCategory(fileSize)
        ])
        
        addTraceMetric(traceName: traceName, key: "file_size_bytes", value: fileSize)
        addTraceMetric(traceName: traceName, key: "upload_time_ms", value: Int64(uploadTime * 1000))
        addTraceMetric(traceName: traceName, key: "upload_speed_kbps", value: Int64((Double(fileSize) / 1024) / uploadTime))
        
        stopTrace(name: traceName)
    }
    
    // MARK: - ML Service Performance
    
    func trackMLServiceCall(serviceName: String, responseTime: TimeInterval, success: Bool) {
        let traceName = "ml_service_call"
        startTrace(name: traceName, attributes: [
            "service_name": serviceName,
            "success": String(success)
        ])
        
        addTraceMetric(traceName: traceName, key: "response_time_ms", value: Int64(responseTime * 1000))
        stopTrace(name: traceName)
    }
    
    // MARK: - Database Performance
    
    func trackFirestoreQuery(collection: String, queryTime: TimeInterval, resultCount: Int) {
        let traceName = "firestore_query"
        startTrace(name: traceName, attributes: [
            "collection": collection
        ])
        
        addTraceMetric(traceName: traceName, key: "query_time_ms", value: Int64(queryTime * 1000))
        addTraceMetric(traceName: traceName, key: "result_count", value: Int64(resultCount))
        
        stopTrace(name: traceName)
    }
    
    // MARK: - Helper Methods
    
    private func fileSizeCategory(_ size: Int64) -> String {
        switch size {
        case 0..<1024*1024: // < 1MB
            return "small"
        case 1024*1024..<10*1024*1024: // 1-10MB
            return "medium"
        case 10*1024*1024..<100*1024*1024: // 10-100MB
            return "large"
        default: // > 100MB
            return "xlarge"
        }
    }
}

// MARK: - Performance Tracking Extensions

extension PerformanceMonitoringManager {
    
    // Track app launch performance
    func trackAppLaunch(launchTime: TimeInterval) {
        let traceName = "app_launch"
        startTrace(name: traceName)
        addTraceMetric(traceName: traceName, key: "launch_time_ms", value: Int64(launchTime * 1000))
        stopTrace(name: traceName)
    }
    
    // Track screen load times
    func trackScreenLoad(screenName: String, loadTime: TimeInterval) {
        let traceName = "screen_load"
        startTrace(name: traceName, attributes: [
            "screen_name": screenName
        ])
        addTraceMetric(traceName: traceName, key: "load_time_ms", value: Int64(loadTime * 1000))
        stopTrace(name: traceName)
    }
    
    // Track API call performance
    func trackAPICall(endpoint: String, method: String, responseTime: TimeInterval, statusCode: Int) {
        let traceName = "api_call"
        startTrace(name: traceName, attributes: [
            "endpoint": endpoint,
            "method": method,
            "status_code": String(statusCode)
        ])
        addTraceMetric(traceName: traceName, key: "response_time_ms", value: Int64(responseTime * 1000))
        stopTrace(name: traceName)
    }
}
