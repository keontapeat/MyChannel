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
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCreateMatch = false
    @State private var joiningTournamentId: String? = nil
    @State private var acceptingMatchId: String? = nil
    @State private var joinAlertMessage: String? = nil
    @State private var showJoinAlert = false
    
    var body: some View {
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
                        case .bracket:
                            bracketContent
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
        .task {
            await viewModel.loadData()
        }
        .onChange(of: viewModel.selectedPeriod) { period in
            Task {
                await viewModel.refreshLeaderboard(for: period)
            }
        }
        .sheet(isPresented: $showingCreateMatch) {
            // 🔥 FIX 3.1.1/5.3.4: Gate real-money wagering behind feature flag
            if AppConfig.Features.enableCreatorMonetization {
                VersusMatchCreatorView()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Competitive Matches Coming Soon")
                        .font(.title3.bold())
                    Text("1v1 matches will be available in a future update.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .alert(joinAlertMessage ?? "", isPresented: $showJoinAlert) {
            Button("OK", role: .cancel) {}
        }
    }
    
    // MARK: - Header
    
    private var esportsHeader: some View {
        VStack(spacing: 12) {
            HStack {
                // Back button
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.surface)
                        )
                }
                .accessibilityLabel("Go back")
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Esports Arena")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Compete. Win Money. Rise to the Top.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Esports Arena. Compete, Win Money, Rise to the Top.")
                
                Spacer()
                
                // 🔥 AI Status Indicator
                if viewModel.isAIOnline {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(viewModel.aiAgentsOnline)/7")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.15))
                    )
                    .accessibilityLabel("\(viewModel.aiAgentsOnline) of 7 AI agents online")
                }
                
                // Live indicator with pulsing animation
                if viewModel.hasLiveTournaments {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.5), lineWidth: 2)
                                    .scaleEffect(1.5)
                                    .opacity(0)
                                    .animation(
                                        .easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: false),
                                        value: viewModel.hasLiveTournaments
                                    )
                            )
                        
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
                    .accessibilityLabel("Live tournaments available")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 16)
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
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: tab.iconName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                        .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                    
                    Text(tab.title)
                        .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                
                // Selection indicator with spring animation
                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(height: 3)
                    .scaleEffect(x: selectedTab == tab ? 1.0 : 0.0, y: 1.0, anchor: .center)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("\(tab.title) tab")
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
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
    
    private func featuredTournamentCard(tournament: GamingEsportsTournament) -> some View {
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
                        .foregroundColor(Color(hexString: "#FFD700"))
                    
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
                        if let t = viewModel.featuredTournament {
                            joinTournament(t)
                        }
                    }) {
                        Group {
                            if let t = viewModel.featuredTournament, joiningTournamentId == t.id {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(height: 52)
                            } else {
                                Text("JOIN NOW")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color(hexString: "#DC143C") ?? .red, Color(hexString: "#8B0000") ?? Color(red: 0.55, green: 0, blue: 0)],
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
                        colors: [(Color(hexString: "#FFD700") ?? .yellow).opacity(0.5), (Color(hexString: "#DC143C") ?? .red).opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 2)
            )
        }
    }
    
    private func tournamentCard(tournament: GamingEsportsTournament) -> some View {
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
                    .foregroundColor(Color(hexString: "#FFD700"))
                
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
                joinTournament(tournament)
            }) {
                Group {
                    if joiningTournamentId == tournament.id {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(tournament.isFull ? "FULL" : "JOIN")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(tournament.isFull ? Color.gray : AppTheme.Colors.primary)
                .cornerRadius(10)
            }
            .disabled(tournament.isFull || joiningTournamentId == tournament.id)
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
    
    // MARK: - 3D Bracket Content

    private var bracketContent: some View {
        VStack(spacing: 20) {
            // Section header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red:1,green:0.84,blue:0), Color(red:1,green:0.55,blue:0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIVE BRACKET")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .tracking(0.5)
                    Text("3D interactive tournament bracket")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                Spacer()
                if viewModel.hasLiveTournaments {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                        Text("LIVE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.red.opacity(0.12)))
                }
            }
            .padding(.horizontal, 4)

            // Featured bracket
            if let featured = viewModel.featuredTournament {
                TournamentBracket3DView(tournament: Bracket3DTournament(
                    id: featured.id,
                    name: featured.name,
                    rounds: Bracket3DTournament.sample.rounds,
                    startDate: featured.startDate,
                    endDate: featured.startDate.addingTimeInterval(604800),
                    prizePool: featured.prizePool
                ))
                .padding(.horizontal, -20)
            } else {
                TournamentBracket3DView(tournament: .sample)
                    .padding(.horizontal, -20)
            }

            // AI Bracket Insight Card
            if let insight = viewModel.aiBracketInsight {
                aiBracketInsightCard(insight: insight)
            }

            // Browse all active tournaments
            if viewModel.activeTournaments.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ALL ACTIVE BRACKETS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .tracking(1.4)
                        .padding(.horizontal, 4)

                    ForEach(viewModel.activeTournaments.dropFirst()) { tournament in
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.Colors.primary.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "gamecontroller.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tournament.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                    Text(tournament.gameName)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(tournament.formattedPrizePool)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red:1,green:0.84,blue:0))
                                    if tournament.isLive {
                                        Text("LIVE")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.red))
                                    }
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(AppTheme.Colors.divider.opacity(0.15), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private func aiBracketInsightCard(insight: AIBracketInsight) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red:0.4,green:0.2,blue:1.0), Color(red:0.2,green:0.8,blue:0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("AI Bracket Analysis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text("\(Int(insight.fairnessScore * 100))% fair")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                insight.fairnessScore > 0.8
                                    ? Color.green
                                    : insight.fairnessScore > 0.6
                                        ? Color.orange
                                        : AppTheme.Colors.primary
                            )
                        )
                }
                Text(insight.insight)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                if let champion = insight.predictedChampion {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red:1,green:0.84,blue:0))
                        Text("Predicted: @\(champion.prefix(8))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(Int(insight.confidence * 100))%")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(Color(red:0.4,green:0.2,blue:1.0))
                Text("conf.")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.surface)
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(red:0.4,green:0.2,blue:1.0).opacity(0.07), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(red:0.4,green:0.2,blue:1.0).opacity(0.18), lineWidth: 1)
            }
        )
    }

    // MARK: - VS Matches Content
    
    private var vsMatchesContent: some View {
        VStack(spacing: 24) {
            // Create Match Button
            Button(action: {
                showingCreateMatch = true
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
            matchHeader(match: match)
            competitorsSection(match: match)
            actionButtons(match: match)
        }
        .padding(16)
        .background(cardBackground(match: match))
    }
    
    private func matchHeader(match: VSMatch) -> some View {
        HStack {
            Text(match.category)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
            
            verificationStatusBadge(status: match.verificationStatus)
            
            Text(match.formattedWager)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hexString: "#FFD700") ?? .yellow)
        }
    }
    
    private func verificationStatusBadge(status: MatchVerificationStatus) -> some View {
        Group {
            if status == .verified {
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
            } else if status == .pending {
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
            } else if status == .disputed {
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
        }
    }
    
    private func competitorsSection(match: VSMatch) -> some View {
        HStack(spacing: 12) {
            playerView(name: match.challenger.displayName)
            
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 44, height: 44)
                
                Text("VS")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            if let opponent = match.opponent {
                playerView(name: opponent.displayName)
            } else {
                waitingPlayerView
            }
        }
    }
    
    private func playerView(name: String) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(AppTheme.Colors.surface)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                )
            
            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var waitingPlayerView: some View {
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
    
    private func actionButtons(match: VSMatch) -> some View {
        Group {
            if match.needsProofSubmission {
                submitResultButton(match: match)
            } else {
                acceptOrViewButton(match: match)
            }
        }
    }
    
    private func submitResultButton(match: VSMatch) -> some View {
        let team1 = BracketTeam(id: match.challenger.id, name: match.challenger.displayName)
        let team2: BracketTeam? = match.opponent.map { BracketTeam(id: $0.id, name: $0.displayName) }
        
        let bracketMatch = BracketMatch(
            id: match.id,
            team1: team1,
            team2: team2,
            score1: nil,
            score2: nil,
            winner: nil,
            isLive: true
        )
        
        return NavigationLink(destination: MatchResultSubmissionView(match: bracketMatch)) {
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
    }
    
    private func acceptOrViewButton(match: VSMatch) -> some View {
        Button(action: {
            if match.opponent == nil {
                acceptChallenge(match)
            }
        }) {
            Group {
                if acceptingMatchId == match.id {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(match.opponent == nil ? "ACCEPT CHALLENGE" : "VIEW MATCH")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AppTheme.Colors.primary)
            .cornerRadius(10)
        }
        .disabled(acceptingMatchId == match.id)
    }
    
    private func cardBackground(match: VSMatch) -> some View {
        let borderColor: Color = {
            switch match.verificationStatus {
            case .verified: return Color.green.opacity(0.3)
            case .disputed: return Color.red.opacity(0.3)
            default: return AppTheme.Colors.divider.opacity(0.1)
            }
        }()
        
        return RoundedRectangle(cornerRadius: 12)
            .fill(AppTheme.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
    
    // MARK: - Leaderboard Content
    
    private var leaderboardContent: some View {
        VStack(spacing: 24) {
            // AI Status strip
            aiLeaderboardBanner

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
    
    // MARK: - AI Status Banner (Leaderboard)

    private var aiLeaderboardBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red:0.4,green:0.2,blue:1.0), Color(red:0.2,green:0.6,blue:1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("AI-Ranked Leaderboard")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    if viewModel.isAIRefreshingRankings {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                            .scaleEffect(0.65)
                    }
                }
                Text("\(viewModel.aiAgentsOnlineCount)/7 agents online · \(viewModel.aiTotalPredictionsCount) predictions made")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            if viewModel.aiRankingConfidence > 0 {
                VStack(spacing: 2) {
                    Text("\(Int(viewModel.aiRankingConfidence * 100))%")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(Color(red:0.4,green:0.2,blue:1.0))
                    Text("ELO conf.")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.Colors.surface)
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color(red:0.4,green:0.2,blue:1.0).opacity(0.08), Color.clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(red:0.4,green:0.2,blue:1.0).opacity(0.2), lineWidth: 1)
            }
        )
    }

    private func periodButton(period: LeaderboardPeriod) -> some View {
        Button(action: {
            viewModel.selectedPeriod = period
            Task { await viewModel.refreshLeaderboardWithAI(for: period) }
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
                            colors: rank == 1 ? [Color(hexString: "#FFD700") ?? .yellow, Color(hexString: "#FFA500") ?? .orange] :
                                    rank == 2 ? [Color(hexString: "#C0C0C0") ?? .gray, Color(hexString: "#A8A8A8") ?? .gray] :
                                    [Color(hexString: "#CD7F32") ?? .brown, Color(hexString: "#8B4513") ?? .brown],
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
                .foregroundColor(Color(hexString: "#FFD700"))
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            (rank == 1 ? (Color(hexString: "#FFD700") ?? .yellow).opacity(0.5) :
                             rank == 2 ? (Color(hexString: "#C0C0C0") ?? .gray).opacity(0.5) :
                             (Color(hexString: "#CD7F32") ?? .brown).opacity(0.5)),
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
                .foregroundColor(Color(hexString: "#FFD700"))
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
                
                // 🔥 Animated count-up for total earnings
                AnimatedStatText(
                    value: viewModel.totalEarnings,
                    prefix: "$",
                    font: .system(size: 42, weight: .black),
                    color: Color(hexString: "#FFD700") ?? .yellow
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total Earnings: \(viewModel.formattedTotalEarnings)")
            
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    // 🔥 Animated available balance
                    AnimatedStatText(
                        value: viewModel.availableBalance,
                        prefix: "$",
                        font: .system(size: 18, weight: .bold),
                        color: AppTheme.Colors.textPrimary
                    )
                    
                    Text("Available")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Available balance: \(viewModel.formattedAvailableBalance)")
                
                Divider()
                    .frame(height: 40)
                    .background(AppTheme.Colors.divider.opacity(0.2))
                
                VStack(spacing: 4) {
                    // 🔥 Animated pending balance
                    AnimatedStatText(
                        value: viewModel.pendingBalance,
                        prefix: "$",
                        font: .system(size: 18, weight: .bold),
                        color: AppTheme.Colors.textPrimary
                    )
                    
                    Text("Pending")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Pending balance: \(viewModel.formattedPendingBalance)")
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
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
                .accessibilityLabel("Deposit funds")
                
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
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
                .accessibilityLabel("Withdraw funds")
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
                                colors: [(Color(hexString: "#FFD700") ?? .yellow).opacity(0.3), (Color(hexString: "#DC143C") ?? .red).opacity(0.3)],
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
            statCard(title: "Tournaments Won", value: "\(viewModel.tournamentsWon)", icon: "trophy.fill", color: Color(hexString: "#FFD700") ?? .yellow)
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
    
    // MARK: - Actions
    
    private func joinTournament(_ tournament: GamingEsportsTournament) {
        guard joiningTournamentId == nil else { return }
        guard let userId = AuthenticationManager.shared.currentUser?.id ?? AppState.shared.currentUser?.id else {
            joinAlertMessage = "Sign in to join tournaments."
            showJoinAlert = true
            return
        }
        guard !tournament.isFull else { return }
        
        joiningTournamentId = tournament.id
        HapticManager.shared.impact(style: .medium)
        
        Task {
            do {
                try await EsportsTournamentService.shared.joinTournament(
                    tournamentId: tournament.id,
                    userId: userId
                )
                await viewModel.loadData()
                joinAlertMessage = "You joined \(tournament.name)! 🏆"
                HapticManager.shared.notification(type: .success)
            } catch {
                joinAlertMessage = "Failed to join: \(error.localizedDescription)"
                HapticManager.shared.notification(type: .error)
            }
            joiningTournamentId = nil
            showJoinAlert = true
        }
    }
    
    private func acceptChallenge(_ match: VSMatch) {
        guard acceptingMatchId == nil else { return }
        guard let userId = AuthenticationManager.shared.currentUser?.id ?? AppState.shared.currentUser?.id else {
            joinAlertMessage = "Sign in to accept challenges."
            showJoinAlert = true
            return
        }
        
        acceptingMatchId = match.id
        HapticManager.shared.impact(style: .medium)
        
        Task {
            do {
                try await VersusMatchService.shared.acceptMatch(matchId: match.id, opponentId: userId)
                await viewModel.loadData()
                joinAlertMessage = "Challenge accepted! Get ready to compete. 🎮"
                HapticManager.shared.notification(type: .success)
            } catch {
                joinAlertMessage = "Failed to accept: \(error.localizedDescription)"
                HapticManager.shared.notification(type: .error)
            }
            acceptingMatchId = nil
            showJoinAlert = true
        }
    }
}

// MARK: - Supporting Types

enum GamingTab: String, CaseIterable, Identifiable {
    case tournaments
    case vsMatches
    case bracket
    case leaderboard
    case myEarnings
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .tournaments: return "Tournaments"
        case .vsMatches: return "VS Matches"
        case .bracket: return "3D Bracket"
        case .leaderboard: return "Leaderboard"
        case .myEarnings: return "My Earnings"
        }
    }
    
    var iconName: String {
        switch self {
        case .tournaments: return "trophy.fill"
        case .vsMatches: return "person.2.fill"
        case .bracket: return "square.grid.3x1.below.line.grid.1x2"
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

struct GamingEsportsTournament: Identifiable {
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

// Color extension removed - use Color+Hex.swift file instead

// MARK: - 🔥 PREMIUM: Animated Stat Text with Count-Up Animation
struct AnimatedStatText: View {
    let value: Double
    let prefix: String
    let font: Font
    let color: Color
    
    @State private var displayedValue: Double = 0
    @State private var hasAnimated = false
    
    init(value: Double, prefix: String = "", font: Font = .body, color: Color = .primary) {
        self.value = value
        self.prefix = prefix
        self.font = font
        self.color = color
    }
    
    var body: some View {
        Text("\(prefix)\(Int(displayedValue).formatted())")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayedValue)
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                animateCount()
            }
            .onChange(of: value) { newValue in
                // Smoothly animate to new value
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    displayedValue = newValue
                }
            }
    }
    
    private func animateCount() {
        // 🔥 PREMIUM: Smooth count-up animation with easing
        let steps = min(Int(value), 25)
        guard steps > 0 else {
            displayedValue = value
            return
        }
        
        let animationDuration = 0.6
        let stepDuration = animationDuration / Double(steps)
        
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let progress = Double(step) / Double(steps)
                // Cubic ease-out for premium feel
                let easedProgress = 1 - pow(1 - progress, 3)
                let newValue = value * easedProgress
                
                withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                    displayedValue = newValue
                }
            }
        }
    }
}

#Preview {
    GamingEsportsView()
}

