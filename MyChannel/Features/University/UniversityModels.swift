//
//  UniversityModels.swift
//  MyChannel
//
//  Data Models for MyChannel University
//  Created for MyChannel by AI Assistant
//

import Foundation
import SwiftUI

// MARK: - Subject Category
enum SubjectCategory: String, CaseIterable, Identifiable, Codable {
    case technology = "Technology"
    case business = "Business"
    case creative = "Creative"
    case science = "Science"
    case health = "Health & Fitness"
    case lifestyle = "Lifestyle"
    case education = "Education"
    case trades = "Skilled Trades"
    case language = "Languages"
    case finance = "Finance"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .technology: return "desktopcomputer"
        case .business: return "briefcase.fill"
        case .creative: return "paintbrush.fill"
        case .science: return "atom"
        case .health: return "heart.fill"
        case .lifestyle: return "star.fill"
        case .education: return "book.fill"
        case .trades: return "hammer.fill"
        case .language: return "globe"
        case .finance: return "dollarsign.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .technology: return .blue
        case .business: return .purple
        case .creative: return .pink
        case .science: return .green
        case .health: return .red
        case .lifestyle: return .orange
        case .education: return .indigo
        case .trades: return .brown
        case .language: return .cyan
        case .finance: return Color(red: 0.0, green: 0.7, blue: 0.4)
        }
    }
}

// MARK: - University Subject
struct UniversitySubject: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let category: SubjectCategory
    let icon: String
    let color: Color
    let videosCount: Int
    let learnerCount: Int
    let totalHours: Double
    let difficulty: Difficulty
    let tags: [String]
    
    enum Difficulty: String, Codable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
    }
}

// MARK: - Learning Path
struct LearningPath: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let category: SubjectCategory
    let icon: String
    let color: Color
    let videosCount: Int
    let estimatedHours: Int
    let subjects: [String] // Subject IDs
    var progress: Double // 0.0 - 1.0
    let difficulty: UniversitySubject.Difficulty
    let certificateId: String?
}

// MARK: - Certificate
struct Certificate: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let category: SubjectCategory
    let color: Color
    let requiredHours: Int
    let requiredVideos: Int
    let requiredSubjects: [String]
    var progress: Double // 0.0 - 1.0
    var isEarned: Bool
    var earnedDate: Date?
    let verificationHash: String? // Blockchain verification
    let aiVerificationScore: Int // 0-100
}

// MARK: - Learning Activity
struct LearningActivity: Identifiable, Codable {
    let id: String
    let type: ActivityType
    let title: String
    let subjectId: String?
    let timestamp: Date
    let duration: TimeInterval // in seconds
    let aiVerified: Bool
    
    enum ActivityType: String, Codable {
        case videoWatched = "video_watched"
        case pathStarted = "path_started"
        case pathCompleted = "path_completed"
        case certificateEarned = "certificate_earned"
        case milestoneReached = "milestone_reached"
        case streakMaintained = "streak_maintained"
        case goalAchieved = "goal_achieved"
    }
    
    var icon: String {
        switch type {
        case .videoWatched: return "play.circle.fill"
        case .pathStarted: return "flag.fill"
        case .pathCompleted: return "checkmark.circle.fill"
        case .certificateEarned: return "medal.fill"
        case .milestoneReached: return "star.fill"
        case .streakMaintained: return "flame.fill"
        case .goalAchieved: return "trophy.fill"
        }
    }
    
    var color: Color {
        switch type {
        case .videoWatched: return .blue
        case .pathStarted: return .green
        case .pathCompleted: return .purple
        case .certificateEarned: return .yellow
        case .milestoneReached: return .orange
        case .streakMaintained: return .red
        case .goalAchieved: return Color(red: 1.0, green: 0.8, blue: 0.0)
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Badge
struct Badge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let requirement: String
    var isEarned: Bool
    var earnedDate: Date?
    let points: Int
}

// MARK: - Milestone
struct Milestone: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let requirement: Int
    var progress: Int
    var isCompleted: Bool
    let points: Int
    let reward: String?
}

// MARK: - Learner (for leaderboard)
struct Learner: Identifiable, Codable {
    let id: String
    let name: String
    let avatarURL: String
    let rank: Int
    let points: Int
    let certificates: Int
    let watchHours: Int
    let currentStreak: Int
}

// MARK: - Learning Streak
struct LearningStreak: Identifiable, Codable {
    let id: String
    let userId: String
    let subjectId: String?
    var currentStreak: Int // Days
    var longestStreak: Int
    var lastActivityDate: Date
    var dailyGoalHours: Double
    var todayProgress: Double // Hours watched today
    var weeklyGoalHours: Double
    var weekProgress: Double // Hours watched this week
    var monthlyGoalHours: Double
    var monthProgress: Double // Hours watched this month
    
