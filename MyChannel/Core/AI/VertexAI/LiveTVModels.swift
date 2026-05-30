// ⚡ PERFORMANCE: Extracted from LiveTVIntelligenceAgent.swift — independent compilation unit.
// All supporting data models compile in parallel with the 842-line main agent class.
import Foundation

// MARK: - Supporting Models

struct LiveTVContext {
    let timeOfDay: Int // Hour 0-23
    let dayOfWeek: Int // 1-7 (Sunday = 1)
    let deviceType: String
    let connectionQuality: ConnectionQuality
    
    static func current() -> LiveTVContext {
        let now = Date()
        return LiveTVContext(
            timeOfDay: Calendar.current.component(.hour, from: now),
            dayOfWeek: Calendar.current.component(.weekday, from: now),
            deviceType: "iphone",
            connectionQuality: NetworkOptimizer.shared.connectionQuality
        )
    }
}

struct LiveTVRecommendation: Identifiable {
    let id = UUID()
    let channel: LiveTVChannel
    let score: LiveTVScore
    let reason: String
    let rank: Int
    let aiConfidence: Double
    let predictedWatchTime: Double
    let matchedInterests: [String]
}

struct LiveTVScore {
    let categoryRelevance: Double
    let timeRelevance: Double
    let popularityScore: Double
    let qualityScore: Double
    let noveltyScore: Double
    let totalScore: Double
    let predictedWatchMinutes: Double
    let matchedInterests: [String]
}

struct TrendingChannel: Identifiable {
    let id = UUID()
    let channel: LiveTVChannel
    let trendingScore: Double
    let viewerGrowthPercent: Double
    let trendingReason: String
    var rank: Int
}

struct LiveTVForYouSection {
    let personalizedPicks: [LiveTVRecommendation]
    let trendingNow: [TrendingChannel]
    let becauseYouWatched: [BecauseYouWatchedItem]
    let perfectForRightNow: [TimeBasedPick]
    let aiInsight: String
}

struct BecauseYouWatchedItem: Identifiable {
    let id = UUID()
    let watchedChannel: LiveTVChannel
    let recommendedChannel: LiveTVChannel
    let similarity: Double
}

struct TimeBasedPick: Identifiable {
    let id = UUID()
    let channel: LiveTVChannel
    let timeLabel: String
    let reason: String
}

struct ContentAnalysis {
    let channelId: String
    let contentType: String
    let targetAudience: String
    let mood: String
    let bestTimeToWatch: String
    let similarChannels: [LiveTVChannel]
    let aiGeneratedDescription: String
    let confidence: Double
}

struct EngagementPrediction {
    let channelId: String
    let predictedWatchMinutes: Double
    let engagementScore: Double
    let willComplete: Bool
    let likelyToReturn: Bool
    let confidence: Double
}

struct ChannelSuggestion: Identifiable {
    let id = UUID()
    let channel: LiveTVChannel
    let reason: String
    let predictedEngagement: Double
    let switchType: SwitchType
    
    enum SwitchType {
        case similar
        case discovery
        case trending
    }
}

enum SwitchReason {
    case commercial
    case bored
    case manual
    case endOfContent
}

struct UserPreferences {
    let userId: String
    let preferredCategories: [LiveTVChannel.ChannelCategory]
    let avgWatchTimeByCategory: [LiveTVChannel.ChannelCategory: TimeInterval]
    let preferredTimeOfDay: Int
    let totalWatchEvents: Int
    let engagementLevel: EngagementLevel
}

enum EngagementLevel {
    case new
    case casual
    case regular
    case power
}

struct LiveTVWatchEvent {
    let userId: String
    let channelId: String
    let category: LiveTVChannel.ChannelCategory
    let watchDuration: TimeInterval
    let completed: Bool
    let timestamp: Date
    let timeOfDay: Int
    let dayOfWeek: Int
}

struct CachedRecommendation {
    let recommendations: [LiveTVRecommendation]
    let timestamp: Date
}

// Sub-models (stubs for ML models)
class UserPreferenceModel {}
class ContentUnderstandingModel {}
class TrendPredictionModel {}
class EngagementPredictionModel {}

