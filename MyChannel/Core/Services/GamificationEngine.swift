//
//  GamificationEngine.swift
//  MyChannel
//
//  🎮 GAMIFICATION ENGINE - MAKE IT FUN & ADDICTIVE!
//  Points, badges, levels, streaks - YouTube doesn't have THIS! 🔥
//

import Foundation
import FirebaseFirestore

@MainActor
class GamificationEngine: ObservableObject {
    static let shared = GamificationEngine()
    
    @Published var totalXP: Int = 0
    @Published var currentLevel: Int = 1
    @Published var badges: [Badge] = []
    @Published var dailyStreak: Int = 0
    
    private let db = Firestore.firestore()
    private var userProfiles: [String: UserGameProfile] = [:]
    
    private init() {}
    
    // MARK: - 🎯 XP SYSTEM
    
    /// Award XP for various actions
    func awardXP(_ amount: Int, to userId: String, for action: GameAction) async throws {
        print("⭐ [Gamification] Awarding \(amount) XP for \(action.rawValue)")
        
        var profile = try await getUserProfile(userId)
        
        // Add XP
        profile.xp += amount
        totalXP = profile.xp
        
        // Check for level up
        if let newLevel = checkLevelUp(currentXP: profile.xp, currentLevel: profile.level) {
            profile.level = newLevel
            currentLevel = newLevel
            await notifyLevelUp(userId: userId, level: newLevel)
            print("🎉 [Gamification] LEVEL UP! Now level \(newLevel)")
        }
        
        // Check for new badges
        let newBadges = try await checkBadges(profile: profile, action: action)
        if !newBadges.isEmpty {
            profile.badges.append(contentsOf: newBadges)
            badges = profile.badges
            await notifyNewBadges(userId: userId, badges: newBadges)
        }
        
        // Update streak
        profile.lastActiveDate = Date()
        profile.dailyStreak = calculateStreak(lastActive: profile.lastActiveDate)
        dailyStreak = profile.dailyStreak
        
        // Save profile
        try await saveUserProfile(profile)
    }
    
    /// Game actions that earn XP
    enum GameAction: String {
        case uploadVideo = "upload_video"          // 100 XP
        case watchVideo = "watch_video"            // 5 XP
        case likeVideo = "like_video"              // 10 XP
        case comment = "comment"                   // 15 XP
        case subscribe = "subscribe"               // 50 XP
        case share = "share"                       // 25 XP
        case dailyLogin = "daily_login"            // 10 XP
        case completeProfile = "complete_profile"  // 200 XP
        case verifyEmail = "verify_email"          // 100 XP
        case firstUpload = "first_upload"          // 500 XP
        case reach1KViews = "reach_1k_views"       // 1000 XP
        case reach10KViews = "reach_10k_views"     // 5000 XP
        
        var xpReward: Int {
            switch self {
            case .uploadVideo: return 100
            case .watchVideo: return 5
            case .likeVideo: return 10
            case .comment: return 15
            case .subscribe: return 50
            case .share: return 25
            case .dailyLogin: return 10
            case .completeProfile: return 200
            case .verifyEmail: return 100
            case .firstUpload: return 500
            case .reach1KViews: return 1000
            case .reach10KViews: return 5000
            }
        }
    }
    
    // MARK: - 🏆 LEVEL SYSTEM
    
    private func checkLevelUp(currentXP: Int, currentLevel: Int) -> Int? {
        let requiredXP = xpRequiredForLevel(currentLevel + 1)
        
        if currentXP >= requiredXP {
            return currentLevel + 1
        }
        
        return nil
    }
    
    /// XP required for each level (exponential growth)
    func xpRequiredForLevel(_ level: Int) -> Int {
        return level * level * 100  // Level 1: 100 XP, Level 2: 400 XP, Level 3: 900 XP...
    }
    
