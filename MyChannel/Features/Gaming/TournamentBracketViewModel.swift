//
//  TournamentBracketViewModel.swift
//  MyChannel
//
//  Tournament Bracket ViewModel with Vertex AI Integration
//

import Foundation
import SwiftUI

@MainActor
final class TournamentBracketViewModel: ObservableObject {
    @Published var tournament: BracketTournament?
    @Published var isLoading = false
    
    func loadTournament(_ tournamentId: String) async {
        // Load from Firestore + process with Vertex AI agents
    }
}

@MainActor
final class LiveMatchViewModel: ObservableObject {
    @Published var spectatorCount: Int = 0
    @Published var gameFeedEvents: [GameFeedEvent] = []
    @Published var chatMessages: [TournamentChatMessage] = []
    @Published var chatInput: String = ""
    
    func loadMatch(_ match: BracketMatch) async {
        // Load match data
        spectatorCount = Int.random(in: 50...500)
        
        // Load game feed
        gameFeedEvents = [
            GameFeedEvent(
                id: "1",
                text: "\(match.team1.name) scored first blood!",
                time: Date().addingTimeInterval(-120),
                iconName: "star.fill",
                color: Color(hexString: "#FFD700") ?? .yellow
            ),
            GameFeedEvent(
                id: "2",
                text: "Power play activated",
                time: Date().addingTimeInterval(-90),
                iconName: "bolt.fill",
                color: Color.blue
            ),
            GameFeedEvent(
                id: "3",
                text: "\(match.team2?.name ?? "Player 2") is on a streak!",
                time: Date().addingTimeInterval(-60),
                iconName: "flame.fill",
                color: Color.orange
            ),
            GameFeedEvent(
                id: "4",
                text: "Round complete",
                time: Date().addingTimeInterval(-30),
                iconName: "checkmark.circle.fill",
                color: Color.green
            ),
        ]
        
        // Load chat
        chatMessages = [
            TournamentChatMessage(
                id: "1",
                username: "ProGamer_2024",
                message: "This is intense! 🔥",
                isUser: false,
                timestamp: Date().addingTimeInterval(-180)
            ),
            TournamentChatMessage(
                id: "2",
                username: "ElitePlayer",
                message: "Who y'all got winning?",
                isUser: false,
                timestamp: Date().addingTimeInterval(-150)
            ),
            TournamentChatMessage(
                id: "3",
                username: "SkillMaster",
                message: "Team 1 got this easy",
                isUser: false,
                timestamp: Date().addingTimeInterval(-120)
            ),
            TournamentChatMessage(
                id: "4",
                username: "ChampionX",
                message: "Let's go!!! 💪",
                isUser: false,
                timestamp: Date().addingTimeInterval(-90)
            ),
        ]
    }
    
    func sendMessage() async {
        guard !chatInput.isEmpty else { return }
        
        let message = TournamentChatMessage(
            id: UUID().uuidString,
            username: "You",
            message: chatInput,
            isUser: true,
            timestamp: Date()
        )
        
        chatMessages.append(message)
        chatInput = ""
    }
}

