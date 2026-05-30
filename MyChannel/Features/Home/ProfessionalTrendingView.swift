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


// ⚡ All supporting views/sheets extracted to TrendingViewComponents.swift