    func getProgressToNextLevel(currentXP: Int, currentLevel: Int) -> Double {
        let currentLevelXP = xpRequiredForLevel(currentLevel)
        let nextLevelXP = xpRequiredForLevel(currentLevel + 1)
        let xpInCurrentLevel = currentXP - currentLevelXP
        let xpNeededForNextLevel = nextLevelXP - currentLevelXP
        
        return Double(xpInCurrentLevel) / Double(xpNeededForNextLevel)
    }
    
    // MARK: - 🏅 BADGE SYSTEM
    
    struct Badge: Codable, Identifiable {
        let id: String
        let name: String
        let description: String
        let icon: String
        let rarity: BadgeRarity
        let earnedAt: Date
        
        enum BadgeRarity: String, Codable {
            case common = "Common"
            case rare = "Rare"
            case epic = "Epic"
            case legendary = "Legendary"
        }
    }
    
    private func checkBadges(profile: UserGameProfile, action: GameAction) async throws -> [Badge] {
        var newBadges: [Badge] = []
        
        // Check milestone badges
        if action == .firstUpload && !profile.badges.contains(where: { $0.id == "first_upload" }) {
            newBadges.append(Badge(
                id: "first_upload",
                name: "First Steps",
                description: "Uploaded your first video!",
                icon: "🎬",
                rarity: .common,
                earnedAt: Date()
            ))
        }
        
        if action == .reach1KViews && !profile.badges.contains(where: { $0.id == "1k_views" }) {
            newBadges.append(Badge(
                id: "1k_views",
                name: "Rising Star",
                description: "Reached 1,000 views!",
                icon: "⭐",
                rarity: .rare,
                earnedAt: Date()
            ))
        }
        
        if action == .reach10KViews && !profile.badges.contains(where: { $0.id == "10k_views" }) {
            newBadges.append(Badge(
                id: "10k_views",
                name: "Content Creator",
                description: "Reached 10,000 views!",
                icon: "🔥",
                rarity: .epic,
                earnedAt: Date()
            ))
        }
        
        // Daily streak badges
        if profile.dailyStreak >= 7 && !profile.badges.contains(where: { $0.id == "week_streak" }) {
            newBadges.append(Badge(
                id: "week_streak",
                name: "Consistent Creator",
                description: "7 day login streak!",
                icon: "📅",
                rarity: .rare,
                earnedAt: Date()
            ))
        }
        
        return newBadges
    }
    
    // MARK: - 🔥 STREAK SYSTEM
    
    private func calculateStreak(lastActive: Date?) -> Int {
        guard let lastActive = lastActive else { return 1 }
        
        let calendar = Calendar.current
        let daysSinceLastActive = calendar.dateComponents([.day], from: lastActive, to: Date()).day ?? 0
        
        if daysSinceLastActive <= 1 {
            return dailyStreak + 1
        } else {
            return 1 // Reset streak
        }
    }
    
    // MARK: - 🎁 REWARDS
    
    func claimDailyReward(userId: String) async throws -> DailyReward {
        let profile = try await getUserProfile(userId)
        
        // Check if already claimed today
        let calendar = Calendar.current
        if let lastClaim = profile.lastDailyRewardClaim,
           calendar.isDateInToday(lastClaim) {
            throw GamificationError.dailyRewardAlreadyClaimed
        }
        
        // Award reward based on streak
        let reward = calculateDailyReward(streak: profile.dailyStreak)
        
        try await awardXP(reward.xp, to: userId, for: .dailyLogin)
        
        print("🎁 [Gamification] Daily reward claimed: \(reward.xp) XP")
        
        return reward
    }
    
    private func calculateDailyReward(streak: Int) -> DailyReward {
        let baseXP = 10
        let streakBonus = streak * 5
        let totalXP = baseXP + streakBonus
        
        return DailyReward(
            xp: totalXP,
            streak: streak,
            bonusMultiplier: Double(streakBonus) / Double(baseXP)
        )
    }
    
    struct DailyReward {
        let xp: Int
        let streak: Int
        let bonusMultiplier: Double
    }
    
    // MARK: - 📊 LEADERBOARD
    
