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
    @Published var chatMessages: [ChatMessage] = []
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
                color: Color(hex: "#FFD700")
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
            ChatMessage(
                id: "1",
                username: "ProGamer_2024",
                text: "This is intense! 🔥",
                time: Date().addingTimeInterval(-180)
            ),
            ChatMessage(
                id: "2",
                username: "ElitePlayer",
                text: "Who y'all got winning?",
                time: Date().addingTimeInterval(-150)
            ),
            ChatMessage(
                id: "3",
                username: "SkillMaster",
                text: "Team 1 got this easy",
                time: Date().addingTimeInterval(-120)
            ),
            ChatMessage(
                id: "4",
                username: "ChampionX",
                text: "Let's go!!! 💪",
                time: Date().addingTimeInterval(-90)
            ),
        ]
    }
    
    func sendMessage() async {
        guard !chatInput.isEmpty else { return }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            username: "You",
            text: chatInput,
            time: Date()
        )
        
        chatMessages.append(message)
        chatInput = ""
    }
}

