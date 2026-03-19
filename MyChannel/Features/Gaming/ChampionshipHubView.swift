//
//  ChampionshipHubView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🏆 CHAMPIONSHIP HUB - All medals & rankings! 🔥
//

import SwiftUI

struct ChampionshipHubView: View {
    @StateObject private var medalSystem = ChampionshipBeltSystem.shared
    @StateObject private var tournamentService = TournamentService.shared
    @ObservedObject private var aiOrchestrator = GamingAIOrchestrator.shared
    @State private var selectedDivision: ChampionshipBeltSystem.ChampionshipDivision = .gold
    @State private var flameScale: CGFloat = 1.0
    @State private var shelfOffset: CGFloat = 0
    @State private var aiRankingConfidence: Double = 0
    @State private var isAIRefreshing: Bool = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                olympicHeroHeader
                myMedals3DShelf
                sectionLabel("ALL DIVISIONS", icon: "square.grid.2x2.fill")
                medalsGrid
                aiStatusBanner
                sectionLabel("RANKINGS", icon: "chart.bar.fill")
                rankingsSection
                sectionLabel("TOURNAMENT VICTORIES", icon: "trophy.fill")
                tournamentVictoriesSection
                sectionLabel("TITLE DEFENSES", icon: "shield.lefthalf.filled")
                upcomingDefensesSection
            }
            .padding(.bottom, 40)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Championship Games")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                flameScale = 1.12
            }
            Task { await trackHubOpened() }
        }
    }

    // MARK: - AI Tracking

    private func trackHubOpened() async {
        guard let userId = AuthenticationManager.shared.currentUser?.id
                        ?? AppState.shared.currentUser?.id else { return }
        await aiOrchestrator.trackChampionshipEvent(userId: userId, event: .hubOpened)
    }

    private func trackDivisionSwitched(to division: ChampionshipBeltSystem.ChampionshipDivision) {
        guard let userId = AuthenticationManager.shared.currentUser?.id
                        ?? AppState.shared.currentUser?.id else { return }
        Task {
            await aiOrchestrator.trackChampionshipEvent(userId: userId, event: .divisionSwitched)
            isAIRefreshing = true
            defer { isAIRefreshing = false }
            let competitors = medalSystem.rankings[division] ?? []
            guard !competitors.isEmpty else { return }
            let result = await aiOrchestrator.refreshRankingsWithAI(
                division: division.rawValue,
                currentUserIds: competitors.map { $0.userId }
            )
            aiRankingConfidence = result.avgConfidence
        }
    }

    // MARK: - Section Label Helper

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .tracking(1.5)
            Rectangle()
                .fill(AppTheme.Colors.divider)
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Olympic Hero Header

    private var olympicHeroHeader: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Colors.primary.opacity(0.18),
                    AppTheme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 14) {
                // Flame torch icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red:1.0, green:0.84, blue:0.0).opacity(0.35),
                                    AppTheme.Colors.primary.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 70
                            )
                        )
                        .frame(width: 130, height: 130)
                        .scaleEffect(flameScale)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, Color(red:0.85,green:0.20,blue:0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: AppTheme.Colors.primary.opacity(0.5), radius: 18, x: 0, y: 6)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("CHAMPIONSHIP GAMES")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .tracking(1.2)

                Text("\(medalSystem.allMedals.count) divisions  •  Compete to be #1")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)

                // Olympic ring dots
                HStack(spacing: 6) {
                    ForEach([Color.blue, Color.black, Color.red, Color(red:1,green:0.84,blue:0), Color.green], id: \.self) { c in
                        Circle()
                            .strokeBorder(c, lineWidth: 2.5)
                            .frame(width: 18, height: 18)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 3D Trophy Shelf

    private var myMedals3DShelf: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red:1,green:0.84,blue:0))
                Text("MY MEDALS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .tracking(1.5)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            ZStack(alignment: .bottom) {
                // Shelf backing wall
                LinearGradient(
                    colors: [
                        AppTheme.Colors.surface.opacity(0.6),
                        AppTheme.Colors.surface.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                .cornerRadius(20)
                .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    // Medal row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 22) {
                            if medalSystem.myMedals.isEmpty {
                                emptyShelfCard
                            } else {
                                ForEach(Array(medalSystem.myMedals.enumerated()), id: \.element.id) { idx, medal in
                                    TrophyShelfMedal3D(medal: medal, index: idx)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 10)
                    }

                    // Shelf surface
                    ZStack {
                        // Shelf top face
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red:0.22, green:0.16, blue:0.10),
                                        Color(red:0.16, green:0.11, blue:0.07)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 14)

                        // Wood grain highlight
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 2)
                            .offset(y: -4)

                        // Shelf bottom edge (3D depth)
                        Rectangle()
                            .fill(Color(red:0.10, green:0.07, blue:0.04))
                            .frame(height: 7)
                            .offset(y: 10)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 8)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var emptyShelfCard: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .strokeBorder(
                        AppTheme.Colors.textSecondary.opacity(0.25),
                        style: StrokeStyle(lineWidth: 2, dash: [6])
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "medal")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.4))
            }
            Text("Compete to earn\nyour first medal")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(width: 110, height: 110)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - AI Status Banner

    private var aiStatusBanner: some View {
        HStack(spacing: 12) {
            // Animated brain icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red:0.4,green:0.2,blue:1.0), Color(red:0.2,green:0.6,blue:1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("ML AI Rankings")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    if isAIRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red:0.4,green:0.2,blue:1.0)))
                            .scaleEffect(0.65)
                    } else {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                }
                Text("\(aiOrchestrator.agentsActive)/7 agents · \(aiOrchestrator.totalPredictions) predictions · ELO-powered")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Confidence pill
            if aiRankingConfidence > 0 {
                VStack(spacing: 2) {
                    Text("\(Int(aiRankingConfidence * 100))%")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(Color(red:0.4,green:0.2,blue:1.0))
                    Text("conf.")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red:0.4,green:0.2,blue:1.0).opacity(0.12))
                )
            } else {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red:0.4,green:0.2,blue:1.0).opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.surface)
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(red:0.4,green:0.2,blue:1.0).opacity(0.09), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(red:0.4,green:0.2,blue:1.0).opacity(0.22), lineWidth: 1)
            }
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Medals Grid

    private var medalsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(medalSystem.allMedals) { medal in
                MedalCard(
                    medal: medal,
                    champion: medalSystem.champions[medal.id],
                    isSelected: selectedDivision == medal.division
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedDivision = medal.division
                    }
                    HapticManager.shared.impact(style: .light)
                    trackDivisionSwitched(to: medal.division)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Rankings

    private var rankingsSection: some View {
        VStack(spacing: 16) {
            // Division pill tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ChampionshipBeltSystem.ChampionshipDivision.allCases) { div in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedDivision = div
                            }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            HStack(spacing: 5) {
                                Text(div.icon)
                                    .font(.system(size: 13))
                                Text(div.shortName)
                                    .font(.system(size: 13, weight: selectedDivision == div ? .bold : .medium))
                                    .foregroundColor(selectedDivision == div ? .white : AppTheme.Colors.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedDivision == div
                                          ? div.swiftUIColor
                                          : AppTheme.Colors.surface)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(selectedDivision == div
                                                  ? Color.clear
                                                  : AppTheme.Colors.divider.opacity(0.3),
                                                  lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }

            // Podium (top 3)
            if let rankings = medalSystem.rankings[selectedDivision], rankings.count >= 3 {
                OlympicPodiumView(
                    first: rankings[0],
                    second: rankings[1],
                    third: rankings[2],
                    division: selectedDivision
                )
                .padding(.horizontal, 20)
            }

            // Full list
            if let rankings = medalSystem.rankings[selectedDivision], !rankings.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rankings.enumerated()), id: \.element.id) { idx, competitor in
                        CompetitorRankingCard(competitor: competitor, division: selectedDivision)
                        if idx < rankings.count - 1 {
                            Divider()
                                .padding(.leading, 72)
                                .opacity(0.3)
                        }
                    }
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(18)
                .padding(.horizontal, 20)
            } else {
                Text("No ranked competitors yet — be the first!")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(18)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Tournament Victories

    private var tournamentVictoriesSection: some View {
        Group {
            if tournamentService.completedTournaments.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "trophy")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.4))
                    Text("Win a tournament to see it here")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(AppTheme.Colors.surface)
                .cornerRadius(18)
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(tournamentService.completedTournaments) { t in
                            TournamentVictoryCard(tournament: t)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Upcoming Title Defenses

    private var upcomingDefensesSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Upcoming Title Defenses")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text("Next scheduled match")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.Colors.surface)
                    .padding(.horizontal, 20)

                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.5))
                    Text("No defenses scheduled")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("Earn a championship to defend it")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.6))
                }
                .padding(.vertical, 32)
            }
            .frame(height: 110)
        }
    }
}

