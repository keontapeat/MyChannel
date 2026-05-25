//
//  EnhancedAnalyticsManager.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

// 📊 Enhanced Analytics Manager
// Comprehensive analytics tracking for all user interactions
@MainActor
class EnhancedAnalyticsManager {
    static let shared = EnhancedAnalyticsManager()
    
    private var sessionStartTime: Date?
    private var currentScreen: String?
    private var userProperties: [String: String] = [:]
    
    private init() {
        startSession()
    }
    
    // MARK: - Session Management
    
    func startSession() {
        sessionStartTime = Date()
        logEvent("app_session_start", parameters: [
            "timestamp": Date().timeIntervalSince1970,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])
    }
    
    func endSession() {
        guard let startTime = sessionStartTime else { return }
        let sessionDuration = Date().timeIntervalSince(startTime)
        
        logEvent("app_session_end", parameters: [
            "session_duration": sessionDuration,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        sessionStartTime = nil
    }
    
    // MARK: - Screen Tracking
    
    func trackScreen(_ screenName: String, screenClass: String? = nil) {
        currentScreen = screenName
        
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
        #endif
        
        logEvent("screen_view", parameters: [
            "screen_name": screenName,
            "screen_class": screenClass ?? screenName,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Search Analytics
    
    func trackSearchQuery(query: String, scope: String, hasFilters: Bool, resultCount: Int, responseTime: Double) {
        logEvent("search_performed", parameters: [
            "search_query": query,
            "search_scope": scope,
            "has_filters": hasFilters,
            "result_count": resultCount,
            "response_time_ms": responseTime * 1000,
            "query_length": query.count,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackSearchResult(query: String, resultType: String, resultId: String, position: Int) {
        logEvent("search_result_clicked", parameters: [
            "search_query": query,
            "result_type": resultType,
            "result_id": resultId,
            "position": position,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackVoiceSearch(query: String, duration: Double, success: Bool) {
        logEvent("voice_search_used", parameters: [
            "query": query,
            "duration_seconds": duration,
            "success": success,
            "query_length": query.count,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackVisualSearch(success: Bool, processingTime: Double, textExtracted: String?) {
        logEvent("visual_search_used", parameters: [
            "success": success,
            "processing_time_ms": processingTime * 1000,
            "text_extracted": textExtracted ?? "",
            "text_length": textExtracted?.count ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Video Analytics
    
    func trackVideoView(videoId: String, title: String, creator: String, category: String, duration: Double) {
        logEvent("video_view", parameters: [
            "video_id": videoId,
            "video_title": title,
            "creator_id": creator,
            "category": category,
            "video_duration": duration,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackVideoProgress(videoId: String, watchTime: Double, totalDuration: Double, quality: String) {
        let progressPercent = (watchTime / totalDuration) * 100
        
        logEvent("video_progress", parameters: [
            "video_id": videoId,
            "watch_time": watchTime,
            "total_duration": totalDuration,
            "progress_percent": progressPercent,
            "quality": quality,
            "timestamp": Date().timeIntervalSince1970
        ])
        
        // Track milestone events
        if progressPercent >= 25 && progressPercent < 50 {
            logEvent("video_25_percent", parameters: ["video_id": videoId])
        } else if progressPercent >= 50 && progressPercent < 75 {
            logEvent("video_50_percent", parameters: ["video_id": videoId])
        } else if progressPercent >= 75 && progressPercent < 95 {
            logEvent("video_75_percent", parameters: ["video_id": videoId])
        } else if progressPercent >= 95 {
            logEvent("video_completed", parameters: ["video_id": videoId])
        }
    }
    
    func trackVideoInteraction(videoId: String, action: String, value: String? = nil) {
        logEvent("video_interaction", parameters: [
            "video_id": videoId,
            "action": action,
            "value": value ?? "",
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Stories Analytics
    
    func trackStoryView(storyId: String, creatorId: String, mediaType: String, viewDuration: Double) {
        logEvent("story_view", parameters: [
            "story_id": storyId,
            "creator_id": creatorId,
            "media_type": mediaType,
            "view_duration": viewDuration,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackStoryInteraction(storyId: String, action: String, value: String? = nil) {
        logEvent("story_interaction", parameters: [
            "story_id": storyId,
            "action": action,
            "value": value ?? "",
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackStoryCreation(storyId: String, mediaType: String, duration: Double, filters: [String]) {
        logEvent("story_created", parameters: [
            "story_id": storyId,
            "media_type": mediaType,
            "duration": duration,
            "filters_used": filters.joined(separator: ","),
            "filter_count": filters.count,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Live Streaming Analytics
    
    func trackLiveStreamStart(streamId: String, title: String, category: String) {
        logEvent("live_stream_started", parameters: [
            "stream_id": streamId,
            "title": title,
            "category": category,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackLiveStreamView(streamId: String, viewDuration: Double, peakViewers: Int) {
        logEvent("live_stream_viewed", parameters: [
            "stream_id": streamId,
            "view_duration": viewDuration,
            "peak_viewers": peakViewers,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackLiveChatMessage(streamId: String, messageLength: Int, hasEmojis: Bool) {
        logEvent("live_chat_message", parameters: [
            "stream_id": streamId,
            "message_length": messageLength,
            "has_emojis": hasEmojis,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Gaming Analytics
    
    func trackVSMatchStart(matchId: String, gameType: String, betAmount: Double?) {
        logEvent("vs_match_started", parameters: [
            "match_id": matchId,
            "game_type": gameType,
            "bet_amount": betAmount ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackVSMatchResult(matchId: String, result: String, winnings: Double?) {
        logEvent("vs_match_completed", parameters: [
            "match_id": matchId,
            "result": result,
            "winnings": winnings ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackTournamentParticipation(tournamentId: String, gameType: String, entryFee: Double?) {
        logEvent("tournament_joined", parameters: [
            "tournament_id": tournamentId,
            "game_type": gameType,
            "entry_fee": entryFee ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Monetization Analytics
    
    func trackSubscription(creatorId: String, tier: String, amount: Double) {
        logEvent("subscription_created", parameters: [
            "creator_id": creatorId,
            "tier": tier,
            "amount": amount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackTip(creatorId: String, amount: Double, message: String?) {
        logEvent("tip_sent", parameters: [
            "creator_id": creatorId,
            "amount": amount,
            "has_message": message != nil,
            "message_length": message?.count ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackPremiumUpgrade(tier: String, amount: Double, features: [String]) {
        logEvent("premium_upgrade", parameters: [
            "tier": tier,
            "amount": amount,
            "features": features.joined(separator: ","),
            "feature_count": features.count,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackAdView(adId: String, adType: String, duration: Double, skipped: Bool) {
        logEvent("ad_viewed", parameters: [
            "ad_id": adId,
            "ad_type": adType,
            "duration": duration,
            "skipped": skipped,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Social Analytics
    
    func trackComment(contentId: String, contentType: String, commentLength: Int, hasMedia: Bool) {
        logEvent("comment_posted", parameters: [
            "content_id": contentId,
            "content_type": contentType,
            "comment_length": commentLength,
            "has_media": hasMedia,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackLike(contentId: String, contentType: String, action: String) {
        logEvent("like_action", parameters: [
            "content_id": contentId,
            "content_type": contentType,
            "action": action, // "like" or "unlike"
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackShare(contentId: String, contentType: String, platform: String) {
        logEvent("content_shared", parameters: [
            "content_id": contentId,
            "content_type": contentType,
            "platform": platform,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Upload Analytics
    
    func trackUploadStart(contentType: String, fileSize: Int64, estimatedDuration: Double?) {
        logEvent("upload_started", parameters: [
            "content_type": contentType,
            "file_size_mb": Double(fileSize) / (1024 * 1024),
            "estimated_duration": estimatedDuration ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackUploadComplete(contentId: String, contentType: String, uploadDuration: Double, fileSize: Int64) {
        logEvent("upload_completed", parameters: [
            "content_id": contentId,
            "content_type": contentType,
            "upload_duration": uploadDuration,
            "file_size_mb": Double(fileSize) / (1024 * 1024),
            "upload_speed_mbps": (Double(fileSize) / (1024 * 1024)) / uploadDuration,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Error Analytics
    
    func trackError(error: Error, context: String, fatal: Bool = false) {
        logEvent("error_occurred", parameters: [
            "error_message": error.localizedDescription,
            "context": context,
            "fatal": fatal,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackAPIError(endpoint: String, statusCode: Int, errorMessage: String) {
        logEvent("api_error", parameters: [
            "endpoint": endpoint,
            "status_code": statusCode,
            "error_message": errorMessage,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - User Properties
    
    func setUserProperty(_ value: String, forName name: String) {
        userProperties[name] = value
        
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
    }
    
    func setUserId(_ userId: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserID(userId)
        #endif
        
        setUserProperty(userId, forName: "user_id")
    }
    
    func setUserTier(_ tier: String) {
        setUserProperty(tier, forName: "user_tier")
    }
    
    func setCreatorStatus(_ isCreator: Bool) {
        setUserProperty(isCreator ? "creator" : "viewer", forName: "user_type")
    }
    
    // MARK: - Custom Events
    
    func logEvent(_ name: String, parameters: [String: Any] = [:]) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
        #endif
        
        // Also log to console in debug mode
        #if DEBUG
        print("📊 [Analytics] \(name): \(parameters)")
        #endif
    }
    
    // MARK: - Batch Analytics
    
    func trackUserEngagement(sessionDuration: Double, screensViewed: Int, actionsPerformed: Int) {
        logEvent("user_engagement", parameters: [
            "session_duration": sessionDuration,
            "screens_viewed": screensViewed,
            "actions_performed": actionsPerformed,
            "engagement_rate": Double(actionsPerformed) / sessionDuration,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackContentDiscovery(source: String, contentType: String, contentId: String, position: Int?) {
        logEvent("content_discovered", parameters: [
            "discovery_source": source,
            "content_type": contentType,
            "content_id": contentId,
            "position": position ?? -1,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackFeatureUsage(feature: String, usageCount: Int, lastUsed: Date) {
        logEvent("feature_usage", parameters: [
            "feature_name": feature,
            "usage_count": usageCount,
            "last_used": lastUsed.timeIntervalSince1970,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
}
