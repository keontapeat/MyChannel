//
//  GamingEsportsViewModel.swift
//  MyChannel
//
//  Created by AI Assistant
//

import Foundation
import SwiftUI

@MainActor
final class GamingEsportsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Tournaments
    @Published var featuredTournament: Tournament?
    @Published var activeTournaments: [Tournament] = []
    @Published var hasLiveTournaments = false
    
    // VS Matches
    @Published var activeMatches: [VSMatch] = []
    
    // Leaderboard
    @Published var leaderboardUsers: [LeaderboardUser] = []
    @Published var selectedPeriod: LeaderboardPeriod = .weekly
    
    // My Earnings
    @Published var totalEarnings: Double = 0
    @Published var availableBalance: Double = 0
    @Published var pendingBalance: Double = 0
    @Published var tournamentsWon: Int = 0
    @Published var vsWins: Int = 0
    @Published var totalMatches: Int = 0
    @Published var winRate: Int = 0
    @Published var recentTransactions: [EarningsTransaction] = []
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Services
    
    private let vsMatchService = VersusMatchService.shared
    private let walletService = VSMatchWalletService.shared
    
    // MARK: - Formatted Properties
    
    var formattedTotalEarnings: String {
        "$\(Int(totalEarnings).formatted())"
    }
    
    var formattedAvailableBalance: String {
        "$\(Int(availableBalance).formatted())"
    }
    
    var formattedPendingBalance: String {
        "$\(Int(pendingBalance).formatted())"
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTournaments() }
            group.addTask { await self.loadVSMatches() }
            group.addTask { await self.loadLeaderboard() }
            group.addTask { await self.loadEarnings() }
        }
    }
    
    private func loadTournaments() async {
        // Load featured tournament
        featuredTournament = Tournament(
            id: "spring-championship",
            name: "Spring Championship",
            gameName: "Multi-Game",
            prizePool: 50_000,
            entryFee: 50,
            format: "Single Elimination",
            currentPlayers: 248,
            maxPlayers: 256,
            startDate: Date().addingTimeInterval(60 * 60 * 38), // 2d 14h from now
            isLive: false
        )
        
        // Load active tournaments
        activeTournaments = [
            Tournament(
                id: "pro-league",
                name: "Pro League Finals",
                gameName: "Fortnite",
                prizePool: 75_000,
                entryFee: 100,
                format: "Single Elimination",
                currentPlayers: 32,
                maxPlayers: 128,
                startDate: Date().addingTimeInterval(60 * 60 * 125), // 5d 3h
                isLive: false
            ),
            Tournament(
                id: "masters",
                name: "Masters Tournament",
                gameName: "Valorant",
                prizePool: 100_000,
                entryFee: 150,
                format: "Double Elimination",
                currentPlayers: 256,
                maxPlayers: 256,
                startDate: Date().addingTimeInterval(-60 * 60 * 2), // Started 2h ago
                isLive: true
            ),
            Tournament(
                id: "pro-league-val",
                name: "Pro League Finals",
                gameName: "Valorant",
                prizePool: 75_000,
                entryFee: 100,
                format: "Single Elimination",
                currentPlayers: 64,
                maxPlayers: 128,
                startDate: Date().addingTimeInterval(60 * 60 * 72), // 3d
                isLive: false
            ),
        ]
        
        hasLiveTournaments = activeTournaments.contains { $0.isLive }
    }
    
    private func loadVSMatches() async {
        // Load active matches
        activeMatches = [
            VSMatch(
                id: "match-1",
                challenger: User.sampleUsers[0],
                opponent: nil,
                category: "Gaming Views",
                wagerAmount: 100,
                createdAt: Date().addingTimeInterval(-60 * 15)
            ),
            VSMatch(
                id: "match-2",
                challenger: User.sampleUsers[1],
                opponent: User.sampleUsers[2],
                category: "Likes Battle",
                wagerAmount: 250,
                createdAt: Date().addingTimeInterval(-60 * 30)
            ),
            VSMatch(
                id: "match-3",
                challenger: User.sampleUsers[3],
                opponent: nil,
                category: "Dance Battle",
                wagerAmount: 50,
                createdAt: Date().addingTimeInterval(-60 * 5)
            ),
        ]
    }
    
    private func loadLeaderboard() async {
        // Load leaderboard users
        leaderboardUsers = [
            LeaderboardUser(id: "1", displayName: "ProGamer_2024", totalEarnings: 125_000, wins: 45, matches: 52),
            LeaderboardUser(id: "2", displayName: "ElitePlayer", totalEarnings: 98_500, wins: 38, matches: 48),
            LeaderboardUser(id: "3", displayName: "ChampionX", totalEarnings: 87_200, wins: 35, matches: 45),
            LeaderboardUser(id: "4", displayName: "SkillMaster", totalEarnings: 72_100, wins: 32, matches: 42),
            LeaderboardUser(id: "5", displayName: "TopTier", totalEarnings: 65_400, wins: 28, matches: 38),
            LeaderboardUser(id: "6", displayName: "ProKing", totalEarnings: 58_900, wins: 25, matches: 35),
            LeaderboardUser(id: "7", displayName: "EliteForce", totalEarnings: 52_300, wins: 23, matches: 32),
            LeaderboardUser(id: "8", displayName: "Champion", totalEarnings: 47_800, wins: 21, matches: 30),
            LeaderboardUser(id: "9", displayName: "GamerPro", totalEarnings: 43_200, wins: 19, matches: 28),
            LeaderboardUser(id: "10", displayName: "SkillZ", totalEarnings: 38_500, wins: 17, matches: 25),
        ]
    }
    
    private func loadEarnings() async {
        // Load user earnings
        totalEarnings = 12_450
        availableBalance = 8_230
        pendingBalance = 4_220
        tournamentsWon = 8
        vsWins = 23
        totalMatches = 35
        winRate = 66
        
        // Load recent transactions
        recentTransactions = [
            EarningsTransaction(
                id: "1",
                description: "Tournament Win - Spring Finals",
                amount: 2_500,
                date: Date().addingTimeInterval(-60 * 60 * 2),
                type: .win
            ),
            EarningsTransaction(
                id: "2",
                description: "VS Match Win vs ProGamer",
                amount: 500,
                date: Date().addingTimeInterval(-60 * 60 * 5),
                type: .win
            ),
            EarningsTransaction(
                id: "3",
                description: "Withdrawal to Bank",
                amount: 1_000,
                date: Date().addingTimeInterval(-60 * 60 * 24),
                type: .withdrawal
            ),
            EarningsTransaction(
                id: "4",
                description: "Deposit",
                amount: 500,
                date: Date().addingTimeInterval(-60 * 60 * 48),
                type: .deposit
            ),
            EarningsTransaction(
                id: "5",
                description: "VS Match Loss vs ElitePlayer",
                amount: 250,
                date: Date().addingTimeInterval(-60 * 60 * 72),
                type: .loss
            ),
        ]
    }
}

