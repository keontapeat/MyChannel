//
//  ErrorReportingManager.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation
import UIKit

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

// 🚨 Enhanced Error Reporting Manager
// Comprehensive error tracking and reporting beyond basic Crashlytics
@MainActor
class ErrorReportingManager {
    static let shared = ErrorReportingManager()
    
    private var errorQueue: [ErrorReport] = []
    private var isEnabled = true
    private let maxQueueSize = 100
    
    private init() {
        configure()
    }
    
    // MARK: - Configuration
    
    func configure() {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(isEnabled)
        #endif
        
        // Set up custom error handling
        setupCustomErrorHandling()
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
        #endif
    }
    
    private func setupCustomErrorHandling() {
        // Set up global exception handler
        NSSetUncaughtExceptionHandler { exception in
            ErrorReportingManager.shared.reportCrash(
                exception: exception,
                context: "UncaughtException"
            )
        }
    }
    
    // MARK: - Error Reporting
    
    func reportError(_ error: Error, context: String, severity: ErrorSeverity = .error, metadata: [String: Any] = [:]) {
        let errorReport = ErrorReport(
            error: error,
            context: context,
            severity: severity,
            metadata: metadata,
            timestamp: Date(),
            userId: getCurrentUserId(),
            appVersion: getAppVersion(),
            deviceInfo: getDeviceInfo()
        )
        
        // Add to queue
        addToQueue(errorReport)
        
        // Report to Crashlytics
        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        
        // Set custom keys
        crashlytics.setCustomValue(context, forKey: "error_context")
        crashlytics.setCustomValue(severity.rawValue, forKey: "error_severity")
        crashlytics.setCustomValue(errorReport.timestamp.timeIntervalSince1970, forKey: "error_timestamp")
        
        // Set metadata
        for (key, value) in metadata {
            crashlytics.setCustomValue(value, forKey: "metadata_\(key)")
        }
        
        // Record error
        crashlytics.record(error: error)
        #endif
        
        // Log to analytics
        EnhancedAnalyticsManager.shared.trackError(error: error, context: context, fatal: false)
        
        print("🚨 [ErrorReporting] \(severity.rawValue.uppercased()): \(error.localizedDescription) in \(context)")
    }
    
    func reportCrash(exception: NSException, context: String) {
        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(context, forKey: "crash_context")
        crashlytics.record(exceptionModel: ExceptionModel(name: exception.name.rawValue, reason: exception.reason ?? "Unknown"))
        #endif
        
        print("💥 [ErrorReporting] CRASH: \(exception.name.rawValue) - \(exception.reason ?? "Unknown") in \(context)")
    }
    
    func reportNetworkError(url: String, statusCode: Int, error: Error?, responseTime: Double) {
        let metadata: [String: Any] = [
            "url": url,
            "status_code": statusCode,
            "response_time": responseTime,
            "network_type": getNetworkType()
        ]
        
        if let error = error {
            reportError(error, context: "NetworkRequest", severity: .warning, metadata: metadata)
        } else {
            reportCustomError(
                message: "HTTP \(statusCode) error",
                context: "NetworkRequest",
                severity: statusCode >= 500 ? .error : .warning,
                metadata: metadata
            )
        }
        
        // Track API error in analytics
        EnhancedAnalyticsManager.shared.trackAPIError(
            endpoint: url,
            statusCode: statusCode,
            errorMessage: error?.localizedDescription ?? "HTTP \(statusCode)"
        )
    }
    
    func reportCustomError(message: String, context: String, severity: ErrorSeverity = .error, metadata: [String: Any] = [:]) {
        let customError = CustomError(message: message, code: 0)
        reportError(customError, context: context, severity: severity, metadata: metadata)
    }
    
    // MARK: - Search-Specific Error Reporting
    
    func reportSearchError(query: String, error: Error, searchType: String, filters: [String: Any]?) {
        let metadata: [String: Any] = [
            "search_query": query,
            "search_type": searchType,
            "query_length": query.count,
            "has_filters": filters != nil,
            "filter_count": filters?.count ?? 0
        ]
        
        reportError(error, context: "SearchOperation", severity: .warning, metadata: metadata)
    }
    
    func reportVoiceSearchError(error: Error, duration: Double, partialTranscript: String?) {
        let metadata: [String: Any] = [
            "duration": duration,
            "partial_transcript": partialTranscript ?? "",
            "transcript_length": partialTranscript?.count ?? 0
        ]
        
        reportError(error, context: "VoiceSearch", severity: .warning, metadata: metadata)
    }
    
    func reportVisualSearchError(error: Error, processingTime: Double, imageSize: CGSize?) {
        var metadata: [String: Any] = [
            "processing_time": processingTime
        ]
        
        if let size = imageSize {
            metadata["image_width"] = size.width
            metadata["image_height"] = size.height
        }
        
        reportError(error, context: "VisualSearch", severity: .warning, metadata: metadata)
    }
    
    // MARK: - Video-Specific Error Reporting
    
    func reportVideoPlaybackError(videoId: String, error: Error, quality: String, position: Double) {
        let metadata: [String: Any] = [
            "video_id": videoId,
            "quality": quality,
            "playback_position": position
        ]
        
        reportError(error, context: "VideoPlayback", severity: .error, metadata: metadata)
    }
    
    func reportUploadError(error: Error, fileSize: Int64, contentType: String, progress: Double) {
        let metadata: [String: Any] = [
            "file_size_mb": Double(fileSize) / (1024 * 1024),
            "content_type": contentType,
            "upload_progress": progress
        ]
        
        reportError(error, context: "ContentUpload", severity: .error, metadata: metadata)
    }
    
