//
//  LiveStreamerAwardsView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🏆 LIVE STREAMER AWARDS UI - Compete for glory! 🔥
//

import SwiftUI

struct LiveStreamerAwardsView: View {
    @StateObject private var awards = LiveStreamerAwardsSystem.shared
    @State private var selectedTab: Tab = .leaderboard
    @State private var selectedTimeframe: LiveStreamerAwardsSystem.Timeframe = .weekly
    @State private var selectedCategory: LiveStreamerAwardsSystem.LeaderboardCategory = .overall
    @State private var showLiveStream = false
    
    enum Tab {
        case leaderboard
        case awards
        case achievements
        case myStats
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Tab Bar
            tabBar
            
            // Content
            TabView(selection: $selectedTab) {
                leaderboardView
                    .tag(Tab.leaderboard)
                
                awardsView
                    .tag(Tab.awards)
                
                achievementsView
                    .tag(Tab.achievements)
                
                myStatsView
                    .tag(Tab.myStats)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("🏆 Streamer Awards")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showLiveStream) {
            LiveCeremonyStreamView(
                streamURL: "https://example.com/live-stream",
                onDismiss: {
                    showLiveStream = false
                }
            )
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            AwardsTabButton(icon: "chart.bar.fill", title: "Leaderboard", isSelected: selectedTab == .leaderboard) {
                withAnimation { selectedTab = .leaderboard }
            }
            
            AwardsTabButton(icon: "trophy.fill", title: "Awards", isSelected: selectedTab == .awards) {
                withAnimation { selectedTab = .awards }
            }
            
            AwardsTabButton(icon: "medal.fill", title: "Achievements", isSelected: selectedTab == .achievements) {
                withAnimation { selectedTab = .achievements }
            }
            
            AwardsTabButton(icon: "person.fill", title: "My Stats", isSelected: selectedTab == .myStats) {
                withAnimation { selectedTab = .myStats }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.surface)
    }
    
    // MARK: - Leaderboard View
    
    private var leaderboardView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Filters
                VStack(spacing: 12) {
                    // Timeframe picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach([
                                LiveStreamerAwardsSystem.Timeframe.daily,
                                .weekly,
                                .monthly,
                                .quarterly,
                                .yearly,
                                .allTime
                            ], id: \.rawValue) { timeframe in
                                FilterChip(
                                    title: timeframe.rawValue,
                                    isSelected: selectedTimeframe == timeframe
                                ) {
                                    selectedTimeframe = timeframe
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Category picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(LiveStreamerAwardsSystem.LeaderboardCategory.allCases, id: \.rawValue) { category in
                                FilterChip(
                                    title: category.rawValue,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                // Top 3 Podium
                if awards.topStreamers.count >= 3 {
                    podiumView
                }
                
                // Rankings List
                VStack(spacing: 12) {
                    ForEach(Array(awards.topStreamers.enumerated()), id: \.element.id) { index, ranking in
                        RankingCard(ranking: ranking)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 20)
        }
    }
    
    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // 2nd Place
            if awards.topStreamers.count > 1 {
                PodiumCard(ranking: awards.topStreamers[1], place: 2)
            }
            
            // 1st Place (Bigger!)
            if awards.topStreamers.count > 0 {
                PodiumCard(ranking: awards.topStreamers[0], place: 1)
                    .frame(height: 280)
            }
            
            // 3rd Place
            if awards.topStreamers.count > 2 {
                PodiumCard(ranking: awards.topStreamers[2], place: 3)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Awards View
    
    private var awardsView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Section 1: Cinematic Hero Countdown
                cinematicHeroSection
                
                // Section 2: Nominee Showcase
                if awards.currentSeason.isVotingOpen {
                    nomineeShowcaseSection
                }
                
                // Section 3: Premium Category Explorer
                premiumCategorySection
                
                // Section 4: Winner Hall of Fame
                if !awards.currentSeason.winners.isEmpty {
                    winnerHallOfFameSection
                }
                
                // Section 5: Live Voting Interface
                if awards.currentSeason.isVotingOpen {
                    liveVotingSection
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Section 1: Cinematic Hero
    
    private var cinematicHeroSection: some View {
        CeremonyCountdownHero(
            ceremonyDate: awards.currentSeason.ceremonyDate,
            isLive: false, // TODO: Connect to live stream status
            isVotingOpen: awards.currentSeason.isVotingOpen,
            onWatchLive: {
                showLiveStream = true
            },
            onVote: {
                // Scroll to voting section
                withAnimation {
                    selectedTab = .awards
                }
            }
        )
    }
    
    // MARK: - Section 2: Nominee Showcase
    
    private var nomineeShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Featured Nominees")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .staggeredReveal(index: 0)
            
            // Horizontal scrolling nominees by category
            ForEach(Array(LiveStreamerAwardsSystem.AwardCategory.allCases.prefix(3).enumerated()), id: \.element.id) { categoryIndex, category in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: category.icon)
                            .font(.system(size: 16))
                            .foregroundColor(category.color)
                        
                        Text(category.rawValue)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<5, id: \.self) { index in
                                NomineeCard(
                                    nominee: AwardNominee(
                                        id: "\(category.id)-\(index)",
                                        streamerName: "Nominee \(index + 1)",
                                        categoryName: category.rawValue,
                                        voteCount: Int.random(in: 100...1000),
                                        avgViewers: "2.4K",
                                        hoursStreamed: "142",
                                        subscribers: "856"
                                    ),
                                    isVoted: false,
                                    onVote: {
                                        // TODO: Handle vote
                                    }
                                )
                                .staggeredReveal(index: index, delay: 0.05)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .staggeredReveal(index: categoryIndex + 1)
            }
        }
    }
    
    // MARK: - Section 3: Premium Categories
    
    @State private var expandedCategory: String?
    
    private var premiumCategorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Award Categories")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .staggeredReveal(index: 0)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(Array(LiveStreamerAwardsSystem.AwardCategory.allCases.enumerated()), id: \.element.id) { index, category in
                    PremiumCategoryCard(
                        category: category,
                        isExpanded: expandedCategory == category.id,
                        onTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                expandedCategory = expandedCategory == category.id ? nil : category.id
                            }
                        }
                    )
                    .pressScale()
                    .staggeredReveal(index: index, delay: 0.05)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Section 4: Winner Hall of Fame
    
