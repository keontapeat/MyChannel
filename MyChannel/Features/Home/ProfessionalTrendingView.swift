//
//  ProfessionalTrendingView.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import SwiftUI

// 🔥 Professional Trending Now Interface
// Industry-standard trending section with enterprise backend
struct ProfessionalTrendingView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var trendingService = EnhancedTrendingService.shared
    @StateObject private var termsService = TermsEnforcementService.shared
    @State private var selectedCategory: TrendingCategory = .general
    @State private var showingTrendingDetails = false
    @State private var selectedVideo: TrendingVideo?
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Header Section
                    headerSection
                    
                    // Category Filter
                    categoryFilterSection
                    
                    // Trending Videos
                    trendingVideosSection
                    
                    // Trending Topics
                    trendingTopicsSection
                    
                    // Trending Creators
                    trendingCreatorsSection
                    
                    // Trending Hashtags
                    trendingHashtagsSection
                }
            }
            .navigationTitle("Trending Now")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshTrendingData()
            }
            .task {
                await loadTrendingData()
            }
            .sheet(item: $selectedVideo) { video in
                TrendingVideoDetailsSheet(video: video)
            }
            .sheet(isPresented: $termsService.shouldShowTerms) {
                TermsAndConditionsSheet()
                    .environmentObject(termsService)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 20))
                        
                        Text("Trending Now")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Text("What's hot right now")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Live indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isRefreshing ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(), value: isRefreshing)
                    
                    Text("LIVE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            
            // Quick stats
            if !trendingService.trendingVideos.isEmpty {
                quickStatsSection
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var quickStatsSection: some View {
        HStack(spacing: 20) {
            StatBadge(
                title: "Trending Videos",
                value: "\(trendingService.trendingVideos.count)",
                icon: "play.rectangle.fill",
                color: .red
            )
            
            StatBadge(
                title: "Hot Topics",
                value: "\(trendingService.trendingTopics.count)",
                icon: "number.circle.fill",
                color: .orange
            )
            
            StatBadge(
                title: "Rising Creators",
                value: "\(trendingService.trendingCreators.count)",
                icon: "person.2.fill",
                color: .blue
            )
            
            Spacer()
        }
    }
    
    // MARK: - Category Filter
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TrendingCategory.allCases, id: \.self) { category in
                    TrendingCategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        Task {
                            await loadTrendingVideos(category: category)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Trending Videos Section
    
    private var trendingVideosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "🔥 Trending Videos",
                subtitle: "Most viral content right now"
            )
            
            if trendingService.isLoading {
                loadingView
            } else if trendingService.trendingVideos.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(trendingService.trendingVideos.prefix(10).enumerated()), id: \.element.id) { index, video in
                        TrendingVideoCard(
                            video: video,
                            rank: index + 1,
                            onTap: {
                                selectedVideo = video
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Trending Topics Section
    
    private var trendingTopicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "📈 Hot Topics",
                subtitle: "What everyone's talking about"
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(trendingService.trendingTopics.prefix(10).enumerated()), id: \.element.id) { index, topic in
                        TrendingTopicCardView(topic: topic, rank: index + 1)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Trending Creators Section
    
    private var trendingCreatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "⭐ Rising Creators",
                subtitle: "Fastest growing creators this week"
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(trendingService.trendingCreators.prefix(10).enumerated()), id: \.element.id) { index, creator in
                        TrendingCreatorCard(creator: creator, rank: index + 1)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Trending Hashtags Section
    
    private var trendingHashtagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "# Trending Tags",
                subtitle: "Popular hashtags and topics"
            )
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(trendingService.trendingHashtags.prefix(12).enumerated()), id: \.element.id) { index, hashtag in
                    TrendingHashtagCard(hashtag: hashtag, rank: index + 1)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Loading and Empty States
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { _ in
                TrendingVideoCardSkeleton()
                    .padding(.horizontal, 16)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "flame")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No trending content")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Check back later for the latest trends")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Actions
    
    private func loadTrendingData() async {
        isRefreshing = true
        
        do {
            async let videos = trendingService.loadTrendingVideos(category: selectedCategory.rawValue)
            async let topics = trendingService.loadTrendingTopics()
            async let creators = trendingService.loadTrendingCreators()
            async let hashtags = trendingService.loadTrendingHashtags()
            
            let _ = try await (videos, topics, creators, hashtags)
            
        } catch {
            print("Failed to load trending data: \(error)")
        }
        
        isRefreshing = false
    }
    
    private func loadTrendingVideos(category: TrendingCategory) async {
        do {
            let _ = try await trendingService.loadTrendingVideos(category: category.rawValue)
        } catch {
            print("Failed to load trending videos: \(error)")
        }
    }
    
    private func refreshTrendingData() async {
        await loadTrendingData()
        HapticManager.shared.impact(style: .light)
    }
}

// MARK: - Supporting Views

struct TrendingCategoryButton: View {
    let category: TrendingCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(categoryIcon(category))
                    .font(.system(size: 14))
                
                Text(categoryName(category))
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.red : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func categoryIcon(_ category: TrendingCategory) -> String {
        switch category {
        case .general: return "🔥"
        case .music: return "🎵"
        case .gaming: return "🎮"
        case .sports: return "⚽"
        case .news: return "📰"
        case .entertainment: return "🎬"
        case .education: return "📚"
        case .technology: return "💻"
        case .lifestyle: return "✨"
        case .comedy: return "😂"
        }
    }
    
    private func categoryName(_ category: TrendingCategory) -> String {
        switch category {
        case .general: return "All"
        case .music: return "Music"
        case .gaming: return "Gaming"
        case .sports: return "Sports"
        case .news: return "News"
        case .entertainment: return "Entertainment"
        case .education: return "Education"
        case .technology: return "Tech"
        case .lifestyle: return "Lifestyle"
        case .comedy: return "Comedy"
        }
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
    }
}

struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TrendingVideoCard: View {
    let video: TrendingVideo
    let rank: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 32, height: 32)
                    
                    Text("\(rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    // Trending badge
                    Text("🔥")
                        .font(.system(size: 12))
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                        .padding(4),
                    alignment: .topTrailing
                )
                
                // Video info
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(video.creatorName)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text(video.formattedViewCount)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Text(video.trendingBadge)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                        
                        if video.viralVelocity > 0.5 {
                            Text("📈 Rising Fast")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Trending score
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(video.trendingScore * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text("trending")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .red
        case 2...3: return .orange
        case 4...5: return .yellow
        default: return .gray
        }
    }
}