    // MARK: - ML Service Error Reporting
    
    func reportMLServiceError(serviceName: String, error: Error, requestData: [String: Any]?, responseTime: Double) {
        var metadata: [String: Any] = [
            "service_name": serviceName,
            "response_time": responseTime,
            "has_request_data": requestData != nil
        ]
        
        if let data = requestData {
            metadata["request_data_size"] = data.count
        }
        
        reportError(error, context: "MLService", severity: .warning, metadata: metadata)
    }
    
    // MARK: - Performance Issue Reporting
    
    func reportPerformanceIssue(operation: String, duration: Double, threshold: Double, metadata: [String: Any] = [:]) {
        var perfMetadata = metadata
        perfMetadata["operation"] = operation
        perfMetadata["duration"] = duration
        perfMetadata["threshold"] = threshold
        perfMetadata["performance_ratio"] = duration / threshold
        
        reportCustomError(
            message: "Performance threshold exceeded for \(operation)",
            context: "Performance",
            severity: .warning,
            metadata: perfMetadata
        )
    }
    
    func reportMemoryWarning(memoryUsage: Int64, availableMemory: Int64) {
        let metadata: [String: Any] = [
            "memory_usage_mb": memoryUsage / (1024 * 1024),
            "available_memory_mb": availableMemory / (1024 * 1024),
            "memory_pressure": Double(memoryUsage) / Double(availableMemory)
        ]
        
        reportCustomError(
            message: "Memory warning triggered",
            context: "MemoryManagement",
            severity: .warning,
            metadata: metadata
        )
    }
    
    // MARK: - User Context
    
    func setUserId(_ userId: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(userId)
        #endif
    }
    
    func setCustomKey(_ key: String, value: Any) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }
    
    func addBreadcrumb(_ message: String, category: String = "general") {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("\(category): \(message)")
        #endif
        
        print("🍞 [Breadcrumb] \(category): \(message)")
    }
    
    // MARK: - Error Queue Management
    
    private func addToQueue(_ errorReport: ErrorReport) {
        errorQueue.append(errorReport)
        
        // Maintain queue size
        if errorQueue.count > maxQueueSize {
            errorQueue.removeFirst()
        }
    }
    
    func getRecentErrors(limit: Int = 10) -> [ErrorReport] {
        return Array(errorQueue.suffix(limit))
    }
    
    func clearErrorQueue() {
        errorQueue.removeAll()
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentUserId() -> String? {
        // Get current user ID from authentication manager
        return nil // Implement based on your auth system
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
    
    private func getDeviceInfo() -> [String: Any] {
        return [
            "device_model": UIDevice.current.model,
            "system_name": UIDevice.current.systemName,
            "system_version": UIDevice.current.systemVersion,
            "app_version": getAppVersion()
        ]
    }
    
    private func getNetworkType() -> String {
        // Implement network type detection
        return "unknown"
    }
    
    // MARK: - Error Statistics
    
    func getErrorStatistics() -> ErrorStatistics {
        let now = Date()
        let oneDayAgo = now.addingTimeInterval(-24 * 60 * 60)
        
        let recentErrors = errorQueue.filter { $0.timestamp >= oneDayAgo }
        let errorsByContext = Dictionary(grouping: recentErrors) { $0.context }
        let errorsBySeverity = Dictionary(grouping: recentErrors) { $0.severity }
        
        return ErrorStatistics(
            totalErrors: errorQueue.count,
            recentErrors: recentErrors.count,
            errorsByContext: errorsByContext.mapValues { $0.count },
            errorsBySeverity: errorsBySeverity.mapValues { $0.count },
            mostCommonError: errorsByContext.max(by: { $0.value.count < $1.value.count })?.key
        )
    }
}

// MARK: - Supporting Types

struct ErrorReport {
    let id = UUID()
    let error: Error
    let context: String
    let severity: ErrorSeverity
    let metadata: [String: Any]
    let timestamp: Date
    let userId: String?
    let appVersion: String
    let deviceInfo: [String: Any]
}

enum ErrorSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

struct CustomError: Error, LocalizedError {
    let message: String
    let code: Int
    
    var errorDescription: String? {
        return message
    }
}

struct ErrorStatistics {
    let totalErrors: Int
    let recentErrors: Int
    let errorsByContext: [String: Int]
    let errorsBySeverity: [ErrorSeverity: Int]
    let mostCommonError: String?
}

// MARK: - Error Reporting Extensions

extension ErrorReportingManager {
    
    // Convenience methods for common error scenarios
    func reportAuthenticationError(_ error: Error) {
        reportError(error, context: "Authentication", severity: .error)
    }
    
    func reportDatabaseError(_ error: Error, operation: String) {
        reportError(error, context: "Database", severity: .error, metadata: ["operation": operation])
    }
    
    func reportStorageError(_ error: Error, operation: String, fileSize: Int64? = nil) {
        var metadata: [String: Any] = ["operation": operation]
        if let size = fileSize {
            metadata["file_size_mb"] = Double(size) / (1024 * 1024)
        }
        reportError(error, context: "Storage", severity: .error, metadata: metadata)
    }
    
    func reportUIError(_ error: Error, screen: String, action: String) {
        let metadata: [String: Any] = [
            "screen": screen,
            "action": action
        ]
        reportError(error, context: "UI", severity: .warning, metadata: metadata)
    }
}
