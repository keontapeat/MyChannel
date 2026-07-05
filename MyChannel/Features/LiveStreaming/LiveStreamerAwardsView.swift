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
        .navigationTitle("Streamer Awards")
        .navigationBarTitleDisplayMode(.large)
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
                            ForEach(LiveStreamerAwardsSystem.Timeframe.allCases, id: \.rawValue) { timeframe in
                                AwardsFilterChip(
                                    title: timeframe.rawValue,
                                    isSelected: selectedTimeframe == timeframe
                                ) {
                                    selectedTimeframe = timeframe
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        awards.applyFilters(timeframe: timeframe, category: selectedCategory)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Category picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(LiveStreamerAwardsSystem.LeaderboardCategory.allCases, id: \.rawValue) { category in
                                AwardsFilterChip(
                                    title: category.rawValue,
                                    icon: category.icon,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        awards.applyFilters(timeframe: selectedTimeframe, category: category)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                if awards.topStreamers.isEmpty {
                    leaderboardEmptyState
                } else {
                    if let topStreamer = awards.topStreamers.first {
                        ZStack {
                            NavigationLink(destination: CreatorProfileView(creator: topStreamer.streamer)) {
                                EmptyView()
                            }
                            .opacity(0)

                            featuredTopStreamerCard(ranking: topStreamer)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Rankings List
                    VStack(spacing: 12) {
                        ForEach(Array(awards.topStreamers.dropFirst().enumerated()), id: \.element.id) { index, ranking in
                            RankingCard(ranking: ranking)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 20)
        }
    }

    private var leaderboardEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text("No streamers ranked yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("No one has charted in \(selectedCategory.rawValue) for \(selectedTimeframe.rawValue.lowercased()) yet. Check back soon or pick another filter.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func featuredTopStreamerCard(ranking: LiveStreamerAwardsSystem.StreamerRanking) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                featuredAvatar(ranking: ranking)
                featuredInfoColumn(ranking: ranking)
                Spacer(minLength: 0)
                featuredMedalBadge
            }
            featuredFollowButton(ranking: ranking)
        }
        .padding(12)
        .background(featuredCardBackground)
        .overlay(featuredCardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: AppTheme.Colors.primary.opacity(0.18), radius: 12, x: 0, y: 8)
    }

    private func featuredAvatar(ranking: LiveStreamerAwardsSystem.StreamerRanking) -> some View {
        ZStack(alignment: .bottomTrailing) {
            CachedAsyncImage(
                url: ranking.streamer.profileImageURL.flatMap(URL.init),
                content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                },
                placeholder: {
                    LinearGradient(
                        colors: [Color(.systemGray4), Color(.systemGray2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Image(systemName: "person.crop.square.fill")
                            .font(.system(size: 54, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                    )
                }
            )
            .frame(width: 128, height: 142)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if ranking.isLiveNow {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(AppTheme.Colors.live, in: Capsule())
                .padding(8)
                .accessibilityLabel("Live now")
            }
        }
    }

    private func featuredFollowButton(ranking: LiveStreamerAwardsSystem.StreamerRanking) -> some View {
        let isFollowing = awards.isFollowing(ranking.streamer.id)
        return Button {
            withAnimation(AppTheme.AnimationPresets.spring) {
                awards.toggleFollow(ranking.streamer.id)
            }
        } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isFollowing ? AppTheme.Colors.textPrimary : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isFollowing ? AppTheme.Colors.backgroundSecondary : AppTheme.Colors.primary,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFollowing ? "Following \(ranking.streamer.displayName)" : "Follow \(ranking.streamer.displayName)")
    }

    private func featuredInfoColumn(ranking: LiveStreamerAwardsSystem.StreamerRanking) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Streamer of the \(selectedTimeframe.periodNoun)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)

            Text("#1")
                .font(.system(size: 50, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.Colors.primary)

            Text(ranking.streamer.displayName)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)

            Divider()

            HStack(spacing: 18) {
                featuredStat(label: "Hours Streamed", value: String(format: "%.0f", ranking.totalHoursStreamed))
                featuredStat(label: "Peak CCU", value: formatCompactNumber(ranking.peakViewers))
            }
        }
    }

    private func featuredStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }

    private var featuredMedalBadge: some View {
        VStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.16))
                    .frame(width: 58, height: 58)
                Image(systemName: "medal.star.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
    }

    private var featuredCardBackground: some View {
        LinearGradient(
            colors: [Color(.systemBackground), AppTheme.Colors.primary.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var featuredCardBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(AppTheme.Colors.primary.opacity(0.65), lineWidth: 2)
    }

    private func formatCompactNumber(_ value: Int) -> String {
        if value >= 1000 {
            let formatted = Double(value) / 1000.0
            return formatted.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(formatted))K" : String(format: "%.1fK", formatted)
        }
        return "\(value)"
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
            isLive: awards.currentSeason.isCurrentlyLive,
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

    /// Deterministic vote count from stable seeds so numbers don't jitter on redraw.
    private func stableVoteCount(categoryId: String, index: Int, salt: Int = 0) -> Int {
        var hasher = Hasher()
        hasher.combine(categoryId)
        hasher.combine(index)
        hasher.combine(salt)
        let base = abs(hasher.finalize())
        return 100 + (base % 900)
    }
    
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
                                let nomineeId = "\(category.id)-\(index)"
                                NomineeCard(
                                    nominee: AwardNominee(
                                        id: nomineeId,
                                        streamerName: "Nominee \(index + 1)",
                                        categoryName: category.rawValue,
                                        voteCount: stableVoteCount(categoryId: category.id, index: index) + awards.voteBoost(forNominee: nomineeId),
                                        avgViewers: "2.4K",
                                        hoursStreamed: "142",
                                        subscribers: "856"
                                    ),
                                    isVoted: awards.didVote(forNominee: nomineeId, inCategory: category.id),
                                    onVote: {
                                        awards.castVote(nomineeId: nomineeId, categoryId: category.id)
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
                                // Play acceptance speech video if winner has one
                                if let videoId = winner.acceptanceSpeechVideoId {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("NavigateToVideoId"),
                                        object: videoId
                                    )
                                }
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

    /// Human-readable countdown to the end of the voting window.
    private var votingTimeRemaining: String {
        let seconds = awards.currentSeason.endDate.timeIntervalSinceNow
        guard seconds > 0 else { return "Voting closed" }
        let days = Int(seconds / 86400)
        if days >= 1 { return "\(days)d left" }
        let hours = Int(seconds / 3600)
        if hours >= 1 { return "\(hours)h left" }
        let minutes = max(1, Int(seconds / 60))
        return "\(minutes)m left"
    }

    /// Stable, descending-sorted nominees for a category's live voting panel.
    private func votingNominees(for category: LiveStreamerAwardsSystem.AwardCategory) -> [AwardNominee] {
        (0..<3).map { index in
            let nomineeId = "\(category.id)-vote-\(index)"
            return AwardNominee(
                id: nomineeId,
                streamerName: "Nominee \(index + 1)",
                categoryName: category.rawValue,
                voteCount: stableVoteCount(categoryId: category.id, index: index, salt: 7) + awards.voteBoost(forNominee: nomineeId),
                avgViewers: "2.4K",
                hoursStreamed: "142",
                subscribers: "856"
            )
        }
        .sorted { $0.voteCount > $1.voteCount }
    }
    
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
                    Text(votingTimeRemaining)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // Category voting results
            ForEach(Array(LiveStreamerAwardsSystem.AwardCategory.allCases.prefix(3)), id: \.id) { category in
                votingCategoryPanel(category: category)
            }
        }
    }

    private func votingCategoryPanel(category: LiveStreamerAwardsSystem.AwardCategory) -> some View {
        let nominees = votingNominees(for: category)
        let totalVotes = max(1, nominees.reduce(0) { $0 + $1.voteCount })
        return VStack(alignment: .leading, spacing: 12) {
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
                ForEach(Array(nominees.enumerated()), id: \.element.id) { index, nominee in
                    VotingProgressBar(
                        nominee: nominee,
                        totalVotes: totalVotes,
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
                    progress: LiveStreamerAwardsSystem.allAchievements.isEmpty ? 0 : Double(awards.myAchievements.count) / Double(LiveStreamerAwardsSystem.allAchievements.count),
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
            myRankBadge(ranking: ranking)
            myRankChange(ranking: ranking)
            myRankPoints(ranking: ranking)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AppTheme.Colors.surface)
        .cornerRadius(20)
        .padding(.horizontal, 16)
    }

    private func myRankBadge(ranking: LiveStreamerAwardsSystem.StreamerRanking) -> some View {
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
    }

    @ViewBuilder
    private func myRankChange(ranking: LiveStreamerAwardsSystem.StreamerRanking) -> some View {
        if let change = ranking.rankChange {
            let symbol = change > 0 ? "arrow.up" : (change < 0 ? "arrow.down" : "minus")
            let tint: Color = change > 0 ? .green : (change < 0 ? .red : .gray)
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .foregroundColor(tint)
                Text("\(abs(change)) from last \(selectedTimeframe.periodNoun.lowercased())")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func myRankPoints(ranking: LiveStreamerAwardsSystem.StreamerRanking) -> some View {
        VStack(spacing: 4) {
            Text("\(ranking.points) Points")
                .font(.system(size: 24, weight: .bold))
            Text("\(awards.percentileLabel(for: ranking.rank)) of streamers")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
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

struct AwardsFilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            }
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

    @ObservedObject private var awards = LiveStreamerAwardsSystem.shared

    private var isFollowing: Bool { awards.isFollowing(ranking.streamer.id) }

    var body: some View {
        ZStack {
            NavigationLink(destination: CreatorProfileView(creator: ranking.streamer)) {
                EmptyView()
            }
            .opacity(0)

            rowContent
        }
        .padding(12)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 7, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(ranking.rank), \(ranking.streamer.displayName), \(categoryLabel), \(compactWeeklyViews) weekly views")
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            rankColumn

            avatarView

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ranking.streamer.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    if ranking.streamer.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.verificationBlue)
                    }
                }
                HStack(spacing: 5) {
                    Image(systemName: categoryIcon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(categoryLabel)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                    Text(compactWeeklyViews)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .contentTransition(.numericText())
                }
                Text("Weekly Views")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            followButton
        }
    }

    private var rankColumn: some View {
        VStack(spacing: 2) {
            Text("\(ranking.rank)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)

            if let change = ranking.rankChange, change != 0 {
                HStack(spacing: 1) {
                    Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(abs(change))")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(change > 0 ? AppTheme.Colors.success : AppTheme.Colors.error)
            }
        }
        .frame(width: 30)
    }

    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            CachedAsyncImage(
                url: ranking.streamer.profileImageURL.flatMap(URL.init),
                content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                },
                placeholder: {
                    LinearGradient(
                        colors: [ranking.tier.color.opacity(0.95), ranking.tier.color.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Text(String(ranking.streamer.displayName.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                }
            )
            .frame(width: 46, height: 46)
            .clipShape(Circle())

            if ranking.isLiveNow {
                Text("LIVE")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(AppTheme.Colors.live, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.Colors.cardBackground, lineWidth: 1.5))
                    .offset(x: 6, y: 6)
                    .accessibilityLabel("Live now")
            }
        }
    }

    private var followButton: some View {
        Button {
            withAnimation(AppTheme.AnimationPresets.spring) {
                awards.toggleFollow(ranking.streamer.id)
            }
        } label: {
            Text(isFollowing ? "Following" : "Follow")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isFollowing ? AppTheme.Colors.textPrimary : .white)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(
                    isFollowing ? AppTheme.Colors.backgroundSecondary : AppTheme.Colors.primary,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFollowing ? "Following \(ranking.streamer.displayName)" : "Follow \(ranking.streamer.displayName)")
        .accessibilityHint("Double tap to \(isFollowing ? "unfollow" : "follow")")
    }

    private var categoryLabel: String {
        if ranking.categoryScores.keys.contains(.gamingStreamer) { return "Gaming" }
        if ranking.categoryScores.keys.contains(.justChattingStreamer) { return "Just Chatting" }
        if ranking.categoryScores.keys.contains(.creativeStreamer) { return "Creative" }
        return "Overall"
    }

    private var categoryIcon: String {
        if ranking.categoryScores.keys.contains(.gamingStreamer) { return "gamecontroller.fill" }
        if ranking.categoryScores.keys.contains(.justChattingStreamer) { return "message.fill" }
        if ranking.categoryScores.keys.contains(.creativeStreamer) { return "paintbrush.fill" }
        return "crown.fill"
    }

    private var compactWeeklyViews: String {
        if ranking.totalViews >= 1000 {
            let value = Double(ranking.totalViews) / 1000.0
            return value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))K" : String(format: "%.1fK", value)
        }
        return "\(ranking.totalViews)"
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

