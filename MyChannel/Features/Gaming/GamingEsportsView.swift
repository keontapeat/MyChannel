//
//  GamingEsportsView.swift
//  MyChannel
//
//  Created by AI Assistant
//

import SwiftUI

struct GamingEsportsView: View {
    @StateObject private var viewModel = GamingEsportsViewModel()
    @State private var selectedTab: GamingTab = .tournaments
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    esportsHeader
                    
                    // Tab Navigation
                    tabNavigation
                    
                    // Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            switch selectedTab {
                            case .tournaments:
                                tournamentsContent
                            case .vsMatches:
                                vsMatchesContent
                            case .leaderboard:
                                leaderboardContent
                            case .myEarnings:
                                myEarningsContent
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await viewModel.loadData()
        }
    }
    
    // MARK: - Header
    
    private var esportsHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Esports Arena")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Compete. Win Money. Rise to the Top.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Live indicator
                if viewModel.hasLiveTournaments {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text("LIVE")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 20)
        }
        .background(
            AppTheme.Colors.surface
                .ignoresSafeArea(edges: .top)
        )
    }
    
    // MARK: - Tab Navigation
    
    private var tabNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(GamingTab.allCases) { tab in
                    tabButton(tab: tab)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 56)
        .background(AppTheme.Colors.surface)
    }
    
    private func tabButton(tab: GamingTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: tab.iconName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    
                    Text(tab.title)
                        .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                
                // Selection indicator
                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(height: 2)
                    .scaleEffect(x: selectedTab == tab ? 1.0 : 0.0, y: 1.0, anchor: .center)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
    
    // MARK: - Tournaments Content
    
    private var tournamentsContent: some View {
        VStack(spacing: 24) {
            // Featured Tournament
            if let featured = viewModel.featuredTournament {
                featuredTournamentCard(tournament: featured)
            }
            
            // Tournament List
            VStack(spacing: 12) {
                HStack {
                    Text("Active Tournaments")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(viewModel.activeTournaments.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.surface)
                        )
                }
                
                ForEach(viewModel.activeTournaments) { tournament in
                    tournamentCard(tournament: tournament)
                }
            }
        }
    }
    
    private func featuredTournamentCard(tournament: Tournament) -> some View {
        VStack(spacing: 0) {
            // Background Image
            ZStack {
                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(spacing: 16) {
                    // Title
                    Text(tournament.name.uppercased())
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // Prize Pool
                    Text(tournament.formattedPrizePool)
                        .font(.system(size: 42, weight: .black))
                        .foregroundColor(Color(hex: "#FFD700"))
                    
                    // Format
                    Text(tournament.format)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    // Stats
                    HStack(spacing: 32) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("\(tournament.currentPlayers)/\(tournament.maxPlayers)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(tournament.timeRemaining)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Join Button
                    Button(action: {
                        // Join tournament
                    }) {
                        Text("JOIN NOW")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#DC143C"), Color(hex: "#8B0000")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
            }
            .frame(height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient(
                        colors: [Color(hex: "#FFD700").opacity(0.5), Color(hex: "#DC143C").opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 2)
            )
        }
    }
    
    private func tournamentCard(tournament: Tournament) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Game Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(tournament.gameName)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Live badge
                if tournament.isLive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        
                        Text("LIVE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }
            
            // Prize Pool
            HStack {
                Text(tournament.formattedPrizePool)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "#FFD700"))
                
                Spacer()
                
                Text(tournament.format)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            // Stats
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("\(tournament.currentPlayers)/\(tournament.maxPlayers)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(tournament.timeRemaining)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Entry fee
                Text("Entry: \(tournament.formattedEntryFee)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            // Join Button
            Button(action: {
                // Join tournament
            }) {
                Text(tournament.isFull ? "FULL" : "JOIN")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        tournament.isFull ? Color.gray : AppTheme.Colors.primary
                    )
                    .cornerRadius(10)
            }
            .disabled(tournament.isFull)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - VS Matches Content
    
    private var vsMatchesContent: some View {
        VStack(spacing: 24) {
            // Create Match Button
            Button(action: {
                // Create match
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Create VS Match")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.Colors.primary)
                .cornerRadius(12)
            }
            
            // Active Matches
            VStack(spacing: 12) {
                HStack {
                    Text("Active Matches")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                }
                
                ForEach(viewModel.activeMatches) { match in
                    vsMatchCard(match: match)
                }
            }
        }
    }
    
    private func vsMatchCard(match: VSMatch) -> some View {
        VStack(spacing: 16) {
            // Match Header with Status Badge
            HStack {
                Text(match.category)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                // Verification Status Badge
                if match.verificationStatus == .verified {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                        
                        Text("VERIFIED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.1))
                    )
                } else if match.verificationStatus == .pending {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Text("PENDING")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.1))
                    )
                } else if match.verificationStatus == .disputed {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                        
                        Text("DISPUTED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                    )
                }
                
                Text(match.formattedWager)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#FFD700"))
            }
            
            // Competitors
            HStack(spacing: 12) {
                // Player 1
                VStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        )
                    
                    Text(match.challenger.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                
                // VS
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 44, height: 44)
                    
                    Text("VS")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                // Player 2
                if let opponent = match.opponent {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            )
                        
                        Text(opponent.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            )
                        
                        Text("Waiting")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Action Buttons
            if match.needsProofSubmission {
                // Submit Result Button
                NavigationLink(destination: MatchResultSubmissionView(match: BracketMatch(
                    id: match.id,
                    team1: BracketTeam(id: match.challenger.id, name: match.challenger.displayName, logoURL: nil, seed: 1),
                    team2: BracketTeam(id: match.opponent?.id ?? "", name: match.opponent?.displayName ?? "Opponent", logoURL: nil, seed: 2),
                    winnerId: nil,
                    startTime: match.createdAt,
                    status: "in_progress"
                ))) {
                    HStack(spacing: 8) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("SUBMIT RESULT")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(10)
                }
            } else {
                Button(action: {
                    // Accept/View match
                }) {
                    Text(match.opponent == nil ? "ACCEPT CHALLENGE" : "VIEW MATCH")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            match.verificationStatus == .verified ? Color.green.opacity(0.3) :
                            match.verificationStatus == .disputed ? Color.red.opacity(0.3) :
                            AppTheme.Colors.divider.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Leaderboard Content
    
    private var leaderboardContent: some View {
        VStack(spacing: 24) {
            // Filter Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LeaderboardPeriod.allCases) { period in
                        periodButton(period: period)
                    }
                }
            }
            
            // Top 3 Podium
            topThreePodium
            
            // Leaderboard List
            VStack(spacing: 0) {
                ForEach(Array(viewModel.leaderboardUsers.enumerated()), id: \.element.id) { index, user in
                    leaderboardRow(user: user, rank: index + 1)
                    
                    if index < viewModel.leaderboardUsers.count - 1 {
                        Divider()
                            .background(AppTheme.Colors.divider.opacity(0.1))
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
            )
        }
    }
    
    private func periodButton(period: LeaderboardPeriod) -> some View {
        Button(action: {
            viewModel.selectedPeriod = period
        }) {
            Text(period.title)
                .font(.system(size: 14, weight: viewModel.selectedPeriod == period ? .semibold : .regular))
                .foregroundColor(viewModel.selectedPeriod == period ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(viewModel.selectedPeriod == period ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                )
        }
    }
    
    private var topThreePodium: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 2nd Place
            if viewModel.leaderboardUsers.count > 1 {
                podiumPlace(user: viewModel.leaderboardUsers[1], rank: 2, height: 140)
            }
            
            // 1st Place
            if viewModel.leaderboardUsers.count > 0 {
                podiumPlace(user: viewModel.leaderboardUsers[0], rank: 1, height: 180)
            }
            
            // 3rd Place
            if viewModel.leaderboardUsers.count > 2 {
                podiumPlace(user: viewModel.leaderboardUsers[2], rank: 3, height: 120)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func podiumPlace(user: LeaderboardUser, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: 12) {
            // Medal
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: rank == 1 ? [Color(hex: "#FFD700"), Color(hex: "#FFA500")] :
                                    rank == 2 ? [Color(hex: "#C0C0C0"), Color(hex: "#A8A8A8")] :
                                    [Color(hex: "#CD7F32"), Color(hex: "#8B4513")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: rank == 1 ? 80 : 60, height: rank == 1 ? 80 : 60)
                
                Text("\(rank)")
                    .font(.system(size: rank == 1 ? 32 : 24, weight: .black))
                    .foregroundColor(.white)
            }
            
            // Profile
            Circle()
                .fill(AppTheme.Colors.surface)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                )
            
            // Name
            Text(user.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(1)
            
            // Earnings
            Text(user.formattedEarnings)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#FFD700"))
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            rank == 1 ? Color(hex: "#FFD700").opacity(0.5) :
                            rank == 2 ? Color(hex: "#C0C0C0").opacity(0.5) :
                            Color(hex: "#CD7F32").opacity(0.5),
                            lineWidth: 2
                        )
                )
        )
    }
    
    private func leaderboardRow(user: LeaderboardUser, rank: Int) -> some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 32)
            
            // Profile
            Circle()
                .fill(AppTheme.Colors.surface)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("\(user.wins) wins • \(user.matches) matches")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Earnings
            Text(user.formattedEarnings)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#FFD700"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - My Earnings Content
    
    private var myEarningsContent: some View {
        VStack(spacing: 24) {
            // Total Earnings Card
            totalEarningsCard
            
            // Stats Grid
            statsGrid
            
            // Recent Transactions
            VStack(spacing: 12) {
                HStack {
                    Text("Recent Transactions")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                }
                
                ForEach(viewModel.recentTransactions) { transaction in
                    transactionRow(transaction: transaction)
                }
            }
        }
    }
    
    private var totalEarningsCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Total Earnings")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(viewModel.formattedTotalEarnings)
                    .font(.system(size: 42, weight: .black))
                    .foregroundColor(Color(hex: "#FFD700"))
            }
            
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(viewModel.formattedAvailableBalance)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Available")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                    .background(AppTheme.Colors.divider.opacity(0.2))
                
                VStack(spacing: 4) {
                    Text(viewModel.formattedPendingBalance)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Pending")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    // Deposit
                }) {
                    Text("Deposit")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // Withdraw
                }) {
                    Text("Withdraw")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FFD700").opacity(0.3), Color(hex: "#DC143C").opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            statCard(title: "Tournaments Won", value: "\(viewModel.tournamentsWon)", icon: "trophy.fill", color: Color(hex: "#FFD700"))
            statCard(title: "VS Wins", value: "\(viewModel.vsWins)", icon: "flag.checkered", color: AppTheme.Colors.primary)
            statCard(title: "Win Rate", value: "\(viewModel.winRate)%", icon: "chart.line.uptrend.xyaxis", color: Color.green)
            statCard(title: "Total Matches", value: "\(viewModel.totalMatches)", icon: "gamecontroller.fill", color: Color.blue)
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func transactionRow(transaction: EarningsTransaction) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(transaction.isPositive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: transaction.isPositive ? "arrow.down.left" : "arrow.up.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(transaction.isPositive ? Color.green : Color.red)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(transaction.formattedDate)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Amount
            Text(transaction.formattedAmount)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(transaction.isPositive ? Color.green : Color.red)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Supporting Types

enum GamingTab: String, CaseIterable, Identifiable {
    case tournaments
    case vsMatches
    case leaderboard
    case myEarnings
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .tournaments: return "Tournaments"
        case .vsMatches: return "VS Matches"
        case .leaderboard: return "Leaderboard"
        case .myEarnings: return "My Earnings"
        }
    }
    
    var iconName: String {
        switch self {
        case .tournaments: return "trophy.fill"
        case .vsMatches: return "person.2.fill"
        case .leaderboard: return "chart.bar.fill"
        case .myEarnings: return "dollarsign.circle.fill"
        }
    }
}

enum LeaderboardPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case allTime
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .daily: return "Today"
        case .weekly: return "This Week"
        case .monthly: return "This Month"
        case .allTime: return "All Time"
        }
    }
}