struct TrendingTopicCardView: View {
    let topic: TrendingTopic
    let rank: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .clipShape(Capsule())
                
                Spacer()
                
                if topic.isRising {
                    Text("📈")
                        .font(.system(size: 14))
                }
            }
            
            Text(topic.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Text("\(topic.mentions) mentions")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            HStack {
                Text("+\(Int(topic.growth * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                
                Spacer()
                
                Text(sentimentEmoji(topic.sentiment))
                    .font(.system(size: 14))
            }
        }
        .padding(12)
        .frame(width: 160, height: 120)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func sentimentEmoji(_ sentiment: Double) -> String {
        if sentiment > 0.6 { return "😊" }
        else if sentiment > 0.2 { return "😐" }
        else { return "😞" }
    }
}

struct TrendingCreatorCard: View {
    let creator: TrendingCreator
    let rank: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // Avatar with rank
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: creator.avatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                Text("\(rank)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 8, y: -8)
            }
            
            VStack(spacing: 4) {
                HStack {
                    Text(creator.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
                
                Text(creator.formattedSubscriberCount)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("+\(Int(creator.weeklyGrowth * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .frame(width: 100)
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TrendingHashtagCard: View {
    let hashtag: TrendingHashtag
    let rank: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(rank)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .clipShape(Capsule())
                
                Spacer()
                
                if hashtag.isRising {
                    Text("🚀")
                        .font(.system(size: 12))
                }
            }
            
            Text(hashtag.tag)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text("\(hashtag.usage) uses")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TrendingVideoCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 32, height: 32)
            
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Detail Sheets

struct TrendingVideoDetailsSheet: View {
    let video: TrendingVideo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Video preview
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(16/9, contentMode: .fit)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Video details
                    VStack(alignment: .leading, spacing: 12) {
                        Text(video.title)
                            .font(.system(size: 20, weight: .semibold))
                        
                        HStack {
                            Text(video.creatorName)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(video.trendingBadge)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                        }
                        
                        // Stats
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            TrendingStatItem(title: "Views", value: video.formattedViewCount)
                            TrendingStatItem(title: "Likes", value: "\(video.likeCount)")
                            TrendingStatItem(title: "Comments", value: "\(video.commentCount)")
                            TrendingStatItem(title: "Shares", value: "\(video.shareCount)")
                        }
                        
                        // Trending insights
                        if let insights = video.mlInsights {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Trending Insights")
                                    .font(.system(size: 18, weight: .semibold))
                                
                                VStack(spacing: 8) {
                                    TrendingInsightRow(title: "Trending Score", value: "\(Int(insights.trendingScore * 100))%")
                                    TrendingInsightRow(title: "Viral Potential", value: "\(Int(insights.viralPotential * 100))%")
                                    TrendingInsightRow(title: "Audience Match", value: "\(Int(insights.audienceMatch * 100))%")
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Trending Details")
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

struct TrendingStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TrendingInsightRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

struct TermsAndConditionsSheet: View {
    @EnvironmentObject private var termsService: TermsEnforcementService
    @Environment(\.dismiss) private var dismiss
    @State private var termsContent: TermsContent?
    @State private var hasScrolledToBottom = false
    @State private var isAccepting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image("MC")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Text("Terms & Conditions")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Please review and accept our terms before continuing.")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Terms content
                if let content = termsContent {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 20) {
                                ForEach(content.sections, id: \.id) { section in
                                    TermsSectionView(section: section)
                                }
                                
                                // Bottom marker for scroll detection
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                                    .onAppear {
                                        hasScrolledToBottom = true
                                    }
                            }
                            .padding()
                        }
                        .onAppear {
                            // Auto-scroll to bottom after a delay to ensure user sees content
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView("Loading terms...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await acceptTerms()
                        }
                    }) {
                        HStack {
                            if isAccepting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isAccepting ? "Processing..." : "Agree & Continue")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isAccepting)
                    
                    Text("By tapping \"Agree & Continue\" you accept our Terms of Service and Privacy Policy.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .task {
                termsContent = await termsService.getTermsContent()
            }
            .interactiveDismissDisabled() // Prevent dismissal without accepting
        }
    }
    
    private func acceptTerms() async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        
        isAccepting = true
        
        do {
            try await termsService.acceptTerms(userId: userId)
            dismiss()
        } catch {
            // Handle error
            print("Failed to accept terms: \(error)")
        }
        
        isAccepting = false
    }
}

struct TermsSectionView: View {
    let section: EnforcementTermsSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                
                Text(section.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Text(section.description)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .lineSpacing(4)
            
            if !section.details.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(section.details, id: \.self) { detail in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            Text(detail)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ProfessionalTrendingView()
        .environmentObject(AppState())
}