    private var winnerHallOfFameSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.awardGold)
                
                Text("Hall of Fame")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .staggeredReveal(index: 0)
            
            // Year timeline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array([2024, 2023, 2022].enumerated()), id: \.element) { index, year in
                        Text("\(year)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.awardGold)
                            .cornerRadius(20)
                            .shimmer()
                            .pressScale()
                            .staggeredReveal(index: index, delay: 0.1)
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Winner cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(Array(awards.currentSeason.winners.prefix(5).enumerated()), id: \.element.id) { index, winner in
                        WinnerSpotlightCard(
                            winner: winner,
                            year: 2024,
                            onPlayVideo: {
                                // TODO: Play acceptance speech
                            }
                        )
                        .frame(width: 280)
                        .pressScale()
                        .staggeredReveal(index: index, delay: 0.08)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Section 5: Live Voting
    
    private var liveVotingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Live Voting Results")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                // Time remaining
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text("14d left")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // Category voting results
            ForEach(Array(LiveStreamerAwardsSystem.AwardCategory.allCases.prefix(3)), id: \.id) { category in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: category.icon)
                            .font(.system(size: 14))
                            .foregroundColor(category.color)
                        
                        Text(category.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            VotingProgressBar(
                                nominee: AwardNominee(
                                    id: "\(category.id)-vote-\(index)",
                                    streamerName: "Nominee \(index + 1)",
                                    categoryName: category.rawValue,
                                    voteCount: Int.random(in: 100...1000),
                                    avgViewers: "2.4K",
                                    hoursStreamed: "142",
                                    subscribers: "856"
                                ),
                                totalVotes: 2500,
                                isLeading: index == 0
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - Achievements View
    
    private var achievementsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress Overview
                achievementProgressCard
                
                // Achievements Grid
                VStack(alignment: .leading, spacing: 16) {
                    Text("All Achievements")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.horizontal, 16)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(LiveStreamerAwardsSystem.allAchievements) { achievement in
                            AchievementCard(achievement: achievement)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    private var achievementProgressCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Progress")
                        .font(.system(size: 20, weight: .bold))
                    Text("\(awards.myAchievements.count) / \(LiveStreamerAwardsSystem.allAchievements.count) unlocked")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                CircularProgress(
                    progress: Double(awards.myAchievements.count) / Double(LiveStreamerAwardsSystem.allAchievements.count),
                    size: 60
                )
            }
            
            ProgressView(
                value: Double(awards.myAchievements.count),
                total: Double(LiveStreamerAwardsSystem.allAchievements.count)
            )
            .tint(AppTheme.Colors.primary)
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
        .padding(.horizontal, 16)
    }
    
    // MARK: - My Stats View
    
    private var myStatsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Rank Card
                if let myRanking = awards.myRanking {
                    myRankCard(ranking: myRanking)
                }
                
                // Stats Grid
                statsGrid
                
                // Badges
                badgesSection
                
                // Recent Achievements
                recentAchievementsSection
            }
            .padding(.vertical, 20)
        }
    }
    
    private func myRankCard(ranking: LiveStreamerAwardsSystem.StreamerRanking) -> some View {
        VStack(spacing: 20) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ranking.tier.color, ranking.tier.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                VStack(spacing: 4) {
                    Text("#\(ranking.rank)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(ranking.tier.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            // Rank Change
            if let change = ranking.rankChange {
                HStack(spacing: 4) {
                    Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "minus")
                        .foregroundColor(change > 0 ? .green : change < 0 ? .red : .gray)
                    Text("\(abs(change)) from last week")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            // Points
            VStack(spacing: 4) {
                Text("\(ranking.points) Points")
                    .font(.system(size: 24, weight: .bold))
                Text("Top \(Int(Double(ranking.rank) / 1000.0 * 100))% of streamers")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
        .padding(.horizontal, 16)
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            AwardsStatCard(title: "Hours Streamed", value: "142.5", icon: "timer", color: .blue)
            AwardsStatCard(title: "Avg Viewers", value: "2.4K", icon: "eye.fill", color: .green)
            AwardsStatCard(title: "Peak Viewers", value: "12.8K", icon: "chart.line.uptrend.xyaxis", color: .orange)
            AwardsStatCard(title: "Subscribers", value: "856", icon: "person.fill", color: .purple)
            AwardsStatCard(title: "Viral Clips", value: "23", icon: "rocket.fill", color: .red)
            AwardsStatCard(title: "Stream Days", value: "89", icon: "calendar", color: .cyan)
        }
        .padding(.horizontal, 16)
    }
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Badges")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(awards.myBadges) { badge in
                        AwardsBadgeCard(badge: badge)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var recentAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Achievements")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                ForEach(awards.myAchievements.prefix(5)) { achievement in
                    AchievementRow(achievement: achievement)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Supporting Views

struct AwardsTabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? AppTheme.Colors.primary : .secondary)
            .frame(maxWidth: .infinity)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                .cornerRadius(20)
        }
    }
}

