//
//  GamingViewModel.swift
//  MyChannel
//
//  ViewModel for MyChannel Gaming
//

import Foundation
import SwiftUI

struct Game: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let color: Color
}

struct GamingTournament: Identifiable, Codable {
    let id: String
    let name: String
    let game: Game
    let prizePool: String
    let participants: Int
    let maxParticipants: Int
    let timeRemaining: String
    let format: String
    let startDate: Date
}

struct GamingTeam: Identifiable, Codable {
    let id: String
    let name: String
    let tag: String
    let members: Int
    let wins: Int
    let losses: Int
    let rank: Int
    let color: Color
}

struct LiveMatch: Identifiable, Codable {
    let id: String
    let tournament: String
    let team1: String
    let team2: String
    let team1Score: Int
    let team2Score: Int
    let viewers: Int
}

struct GamingPlayer: Identifiable, Codable {
    let id: String
    let name: String
    let avatarURL: String
    let totalPoints: Int
    let wins: Int
    let earnings: String
}

struct GamingEvent: Identifiable, Codable {
    let id: String
    let name: String
    let game: Game
    let prizePool: String
    let startDate: Date
}

@MainActor
class GamingViewModel: ObservableObject {
    @Published var activeTournaments: [GamingTournament] = []
    @Published var yourTeams: [GamingTeam] = []
    @Published var liveMatches: [LiveMatch] = []
    @Published var topPlayers: [GamingPlayer] = []
    @Published var upcomingEvents: [GamingEvent] = []
    
    @Published var totalPrizePool: String = "0"
    @Published var activePlayers: String = "0"
    @Published var monthlyPrizePool: String = "0"
    
    // 🔥 PERFORMANCE: Track tasks for proper cancellation
    private var loadTask: Task<Void, Never>?
    
    // 🔥 PERFORMANCE: Proper deinit cleanup
    deinit {
        loadTask?.cancel()
        print("✅ [GamingViewModel] Deallocated - no memory leak!")
    }
    
    func loadGamingData() async {
        totalPrizePool = "500K"
        activePlayers = "24.5K"
        monthlyPrizePool = "150,000"
        
        let fortniteGame = Game(id: "fn", name: "Fortnite", emoji: "🎮", color: .purple)
        let valorantGame = Game(id: "val", name: "Valorant", emoji: "🔫", color: .red)
        let lolGame = Game(id: "lol", name: "League of Legends", emoji: "⚔️", color: .blue)
        
        activeTournaments = [
            GamingTournament(
                id: "1",
                name: "Spring Championship",
                game: fortniteGame,
                prizePool: "50,000",
                participants: 248,
                maxParticipants: 256,
                timeRemaining: "2d 14h",
                format: "Single Elimination",
                startDate: Date().addingTimeInterval(86400 * 2)
            ),
            GamingTournament(
                id: "2",
                name: "Pro League Finals",
                game: valorantGame,
                prizePool: "75,000",
                participants: 128,
                maxParticipants: 128,
                timeRemaining: "5d 3h",
                format: "Double Elimination",
                startDate: Date().addingTimeInterval(86400 * 5)
            ),
            GamingTournament(
                id: "3",
                name: "Masters Tournament",
                game: lolGame,
                prizePool: "100,000",
                participants: 189,
                maxParticipants: 512,
                timeRemaining: "7d 18h",
                format: "Swiss System",
                startDate: Date().addingTimeInterval(86400 * 7)
            )
        ]
        
        yourTeams = []
        
        liveMatches = [
            LiveMatch(
                id: "1",
                tournament: "Spring Championship",
                team1: "Team Alpha",
                team2: "Team Beta",
                team1Score: 12,
                team2Score: 9,
                viewers: 3245
            ),
            LiveMatch(
                id: "2",
                tournament: "Pro League",
                team1: "Storm Gaming",
                team2: "Thunder Squad",
                team1Score: 8,
                team2Score: 8,
                viewers: 5621
            )
        ]
        
        topPlayers = [
            GamingPlayer(id: "1", name: "ProGamer420", avatarURL: "", totalPoints: 24580, wins: 234, earnings: "48,200"),
            GamingPlayer(id: "2", name: "ElitePlayer", avatarURL: "", totalPoints: 23150, wins: 218, earnings: "42,800"),
            GamingPlayer(id: "3", name: "GamingMaster", avatarURL: "", totalPoints: 21940, wins: 205, earnings: "38,500"),
            GamingPlayer(id: "4", name: "SkillzPro", avatarURL: "", totalPoints: 20120, wins: 189, earnings: "34,200"),
            GamingPlayer(id: "5", name: "UltimateGamer", avatarURL: "", totalPoints: 19450, wins: 176, earnings: "31,800")
        ]
        
        upcomingEvents = [
            GamingEvent(
                id: "1",
                name: "World Championship",
                game: fortniteGame,
                prizePool: "1,000,000",
                startDate: Date().addingTimeInterval(86400 * 30)
            ),
            GamingEvent(
                id: "2",
                name: "International Cup",
                game: valorantGame,
                prizePool: "500,000",
                startDate: Date().addingTimeInterval(86400 * 45)
            )
        ]
    }
}