struct Tournament: Identifiable {
    let id: String
    let name: String
    let gameName: String
    let prizePool: Double
    let entryFee: Double
    let format: String
    let currentPlayers: Int
    let maxPlayers: Int
    let startDate: Date
    let isLive: Bool
    
    var formattedPrizePool: String {
        "$\(Int(prizePool).formatted())"
    }
    
    var formattedEntryFee: String {
        "$\(Int(entryFee))"
    }
    
    var timeRemaining: String {
        let interval = startDate.timeIntervalSinceNow
        if interval < 0 { return "Started" }
        
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
    
    var isFull: Bool {
        currentPlayers >= maxPlayers
    }
}

struct VSMatch: Identifiable {
    let id: String
    let challenger: User
    let opponent: User?
    let category: String
    let wagerAmount: Double
    let createdAt: Date
    var verificationStatus: MatchVerificationStatus = .none
    var needsProofSubmission: Bool = false
    
    var formattedWager: String {
        "$\(Int(wagerAmount).formatted())"
    }
}

enum MatchVerificationStatus {
    case none
    case pending
    case verified
    case disputed
}

struct LeaderboardUser: Identifiable {
    let id: String
    let displayName: String
    let totalEarnings: Double
    let wins: Int
    let matches: Int
    
    var formattedEarnings: String {
        "$\(Int(totalEarnings).formatted())"
    }
}

struct EarningsTransaction: Identifiable {
    let id: String
    let description: String
    let amount: Double
    let date: Date
    let type: TransactionType
    
    enum TransactionType {
        case win, loss, deposit, withdrawal
    }
    
    var isPositive: Bool {
        type == .win || type == .deposit
    }
    
    var formattedAmount: String {
        let prefix = isPositive ? "+" : "-"
        return "\(prefix)$\(Int(abs(amount)).formatted())"
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Color extension for hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    GamingEsportsView()
}

