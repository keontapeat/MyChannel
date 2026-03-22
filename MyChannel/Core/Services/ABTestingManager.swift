//
//  ABTestingManager.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import Foundation

#if canImport(FirebaseABTesting)
import FirebaseABTesting
#endif

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

// 🧪 Firebase A/B Testing Manager
// Manages experiments and feature rollouts
@MainActor
class ABTestingManager: ObservableObject {
    static let shared = ABTestingManager()
    
    @Published var activeExperiments: [String: String] = [:]
    @Published var isConfigured = false
    
    // Experiment keys
    struct ExperimentKeys {
        static let searchUIVariant = "search_ui_variant"
        static let videoPlayerLayout = "video_player_layout"
        static let storiesFormat = "stories_format"
        static let recommendationAlgorithm = "recommendation_algorithm"
        static let monetizationFlow = "monetization_flow"
        static let onboardingFlow = "onboarding_flow"
        static let feedLayout = "feed_layout"
        static let uploadFlow = "upload_flow"
        static let commentSystem = "comment_system"
        static let notificationStyle = "notification_style"
    }
    
    private init() {
        configure()
    }
    
    // MARK: - Configuration
    
    func configure() {
        #if canImport(FirebaseABTesting)
        // A/B Testing is automatically configured with Firebase
        isConfigured = true
        loadActiveExperiments()
        #endif
    }
    
    private func loadActiveExperiments() {
        // Load all active experiments
        let experimentKeys = [
            ExperimentKeys.searchUIVariant,
            ExperimentKeys.videoPlayerLayout,
            ExperimentKeys.storiesFormat,
            ExperimentKeys.recommendationAlgorithm,
            ExperimentKeys.monetizationFlow,
            ExperimentKeys.onboardingFlow,
            ExperimentKeys.feedLayout,
            ExperimentKeys.uploadFlow,
            ExperimentKeys.commentSystem,
            ExperimentKeys.notificationStyle
        ]
        
        for key in experimentKeys {
            let variant = getExperimentVariant(key)
            if !variant.isEmpty {
                activeExperiments[key] = variant
            }
        }
        
        print("🧪 [ABTesting] Loaded \(activeExperiments.count) active experiments")
    }
    
    // MARK: - Experiment Variants
    
    func getExperimentVariant(_ experimentKey: String) -> String {
        #if canImport(FirebaseABTesting)
        // Get variant from Remote Config (A/B Testing uses Remote Config)
        let variant = RemoteConfigManager.shared.getString(for: experimentKey)
        
        // Log experiment participation
        if !variant.isEmpty {
            logExperimentParticipation(experimentKey, variant: variant)
        }
        
        return variant
        #else
        return getDefaultVariant(for: experimentKey)
        #endif
    }
    
    private func getDefaultVariant(for experimentKey: String) -> String {
        switch experimentKey {
        case ExperimentKeys.searchUIVariant:
            return "control"
        case ExperimentKeys.videoPlayerLayout:
            return "standard"
        case ExperimentKeys.storiesFormat:
            return "instagram_style"
        case ExperimentKeys.recommendationAlgorithm:
            return "collaborative_filtering"
        case ExperimentKeys.monetizationFlow:
            return "standard"
        case ExperimentKeys.onboardingFlow:
            return "step_by_step"
        case ExperimentKeys.feedLayout:
            return "grid"
        case ExperimentKeys.uploadFlow:
            return "simple"
        case ExperimentKeys.commentSystem:
            return "threaded"
        case ExperimentKeys.notificationStyle:
            return "standard"
        default:
            return "control"
        }
    }
    
    // MARK: - Specific Experiment Getters
    
    var searchUIVariant: SearchUIVariant {
        let variant = getExperimentVariant(ExperimentKeys.searchUIVariant)
        return SearchUIVariant(rawValue: variant) ?? .control
    }
    
    var videoPlayerLayout: VideoPlayerLayout {
        let variant = getExperimentVariant(ExperimentKeys.videoPlayerLayout)
        return VideoPlayerLayout(rawValue: variant) ?? .standard
    }
    
    var storiesFormat: StoriesFormat {
        let variant = getExperimentVariant(ExperimentKeys.storiesFormat)
        return StoriesFormat(rawValue: variant) ?? .instagramStyle
    }
    
    var recommendationAlgorithm: RecommendationAlgorithm {
        let variant = getExperimentVariant(ExperimentKeys.recommendationAlgorithm)
        return RecommendationAlgorithm(rawValue: variant) ?? .collaborativeFiltering
    }
    
    var monetizationFlow: MonetizationFlow {
        let variant = getExperimentVariant(ExperimentKeys.monetizationFlow)
        return MonetizationFlow(rawValue: variant) ?? .standard
    }
    
    var onboardingFlow: OnboardingFlow {
        let variant = getExperimentVariant(ExperimentKeys.onboardingFlow)
        return OnboardingFlow(rawValue: variant) ?? .stepByStep
    }
    
    var feedLayout: FeedLayout {
        let variant = getExperimentVariant(ExperimentKeys.feedLayout)
        return FeedLayout(rawValue: variant) ?? .grid
    }
    
    var uploadFlow: UploadFlow {
        let variant = getExperimentVariant(ExperimentKeys.uploadFlow)
        return UploadFlow(rawValue: variant) ?? .simple
    }
    
    var commentSystem: CommentSystem {
        let variant = getExperimentVariant(ExperimentKeys.commentSystem)
        return CommentSystem(rawValue: variant) ?? .threaded
    }
    
    var notificationStyle: NotificationStyle {
        let variant = getExperimentVariant(ExperimentKeys.notificationStyle)
        return NotificationStyle(rawValue: variant) ?? .standard
    }
    
