//
//  CompetitiveMatchModels.swift
//  MyChannel
//
//  🔥 1V1 COMPETITIVE MATCH SYSTEM WITH REAL MONEY BETTING 💰
//  Professional wagering system where winner takes all
//

import Foundation
import SwiftUI

// MARK: - Match Status
enum MatchStatus: String, Codable {
    case searching = "searching"      // Looking for opponent
    case pending = "pending"          // Found opponent, waiting for acceptance
    case accepted = "accepted"        // Both players accepted, payment processing
    case live = "live"                // Match is currently happening
    case completed = "completed"      // Match finished
    case disputed = "disputed"        // Match result is being disputed
    case cancelled = "cancelled"      // Match was cancelled
}

// MARK: - Match Payment Status
enum MatchPaymentStatus: String, Codable {
    case pending = "pending"          // Awaiting payment
    case held = "held"                // Money is held in escrow
    case released = "released"        // Winner received payment
    case refunded = "refunded"        // Payment was refunded
}

// MARK: - Competitive Player
struct CompetitivePlayer: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let displayName: String
    let avatarURL: String
    let level: Int
    let rating: Int              // ELO rating
    let wins: Int
    let losses: Int
    let totalEarnings: Double
    let winStreak: Int
    let isVerified: Bool
    let countryCode: String      // For flag emoji
    
    var winRate: Double {
        let total = wins + losses
        return total > 0 ? Double(wins) / Double(total) * 100 : 0
    }
    
    var countryFlag: String {
        String(String.UnicodeScalarView(
            countryCode.unicodeScalars.compactMap {
                UnicodeScalar(127397 + $0.value)
            }
        ))
    }
}

// MARK: - Competitive Game
// Note: Renamed to avoid conflict with GamingViewModel.Game
struct CompetitiveGame: Codable, Hashable {
    let id: String
    let name: String
    let category: String
}

// MARK: - Match Wager
struct MatchWager: Codable, Hashable {
    let amount: Double              // Amount each player puts in
    let currency: String            // USD, EUR, etc
    let platformFee: Double         // Platform's cut (5-10%)
    let totalPot: Double           // Total pot (amount * 2)
    let winnerPayout: Double       // What winner gets (pot - fee)
    
    var formattedAmount: String {
        String(format: "$%.2f", amount)
    }
    
    var formattedPot: String {
        String(format: "$%.2f", totalPot)
    }
    
    var formattedWinnerPayout: String {
        String(format: "$%.2f", winnerPayout)
    }
}

// MARK: - Competitive Match (1v1)
struct CompetitiveMatch: Identifiable, Codable, Hashable {
    let id: String
    let game: CompetitiveGame
    let wager: MatchWager
    let player1: CompetitivePlayer
    var player2: CompetitivePlayer?
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var status: MatchStatus
    var paymentStatus: MatchPaymentStatus
    
    // Match details
    var player1Score: Int?
    var player2Score: Int?
    var winner: String?            // Player ID of winner
    
    // Live match info
    var currentViewers: Int
    var streamURL: String?
    var replayURL: String?
    
    // Match settings
    let format: String              // "Best of 1", "Best of 3", etc
    let rules: String
    let maxDuration: Int            // In minutes
    
    var isLive: Bool {
        status == .live
    }
    
    var hasWinner: Bool {
        winner != nil
    }
    
    var totalPot: String {
        wager.formattedPot
    }
}

// MARK: - Match Challenge
struct MatchChallenge: Identifiable, Codable {
    let id: String
    let challenger: CompetitivePlayer
    let game: CompetitiveGame
    let wager: MatchWager
    let format: String
    let rules: String
    let expiresAt: Date
    let createdAt: Date
    
    var timeRemaining: String {
        let remaining = expiresAt.timeIntervalSince(Date())
        let minutes = Int(remaining / 60)
        return minutes > 0 ? "\(minutes)m" : "Expired"
    }
}

// MARK: - Match History Entry
struct MatchHistory: Identifiable, Codable {
    let id: String
    let match: CompetitiveMatch
    let result: MatchResult
}

enum MatchResult: String, Codable {
    case won = "Won"
    case lost = "Lost"
    case draw = "Draw"
    case cancelled = "Cancelled"
}

// MARK: - Live Spectator Info
struct SpectatorInfo: Codable {
    let matchId: String
    let currentViewers: Int
    let peakViewers: Int
    let chatEnabled: Bool
    let bettingEnabled: Bool       // Spectators can bet on outcome
}

// MARK: - Betting Option (for spectators)
struct SpectatorBet: Identifiable, Codable {
    let id: String
    let matchId: String
    let bettor: String             // User ID
    let predictedWinner: String    // Player ID
    let amount: Double
    let odds: Double
    let potentialPayout: Double
    let placedAt: Date
}

