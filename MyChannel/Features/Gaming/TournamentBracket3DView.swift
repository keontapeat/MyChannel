//
//  TournamentBracket3DView.swift
//  MyChannel
//
//  Created by AI Assistant
//  🏆 3D TOURNAMENT BRACKET - NBA Playoffs style with hard 3D effects! 🔥
//

import SwiftUI

struct TournamentBracket3DView: View {
    let tournament: BracketTournament
    @State private var rotationAngle: Double = 0
    @State private var selectedMatch: BracketMatch? = nil
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 🔥 POLISHED HEADER - Tournament Info
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tournament.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack(spacing: 12) {
                            Label("$\(Int(tournament.prizePool).formatted(.number.grouping(.automatic)))", systemImage: "dollarsign.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Text("•")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text(tournament.startDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isExpanded.toggle()
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(AppTheme.Colors.surface)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.surface.opacity(0.6),
                        AppTheme.Colors.surface.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // 🔥 POLISHED 3D BRACKET CONTAINER
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    // Realistic court/arena background
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.background,
                            AppTheme.Colors.surface.opacity(0.4),
                            AppTheme.Colors.background.opacity(0.8),
                            AppTheme.Colors.surface.opacity(0.4),
                            AppTheme.Colors.background
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .ignoresSafeArea()
                    
                    // 3D Bracket with realistic depth
                    bracket3DView
                        .padding(.vertical, 50)
                        .padding(.horizontal, 20)
                }
            }
            .frame(height: isExpanded ? 650 : 450)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.surface.opacity(0.5),
                            AppTheme.Colors.surface.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.primary.opacity(0.2),
                            AppTheme.Colors.primary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - 3D Bracket View
    
