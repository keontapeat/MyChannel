//
//  RemoteConfigManager.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation

#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

enum ConfigFetchStatus {
    case noFetchYet
    case success
    case failure
}

// 🎛️ Firebase Remote Config Manager
// Manages feature flags and remote configuration
@MainActor
class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()
    
    @Published var isConfigured = false
    @Published var lastFetchTime: Date?
    @Published var fetchStatus: ConfigFetchStatus = .noFetchYet
    
    #if canImport(FirebaseRemoteConfig)
    private lazy var remoteConfig = RemoteConfig.remoteConfig()
    #endif

    // Default configuration values
    private let defaults: [String: NSObject] = [
        // Search Features
        "search_suggestions_enabled": true as NSObject,
        "ai_search_enabled": true as NSObject,
        "voice_search_enabled": true as NSObject,
        "visual_search_enabled": true as NSObject,
        "max_search_results": 50 as NSObject,
        "search_debounce_ms": 300 as NSObject,
        
        // Video Features
        "pip_enabled": true as NSObject,
        "background_play_enabled": true as NSObject,
        "auto_play_enabled": true as NSObject,
        "quality_auto_adjust": true as NSObject,
        "max_video_quality": "4K" as NSObject,
        
        // Stories Features
        "stories_enabled": true as NSObject,
        "story_duration_seconds": 15 as NSObject,
        "max_story_length": 30 as NSObject,
        "story_reactions_enabled": true as NSObject,
        
        // Live Streaming
        "live_streaming_enabled": true as NSObject,
        "live_chat_enabled": true as NSObject,
        "super_chat_enabled": true as NSObject,
        "live_polls_enabled": true as NSObject,
        
        // Gaming & VS Matches — OFF until 5.3 licensing clears
        "vs_matches_enabled": false as NSObject,
        "tournaments_enabled": false as NSObject,
        "gaming_leaderboards_enabled": true as NSObject,
        
        // Monetization — viewer tips / real-money off for App Review
        "creator_monetization_enabled": false as NSObject,
        "fan_funding_enabled": false as NSObject,
        "premium_subscriptions_enabled": true as NSObject,
        "ad_revenue_sharing": 0.7 as NSObject,
        
        // ML & AI Features
        "content_moderation_enabled": true as NSObject,
        "ai_thumbnails_enabled": true as NSObject,
        "sentiment_analysis_enabled": true as NSObject,
        "recommendation_engine_enabled": true as NSObject,
        "ml_enhancement_enabled": true as NSObject,
        
        // Performance
        "max_concurrent_uploads": 3 as NSObject,
        "cache_duration_hours": 24 as NSObject,
        "preload_next_videos": 2 as NSObject,
        
        // UI/UX
        "dark_mode_default": false as NSObject,
        "haptic_feedback_enabled": true as NSObject,
        "animations_enabled": true as NSObject,
        "beta_features_enabled": false as NSObject,
        
        // Safety & Security
        "content_filtering_level": "moderate" as NSObject,
        "age_verification_required": true as NSObject,
        "coppa_compliance_enabled": true as NSObject,
        
        // Analytics
        "analytics_enabled": true as NSObject,
        "crash_reporting_enabled": true as NSObject,
        "performance_monitoring_enabled": true as NSObject
    ]
    
    private init() {
        configure()
    }
    
    // MARK: - Configuration
    
    func configure() {
        #if canImport(FirebaseRemoteConfig)
        guard FirebaseManager.shared.isConfigured else {
            isConfigured = false
            return
        }

        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600 // 1 hour in production
        #if DEBUG
        settings.minimumFetchInterval = 0 // No throttling in debug
        #endif

        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(defaults)

        isConfigured = true

        // Fetch initial configuration
        Task {
            await fetchAndActivate()
        }
        #endif
    }

    // MARK: - Fetch Configuration

    func fetchAndActivate() async {
        #if canImport(FirebaseRemoteConfig)
        guard isConfigured else { return }

        do {
            let status = try await remoteConfig.fetchAndActivate()
            fetchStatus = .success
            lastFetchTime = Date()

            print("✅ [RemoteConfig] Fetch completed with status: \(status)")

            // Log important config changes
            logConfigChanges()
        } catch {
            print("🚨 [RemoteConfig] Fetch failed: \(error)")
            fetchStatus = .failure
        }
        #endif
    }

    func fetch() async {
        #if canImport(FirebaseRemoteConfig)
        guard isConfigured else { return }

        do {
            try await remoteConfig.fetch()
            lastFetchTime = Date()
        } catch {
            print("🚨 [RemoteConfig] Fetch failed: \(error)")
        }
        #endif
    }

    func activate() async -> Bool {
        #if canImport(FirebaseRemoteConfig)
        guard isConfigured else { return false }

        do {
            return try await remoteConfig.activate()
        } catch {
            print("🚨 [RemoteConfig] Activate failed: \(error)")
            return false
        }
        #else
        return false
        #endif
    }
    
    // MARK: - Configuration Getters
    
    // Search Configuration
    var isSearchSuggestionsEnabled: Bool {
        getBool(for: "search_suggestions_enabled")
    }
    
    var isAISearchEnabled: Bool {
        getBool(for: "ai_search_enabled")
    }
    
    var isVoiceSearchEnabled: Bool {
        getBool(for: "voice_search_enabled")
    }
    
    var isVisualSearchEnabled: Bool {
        getBool(for: "visual_search_enabled")
    }
    
    var maxSearchResults: Int {
        getInt(for: "max_search_results")
    }
    
    var searchDebounceMs: Int {
        getInt(for: "search_debounce_ms")
    }
    
    // Video Configuration
    var isPiPEnabled: Bool {
        getBool(for: "pip_enabled")
    }
    
    var isBackgroundPlayEnabled: Bool {
        getBool(for: "background_play_enabled")
    }
    
    var isAutoPlayEnabled: Bool {
        getBool(for: "auto_play_enabled")
    }
    
    var maxVideoQuality: String {
        getString(for: "max_video_quality")
    }
    
    // Stories Configuration
    var isStoriesEnabled: Bool {
        getBool(for: "stories_enabled")
    }
    
    var storyDurationSeconds: Int {
        getInt(for: "story_duration_seconds")
    }
    
    var maxStoryLength: Int {
        getInt(for: "max_story_length")
    }
    
    // Gaming Configuration
    var isVSMatchesEnabled: Bool {
        getBool(for: "vs_matches_enabled")
    }
    
    var isTournamentsEnabled: Bool {
        getBool(for: "tournaments_enabled")
    }
    
    // Monetization Configuration
    var isCreatorMonetizationEnabled: Bool {
        getBool(for: "creator_monetization_enabled")
    }
    
    var adRevenueSharing: Double {
        getDouble(for: "ad_revenue_sharing")
    }
    
    // AI Features Configuration
    var isContentModerationEnabled: Bool {
        getBool(for: "content_moderation_enabled")
    }
    
    var isRecommendationEngineEnabled: Bool {
        getBool(for: "recommendation_engine_enabled")
    }
    
    // UI/UX Configuration
    var isHapticFeedbackEnabled: Bool {
        getBool(for: "haptic_feedback_enabled")
    }
    
    var isBetaFeaturesEnabled: Bool {
        getBool(for: "beta_features_enabled")
    }
    
    // Performance Configuration
    var maxConcurrentUploads: Int {
        getInt(for: "max_concurrent_uploads")
    }
    
    var cacheDurationHours: Int {
        getInt(for: "cache_duration_hours")
    }
    
    // MARK: - Generic Getters

    private func getBool(for key: String) -> Bool {
        #if canImport(FirebaseRemoteConfig)
        guard isConfigured else { return defaults[key] as? Bool ?? false }
        return remoteConfig.configValue(forKey: key).boolValue
        #else
        return defaults[key] as? Bool ?? false
        #endif
    }

    func getString(for key: String) -> String {
        #if canImport(FirebaseRemoteConfig)
        guard isConfigured else { return defaults[key] as? String ?? "" }
        return remoteConfig.configValue(forKey: key).stringValue ?? ""
        #else
        return defaults[key] as? String ?? ""
        #endif
    }

    private func getInt(for key: String) -> Int {
        #if canImport(FirebaseRemoteConfig)
        guard isConfigured else { return defaults[key] as? Int ?? 0 }
        return Int(remoteConfig.configValue(forKey: key).numberValue.intValue)
        #else
        return defaults[key] as? Int ?? 0
        #endif
    }

    private func getDouble(for key: String) -> Double {
        #if canImport(FirebaseRemoteConfig)
        guard isConfigured else { return defaults[key] as? Double ?? 0.0 }
        return remoteConfig.configValue(forKey: key).numberValue.doubleValue
        #else
        return defaults[key] as? Double ?? 0.0
        #endif
    }

    // MARK: - Utilities

    private func logConfigChanges() {
        let importantKeys = [
            "ai_search_enabled",
            "pip_enabled",
            "vs_matches_enabled",
            "creator_monetization_enabled",
            "beta_features_enabled"
        ]

        for key in importantKeys {
            let value = getBool(for: key)
            print("🎛️ [RemoteConfig] \(key): \(value)")
        }
    }

    // Get all current configuration as dictionary
    func getAllConfig() -> [String: Any] {
        #if canImport(FirebaseRemoteConfig)
        guard isConfigured else { return defaults.mapValues { $0 as Any } }
        #endif

        var config: [String: Any] = [:]

        for (key, _) in defaults {
            #if canImport(FirebaseRemoteConfig)
            let configValue = remoteConfig.configValue(forKey: key)
            switch configValue.source {
            case .static:
                config[key] = "default"
            case .default:
                config[key] = "default"
            case .remote:
                config[key] = configValue.stringValue
            @unknown default:
                config[key] = "unknown"
            }
            #else
            config[key] = defaults[key]
            #endif
        }

        return config
    }
}