    func getLeaderboard(limit: Int = 100) async throws -> [LeaderboardEntry] {
        let snapshot = try await db.collection("gameProfiles")
            .order(by: "xp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.enumerated().compactMap { index, doc in
            guard let data = try? doc.data(as: UserGameProfile.self) else { return nil }
            
            return LeaderboardEntry(
                rank: index + 1,
                userId: data.userId,
                username: data.username,
                xp: data.xp,
                level: data.level,
                badges: data.badges
            )
        }
    }
    
    struct LeaderboardEntry: Identifiable {
        let rank: Int
        let userId: String
        let username: String
        let xp: Int
        let level: Int
        let badges: [Badge]
        
        var id: String { userId }
    }
    
    // MARK: - 💾 DATA PERSISTENCE
    
    private func getUserProfile(_ userId: String) async throws -> UserGameProfile {
        // Check cache
        if let cached = userProfiles[userId] {
            return cached
        }
        
        // Fetch from Firestore
        let docRef = db.collection("gameProfiles").document(userId)
        
        do {
            let profile = try await docRef.getDocument(as: UserGameProfile.self)
            userProfiles[userId] = profile
            return profile
        } catch {
            // Create new profile
            let newProfile = UserGameProfile(userId: userId)
            try await saveUserProfile(newProfile)
            return newProfile
        }
    }
    
    private func saveUserProfile(_ profile: UserGameProfile) async throws {
        let docRef = db.collection("gameProfiles").document(profile.userId)
        try docRef.setData(from: profile, merge: true)
        
        // Update cache
        userProfiles[profile.userId] = profile
    }
    
    struct UserGameProfile: Codable {
        let userId: String
        var username: String = ""
        var xp: Int = 0
        var level: Int = 1
        var badges: [Badge] = []
        var dailyStreak: Int = 0
        var lastActiveDate: Date?
        var lastDailyRewardClaim: Date?
        var totalVideosUploaded: Int = 0
        var totalWatchTime: TimeInterval = 0
        var createdAt: Date = Date()
    }
    
    // MARK: - 🔔 NOTIFICATIONS
    
    private func notifyLevelUp(userId: String, level: Int) async {
        NotificationCenter.default.post(
            name: NSNotification.Name("GamificationLevelUp"),
            object: nil,
            userInfo: ["userId": userId, "level": level]
        )
    }
    
    private func notifyNewBadges(userId: String, badges: [Badge]) async {
        NotificationCenter.default.post(
            name: NSNotification.Name("GamificationNewBadges"),
            object: nil,
            userInfo: ["userId": userId, "badges": badges]
        )
    }
    
    // MARK: - ❌ ERRORS
    
    enum GamificationError: LocalizedError {
        case userNotFound
        case dailyRewardAlreadyClaimed
        case invalidAction
        
        var errorDescription: String? {
            switch self {
            case .userNotFound: return "User profile not found"
            case .dailyRewardAlreadyClaimed: return "Daily reward already claimed today"
            case .invalidAction: return "Invalid game action"
            }
        }
    }
}

// MARK: - 📱 USAGE EXAMPLES

/*
 
 🎮 GAMIFICATION USAGE:
 
 let game = GamificationEngine.shared
 
 // Award XP for actions
 try await game.awardXP(100, to: userId, for: .uploadVideo)
 try await game.awardXP(50, to: userId, for: .subscribe)
 
 // Claim daily reward
 let reward = try await game.claimDailyReward(userId: userId)
 print("🎁 Claimed \(reward.xp) XP with \(reward.streak)x streak!")
 
 // Get leaderboard
 let leaderboard = try await game.getLeaderboard(limit: 10)
 for entry in leaderboard {
     print("#\(entry.rank): \(entry.username) - Level \(entry.level) (\(entry.xp) XP)")
 }
 
 🎯 BENEFITS:
 - Makes platform addictive
 - Encourages daily engagement
 - Rewards creators
 - Social competition
 
 */
