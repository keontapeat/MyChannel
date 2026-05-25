//
//  VersusMatchModels.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🎮 VS MATCH MODELS - Real money competition system
//

import Foundation

struct VersusMatch: Identifiable, Codable {
    let id: String
    let challengerId: String
    let opponentId: String
    let matchType: MatchType
    let wagerAmount: Double
    let category: Category
    let rules: MatchRules
    var status: Status
    var winnerId: String?
    let createdAt: Date
    let scheduledDate: Date
    var startedAt: Date?
    var completedAt: Date?
    var finalStats: MatchStats?
    
    // MARK: - Match Type
    
    enum MatchType: String, Codable, CaseIterable {
        case headToHead = "Head to Head"
        case bestOfThree = "Best of 3"
        case tournament = "Tournament"
        case timeChallenge = "Time Challenge"
    }
    
    // MARK: - Category
    
    enum Category: String, Codable, CaseIterable {
        case gaming = "Gaming"
        case views = "Most Views"
        case likes = "Most Likes"
        case comments = "Most Comments"
        case subscribers = "Most Subscribers"
        case donations = "Most Donations"
        case creative = "Creative Challenge"
        case cooking = "Cooking Battle"
        case music = "Music Battle"
        case dance = "Dance Battle"
        case sports = "Sports Challenge"
    }
    
    // MARK: - Status
    
    enum Status: String, Codable {
        case pending = "pending"
        case accepted = "accepted"
        case declined = "declined"
        case live = "live"
        case completed = "completed"
        case cancelled = "cancelled"
        case disputed = "disputed"
    }
    
    // MARK: - Match Rules
    
    struct MatchRules: Codable {
        let duration: TimeInterval // in seconds
        let category: Category
        let winCondition: WinCondition
        var customRules: [String]?
        
        enum WinCondition: String, Codable {
            case mostViews = "Most Views"
            case mostLikes = "Most Likes"
            case mostComments = "Most Comments"
            case mostSubscribers = "Most Subscribers"
            case mostDonations = "Most Donations"
            case judgeDecision = "Judge Decision"
            case audienceVote = "Audience Vote"
        }
    }
    
    // MARK: - Match Stats
    
    struct MatchStats: Codable {
        var challengerViews: Int
        var opponentViews: Int
        var challengerLikes: Int
        var opponentLikes: Int
        var challengerComments: Int
        var opponentComments: Int
        var challengerDonations: Double
        var opponentDonations: Double
        var peakViewers: Int
        var totalViewers: Int
        
        var winner: String {
            // Determine winner based on most views
            return challengerViews > opponentViews ? "challenger" : "opponent"
        }
    }
}

// MARK: - Player Stats

struct PlayerMatchStats: Identifiable, Codable {
    let id: String
    let userId: String
    var totalMatches: Int
    var wins: Int
    var losses: Int
    var draws: Int
    var totalEarnings: Double
    var totalLosses: Double
    var winStreak: Int
    var longestWinStreak: Int
    var championshipPoints: Int
    var rank: Int
    var tier: PlayerTier
    
    var winRate: Double {
        guard totalMatches > 0 else { return 0 }
        return Double(wins) / Double(totalMatches) * 100
    }
    
    var netEarnings: Double {
        return totalEarnings - totalLosses
    }
    
    enum PlayerTier: String, Codable {
        case bronze = "Bronze"
        case silver = "Silver"
        case gold = "Gold"
        case platinum = "Platinum"
        case diamond = "Diamond"
        case master = "Master"
        case grandmaster = "Grandmaster"
        case legend = "Legend"
    }
}

