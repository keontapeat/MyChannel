//
//  TournamentBracketView.swift
//  MyChannel
//
//  3D NBA-Style Tournament Bracket
//

import SwiftUI

struct TournamentBracketView: View {
    let tournament: BracketTournament
    @StateObject private var viewModel = TournamentBracketViewModel()
    @State private var selectedMatch: BracketMatch?
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                bracketHeader
                
                // 3D Bracket
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(Array(tournament.rounds.enumerated()), id: \.element.id) { index, round in
                            bracketRound(
                                round: round,
                                roundNumber: index + 1,
                                depth: index
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .frame(height: 600)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedMatch) { match in
            LiveMatchSpectatorView(match: match)
        }
    }
    
    // MARK: - Header
    
    private var bracketHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    HStack(spacing: 12) {
                        Text(tournament.formattedPrizePool)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hexString: "#FFD700"))
                        
                        Text("•")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("\(tournament.totalPlayers) Players")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Prize breakdown button
                Button(action: {
                    // Show prize breakdown
                }) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background(AppTheme.Colors.surface)
    }
    
    // MARK: - Bracket Round
    
    private func bracketRound(round: BracketRound, roundNumber: Int, depth: Int) -> some View {
        VStack(spacing: 20) {
            // Round header
            Text(round.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppTheme.Colors.surface)
                )
            
            // Matches
            VStack(spacing: 20) {
                ForEach(round.matches) { match in
                    matchCard3D(match: match, depth: depth)
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
    }
    
    // MARK: - 3D Match Card
    
    private func matchCard3D(match: BracketMatch, depth: Int) -> some View {
        Button(action: {
            selectedMatch = match
        }) {
            ZStack {
                // Background layers for depth
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.surface,
                                AppTheme.Colors.surface.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Highlight layer
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                
                // Content
                VStack(spacing: 12) {
                    // Player 1
                    playerRow(
                        team: match.team1,
                        score: match.score1,
                        isWinner: match.winner?.id == match.team1.id,
                        isLive: match.isLive
                    )
                    
                    // VS Divider
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(AppTheme.Colors.divider.opacity(0.2))
                            .frame(height: 1)
                        
                        Text("VS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Rectangle()
                            .fill(AppTheme.Colors.divider.opacity(0.2))
                            .frame(height: 1)
                    }
                    
                    // Player 2
                    if let team2 = match.team2 {
                        playerRow(
                            team: team2,
                            score: match.score2,
                            isWinner: match.winner?.id == team2.id,
                            isLive: match.isLive
                        )
                    } else {
                        // TBD placeholder
                        HStack {
                            Text("TBD")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    
                    // Live indicator
                    if match.isLive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.red)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                }
                .padding(14)
                
                // Border glow
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: match.isLive ? 
                                [Color.red.opacity(0.5), Color.orange.opacity(0.3)] :
                                [AppTheme.Colors.divider.opacity(0.2), AppTheme.Colors.divider.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .frame(width: 200, height: 120)
            .rotation3DEffect(
                .degrees(Double(depth) * 10),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .scaleEffect(1.0 - Double(depth) * 0.1)
            .shadow(
                color: .black.opacity(0.25),
                radius: 20 + Double(depth) * 4,
                x: Double(depth) * 3,
                y: Double(depth) * 3 + 8
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func playerRow(team: BracketTeam, score: Int?, isWinner: Bool, isLive: Bool) -> some View {
        HStack(spacing: 10) {
            // Profile
            Circle()
                .fill(isWinner ? (Color(hexString: "#FFD700") ?? .yellow).opacity(0.1) : AppTheme.Colors.surface)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isWinner ? (Color(hexString: "#FFD700") ?? .yellow) : AppTheme.Colors.textPrimary)
                )
            
            // Name
            Text(team.name)
                .font(.system(size: 13, weight: isWinner ? .bold : .semibold))
                .foregroundColor(isWinner ? (Color(hexString: "#FFD700") ?? .yellow) : AppTheme.Colors.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            // Score
            if let score = score {
                Text("\(score)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isWinner ? (Color(hexString: "#FFD700") ?? .yellow) : AppTheme.Colors.textPrimary)
            } else if isLive {
                ProgressView()
                    .scaleEffect(0.7)
            }
            
            // Winner checkmark
            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hexString: "#FFD700") ?? .yellow)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isWinner ? (Color(hexString: "#FFD700") ?? .yellow).opacity(0.05) : Color.clear)
        )
    }
}

// MARK: - Live Match Spectator View

struct LiveMatchSpectatorView: View {
    let match: BracketMatch
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LiveMatchViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Live indicator banner
                        if match.isLive {
                            liveIndicatorBanner
                        }
                        
                        // Match scoreboard
                        matchScoreboard
                        
                        // Game feed (real-time updates)
                        gameFeedSection
                        
                        // Chat
                        chatSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Live Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadMatch(match)
        }
    }
    
    private var liveIndicatorBanner: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                
                Text("LIVE")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.red)
            }
            
            Spacer()
            
            Text("\(viewModel.spectatorCount) watching")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var matchScoreboard: some View {
        VStack(spacing: 20) {
            // Prize pool
            VStack(spacing: 6) {
                Text("Prize Pool")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("$5,000")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(Color(hexString: "#FFD700"))
            }
            
            // Scores
            HStack(spacing: 24) {
                // Player 1
                VStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        )
                    
                    Text(match.team1.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("\(match.score1 ?? 0)")
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(Color(hexString: "#FFD700"))
                }
                .frame(maxWidth: .infinity)
                
                // VS
                Text("VS")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                // Player 2
                if let team2 = match.team2 {
                    VStack(spacing: 12) {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            )
                        
                        Text(team2.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("\(match.score2 ?? 0)")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(Color(hexString: "#FFD700"))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var gameFeedSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Game Feed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(viewModel.gameFeedEvents) { event in
                    gameFeedRow(event: event)
                }
            }
        }
    }
    
    private func gameFeedRow(event: GameFeedEvent) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(event.color.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: event.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(event.color)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(event.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(event.formattedTime)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    private var chatSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Chat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.chatMessages.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.surface)
                    )
            }
            
            VStack(spacing: 8) {
                ForEach(viewModel.chatMessages) { message in
                    chatMessageRow(message: message)
                }
            }
            
            // Chat input
            HStack(spacing: 12) {
                TextField("Send a message...", text: $viewModel.chatInput)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppTheme.Colors.surface)
                    )
                
                Button(action: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.primary)
                        )
                }
            }
        }
    }
    
    private func chatMessageRow(message: TournamentChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(AppTheme.Colors.surface)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(message.formattedTime)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                
                Text(message.text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Types

struct BracketTournament: Identifiable {
    let id: String
    let name: String
    let prizePool: Double
    let totalPlayers: Int
    let rounds: [BracketRound]
    let startDate: Date?
    
    var formattedPrizePool: String {
        "$\(Int(prizePool).formatted())"
    }
    
    static let sample = BracketTournament(
        id: "sample-tournament",
        name: "Sample Championship",
        prizePool: 50_000,
        totalPlayers: 256,
        rounds: [
            BracketRound(
                id: "round-1",
                name: "Round 1",
                matches: []
            )
        ],
        startDate: Date()
    )
}

struct BracketRound: Identifiable {
    let id: String
    let name: String
    let matches: [BracketMatch]
}

struct BracketMatch: Identifiable {
    let id: String
    let team1: BracketTeam
    let team2: BracketTeam?
    let score1: Int?
    let score2: Int?
    let winner: BracketTeam?
    let isLive: Bool
}

struct BracketTeam: Identifiable {
    let id: String
    let name: String
}

// MARK: - Conversion Extension

extension BracketTournament {
    func toBracket3DTournament() -> Bracket3DTournament {
        Bracket3DTournament(
            id: id,
            name: name,
            rounds: rounds.map { round in
                Bracket3DRound(
                    id: round.id,
                    matches: round.matches.map { match in
                        Bracket3DMatch(
                            id: match.id,
                            team1: Bracket3DTeam(
                                id: match.team1.id,
                                name: match.team1.name,
                                score: match.score1
                            ),
                            team2: Bracket3DTeam(
                                id: match.team2?.id ?? "",
                                name: match.team2?.name ?? "TBD",
                                score: match.score2
                            ),
                            winner: match.winner?.id,
                            isCompleted: match.winner != nil,
                            scheduledDate: nil,
                            score1: match.score1,
                            score2: match.score2
                        )
                    },
                    roundName: round.name
                )
            },
            startDate: Date(),
            endDate: Date().addingTimeInterval(604800),
            prizePool: prizePool
        )
    }
}

struct GameFeedEvent: Identifiable {
    let id: String
    let text: String
    let time: Date
    let iconName: String
    let color: Color
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }
}

struct TournamentChatMessage: Identifiable {
    let id: String
    let username: String
    let message: String
    let isUser: Bool
    let timestamp: Date
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: timestamp)
    }
    
    var text: String {
        message
    }
    
    var time: Date {
        timestamp
    }
}

#Preview {
    TournamentBracketView(
        tournament: BracketTournament(
            id: "spring-championship",
            name: "Spring Championship",
            prizePool: 50_000,
            totalPlayers: 256,
            rounds: [],
            startDate: Date()
        )
    )
}