    private var bracket3DView: some View {
        GeometryReader { geometry in
            ZStack {
                // Connecting lines between rounds
                bracketConnectors
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        // Round 1 (Quarterfinals)
                        bracketRound(
                            round: tournament.rounds[0],
                            roundNumber: 1,
                            depth: 0
                        )
                        
                        // Round 2 (Semifinals)
                        bracketRound(
                            round: tournament.rounds[1],
                            roundNumber: 2,
                            depth: 1
                        )
                        
                        // Round 3 (Finals)
                        if tournament.rounds.count > 2 {
                            bracketRound(
                                round: tournament.rounds[2],
                                roundNumber: 3,
                                depth: 2
                            )
                        }
                        
                        // Round 4 (Championship)
                        if tournament.rounds.count > 3 {
                            bracketRound(
                                round: tournament.rounds[3],
                                roundNumber: 4,
                                depth: 3
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
        }
        .frame(height: 600)
    }
    
    // MARK: - 🔥 REALISTIC BRACKET CONNECTORS (NBA-STYLE)
    
    private var bracketConnectors: some View {
        GeometryReader { geometry in
            ZStack {
                // 🔥 REALISTIC CONNECTING LINES - NBA bracket style
                ForEach(0..<tournament.rounds.count - 1, id: \.self) { roundIndex in
                    let currentRound = tournament.rounds[roundIndex]
                    let nextRound = tournament.rounds[roundIndex + 1]
                    
                    // Connect each match to next round
                    ForEach(Array(currentRound.matches.enumerated()), id: \.element.id) { matchIndex, match in
                        if match.isCompleted, let _ = match.winner {
                            // Calculate positions
                            let startX = CGFloat(roundIndex) * 260 + 220
                            let endX = CGFloat(roundIndex + 1) * 260 + 220
                            
                            // Match position in current round
                            let matchSpacing: CGFloat = 140
                            let startY = 65 + CGFloat(matchIndex) * matchSpacing
                            
                            // Find winner's position in next round
                            let nextMatchIndex = matchIndex / 2
                            let endY = 65 + CGFloat(nextMatchIndex) * matchSpacing
                            
                            // 🔥 REALISTIC BRACKET LINE (L-shaped)
                            Path { path in
                                // Horizontal line from match
                                path.move(to: CGPoint(x: startX, y: startY))
                                path.addLine(to: CGPoint(x: startX + 20, y: startY))
                                
                                // Vertical line to next round level
                                path.addLine(to: CGPoint(x: startX + 20, y: endY))
                                
                                // Horizontal line to next round
                                path.addLine(to: CGPoint(x: endX, y: endY))
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        AppTheme.Colors.primary.opacity(0.6),
                                        AppTheme.Colors.primary.opacity(0.4),
                                        AppTheme.Colors.primary.opacity(0.2)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                            .shadow(
                                color: AppTheme.Colors.primary.opacity(0.4),
                                radius: 6,
                                x: 0,
                                y: 2
                            )
                            
                            // 🔥 WINNER INDICATOR (glowing dot)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            AppTheme.Colors.primary,
                                            AppTheme.Colors.primary.opacity(0.6),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 2,
                                        endRadius: 8
                                    )
                                )
                                .frame(width: 8, height: 8)
                                .position(x: endX, y: endY)
                                .shadow(
                                    color: AppTheme.Colors.primary.opacity(0.6),
                                    radius: 8,
                                    x: 0,
                                    y: 0
                                )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 🔥 REALISTIC BRACKET ROUND (NBA-STYLE)
    
    @ViewBuilder
    private func bracketRound(round: BracketRound, roundNumber: Int, depth: Int) -> some View {
        VStack(spacing: 16) {
            // 🔥 POLISHED ROUND HEADER
            VStack(spacing: 6) {
                Text(round.roundName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                if roundNumber == tournament.rounds.count {
                    // Finals badge
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("CHAMPIONSHIP")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.8, blue: 0.0),
                                        Color(red: 1.0, green: 0.6, blue: 0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.5), radius: 8, x: 0, y: 4)
                    )
                } else {
                    // Round number badge
                    Text("\(roundNumber)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.primary.opacity(0.15))
                        )
                }
            }
            .padding(.bottom, 4)
            
            // 🔥 MATCHES IN THIS ROUND
            VStack(spacing: 20) {
                ForEach(round.matches) { match in
                    matchCard3D(match: match, depth: depth)
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .frame(minWidth: 240)
        .background(
            ZStack {
                // 🔥 REALISTIC ROUND CONTAINER
                // Base gradient
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.surface.opacity(0.6),
                                AppTheme.Colors.surface.opacity(0.4),
                                AppTheme.Colors.surface.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // 3D highlight
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                
                // Border glow
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.primary.opacity(0.3),
                                AppTheme.Colors.primary.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(
                color: .black.opacity(0.25),
                radius: 20 + Double(depth) * 4,
                x: Double(depth) * 3,
                y: Double(depth) * 3 + 8
            )
        )
        .rotation3DEffect(
            .degrees(Double(depth) * 10), // More pronounced 3D rotation
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .scaleEffect(1.0 - Double(depth) * 0.1) // More scale for realistic perspective
    }
    
    // MARK: - 🔥 REALISTIC 3D MATCH CARD (NBA-STYLE)
    
    @ViewBuilder
    private func matchCard3D(match: BracketMatch, depth: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedMatch = match
            }
            HapticManager.shared.impact(style: .medium)
        }) {
            VStack(spacing: 0) {
                // 🔥 REALISTIC TEAM 1 (Top)
                realisticTeamCard(
                    team: match.team1,
                    isWinner: match.winner == match.team1.id,
                    isTop: true,
                    match: match
                )
                
                // 🔥 REALISTIC VS DIVIDER
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.divider.opacity(0.3),
                                    AppTheme.Colors.divider.opacity(0.1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                    
                    if !match.isCompleted, let scheduledDate = match.scheduledDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 8, weight: .bold))
                            Text(scheduledDate.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.surface.opacity(0.8))
                        )
                    } else if match.isCompleted {
                        Text("FINAL")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary.opacity(0.15))
                            )
                    }
                }
                .padding(.vertical, 6)
                
                // 🔥 REALISTIC TEAM 2 (Bottom)
                realisticTeamCard(
                    team: match.team2,
                    isWinner: match.winner == match.team2.id,
                    isTop: false,
                    match: match
                )
            }
            .frame(width: 200, height: 120)
            .background(
                ZStack {
                    // 🔥 REALISTIC BASE - NBA court style
                    // Base color
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            match.isCompleted ?
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.surface,
                                    AppTheme.Colors.surface.opacity(0.95),
                                    AppTheme.Colors.primary.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.surface.opacity(0.85),
                                    AppTheme.Colors.surface.opacity(0.7),
                                    AppTheme.Colors.surface.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // 3D highlight (realistic lighting)
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                    
                    // Winner glow effect
                    if match.isCompleted {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        AppTheme.Colors.primary.opacity(0.3),
                                        AppTheme.Colors.primary.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                }
            )
            .shadow(
                color: match.isCompleted ? 
                    AppTheme.Colors.primary.opacity(0.35) : 
                    .black.opacity(0.2),
                radius: Double(depth) * 4 + 12,
                x: Double(depth) * 2.5,
                y: Double(depth) * 2.5 + 6
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: match.isCompleted ? [
                                AppTheme.Colors.primary.opacity(0.7),
                                AppTheme.Colors.primary.opacity(0.4),
                                AppTheme.Colors.primary.opacity(0.2)
                            ] : [
                                AppTheme.Colors.divider.opacity(0.5),
                                AppTheme.Colors.divider.opacity(0.3),
                                AppTheme.Colors.divider.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: match.isCompleted ? 3 : 1.5
                    )
            )
            .rotation3DEffect(
                .degrees(selectedMatch?.id == match.id ? 10 : Double(depth) * 3),
                axis: (x: 1, y: 0.6, z: 0),
                perspective: 0.7
            )
            .scaleEffect(selectedMatch?.id == match.id ? 1.1 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selectedMatch?.id)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 🔥 REALISTIC TEAM CARD
    
    @ViewBuilder
    private func realisticTeamCard(team: BracketTeam, isWinner: Bool, isTop: Bool, match: BracketMatch) -> some View {
        HStack(spacing: 12) {
            // 🔥 REALISTIC TEAM AVATAR (NBA-style)
            ZStack {
                // Outer glow for winner
                if isWinner {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppTheme.Colors.primary.opacity(0.4),
                                    AppTheme.Colors.primary.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 30
                            )
                        )
                        .frame(width: 50, height: 50)
                }
                
                // Team avatar circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isWinner ? [
                                AppTheme.Colors.primary,
                                AppTheme.Colors.primary.opacity(0.8)
                            ] : [
                                AppTheme.Colors.surface,
                                AppTheme.Colors.surface.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .overlay(
                        Circle()
                            .stroke(
                                isWinner ? 
                                    AppTheme.Colors.primary.opacity(0.5) :
                                    AppTheme.Colors.divider.opacity(0.3),
                                lineWidth: isWinner ? 2.5 : 1.5
                            )
                    )
                    .shadow(
                        color: isWinner ? AppTheme.Colors.primary.opacity(0.4) : .black.opacity(0.15),
                        radius: isWinner ? 8 : 4,
                        x: 0,
                        y: isWinner ? 4 : 2
                    )
                
                // Team initial/icon
                Text(team.name.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isWinner ? .white : AppTheme.Colors.textPrimary)
            }
            
            // 🔥 TEAM INFO
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(team.name)
                        .font(.system(size: 15, weight: isWinner ? .bold : .semibold))
                        .foregroundColor(isWinner ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    if isWinner {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                
                if match.isCompleted, let score = team.score {
                    Text("\(score)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isWinner ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                } else if !match.isCompleted {
                    Text("TBD")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            
            Spacer()
            
            // 🔥 SCORE DISPLAY (if completed)
            if match.isCompleted, let score = team.score {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isWinner ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    
                    if isWinner {
                        Text("WIN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Group {
                if isWinner {
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.primary.opacity(0.12),
                            AppTheme.Colors.primary.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Color.clear
                }
            }
        )
    }
    
}

// MARK: - Bracket Tournament Models

struct BracketTournament: Identifiable {
    let id: String
    let name: String
    let rounds: [BracketRound]
    let startDate: Date
    let endDate: Date
    let prizePool: Double
}

struct BracketRound: Identifiable {
    let id: String
    let matches: [BracketMatch]
    let roundName: String
}

struct BracketMatch: Identifiable {
    let id: String
    var team1: BracketTeam
    var team2: BracketTeam
    let winner: String?
    let isCompleted: Bool
    let scheduledDate: Date?
    
    init(id: String, team1: BracketTeam, team2: BracketTeam, winner: String?, isCompleted: Bool, scheduledDate: Date?, score1: Int? = nil, score2: Int? = nil) {
        self.id = id
        var t1 = team1
        var t2 = team2
        t1.score = score1
        t2.score = score2
        self.team1 = t1
        self.team2 = t2
        self.winner = winner
        self.isCompleted = isCompleted
        self.scheduledDate = scheduledDate
    }
}

struct BracketTeam: Identifiable {
    let id: String
    let name: String
    var score: Int?
}

// MARK: - Preview Data

extension BracketTournament {
    static let sample = BracketTournament(
        id: "1",
        name: "MyChannel Championship Finals",
        rounds: [
            BracketRound(
                id: "r1",
                matches: [
                    BracketMatch(id: "m1", team1: BracketTeam(id: "t1", name: "Thunder Squad"), team2: BracketTeam(id: "t2", name: "Fire Hawks"), winner: "t1", isCompleted: true, scheduledDate: nil, score1: 127, score2: 98),
                    BracketMatch(id: "m2", team1: BracketTeam(id: "t3", name: "Storm Riders"), team2: BracketTeam(id: "t4", name: "Ice Breakers"), winner: "t3", isCompleted: true, scheduledDate: nil, score1: 115, score2: 102),
                    BracketMatch(id: "m3", team1: BracketTeam(id: "t5", name: "Dragon Force"), team2: BracketTeam(id: "t6", name: "Phoenix Rising"), winner: "t5", isCompleted: true, scheduledDate: nil, score1: 108, score2: 94),
                    BracketMatch(id: "m4", team1: BracketTeam(id: "t7", name: "Shadow Warriors"), team2: BracketTeam(id: "t8", name: "Lightning Strike"), winner: "t7", isCompleted: true, scheduledDate: nil, score1: 132, score2: 89)
                ],
                roundName: "Quarterfinals"
            ),
            BracketRound(
                id: "r2",
                matches: [
                    BracketMatch(id: "m5", team1: BracketTeam(id: "t1", name: "Thunder Squad"), team2: BracketTeam(id: "t3", name: "Storm Riders"), winner: "t1", isCompleted: true, scheduledDate: nil, score1: 121, score2: 109),
                    BracketMatch(id: "m6", team1: BracketTeam(id: "t5", name: "Dragon Force"), team2: BracketTeam(id: "t7", name: "Shadow Warriors"), winner: nil, isCompleted: false, scheduledDate: Date().addingTimeInterval(86400), score1: nil, score2: nil)
                ],
                roundName: "Semifinals"
            ),
            BracketRound(
                id: "r3",
                matches: [
                    BracketMatch(id: "m7", team1: BracketTeam(id: "t1", name: "Thunder Squad"), team2: BracketTeam(id: "t5", name: "Dragon Force"), winner: nil, isCompleted: false, scheduledDate: Date().addingTimeInterval(172800), score1: nil, score2: nil)
                ],
                roundName: "Finals"
            ),
            BracketRound(
                id: "r4",
                matches: [
                    BracketMatch(id: "m8", team1: BracketTeam(id: "t1", name: "Thunder Squad"), team2: BracketTeam(id: "t9", name: "TBD"), winner: nil, isCompleted: false, scheduledDate: Date().addingTimeInterval(259200), score1: nil, score2: nil)
                ],
                roundName: "Championship"
            )
        ],
        startDate: Date(),
        endDate: Date().addingTimeInterval(604800),
        prizePool: 125000
    )
}

#Preview {
    ScrollView {
        TournamentBracket3DView(tournament: .sample)
            .padding()
    }
    .background(AppTheme.Colors.background)
}

