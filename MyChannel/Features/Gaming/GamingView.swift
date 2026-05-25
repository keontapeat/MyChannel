//
//  GamingView.swift
//  MyChannel
//
//  MYCHANNEL GAMING - Tournaments, leaderboards, live streams
//  Compete for REAL MONEY prizes
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct GamingView: View {
    @StateObject private var viewModel = GamingViewModel()
    @State private var selectedTournament: GamingTournament?
    @State private var showCreateTeam = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        gamingHero
                        
                        // Active Tournaments
                        activeTournamentsSection
                        
                        // Your Teams
                        yourTeamsSection
                        
                        // Live Matches
                        liveMatchesSection
                        
                        // Leaderboard
                        leaderboardSection
                        
                        // Prize Pool
                        prizePoolSection
                        
                        // Upcoming Events
                        upcomingEventsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Gaming")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedTournament) { tournament in
            TournamentDetailSheet(tournament: tournament)
        }
        .sheet(isPresented: $showCreateTeam) {
            CreateTeamSheet(viewModel: viewModel)
        }
        .onAppear {
            Task {
                await viewModel.loadGamingData()
            }
        }
    }
    
    // MARK: - Hero Section
    private var gamingHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            // 🔥 PlayStation blue + DraftKings green + YouTube sleek vibe
                            Color(red: 0.0, green: 0.3, blue: 0.8),  // PlayStation blue
                            Color(red: 0.0, green: 0.5, blue: 0.7),  // Teal accent
                            Color(red: 0.1, green: 0.6, blue: 0.3)   // DraftKings green
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 240)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 32, weight: .bold))
                    Text("Gaming")
                        .font(.system(size: 28, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Compete in tournaments, win real money")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "trophy.fill", text: "Tournaments")
                    featureBadge(icon: "dollarsign.circle.fill", text: "$500K+ Prizes")
                    featureBadge(icon: "person.3.fill", text: "Teams")
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("$\(viewModel.totalPrizePool)")
                            .font(.system(size: 24, weight: .bold))
                        Text("Total Prize Pool")
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(viewModel.activePlayers)")
                            .font(.system(size: 24, weight: .bold))
                        Text("Active Players")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - Active Tournaments
    private var activeTournamentsSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text("Active Tournaments")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            ForEach(viewModel.activeTournaments) { tournament in
                TournamentCard(tournament: tournament) {
                    selectedTournament = tournament
                }
            }
        }
    }
    
    // MARK: - Your Teams
    private var yourTeamsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Teams")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    showCreateTeam = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Team")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if viewModel.yourTeams.isEmpty {
                EmptyTeamsView()
            } else {
                ForEach(viewModel.yourTeams) { team in
                    TeamCard(team: team)
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Live Matches
    private var liveMatchesSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    
                    Text("LIVE MATCHES")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                Text("\(viewModel.liveMatches.count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.liveMatches) { match in
                        LiveMatchCard(match: match)
                    }
                }
            }
        }
    }
    
    // MARK: - Leaderboard
    private var leaderboardSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("Global Leaderboard")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                NavigationLink(destination: Text("Full Leaderboard")) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ForEach(Array(viewModel.topPlayers.enumerated()), id: \.element.id) { index, player in
                LeaderboardRow(rank: index + 1, player: player)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Prize Pool
    private var prizePoolSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("This Month's Prize Pool")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                Text("$\(viewModel.monthlyPrizePool)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.green)
                
                HStack(spacing: 16) {
                    PrizeBreakdown(place: "1st", amount: "$50,000", color: Color(red: 1.0, green: 0.8, blue: 0.0))
                    PrizeBreakdown(place: "2nd", amount: "$25,000", color: Color(red: 0.7, green: 0.7, blue: 0.7))
                    PrizeBreakdown(place: "3rd", amount: "$15,000", color: Color(red: 0.8, green: 0.5, blue: 0.2))
                }
                
                Text("Top 100 players win prizes!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Upcoming Events
    private var upcomingEventsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Upcoming Events")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            ForEach(viewModel.upcomingEvents) { event in
                UpcomingEventCard(event: event)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct TournamentCard: View {
    let tournament: GamingTournament
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(tournament.game.emoji)
                                .font(.system(size: 24))
                            
                            Text(tournament.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        
                        Text(tournament.game.name)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(tournament.prizePool)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("Prize Pool")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 12))
                        Text("\(tournament.participants)/\(tournament.maxParticipants)")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                        Text(tournament.timeRemaining)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(tournament.format)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
                
                if tournament.participants < tournament.maxParticipants {
                    Button {
                        // Join tournament
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14, weight: .bold))
                            Text("Join Tournament")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Tournament Full")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(18)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(tournament.game.color.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

struct TeamCard: View {
    let team: GamingTeam
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(team.color.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Text(team.tag)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(team.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(team.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 11))
                        Text("\(team.members) members")
                            .font(.system(size: 13))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                        Text("\(team.wins)W-\(team.losses)L")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("#\(team.rank)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Rank")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct EmptyTeamsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No teams yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Create or join a team to compete!")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct LiveMatchCard: View {
    let match: LiveMatch
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                
                Text("LIVE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11))
                    Text(match.viewers.abbreviated)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            VStack(spacing: 10) {
                HStack {
                    Text(match.team1)
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text("\(match.team1Score)")
                        .font(.system(size: 18, weight: .bold))
                }
                
                Rectangle()
                    .fill(AppTheme.Colors.divider)
                    .frame(height: 1)
                
                HStack {
                    Text(match.team2)
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text("\(match.team2Score)")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .foregroundColor(AppTheme.Colors.textPrimary)
            
            Button {
                // Watch match
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                    Text("Watch")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: 200)
        .padding(14)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let player: GamingPlayer
    
    var medalColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.8, blue: 0.0)
        case 2: return Color(red: 0.7, green: 0.7, blue: 0.7)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return AppTheme.Colors.textSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(medalColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                if rank <= 3 {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(medalColor)
                } else {
                    Text("#\(rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
            
            AsyncImage(url: URL(string: player.avatarURL)) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(AppTheme.Colors.cardBackground)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("\(player.totalPoints) pts")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(player.earnings)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.green)
                
                Text("\(player.wins)W")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(12)
        .background(rank <= 3 ? medalColor.opacity(0.05) : AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(rank <= 3 ? medalColor.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

struct PrizeBreakdown: View {
    let place: String
    let amount: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(place)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            Text(amount)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct UpcomingEventCard: View {
    let event: GamingEvent
    
    var body: some View {
        HStack(spacing: 14) {
            Text(event.game.emoji)
                .font(.system(size: 40))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(event.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(event.game.name)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(event.startDate, style: .date)
                        .font(.system(size: 12))
                }
                .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(event.prizePool)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                
                Text("Prize")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Tournament Detail Sheet
struct TournamentDetailSheet: View {
    let tournament: GamingTournament
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Full tournament details coming soon")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(24)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(tournament.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Create Team Sheet
struct CreateTeamSheet: View {
    @ObservedObject var viewModel: GamingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var teamName = ""
    @State private var teamTag = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Create your team")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    // Team creation form would go here
                }
                .padding(24)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Create Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    GamingView()
}