// MARK: - Division Color/Name Extensions

private extension ChampionshipBeltSystem.ChampionshipDivision {
    var swiftUIColor: Color {
        switch self {
        case .bronze:   return Color(red:0.72, green:0.45, blue:0.20)
        case .silver:   return Color(red:0.65, green:0.65, blue:0.70)
        case .gold:     return Color(red:0.92, green:0.75, blue:0.00)
        case .platinum: return Color(red:0.20, green:0.80, blue:0.80)
        case .diamond:  return Color(red:0.25, green:0.45, blue:0.90)
        case .legend:   return Color(red:0.65, green:0.20, blue:0.90)
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .bronze:   return [Color(red:0.80,green:0.50,blue:0.20), Color(red:0.55,green:0.27,blue:0.07)]
        case .silver:   return [Color(red:0.82,green:0.82,blue:0.86), Color(red:0.50,green:0.50,blue:0.55)]
        case .gold:     return [Color(red:1.00,green:0.84,blue:0.00), Color(red:0.85,green:0.60,blue:0.00)]
        case .platinum: return [Color(red:0.20,green:0.90,blue:0.90), Color(red:0.00,green:0.60,blue:0.70)]
        case .diamond:  return [Color(red:0.40,green:0.60,blue:1.00), Color(red:0.15,green:0.30,blue:0.80)]
        case .legend:   return [Color(red:0.80,green:0.30,blue:1.00), Color(red:0.45,green:0.10,blue:0.75)]
        }
    }