    // MARK: - Analytics Integration
    
    private func logExperimentParticipation(_ experimentKey: String, variant: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("experiment_participation", parameters: [
            "experiment_key": experimentKey,
            "variant": variant,
            "timestamp": Date().timeIntervalSince1970
        ])
        #endif
        
        print("🧪 [ABTesting] User in experiment '\(experimentKey)' with variant '\(variant)'")
    }
    
    func logExperimentConversion(_ experimentKey: String, conversionType: String, value: Double? = nil) {
        guard let variant = activeExperiments[experimentKey] else { return }
        
        #if canImport(FirebaseAnalytics)
        var parameters: [String: Any] = [
            "experiment_key": experimentKey,
            "variant": variant,
            "conversion_type": conversionType,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let value = value {
            parameters["value"] = value
        }
        
        Analytics.logEvent("experiment_conversion", parameters: parameters)
        #endif
        
        print("🎯 [ABTesting] Conversion logged for '\(experimentKey)' variant '\(variant)': \(conversionType)")
    }
    
    // MARK: - Experiment Utilities
    
    func isInExperiment(_ experimentKey: String) -> Bool {
        return activeExperiments[experimentKey] != nil
    }
    
    func isInVariant(_ experimentKey: String, variant: String) -> Bool {
        return activeExperiments[experimentKey] == variant
    }
    
    func getAllActiveExperiments() -> [String: String] {
        return activeExperiments
    }
    
    // Force refresh experiments (useful for testing)
    func refreshExperiments() async {
        await RemoteConfigManager.shared.fetchAndActivate()
        loadActiveExperiments()
    }
}

// MARK: - Experiment Variant Enums

enum SearchUIVariant: String, CaseIterable {
    case control = "control"
    case enhanced = "enhanced"
    case minimal = "minimal"
    case aiFirst = "ai_first"
}

enum VideoPlayerLayout: String, CaseIterable {
    case standard = "standard"
    case theater = "theater"
    case immersive = "immersive"
    case compact = "compact"
}

enum StoriesFormat: String, CaseIterable {
    case instagramStyle = "instagram_style"
    case snapchatStyle = "snapchat_style"
    case youtubeShorts = "youtube_shorts"
    case tiktokStyle = "tiktok_style"
}

enum RecommendationAlgorithm: String, CaseIterable {
    case collaborativeFiltering = "collaborative_filtering"
    case contentBased = "content_based"
    case hybrid = "hybrid"
    case aiPowered = "ai_powered"
}

enum MonetizationFlow: String, CaseIterable {
    case standard = "standard"
    case simplified = "simplified"
    case gamified = "gamified"
    case subscription_first = "subscription_first"
}

enum OnboardingFlow: String, CaseIterable {
    case stepByStep = "step_by_step"
    case interactive = "interactive"
    case minimal = "minimal"
    case personalized = "personalized"
}

enum FeedLayout: String, CaseIterable {
    case grid = "grid"
    case list = "list"
    case masonry = "masonry"
    case carousel = "carousel"
}

enum UploadFlow: String, CaseIterable {
    case simple = "simple"
    case advanced = "advanced"
    case guided = "guided"
    case bulk = "bulk"
}

enum CommentSystem: String, CaseIterable {
    case threaded = "threaded"
    case flat = "flat"
    case reactions = "reactions"
    case minimal = "minimal"
}

enum NotificationStyle: String, CaseIterable {
    case standard = "standard"
    case rich = "rich"
    case minimal = "minimal"
    case interactive = "interactive"
}

// MARK: - Experiment Tracking Extensions

extension ABTestingManager {
    
    // Track search experiment conversions
    func trackSearchConversion(type: SearchConversionType, query: String? = nil) {
        logExperimentConversion(ExperimentKeys.searchUIVariant, conversionType: type.rawValue)
    }
    
    // Track video player experiment conversions
    func trackVideoPlayerConversion(type: VideoPlayerConversionType, watchTime: Double? = nil) {
        logExperimentConversion(ExperimentKeys.videoPlayerLayout, conversionType: type.rawValue, value: watchTime)
    }
    
    // Track monetization experiment conversions
    func trackMonetizationConversion(type: MonetizationConversionType, amount: Double? = nil) {
        logExperimentConversion(ExperimentKeys.monetizationFlow, conversionType: type.rawValue, value: amount)
    }
    
    // Track onboarding experiment conversions
    func trackOnboardingConversion(type: OnboardingConversionType, step: Int? = nil) {
        logExperimentConversion(ExperimentKeys.onboardingFlow, conversionType: type.rawValue, value: Double(step ?? 0))
    }
}

// MARK: - Conversion Type Enums

enum SearchConversionType: String {
    case querySubmitted = "query_submitted"
    case resultClicked = "result_clicked"
    case filterApplied = "filter_applied"
    case voiceSearchUsed = "voice_search_used"
    case visualSearchUsed = "visual_search_used"
}

enum VideoPlayerConversionType: String {
    case videoStarted = "video_started"
    case videoCompleted = "video_completed"
    case pipActivated = "pip_activated"
    case qualityChanged = "quality_changed"
    case fullscreenToggled = "fullscreen_toggled"
}

enum MonetizationConversionType: String {
    case subscriptionStarted = "subscription_started"
    case tipSent = "tip_sent"
    case premiumUpgrade = "premium_upgrade"
    case adWatched = "ad_watched"
    case purchaseCompleted = "purchase_completed"
}

enum OnboardingConversionType: String {
    case stepCompleted = "step_completed"
    case onboardingCompleted = "onboarding_completed"
    case profileCreated = "profile_created"
    case firstVideoUploaded = "first_video_uploaded"
    case firstSubscription = "first_subscription"
}
