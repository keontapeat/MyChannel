//
//  AILiveTVSection.swift
//  MyChannel
//
//  🔥🔥🔥 AI-POWERED LIVE TV SECTION 🔥🔥🔥
//  The most intelligent Live TV recommendations in the world
//
//  Created by AI Assistant on 11/29/25.
//

import SwiftUI

// MARK: - AI Live TV Section
struct AILiveTVSection: View {
    let onSelectChannel: (LiveTVChannel) -> Void
    let onSeeAll: () -> Void
    
    @StateObject private var aiAgent = LiveTVIntelligenceAgent.shared
    @StateObject private var loadingTracker = LiveChannelLoadingTracker.shared
    @EnvironmentObject private var appState: AppState
    
    @State private var forYouSection: LiveTVForYouSection?
    @State private var isLoading = true
    @State private var selectedTab: AILiveTVTab = .forYou
    @State private var showAIInsight = false  // Disabled - no AI insight banner
    
    enum AILiveTVTab: String, CaseIterable {
        case forYou = "For You"
        case trending = "Trending"
        case categories = "Categories"
    }
    
    // Check if we have any ready channels to show
    private var hasReadyChannels: Bool {
        !loadingTracker.readyChannels.isEmpty
    }
    
    // Check if we're still in initial loading phase
    private var isInitialLoading: Bool {
        !loadingTracker.isInitialLoadComplete && loadingTracker.readyChannels.isEmpty
    }
    