    var shortName: String {
        switch self {
        case .bronze:   return "Bronze"
        case .silver:   return "Silver"
        case .gold:     return "Gold"
        case .platinum: return "Platinum"
        case .diamond:  return "Diamond"
        case .legend:   return "Legend"
        }
    }
}

// MARK: - Medal Card

struct MedalCard: View {
    let medal: ChampionshipBeltSystem.ChampionshipMedal
    let champion: ChampionshipBeltSystem.Champion?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Gradient header with custom medal badge
                ZStack {
                    LinearGradient(
                        colors: medal.division.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    // Specular highlight
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )

                    VStack(spacing: 6) {
                        OlympicMedalBadge(division: medal.division, size: 52)
                        Text(medal.division.shortName.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white.opacity(0.9))
                            .tracking(1.4)
                    }
                    .padding(.vertical, 18)
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Champion info
                VStack(spacing: 5) {
                    if let champion = champion {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(medal.division.swiftUIColor.opacity(0.25))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(String(champion.userId.prefix(1)).uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(medal.division.swiftUIColor)
                                )
                            Text("@\(champion.userId.prefix(8))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                        }
                        Text("\(champion.defenses) defenses")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    } else {
                        Text("VACANT")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                        Text("No champion")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .background(AppTheme.Colors.surface)
            }
            .cornerRadius(16)
            .shadow(
                color: isSelected
                    ? medal.division.swiftUIColor.opacity(0.5)
                    : Color.black.opacity(0.12),
                radius: isSelected ? 12 : 4,
                x: 0,
                y: isSelected ? 6 : 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? medal.division.swiftUIColor : Color.clear,
                        lineWidth: 2.5
                    )
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Competitor Ranking Card

struct CompetitorRankingCard: View {
    let competitor: ChampionshipBeltSystem.RankedCompetitor
    let division: ChampionshipBeltSystem.ChampionshipDivision

    private var rankColor: Color {
        switch competitor.rank {
        case 1: return Color(red:1,green:0.84,blue:0)
        case 2: return Color(red:0.75,green:0.75,blue:0.80)
        case 3: return Color(red:0.72,green:0.45,blue:0.20)
        default: return AppTheme.Colors.primary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(competitor.rank <= 3 ? 0.18 : 0.08))
                    .frame(width: 44, height: 44)
                if competitor.rank <= 3 {
                    Circle()
                        .strokeBorder(rankColor.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                }
                Text("#\(competitor.rank)")
                    .font(.system(size: competitor.rank <= 3 ? 15 : 14, weight: .bold))
                    .foregroundColor(rankColor)
            }

            // Avatar
            Circle()
                .fill(division.swiftUIColor.opacity(0.18))
                .frame(width: 38, height: 38)
                .overlay(
                    Text(String(competitor.userId.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(division.swiftUIColor)
                )

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("@\(competitor.userId.prefix(10))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    if competitor.isContender {
                        Text("CONTENDER")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.Colors.primary))
                    }
                }
                HStack(spacing: 8) {
                    Text("\(competitor.wins)W–\(competitor.losses)L")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("·")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("\(Int(competitor.winRate))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    if competitor.winStreak > 1 {
                        Text("🔥\(competitor.winStreak)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Points pill
            Text("\(competitor.points) pts")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(division.swiftUIColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(division.swiftUIColor.opacity(0.14))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Olympic Podium View

struct OlympicPodiumView: View {
    let first: ChampionshipBeltSystem.RankedCompetitor
    let second: ChampionshipBeltSystem.RankedCompetitor
    let third: ChampionshipBeltSystem.RankedCompetitor
    let division: ChampionshipBeltSystem.ChampionshipDivision

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            podiumColumn(competitor: second, rank: 2, height: 70)
            podiumColumn(competitor: first,  rank: 1, height: 96)
            podiumColumn(competitor: third,  rank: 3, height: 54)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.Colors.surface)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [division.swiftUIColor.opacity(0.08), Color.clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(division.swiftUIColor.opacity(0.2), lineWidth: 1)
            }
        )
        .shadow(color: division.swiftUIColor.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private func podiumColumn(competitor: ChampionshipBeltSystem.RankedCompetitor, rank: Int, height: CGFloat) -> some View {
        let medalColor: Color = rank == 1
            ? Color(red:1,green:0.84,blue:0)
            : rank == 2
                ? Color(red:0.75,green:0.75,blue:0.80)
                : Color(red:0.72,green:0.45,blue:0.20)

        VStack(spacing: 6) {
            // Rank crown/number
            ZStack {
                Circle()
                    .fill(medalColor.opacity(0.18))
                    .frame(width: rank == 1 ? 34 : 28, height: rank == 1 ? 34 : 28)
                Text(rank == 1 ? "👑" : rank == 2 ? "🥈" : "🥉")
                    .font(.system(size: rank == 1 ? 18 : 14))
            }

            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: division.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: rank == 1 ? 52 : 42, height: rank == 1 ? 52 : 42)
                .overlay(
                    Text(String(competitor.userId.prefix(1)).uppercased())
                        .font(.system(size: rank == 1 ? 20 : 16, weight: .black))
                        .foregroundColor(.white)
                )
                .shadow(color: division.swiftUIColor.opacity(0.4), radius: 8, x: 0, y: 4)

            Text("@\(competitor.userId.prefix(7))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(1)

            Text("\(competitor.points) pts")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)

            // Podium block
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [medalColor.opacity(0.7), medalColor.opacity(0.4)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.clear],
                            startPoint: .topLeading, endPoint: .center
                        )
                    )
                Text("#\(rank)")
                    .font(.system(size: rank == 1 ? 18 : 14, weight: .black))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 3D Trophy Shelf Medal

struct TrophyShelfMedal3D: View {
    let medal: ChampionshipBeltSystem.ChampionshipMedal
    let index: Int
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Ribbon drape
            HStack(spacing: 2) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [medal.division.gradientColors[0], medal.division.gradientColors[1]],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 6, height: 22)
                    .rotationEffect(.degrees(-8))
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [medal.division.gradientColors[0], medal.division.gradientColors[1]],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 6, height: 22)
                    .rotationEffect(.degrees(8))
            }

            // Medal face — 3D
            ZStack {
                // Ambient glow behind
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                medal.division.swiftUIColor.opacity(0.55),
                                medal.division.swiftUIColor.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 38
                        )
                    )
                    .frame(width: 76, height: 76)

                // Medal circle with metallic gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: medal.division.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: medal.division.swiftUIColor.opacity(0.6), radius: 8, x: 2, y: 4)

                // Specular highlight top-left
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.55), Color.clear],
                            center: UnitPoint(x: 0.28, y: 0.22),
                            startRadius: 0,
                            endRadius: 22
                        )
                    )
                    .frame(width: 58, height: 58)

