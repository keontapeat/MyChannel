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
    @State private var selectedDivision: ChampionshipBeltSystem.ChampionshipDivision = .gold
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // All Medals
                medalsGrid
                
                // Selected Division Rankings
                rankingsSection
                
                // Title Defenses Schedule
                upcomingDefensesSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Championships")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Load data if needed
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "medal.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Championship Medals")
                .font(.system(size: 28, weight: .bold))
            
            Text("6 medals • Compete to be #1!")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Medals Grid
    
    private var medalsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Divisions")
                .font(.system(size: 24, weight: .bold))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(medalSystem.allMedals) { medal in
                    MedalCard(
                        medal: medal,
                        champion: medalSystem.champions[medal.id],
                        isSelected: selectedDivision == medal.division
                    ) {
                        selectedDivision = medal.division
                    }
                }
            }
        }
    }
    
    // MARK: - Rankings
    
    private var rankingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(selectedDivision.icon) \(selectedDivision.rawValue)")
                    .font(.system(size: 24, weight: .bold))
                
                Spacer()
                
                Text("Rankings")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            if let rankings = medalSystem.rankings[selectedDivision], !rankings.isEmpty {
                VStack(spacing: 12) {
                    ForEach(rankings) { competitor in
                        CompetitorRankingCard(competitor: competitor)
                    }
                }
            } else {
                Text("No ranked competitors yet")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Upcoming Defenses
    
    private var upcomingDefensesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Title Defenses")
                .font(.system(size: 24, weight: .bold))
            
            // Placeholder for upcoming defenses
            Text("No scheduled defenses")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(AppTheme.Colors.surface)
                .cornerRadius(16)
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
            VStack(spacing: 12) {
                // Division Icon
                Text(medal.division.icon)
                    .font(.system(size: 44))
                
                // Division Name
                Text(medal.division.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Divider()
                
                // Champion Info
                if let champion = champion {
                    VStack(spacing: 4) {
                        Text("Champion")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text("@user")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("\(champion.defenses) defenses")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 4) {
                        Text("VACANT")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Text("No champion")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isSelected ?
                AppTheme.Colors.primary.opacity(0.1) :
                AppTheme.Colors.surface
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? AppTheme.Colors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
            .cornerRadius(16)
        }
    }
}

// MARK: - Competitor Ranking Card

struct CompetitorRankingCard: View {
    let competitor: ChampionshipBeltSystem.RankedCompetitor
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text("#\(competitor.rank)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(rankColor)
            }
            
            // Competitor Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Competitor")
                        .font(.system(size: 16, weight: .bold))
                    
                    if competitor.isContender {
                        Text("CONTENDER")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 12) {
                    Text("\(competitor.wins)-\(competitor.losses)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(competitor.winRate))% win rate")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    if competitor.winStreak > 0 {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("🔥 \(competitor.winStreak) streak")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Points
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(competitor.points)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("points")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
    }
    
    private var rankColor: Color {
        switch competitor.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return AppTheme.Colors.primary
        }
    }
}

#Preview {
    NavigationStack {
        ChampionshipHubView()
    }
}