    var body: some View {
        // 🔥 ALWAYS show the Live TV section - never hide it completely
        VStack(alignment: .leading, spacing: 16) {
            // Header with AI badge
            headerView
            
            // AI Insight banner
            if showAIInsight, let insight = forYouSection?.aiInsight {
                aiInsightBanner(insight)
            }
            
            // Tab selector
            tabSelector
            
            // Show loading indicator while channels are loading
            if isInitialLoading && !hasReadyChannels {
                liveChannelsLoadingView
            } else {
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .forYou:
                        forYouContent
                    case .trending:
                        trendingContent
                    case .categories:
                        categoriesContent
                    }
                }
            }
        }
        .task {
            await loadAIRecommendations()
        }
        .animation(.easeOut(duration: 0.3), value: hasReadyChannels)
    }
    
    // MARK: - Loading View
    private var liveChannelsLoadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading live channels...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("Live TV")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            Button(action: onSeeAll) {
                Text("See all")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - AI Insight Banner
    
    private func aiInsightBanner(_ insight: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.yellow)
            
            Text(insight)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: { withAnimation { showAIInsight = false } }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.15, blue: 0.2), Color(red: 0.1, green: 0.1, blue: 0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AILiveTVTab.allCases, id: \.self) { tab in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedTab == tab ? .white : AppTheme.Colors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? Color.black : AppTheme.Colors.surface)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - For You Content
    
    private var forYouContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isLoading {
                loadingView
            } else if let section = forYouSection {
                // Personalized Picks
                if !section.personalizedPicks.isEmpty {
                    personalizedPicksRow(section.personalizedPicks)
                }
                
                // Because You Watched
                if !section.becauseYouWatched.isEmpty {
                    becauseYouWatchedRow(section.becauseYouWatched)
                }
                
                // Perfect for Right Now
                if !section.perfectForRightNow.isEmpty {
                    perfectForNowRow(section.perfectForRightNow)
                }
            }
        }
    }
    
    private func personalizedPicksRow(_ picks: [LiveTVRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎯 Picked for You")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if let topPick = picks.first {
                    Text("\(Int(topPick.aiConfidence * 100))% match")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(picks) { recommendation in
                        AIChannelCard(
                            channel: recommendation.channel,
                            reason: recommendation.reason,
                            confidence: recommendation.aiConfidence,
                            onSelect: { onSelectChannel(recommendation.channel) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func becauseYouWatchedRow(_ items: [BecauseYouWatchedItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📺 Because You Watched")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(items) { item in
                        BecauseYouWatchedCard(
                            item: item,
                            onSelect: { onSelectChannel(item.recommendedChannel) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func perfectForNowRow(_ picks: [TimeBasedPick]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("⏰ Perfect for Right Now")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if let first = picks.first {
                    Text(first.timeLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(picks) { pick in
                        TimeBasedCard(
                            pick: pick,
                            onSelect: { onSelectChannel(pick.channel) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Trending Content
    
    private var trendingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔥 Trending Now")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
            
            if isLoading {
                loadingView
            } else if let trending = forYouSection?.trendingNow {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(trending) { item in
                            TrendingChannelCard(
                                item: item,
                                onSelect: { onSelectChannel(item.channel) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // MARK: - Categories Content
    
    private var categoriesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📂 Browse by Category")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(LiveTVChannel.ChannelCategory.allCases, id: \.self) { category in
                        // Only show categories that have healthy channels
                        let healthyChannels = StreamHealthMLAgent.shared.healthyChannelIds
                        let categoryChannels = LiveTVChannel.sampleChannels.filter { 
                            $0.category == category && (healthyChannels.isEmpty || healthyChannels.contains($0.id))
                        }
                        
                        if !categoryChannels.isEmpty {
                            LiveTVCategoryCard(
                                category: category,
                                channelCount: categoryChannels.count,
                                onSelect: {
                                    // Filter to category - only show healthy channels
                                    if let channel = categoryChannels.first {
                                        onSelectChannel(channel)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    ShimmerLoadingCard()
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Load Data
    
    private func loadAIRecommendations() async {
        isLoading = true
        
        // 🔥 Run health check and AI recommendations in parallel!
        async let healthCheck: Void = StreamHealthMLAgent.shared.isInitialized ? () : Task { 
            _ = await StreamHealthMLAgent.shared.filterHealthyChannels(Array(LiveTVChannel.sampleChannels.prefix(20)))
        }.value
        
        let userId = appState.currentUser?.id ?? "anonymous"
        async let recommendations = aiAgent.getForYouSection(userId: userId)
        
        // Wait for both
        _ = await healthCheck
        forYouSection = await recommendations
        
        withAnimation(.easeOut(duration: 0.2)) {
            isLoading = false
        }
    }
}

// MARK: - AI Channel Card

private struct AIChannelCard: View {
    let channel: LiveTVChannel
    let reason: String
    let confidence: Double
    let onSelect: () -> Void
    
    @State private var streamReady = false
    @State private var streamFailed = false
    
    var body: some View {
        // 🔥 Always show channel - use static thumbnail as fallback
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    // Thumbnail - show live stream or fallback to static image
                    if streamFailed {
                        // Fallback to static logo image
                        AsyncImage(url: URL(string: channel.logoURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(channel.category.color.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tv.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(channel.category.color)
                                )
                        }
                        .frame(width: 180, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        LiveChannelThumbnailView(
                            streamURL: channel.streamURL,
                            posterURL: channel.logoURL,
                            fallbackStreamURL: channel.previewFallbackURL,
                            allowPlaybackInPreviews: false,
                            channelCategory: channel.category,
                            channelName: channel.name,
                            channelId: channel.id,
                            onStreamFailed: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    streamFailed = true
                                }
                            },
                            onStreamReady: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    streamReady = true
                                }
                            }
                        )
                        .frame(width: 180, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .allowsHitTesting(false)
                    }
                    
                    // LIVE badge
                    VStack {
                        HStack {
                            LiveBadgeSmall()
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                    .allowsHitTesting(false)
                    
                    // Match badge - clean green style
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(Int(confidence * 100))%")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.9))
                                )
                        }
                        Spacer()
                    }
                    .padding(8)
                    .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(reason)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("\(formatViewers(channel.viewerCount)) watching")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .frame(width: 180, alignment: .leading)
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }
    
    private func formatViewers(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Trending Channel Card

private struct TrendingChannelCard: View {
    let item: TrendingChannel
    let onSelect: () -> Void
    
    @State private var streamReady = false
    @State private var streamFailed = false
    
    var body: some View {
        // 🔥 Always show channel - use static thumbnail as fallback
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    // Thumbnail - show live stream or fallback to static image
                    if streamFailed {
                        AsyncImage(url: URL(string: item.channel.logoURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(item.channel.category.color.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tv.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(item.channel.category.color)
                                )
                        }
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        LiveChannelThumbnailView(
                            streamURL: item.channel.streamURL,
                            posterURL: item.channel.logoURL,
                            fallbackStreamURL: item.channel.previewFallbackURL,
                            allowPlaybackInPreviews: false,
                            channelCategory: item.channel.category,
                            channelName: item.channel.name,
                            channelId: item.channel.id,
                            onStreamFailed: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    streamFailed = true
                                }
                            },
                            onStreamReady: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    streamReady = true
                                }
                            }
                        )
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .allowsHitTesting(false)
                    }
                    
                    // Rank badge
                    VStack {
                        HStack {
                            Text("#\(item.rank)")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.red)
                                )
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                    .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.channel.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(item.trendingReason)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
                .frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }
}

// MARK: - Because You Watched Card

private struct BecauseYouWatchedCard: View {
    let item: BecauseYouWatchedItem
    let onSelect: () -> Void
    
    @State private var streamReady = false
    @State private var streamFailed = false
    
    var body: some View {
        // 🔥 Always show channel - use static thumbnail as fallback
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    // Thumbnail - show live stream or fallback to static image
                    if streamFailed {
                        AsyncImage(url: URL(string: item.recommendedChannel.logoURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(item.recommendedChannel.category.color.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tv.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(item.recommendedChannel.category.color)
                                )
                        }
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        LiveChannelThumbnailView(
                            streamURL: item.recommendedChannel.streamURL,
                            posterURL: item.recommendedChannel.logoURL,
                            fallbackStreamURL: item.recommendedChannel.previewFallbackURL,
                            allowPlaybackInPreviews: false,
                            channelCategory: item.recommendedChannel.category,
                            channelName: item.recommendedChannel.name,
                            channelId: item.recommendedChannel.id,
                            onStreamFailed: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    streamFailed = true
                                }
                            },
                            onStreamReady: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    streamReady = true
                                }
                            }
                        )
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .allowsHitTesting(false)
                    }
                    
                    // LIVE badge
                    VStack {
                        HStack {
                            LiveBadgeSmall()
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                    .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.recommendedChannel.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text("Because you watched \(item.watchedChannel.name)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
                .frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }
}

// MARK: - Time Based Card

private struct TimeBasedCard: View {
    let pick: TimeBasedPick
    let onSelect: () -> Void
    
    @State private var streamReady = false
    @State private var streamFailed = false
    
    var body: some View {
        // 🔥 Always show channel - use static thumbnail as fallback
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    // Thumbnail - show live stream or fallback to static image
                    if streamFailed {
                        AsyncImage(url: URL(string: pick.channel.logoURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(pick.channel.category.color.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tv.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(pick.channel.category.color)
                                )
                        }
                        .frame(width: 140, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        LiveChannelThumbnailView(
                            streamURL: pick.channel.streamURL,
                            posterURL: pick.channel.logoURL,
                            fallbackStreamURL: pick.channel.previewFallbackURL,
                            allowPlaybackInPreviews: false,
                            channelCategory: pick.channel.category,
                            channelName: pick.channel.name,
                            channelId: pick.channel.id,
                            onStreamFailed: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    streamFailed = true
                                }
                            },
                            onStreamReady: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    streamReady = true
                                }
                            }
                        )
                        .frame(width: 140, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .allowsHitTesting(false)
                    }
                    
                    // LIVE badge
                    VStack {
                        HStack {
                            LiveBadgeSmall()
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(6)
                    .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(pick.channel.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(pick.reason)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }
}

// MARK: - Live TV Category Card

private struct LiveTVCategoryCard: View {
    let category: LiveTVChannel.ChannelCategory
    let channelCount: Int
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            onSelect()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [category.color.opacity(0.8), category.color.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: categoryIcon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 2) {
                    Text(category.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("\(channelCount) channels")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.95))
    }
    
    private var categoryIcon: String {
        switch category {
        case .anime: return "sparkles.tv"
        case .scifi: return "wand.and.stars"
        case .reality: return "person.3.fill"
        case .comedy: return "face.smiling.fill"
        case .kids: return "figure.2.and.child.holdinghands"
        case .news: return "newspaper.fill"
        case .sports: return "sportscourt.fill"
        case .movies: return "film.fill"
        case .music: return "music.note.tv.fill"
        case .entertainment: return "star.fill"
        case .documentary: return "globe.americas.fill"
        case .lifestyle: return "leaf.fill"
        case .business: return "chart.line.uptrend.xyaxis"
        case .international: return "globe"
        case .classic: return "tv.fill"
        }
    }
}

// MARK: - Shimmer Loading Card

private struct ShimmerLoadingCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .frame(width: 180, height: 100)
                .overlay(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: isAnimating ? 200 : -200)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.Colors.surface)
                .frame(width: 120, height: 14)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.Colors.surface)
                .frame(width: 80, height: 10)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Live Badge Small

private struct LiveBadgeSmall: View {
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(.white)
                .frame(width: 4, height: 4)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
            Text("LIVE")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.red))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AILiveTVSection(
        onSelectChannel: { _ in },
        onSeeAll: { }
    )
    .environmentObject(AppState())
    .preferredColorScheme(.light)
}