                // Center icon
                Text(medal.division.icon)
                    .font(.system(size: 22))
            }
            .rotation3DEffect(
                .degrees(appeared ? 0 : 18),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.6
            )
            .rotation3DEffect(
                .degrees(-8),
                axis: (x: 1, y: 0.3, z: 0),
                perspective: 0.5
            )
            .animation(
                .spring(response: 0.6, dampingFraction: 0.75)
                    .delay(Double(index) * 0.08),
                value: appeared
            )
            .onAppear { appeared = true }

            // Label below medal
            Text(medal.division.shortName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.top, 6)
        }
        .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 8)
    }
}

// MARK: - Olympic Medal Badge (used in cards)

struct OlympicMedalBadge: View {
    let division: ChampionshipBeltSystem.ChampionshipDivision
    let size: CGFloat

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: size * 0.04)
                .frame(width: size, height: size)

            // Inner fill
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.85, height: size * 0.85)

            // Icon
            Text(division.icon)
                .font(.system(size: size * 0.46))
        }
    }
}

// MARK: - Tournament Victory Card

struct TournamentVictoryCard: View {
    let tournament: BracketTournament

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red:1,green:0.84,blue:0))
                Text("WINNER")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(red:1,green:0.84,blue:0))
                    .tracking(1.2)
            }
            Text(tournament.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.primary)
                Text("$\(Int(tournament.prizePool).formatted())")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            if let date = tournament.startDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .frame(width: 160)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.surface)
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(red:1,green:0.84,blue:0).opacity(0.10), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(red:1,green:0.84,blue:0).opacity(0.3), lineWidth: 1)
            }
        )
        .shadow(color: Color(red:1,green:0.84,blue:0).opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    NavigationStack {
        ChampionshipHubView()
    }
}

