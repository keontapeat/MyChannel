//
//  AnalyticsService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import Combine
import SwiftUI
import UIKit

// MARK: - Analytics Service
@MainActor
class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()
    
    @Published var isEnabled: Bool = AppConfig.Analytics.enableUserAnalytics
    @Published var sessionId: String = UUID().uuidString
    
    private let networkService = NetworkService.shared
    private let databaseService = DatabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    private var eventQueue: [AnalyticsEvent] = []
    private var sessionStartTime: Date = Date()
    
    private init() {
        setupAnalytics()
    }
    
    // MARK: - Setup
    private func setupAnalytics() {
        // Start new session
        startSession()
        
        // Batch upload events every 30 seconds
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.uploadQueuedEvents()
                }
            }
            .store(in: &cancellables)
        
        // Upload events when app goes to background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.uploadQueuedEvents()
                    await self?.endSession()
                }
            }
            .store(in: &cancellables)
        
        // Start new session when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.startSession()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Session Management
    private func startSession() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        
        Task {
            await trackEvent("session_start", parameters: [
                "session_id": sessionId,
                "app_version": AppConfig.appVersion,
                "build_number": AppConfig.buildNumber,
                "environment": AppConfig.environment.rawValue
            ])
        }
    }
    
    private func endSession() async {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        
        await trackEvent("session_end", parameters: [
            "session_id": sessionId,
            "duration": String(Int(sessionDuration))
        ])
        
        await uploadQueuedEvents()
    }
    
    // MARK: - Event Tracking
    func trackEvent(_ eventName: String, parameters: [String: String] = [:]) async {
        guard isEnabled else { return }
        
        let event = AnalyticsEvent(
            name: eventName,
            parameters: parameters,
            timestamp: Date(),
            userId: AuthService.shared.currentUser?.id,
            sessionId: sessionId
        )
        
        // Add to queue
        eventQueue.append(event)
        
        // Save to local database
        try? await databaseService.saveAnalyticsEvent(event)
        
        // Upload immediately for critical events
        if isCriticalEvent(eventName) {
            await uploadQueuedEvents()
        }
        
        // Log in development
        if AppConfig.Features.enableNetworkLogging {
            print("📊 Analytics: \(eventName) - \(parameters)")
        }
    }
    
    // MARK: - Video Analytics
    func trackVideoView(_ video: Video, watchTime: TimeInterval = 0) async {
        await trackEvent(AppConfig.Analytics.videoWatchEvent, parameters: [
            "video_id": video.id,
            "video_title": video.title,
            "creator_id": video.creator.id,
            "creator_name": video.creator.displayName,
            "category": video.category.rawValue,
            "duration": String(Int(video.duration)),
            "watch_time": String(Int(watchTime)),
            "completion_rate": String(Int((watchTime / video.duration) * 100))
        ])
    }
    
    func trackVideoLike(_ video: Video, liked: Bool) async {
        await trackEvent(AppConfig.Analytics.videoLikeEvent, parameters: [
            "video_id": video.id,
            "creator_id": video.creator.id,
            "action": liked ? "like" : "unlike",
            "category": video.category.rawValue
        ])
    }
    
    func trackVideoShare(_ video: Video, platform: String) async {
        await trackEvent(AppConfig.Analytics.videoShareEvent, parameters: [
            "video_id": video.id,
            "creator_id": video.creator.id,
            "platform": platform,
            "category": video.category.rawValue
        ])
    }
    
    func trackVideoUpload(_ video: Video, uploadTime: TimeInterval) async {
        await trackEvent("video_upload", parameters: [
            "video_id": video.id,
            "title": video.title,
            "category": video.category.rawValue,
            "duration": String(Int(video.duration)),
            "upload_time": String(Int(uploadTime)),
            "file_size": "unknown", // Would be passed from upload service
            "is_short": String(video.isShort)
        ])
    }
    
    // MARK: - User Analytics
    func trackProfileView(_ user: User) async {
        await trackEvent(AppConfig.Analytics.profileViewEvent, parameters: [
            "profile_user_id": user.id,
            "profile_username": user.username,
            "is_verified": String(user.isVerified),
            "is_creator": String(user.isCreator),
            "subscriber_count": String(user.subscriberCount)
        ])
    }
    
    func trackSearch(_ query: String, resultsCount: Int) async {
        await trackEvent(AppConfig.Analytics.searchEvent, parameters: [
            "query": query,
            "results_count": String(resultsCount),
            "query_length": String(query.count)
        ])
    }
    
    func trackUserSignUp(method: String) async {
        await trackEvent("user_signup", parameters: [
            "method": method,
            "timestamp": String(Int(Date().timeIntervalSince1970))
        ])
    }
    
    func trackUserSignIn(method: String) async {
        await trackEvent("user_signin", parameters: [
            "method": method,
            "timestamp": String(Int(Date().timeIntervalSince1970))
        ])
    }
    
    // MARK: - App Analytics
    func trackScreenView(_ screenName: String) async {
        await trackEvent("screen_view", parameters: [
            "screen_name": screenName,
            "timestamp": String(Int(Date().timeIntervalSince1970))
        ])
    }
    
    func trackButtonTap(_ buttonName: String, screen: String) async {
        await trackEvent("button_tap", parameters: [
            "button_name": buttonName,
            "screen": screen
        ])
    }
    
    func trackError(_ error: Error, context: String) async {
        await trackEvent("error", parameters: [
            "error_description": error.localizedDescription,
            "context": context,
            "error_type": String(describing: type(of: error))
        ])
    }
    
    // MARK: - Performance Analytics
    func trackAppLaunchTime(_ launchTime: TimeInterval) async {
        await trackEvent("app_launch", parameters: [
            "launch_time": String(Int(launchTime * 1000)), // milliseconds
            "is_cold_start": "true" // Would determine this based on app state
        ])
    }
    
    func trackVideoLoadTime(_ videoId: String, loadTime: TimeInterval) async {
        await trackEvent("video_load_time", parameters: [
            "video_id": videoId,
            "load_time": String(Int(loadTime * 1000)) // milliseconds
        ])
    }
    
    // MARK: - Upload Events
    private func uploadQueuedEvents() async {
        guard !eventQueue.isEmpty else { return }
        
        let eventsToUpload = eventQueue
        eventQueue.removeAll()
        
        do {
            // In production, this would send to your analytics backend
            if !AppConfig.Features.enableMockData {
                let _: APIResponse<EmptyResponse> = try await networkService.post(
                    endpoint: .analytics,
                    body: AnalyticsUploadRequest(events: eventsToUpload),
                    responseType: APIResponse<EmptyResponse>.self
                )
            }
            
            if AppConfig.Features.enableNetworkLogging {
                print("📊 Uploaded \(eventsToUpload.count) analytics events")
            }
            
        } catch {
            // Re-queue events if upload fails
            eventQueue.append(contentsOf: eventsToUpload)
            
            if AppConfig.Features.enableNetworkLogging {
                print("❌ Failed to upload analytics events: \(error)")
            }
        }
    }
    
    // MARK: - Utilities
    private func isCriticalEvent(_ eventName: String) -> Bool {
        let criticalEvents = [
            "user_signup",
            "user_signin",
            "video_upload",
            "payment_completed",
            "error"
        ]
        return criticalEvents.contains(eventName)
    }
    
    // MARK: - Privacy & Data Management
    func clearAnalyticsData() async {
        eventQueue.removeAll()
        
        // Clear from local database
        do {
            // Would implement clearAnalyticsEvents in DatabaseService
            // try await databaseService.clearAnalyticsEvents()
        } catch {
            print("Failed to clear analytics data: \(error)")
        }
    }
    
    func setAnalyticsEnabled(_ enabled: Bool) {
        isEnabled = enabled
        
        if !enabled {
            Task {
                await clearAnalyticsData()
            }
        }
    }
    
    // MARK: - Analytics Dashboard Data
    func getAnalyticsSummary() async -> AnalyticsSummary {
        do {
            let events = try await databaseService.fetchAnalyticsEvents(limit: 1000)
            
            let videoViews = events.filter { $0.name == AppConfig.Analytics.videoWatchEvent }.count
            let likes = events.filter { $0.name == AppConfig.Analytics.videoLikeEvent }.count
            let shares = events.filter { $0.name == AppConfig.Analytics.videoShareEvent }.count
            let searches = events.filter { $0.name == AppConfig.Analytics.searchEvent }.count
            
            let sessionEvents = events.filter { $0.name == "session_start" }
            let averageSessionDuration = calculateAverageSessionDuration(from: events)
            
            return AnalyticsSummary(
                totalEvents: events.count,
                videoViews: videoViews,
                likes: likes,
                shares: shares,
                searches: searches,
                sessions: sessionEvents.count,
                averageSessionDuration: averageSessionDuration
            )
            
        } catch {
            return AnalyticsSummary(
                totalEvents: 0,
                videoViews: 0,
                likes: 0,
                shares: 0,
                searches: 0,
                sessions: 0,
                averageSessionDuration: 0
            )
        }
    }
    
    private func calculateAverageSessionDuration(from events: [AnalyticsEvent]) -> TimeInterval {
        let sessionStarts = events.filter { $0.name == "session_start" }
        let sessionEnds = events.filter { $0.name == "session_end" }
        
        guard !sessionStarts.isEmpty && !sessionEnds.isEmpty else { return 0 }
        
        var totalDuration: TimeInterval = 0
        var sessionCount = 0
        
        for sessionEnd in sessionEnds {
            if let durationString = sessionEnd.parameters["duration"],
               let duration = TimeInterval(durationString) {
                totalDuration += duration
                sessionCount += 1
            }
        }
        
        return sessionCount > 0 ? totalDuration / TimeInterval(sessionCount) : 0
    }
}

