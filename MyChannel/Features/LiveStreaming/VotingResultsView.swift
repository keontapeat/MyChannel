//
//  VotingResultsView.swift
//  MyChannel
//
//  Live voting results for Streamer Awards
//

import SwiftUI

struct VotingResultsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var votingService = StreamerAwardsVotingService.shared
    @State private var selectedCategoryId: String?
    @State private var categoryResults: [CategoryVoteResults] = []
    @State private var isLoading = false
    
    // Award categories (same as AwardsVotingView)
    private let categories: [AwardCategory] = [
        AwardCategory(id: "streamer-of-year", name: "Streamer of the Year", icon: "crown.fill", color: .yellow),
        AwardCategory(id: "best-newcomer", name: "Best Newcomer", icon: "star.fill", color: .blue),
        AwardCategory(id: "best-gaming", name: "Best Gaming Streamer", icon: "gamecontroller.fill", color: .purple),
        AwardCategory(id: "best-irl", name: "Best IRL Streamer", icon: "camera.fill", color: .orange),
        AwardCategory(id: "best-creative", name: "Best Creative Streamer", icon: "paintbrush.fill", color: .pink),
        AwardCategory(id: "best-music", name: "Best Music Streamer", icon: "music.note", color: .red),
        AwardCategory(id: "best-cooking", name: "Best Cooking Streamer", icon: "flame.fill", color: .orange),
        AwardCategory(id: "best-fitness", name: "Best Fitness Streamer", icon: "figure.run", color: .green),
        AwardCategory(id: "best-educational", name: "Best Educational Content", icon: "book.fill", color: .blue),
        AwardCategory(id: "best-comedy", name: "Best Comedy Streamer", icon: "theatermasks.fill", color: .yellow),
        AwardCategory(id: "best-community", name: "Best Community", icon: "person.3.fill", color: .cyan),
        AwardCategory(id: "most-wholesome", name: "Most Wholesome", icon: "heart.fill", color: .pink),
        AwardCategory(id: "best-charity", name: "Best Charity Streamer", icon: "gift.fill", color: .green),
        AwardCategory(id: "most-interactive", name: "Most Interactive", icon: "bubble.left.and.bubble.right.fill", color: .blue),
        AwardCategory(id: "best-hype", name: "Best Hype Moments", icon: "bolt.fill", color: .yellow),
        AwardCategory(id: "best-clutch", name: "Best Clutch Plays", icon: "target", color: .red),
        AwardCategory(id: "most-creative", name: "Most Creative Content", icon: "lightbulb.fill", color: .orange),
        AwardCategory(id: "best-production", name: "Best Production Quality", icon: "tv.fill", color: .purple),
        AwardCategory(id: "breakout-star", name: "Breakout Star", icon: "star.fill", color: .yellow),
        AwardCategory(id: "best-duo", name: "Best Duo/Team", icon: "person.2.fill", color: .cyan),
        AwardCategory(id: "best-collab", name: "Best Collaboration", icon: "link", color: .blue),
        AwardCategory(id: "most-entertaining", name: "Most Entertaining", icon: "face.smiling.fill", color: .orange),
        AwardCategory(id: "best-editor", name: "Best Editor", icon: "scissors", color: .gray),
        AwardCategory(id: "best-mod-team", name: "Best Mod Team", icon: "shield.fill", color: .green),
        AwardCategory(id: "legacy-award", name: "Legacy Award", icon: "trophy.fill", color: Color(red: 1.0, green: 0.84, blue: 0.0)),
        AwardCategory(id: "peoples-choice", name: "People's Choice", icon: "hand.thumbsup.fill", color: .blue)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Header
                        resultsHeaderView
                        
                        // Category picker
                        categoryPickerView
                        
                        // Results for selected category
                        if let categoryId = selectedCategoryId,
                           let results = votingService.categoryResults[categoryId] {
                            CategoryResultsView(results: results, category: findCategory(id: categoryId))
                        } else if isLoading {
                            ProgressView()
                                .padding(AppTheme.Spacing.xl)
                        } else {
                            emptyStateView
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.lg)
                }
            }
            .navigationTitle("Live Results")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                if let firstCategory = categories.first {
                    selectedCategoryId = firstCategory.id
                    await loadResults(for: firstCategory.id)
                }
            }
        }
    }
    
    // MARK: - Results Header
    private var resultsHeaderView: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 50))
                .foregroundColor(AppTheme.Colors.primary)
            
            Text("Live Voting Results")
                .font(AppTheme.Typography.largeTitle)
                .fontWeight(.bold)
            
            Text("Updated in real-time")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text(votingService.currentVotingPeriod.displayName)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(AppTheme.Colors.cardBackground)
                .cornerRadius(AppTheme.CornerRadius.sm)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }
    
    // MARK: - Category Picker
    private var categoryPickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(categories) { category in
                    CategoryChipView(
                        category: category,
                        isSelected: selectedCategoryId == category.id
                    )
                    .onTapGesture {
                        selectedCategoryId = category.id
                        Task {
                            await loadResults(for: category.id)
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("No votes yet")
                .font(AppTheme.Typography.headline)
            
            Text("Be the first to vote in this category!")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.xl)
    }
    
    // MARK: - Load Results
    private func loadResults(for categoryId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let results = try await votingService.loadCategoryResults(categoryId: categoryId)
            votingService.categoryResults[categoryId] = results
            
            // Start real-time listener
            votingService.listenToCategoryResults(categoryId: categoryId)
            
        } catch {
            print("🚨 [VotingResults] Error loading results: \(error.localizedDescription)")
        }
    }
    
    private func findCategory(id: String) -> AwardCategory? {
        categories.first { $0.id == id }
    }
}

