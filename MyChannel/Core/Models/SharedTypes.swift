import SwiftUI
import Foundation

// MARK: - Missing Types Definition
enum DurationRange {
    case short, medium, long
    
    static func from(seconds: TimeInterval) -> DurationRange {
        if seconds < 1800 { return .short }
        else if seconds < 5400 { return .medium }
        else { return .long }
    }
}

enum DeviceType: String, CaseIterable, Codable {
    case mobile = "mobile"
    case tablet = "tablet"
    case tv = "tv"
    case desktop = "desktop"
}

// MARK: - Centralized Search Types
struct MyChannelSearchResult: Identifiable {
    let id: String
    let content: Video // Use Video instead of UniversalContent for now
    let relevanceScore: Double
    let matchType: MatchType
    let highlightedFields: [String]
    let searchReason: String
    
    enum MatchType {
        case textMatch, semanticMatch, visualMatch, audioMatch, aiMatch
    }
}

struct MyChannelSearchFilters {
    var genre: String?
    var year: Int?
    var duration: DurationRange?
    var quality: String?
    var source: String? // Use String instead of ContentSource for now
    var rating: String?
    var language: String?
}

struct MyChannelSearchAnalytics {
    var totalSearches: Int = 0
    var averageResultsPerSearch: Double = 0.0
    var mostPopularQueries: [String] = []
    var searchSuccessRate: Double = 0.0
}

// MARK: - Centralized User Profile Types
struct MyChannelUserProfile {
    let userId: String
    var favoriteGenres: [String] = []
    var viewingTimes: [Int] = []
    var deviceTypes: [DeviceType] = []
    var subscriptionTier: String = "Free"
    var preferences: [String] = []
}

struct SmartAIUserPreferences {
    let favoriteGenres: [VideoCategory]
    let preferredDuration: DurationPreference
    let watchTime: WatchTimePreference
    let deviceType: DeviceType
    
    enum DurationPreference {
        case short, medium, long
    }
    
    enum WatchTimePreference {
        case morning, afternoon, evening, night
    }
}

// MARK: - AI Insights Types
struct MyChannelAIInsights {
    var watchTimeToday: TimeInterval = 0
    var favoriteGenre: String = "Action"
    var bingeProbability: Double = 0.7
    var moodPrediction: String = "Adventurous"
    var recommendationAccuracy: Double = 0.89
}

#Preview {
    VStack {
        Text("🎯 Centralized Types")
            .font(.title.bold())
        Text("Unified data models for MyChannel")
            .font(.caption)
    }
}