//
//  ChampionshipHubView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🏆 CHAMPIONSHIP HUB - All belts & rankings! 🔥
//

import SwiftUI

struct ChampionshipHubView: View {
    @StateObject private var beltSystem = ChampionshipBeltSystem.shared
    @State private var selectedDivision: ChampionshipBeltSystem.BeltDivision = .middleweight
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // All Belts
                beltsGrid
                
                // Selected Division Rankings
                rankingsSection
                
                // Title Defenses Schedule
                upcomingDefensesSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("🏆 Championships")
        .navigationBarTitleDisplayMode(.inline)
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
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Championship Belts")
                .font(.system(size: 28, weight: .bold))
            
            Text("6 divisions • 6 champions • Defend or conquer!")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Belts Grid
    
    private var beltsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Divisions")
                .font(.system(size: 24, weight: .bold))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(beltSystem.allBelts) { belt in
                    BeltCard(
                        belt: belt,
                        champion: beltSystem.champions[belt.id],
                        isSelected: selectedDivision == belt.division
                    ) {
                        selectedDivision = belt.division
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
            
            if let rankings = beltSystem.rankings[selectedDivision], !rankings.isEmpty {
                VStack(spacing: 12) {
                    ForEach(rankings) { fighter in
                        FighterRankingCard(fighter: fighter)
                    }
                }
            } else {
                Text("No ranked fighters yet")
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

// MARK: - Belt Card

struct BeltCard: View {
    let belt: ChampionshipBeltSystem.ChampionshipBelt
    let champion: ChampionshipBeltSystem.Champion?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Division Icon
                Text(belt.division.icon)
                    .font(.system(size: 44))
                
                // Division Name
                Text(belt.division.rawValue)
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

// MARK: - Fighter Ranking Card

struct FighterRankingCard: View {
    let fighter: ChampionshipBeltSystem.RankedFighter
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text("#\(fighter.rank)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(rankColor)
            }
            
            // Fighter Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Fighter")
                        .font(.system(size: 16, weight: .bold))
                    
                    if fighter.isContender {
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
                    Text("\(fighter.wins)-\(fighter.losses)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(fighter.winRate))% win rate")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    if fighter.winStreak > 0 {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("🔥 \(fighter.winStreak) streak")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Points
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(fighter.points)")
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
        switch fighter.rank {
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