// MARK: - Category Chip View

struct CategoryChipView: View {
    let category: AwardCategory
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: category.icon)
                .font(.system(size: 14))
            
            Text(category.name)
                .font(AppTheme.Typography.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(isSelected ? category.color : AppTheme.Colors.cardBackground)
        .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
        .cornerRadius(AppTheme.CornerRadius.lg)
    }
}

// MARK: - Category Results View

struct CategoryResultsView: View {
    let results: CategoryVoteResults
    let category: AwardCategory?
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            // Category info
            HStack {
                if let category = category {
                    Image(systemName: category.icon)
                        .foregroundColor(category.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(results.categoryName)
                        .font(AppTheme.Typography.headline)
                    
                    Text("\(results.totalVotes) total votes")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            
            // Top 3 podium
            if results.nominees.count >= 3 {
                PodiumView(
                    first: results.nominees[0],
                    second: results.nominees[1],
                    third: results.nominees[2]
                )
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            
            // Full leaderboard
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(Array(results.nominees.enumerated()), id: \.element.id) { index, nominee in
                    NomineeResultRow(
                        nominee: nominee,
                        rank: index + 1,
                        isTopThree: index < 3
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
}

// MARK: - Podium View

struct PodiumView: View {
    let first: NomineeVoteCount
    let second: NomineeVoteCount
    let third: NomineeVoteCount
    
    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
            // Second place
            PodiumPlaceView(nominee: second, place: 2, height: 100, color: .gray)
            
            // First place
            PodiumPlaceView(nominee: first, place: 1, height: 140, color: .yellow)
            
            // Third place
            PodiumPlaceView(nominee: third, place: 3, height: 80, color: .orange)
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }
}

struct PodiumPlaceView: View {
    let nominee: NomineeVoteCount
    let place: Int
    let height: CGFloat
    let color: Color
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            // Profile image
            AsyncImage(url: URL(string: nominee.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 3)
            )
            
            // Name
            Text(nominee.displayName)
                .font(AppTheme.Typography.caption)
                .lineLimit(1)
            
            // Percentage
            Text("\(Int(nominee.votePercentage))%")
                .font(AppTheme.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            // Podium
            VStack {
                Text("\(place)")
                    .font(AppTheme.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(color.opacity(0.8))
            .cornerRadius(AppTheme.CornerRadius.md)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Nominee Result Row

struct NomineeResultRow: View {
    let nominee: NomineeVoteCount
    let rank: Int
    let isTopThree: Bool
    
    private var medalIcon: String? {
        switch rank {
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return nil
        }
    }
    
    private var medalColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Rank
            Text("\(rank)")
                .font(AppTheme.Typography.headline)
                .fontWeight(.bold)
                .foregroundColor(isTopThree ? medalColor : AppTheme.Colors.textSecondary)
                .frame(width: 30)
            
            // Medal (for top 3)
            if let icon = medalIcon {
                Image(systemName: icon)
                    .foregroundColor(medalColor)
            }
            
            // Profile image
            AsyncImage(url: URL(string: nominee.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Name and stats
            VStack(alignment: .leading, spacing: 2) {
                Text(nominee.displayName)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(nominee.voteCount) votes (\(Int(nominee.votePercentage))%)")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Vote percentage bar
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(nominee.votePercentage))%")
                    .font(AppTheme.Typography.caption)
                    .fontWeight(.bold)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AppTheme.Colors.cardBackground)
                        
                        Rectangle()
                            .fill(isTopThree ? medalColor : AppTheme.Colors.primary)
                            .frame(width: geometry.size.width * (nominee.votePercentage / 100))
                    }
                }
                .frame(height: 6)
                .cornerRadius(3)
            }
            .frame(width: 80)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.lg)
    }
}

// MARK: - Preview

#Preview("Voting Results") {
    VotingResultsView()
}