// MARK: - Feature Flag Extensions

extension RemoteConfigManager {

    // Check if a feature is enabled with fallback
    func isFeatureEnabled(_ feature: String, fallback: Bool = false) -> Bool {
        #if canImport(FirebaseRemoteConfig)
        guard isConfigured else { return defaults[feature] as? Bool ?? fallback }

        let configValue = remoteConfig.configValue(forKey: feature)
        if configValue.source == .static {
            return fallback
        }
        return configValue.boolValue
        #else
        return defaults[feature] as? Bool ?? fallback
        #endif
    }

    // Get feature configuration with type safety
    func getFeatureConfig<T>(_ feature: String, type: T.Type, fallback: T) -> T {
        #if canImport(FirebaseRemoteConfig)
        guard isConfigured else { return defaults[feature] as? T ?? fallback }

        let configValue = remoteConfig.configValue(forKey: feature)

        switch type {
        case is Bool.Type:
            return configValue.boolValue as? T ?? fallback
        case is String.Type:
            return configValue.stringValue as? T ?? fallback
        case is Int.Type:
            return configValue.numberValue.intValue as? T ?? fallback
        case is Double.Type:
            return configValue.numberValue.doubleValue as? T ?? fallback
        default:
            return fallback
        }
        #else
        return defaults[feature] as? T ?? fallback
        #endif
    }

    // ML Enhancement feature flag
    var isMLEnhancementEnabled: Bool {
        isFeatureEnabled("ml_enhancement_enabled", fallback: true)
    }
}