    var dailyGoalMet: Bool {
        todayProgress >= dailyGoalHours
    }
    
    var weeklyGoalMet: Bool {
        weekProgress >= weeklyGoalHours
    }
    
    var monthlyGoalMet: Bool {
        monthProgress >= monthlyGoalHours
    }
    
    var streakBroken: Bool {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        return !calendar.isDate(lastActivityDate, inSameDayAs: Date()) &&
               !calendar.isDate(lastActivityDate, inSameDayAs: yesterday)
    }
}

// MARK: - Learning Goal
struct LearningGoal: Identifiable, Codable {
    let id: String
    let userId: String
    let title: String
    let description: String
    let subjectId: String?
    let category: SubjectCategory?
    let targetHours: Double
    var currentHours: Double
    let targetDate: Date
    let createdDate: Date
    var isCompleted: Bool
    let reward: GoalReward?
    
    var progress: Double {
        min(currentHours / targetHours, 1.0)
    }
    
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
    }
    
    var hoursPerDayNeeded: Double {
        let remaining = targetHours - currentHours
        return max(remaining / Double(max(daysRemaining, 1)), 0)
    }
    
    struct GoalReward: Codable {
        let type: RewardType
        let value: Int
        
        enum RewardType: String, Codable {
            case points = "points"
            case badge = "badge"
            case certificate = "certificate"
            case customBadge = "custom_badge"
        }
    }
}

// MARK: - User Learning Profile
struct UserLearningProfile: Codable {
    let userId: String
    var totalWatchHours: Double
    var videosCompleted: Int
    var subjectsStudied: Int
    var certificatesEarned: Int
    var currentLevel: Int
    var totalPoints: Int
    var globalRank: Int
    var verificationScore: Int // AI verification 0-100
    var streaks: [LearningStreak]
    var activeGoals: [LearningGoal]
    var completedGoals: [LearningGoal]
    var badges: [Badge]
    var activePaths: [String] // Learning Path IDs
    var completedPaths: [String]
    var recentActivity: [LearningActivity]
    
    var currentStreak: Int {
        streaks.first?.currentStreak ?? 0
    }
    
    var longestStreak: Int {
        streaks.map(\.longestStreak).max() ?? 0
    }
    
    var todayGoalMet: Bool {
        streaks.first?.dailyGoalMet ?? false
    }
}

// MARK: - AI Verification Result
struct AIVerificationResult: Codable {
    let videoId: String
    let userId: String
    let watchDuration: TimeInterval
    let completionPercentage: Double
    let contentRelevance: Double // 0.0 - 1.0
    let engagementScore: Double // 0.0 - 1.0
    let knowledgeRetention: Double // 0.0 - 1.0 (based on quiz/interaction)
    let overallScore: Int // 0-100
    let verified: Bool
    let verificationTimestamp: Date
    let aiModel: String // "GPT-5" or "Claude-4.5"
    
    var isValidForCertificate: Bool {
        verified && overallScore >= 70 && completionPercentage >= 0.8
    }
}

// MARK: - Watch Session
struct UniversityWatchSession: Codable {
    let id: String
    let userId: String
    let videoId: String
    let subjectId: String?
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var completionPercentage: Double
    var qualityScore: Double // Did user actually watch or just have it running?
    var interactionCount: Int // Pauses, rewinds, etc
    var aiVerificationResult: AIVerificationResult?
    
    var isQualityWatch: Bool {
        qualityScore >= 0.7 && completionPercentage >= 0.7
    }
}

// MARK: - Codable Extensions for Color
extension Color: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let r = try container.decode(Double.self, forKey: .red)
        let g = try container.decode(Double.self, forKey: .green)
        let b = try container.decode(Double.self, forKey: .blue)
        let o = try container.decode(Double.self, forKey: .opacity)
        self.init(red: r, green: g, blue: b, opacity: o)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        guard let components = UIColor(self).cgColor.components else { return }
        try container.encode(components[0], forKey: .red)
        try container.encode(components[1], forKey: .green)
        try container.encode(components[2], forKey: .blue)
        try container.encode(components[3], forKey: .opacity)
    }
}