struct PodiumCard: View {
    let ranking: LiveStreamerAwardsSystem.StreamerRanking
    let place: Int
    
    var height: CGFloat {
        switch place {
        case 1: return 240
        case 2: return 200
        case 3: return 180
        default: return 180
        }
    }
    
    var medalColor: Color {
        switch place {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Medal
            ZStack {
                Circle()
                    .fill(medalColor)
                    .frame(width: place == 1 ? 70 : 60, height: place == 1 ? 70 : 60)
                
                Text("\(place)")
                    .font(.system(size: place == 1 ? 32 : 28, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: place == 1 ? 60 : 50, height: place == 1 ? 60 : 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: place == 1 ? 28 : 24))
                        .foregroundColor(.white)
                )
            
            // Name
            Text(ranking.streamer.username)
                .font(.system(size: place == 1 ? 16 : 14, weight: .bold))
                .lineLimit(1)
            
            // Points
            Text("\(ranking.points) pts")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
    }
}

struct RankingCard: View {
    let ranking: LiveStreamerAwardsSystem.StreamerRanking
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("#\(ranking.rank)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ranking.tier.color)
                .frame(width: 50)
            
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(ranking.streamer.username)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Image(systemName: ranking.tier.icon)
                        .font(.system(size: 12))
                        .foregroundColor(ranking.tier.color)
                }
                
                Text("\(ranking.points) points • \(ranking.tier.rawValue)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Change
            if let change = ranking.rankChange {
                HStack(spacing: 4) {
                    Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(abs(change))")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(change > 0 ? .green : .red)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
    }
}


struct AchievementCard: View {
    let achievement: LiveStreamerAwardsSystem.Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.rarity.color.opacity(achievement.isUnlocked ? 0.2 : 0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 24))
                    .foregroundColor(achievement.isUnlocked ? achievement.rarity.color : .gray)
            }
            
            // Title
            Text(achievement.title)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Rarity
            Text(achievement.rarity.rawValue)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(achievement.rarity.color)
                .cornerRadius(6)
            
            // Progress (if applicable)
            if let progress = achievement.progress, !achievement.isUnlocked {
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                        .tint(achievement.rarity.color)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
        .opacity(achievement.isUnlocked ? 1.0 : 0.5)
    }
}

struct AchievementRow: View {
    let achievement: LiveStreamerAwardsSystem.Achievement
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.rarity.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: achievement.icon)
                    .foregroundColor(achievement.rarity.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.system(size: 15, weight: .semibold))
                
                Text(achievement.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Date
            if let date = achievement.unlockedDate {
                Text(date, style: .relative)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
}

struct AwardsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
    }
}

struct AwardsBadgeCard: View {
    let badge: LiveStreamerAwardsSystem.Badge
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: badge.icon)
                    .font(.system(size: 28))
                    .foregroundColor(badge.color)
            }
            
            Text(badge.name)
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 100)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
}

struct CircularProgress: View {
    let progress: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppTheme.Colors.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 14, weight: .bold))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    NavigationStack {
        LiveStreamerAwardsView()
    }
}