// MARK: - Supporting Models
struct AnalyticsUploadRequest: Codable {
    let events: [AnalyticsEvent]
    let timestamp: Date = Date()
    let appVersion: String = AppConfig.appVersion
    let environment: String = AppConfig.environment.rawValue
}

struct AnalyticsSummary {
    let totalEvents: Int
    let videoViews: Int
    let likes: Int
    let shares: Int
    let searches: Int
    let sessions: Int
    let averageSessionDuration: TimeInterval
    
    var averageSessionDurationFormatted: String {
        let minutes = Int(averageSessionDuration) / 60
        let seconds = Int(averageSessionDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - API Endpoint Extension
extension APIEndpoint {
    static let analytics = APIEndpoint.custom("/analytics/events")
}

// MARK: - Preview
#Preview("Analytics Service Status") {
    VStack(spacing: 20) {
        Text("Analytics Service")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                    .fontWeight(.medium)
                Spacer()
                Text(AnalyticsService.shared.isEnabled ? "Enabled" : "Disabled")
                    .foregroundColor(AnalyticsService.shared.isEnabled ? .green : .red)
            }
            
            HStack {
                Text("Session ID:")
                    .fontWeight(.medium)
                Spacer()
                Text(AnalyticsService.shared.sessionId.prefix(8) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration:")
                    .fontWeight(.medium)
                
                Text("User Analytics: \(AppConfig.Analytics.enableUserAnalytics ? "Enabled" : "Disabled")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Performance Monitoring: \(AppConfig.Analytics.enablePerformanceMonitoring ? "Enabled" : "Disabled")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Crash Reporting: \(AppConfig.Analytics.enableCrashReporting ? "Enabled" : "Disabled")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        
        Spacer()
    }
    .padding()
}