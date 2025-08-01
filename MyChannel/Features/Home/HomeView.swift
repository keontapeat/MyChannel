// 
//  HomeView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct HomeView: View {
    @State private var selectedFilter: ContentFilter = .all
    @State private var searchText: String = ""
    @State private var showingFilters: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isRefreshing: Bool = false
    @State private var showingStories: Bool = true
    @State private var headerOpacity: Double = 1.0
    @State private var isLoading: Bool = false
    @State private var watchLaterVideos: Set<String> = []
    @State private var likedVideos: Set<String> = []
    
    // Sample stories data
    @State private var stories: [Story] = Story.sampleStories
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Parallax Header
                        ParallaxHeaderView(
                            scrollOffset: scrollOffset,
                            headerOpacity: headerOpacity,
                            selectedFilter: $selectedFilter,
                            searchText: $searchText,
                            showingFilters: $showingFilters
                        )
                        
                        // Stories Section
                        if showingStories {
                            StoriesSection(
                                stories: stories,
                                onStoryTap: { story in
                                    // Handle story tap
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                        
                        // Trending Carousel
                        TrendingCarousel(
                            videos: Video.sampleVideos.filter { $0.viewCount > 100000 }
                        )

                        // Filter Chips with Enhanced Animation
                        AnimatedFilterChipsView(
                            selectedFilter: $selectedFilter,
                            scrollOffset: scrollOffset
                        )
                        
                        // Live Streams Section
                        LiveStreamsSection()
                        
                        // Main Video Feed
                        VideoFeedSection(
                            videos: Video.sampleVideos,
                            selectedFilter: selectedFilter,
                            watchLaterVideos: $watchLaterVideos,
                            likedVideos: $likedVideos,
                            isLoading: $isLoading
                        )
                        
                        // Loading indicator for pagination
                        if isLoading {
                            PaginationLoadingView()
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                .onScrollOffsetChange { offset in
                    scrollOffset = offset
                    let offsetValue = Double(abs(offset))
                    headerOpacity = max(0, 1 - offsetValue / 100.0)
                }
                .refreshable {
                    await refreshContent()
                }
                .background(AppTheme.Colors.background)
            }
        }
        .onAppear {
            // Simulate loading
            loadMoreContent()
        }
    }
    
    private func refreshContent() async {
        isRefreshing = true
        // Simulate network request
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        isRefreshing = false
    }
    
    private func loadMoreContent() {
        guard !isLoading else { return }
        isLoading = true
        
        // Simulate loading more content
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
        }
    }
}

// MARK: - Parallax Header View
struct ParallaxHeaderView: View {
    let scrollOffset: CGFloat
    let headerOpacity: Double
    @Binding var selectedFilter: ContentFilter
    @Binding var searchText: String
    @Binding var showingFilters: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Dynamic header with parallax effect
            HStack {
                // Animated logo
                HStack(spacing: 12) {
                    Image("MyChannel")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .scaleEffect(1 + min(scrollOffset / 500, 0.2))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: scrollOffset)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MyChannel")
                            .font(AppTheme.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Welcome back!")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .opacity(headerOpacity)
                    }
                }
                
                Spacer()
                
                // Action buttons with enhanced animations
                HStack(spacing: 16) {
                    // Search button
                    AnimatedButton(
                        icon: "magnifyingglass",
                        action: {
                            // Show search
                        }
                    )
                    
                    // Filters button
                    AnimatedButton(
                        icon: "slider.horizontal.3",
                        isActive: showingFilters,
                        action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingFilters.toggle()
                            }
                        }
                    )
                    
                    // Notifications with enhanced badge
                    NotificationButton()
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                // Gradient background that responds to scroll
                LinearGradient(
                    colors: [
                        AppTheme.Colors.background,
                        AppTheme.Colors.background.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(headerOpacity)
            )
            .overlay(
                // Subtle border
                Rectangle()
                    .fill(AppTheme.Colors.divider.opacity(0.3))
                    .frame(height: 1)
                    .opacity(1 - headerOpacity),
                alignment: .bottom
            )
        }
        .offset(y: scrollOffset > 0 ? -scrollOffset * 0.5 : 0)
        .opacity(headerOpacity)
    }
}

// MARK: - Stories Section
struct StoriesSection: View {
    let stories: [Story]
    let onStoryTap: (Story) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Add story button
                AddStoryButton()
                
                // Story items
                ForEach(stories) { story in
                    StoryItem(story: story) {
                        onStoryTap(story)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }
}

// MARK: - Story Item
struct StoryItem: View {
    let story: Story
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Story ring
                    if story.isViewed {
                        Circle()
                            .stroke(AppTheme.Colors.textTertiary, lineWidth: 3)
                            .frame(width: 70, height: 70)
                    } else {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 70, height: 70)
                    }
                    
                    // Avatar
                    AsyncImage(url: URL(string: story.creator.profileImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                Image(systemName: "person.circle")
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            )
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    
                    // Live indicator
                    if story.isLive {
                        Text("LIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(4)
                            .offset(y: 25)
                    }
                }
                
                Text(story.creator.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .frame(width: 70)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(story.isViewed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: story.isViewed)
    }
}

// MARK: - Add Story Button
struct AddStoryButton: View {
    var body: some View {
        Button(action: {
            // Add story
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(AppTheme.Colors.divider, lineWidth: 2)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                Text("Your story")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 70)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Trending Carousel
struct TrendingCarousel: View {
    let videos: [Video]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("Trending Now")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                Button("See all") {
                    // Show all trending
                }
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(videos.filter { $0.viewCount > 100000 }.prefix(5)) { video in
                        TrendingVideoCard(video: video)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }
}

// MARK: - Trending Video Card
struct TrendingVideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Fixed size thumbnail container
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                .scaleEffect(0.8)
                        )
                }
                .frame(width: 180, height: 101) // Fixed 16:9 aspect ratio
                .clipped()
                .cornerRadius(AppTheme.CornerRadius.md)
                
                // Gradient overlay for better text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .cornerRadius(AppTheme.CornerRadius.md)
                
                // Duration badge
                Text(video.formattedDuration)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(4)
                    .padding(8)
            }
            
            // Video info - fixed height container
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .top) // Fixed height for 2 lines
                
                HStack(spacing: 6) {
                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
                    
                    Text(video.creator.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    if video.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    Text("\(video.formattedViews) views")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(video.timeAgo)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .frame(width: 180, height: 64, alignment: .top) // Fixed height for consistent cards
        }
        .frame(width: 180) // Fixed card width
        .onTapGesture {
            // Play video
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Animated Filter Chips View
struct AnimatedFilterChipsView: View {
    @Binding var selectedFilter: ContentFilter
    let scrollOffset: CGFloat
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ContentFilter.allCases, id: \.self) { filter in
                    AnimatedFilterChip(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter,
                        action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedFilter = filter
                            }
                            
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .background(
            AppTheme.Colors.background
                .opacity(min(1.0, abs(scrollOffset) / 50.0))
        )
    }
}

// MARK: - Animated Filter Chip
struct AnimatedFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text(title)
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, isSelected ? 20 : 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isSelected {
                        AppTheme.Colors.gradient
                    } else {
                        AppTheme.Colors.surface
                    }
                    
                    // Pressed overlay
                    if isPressed {
                        Color.black.opacity(0.1)
                    }
                }
            )
            .foregroundColor(
                isSelected ? .white : AppTheme.Colors.textPrimary
            )
            .cornerRadius(AppTheme.CornerRadius.xl)
            .shadow(
                color: isSelected ? AppTheme.Colors.primary.opacity(0.3) : .clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: 2
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

// MARK: - Live Streams Section
struct LiveStreamsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                    
                    Text("Live Now")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                Button("See all") {
                    // Show all live streams
                }
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3) { index in
                        LiveStreamCard(
                            creator: User.sampleUsers[index % User.sampleUsers.count],
                            viewerCount: Int.random(in: 100...5000)
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }
}

// MARK: - Live Stream Card
struct LiveStreamCard: View {
    let creator: User
    let viewerCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Stream preview
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 160, height: 90)
                    .cornerRadius(AppTheme.CornerRadius.md)
                    .overlay(
                        VStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Text("LIVE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    )
                
                // Live badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 6, height: 6)
                    
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.8))
                .cornerRadius(4)
                .padding(6)
            }
            
            // Creator info
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(creator.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("\(viewerCount.formatted()) watching")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .frame(width: 160, alignment: .leading)
        }
    }
}

// MARK: - Video Feed Section
struct VideoFeedSection: View {
    let videos: [Video]
    let selectedFilter: ContentFilter
    @Binding var watchLaterVideos: Set<String>
    @Binding var likedVideos: Set<String>
    @Binding var isLoading: Bool
    
    var filteredVideos: [Video] {
        if selectedFilter == .all {
            return videos
        } else {
            return videos.filter { $0.category.rawValue == selectedFilter.rawValue }
        }
    }
    
    var body: some View {
        LazyVStack(spacing: AppTheme.Spacing.lg) {
            ForEach(filteredVideos) { video in
                EnhancedVideoCard(
                    video: video,
                    isLiked: likedVideos.contains(video.id),
                    isWatchLater: watchLaterVideos.contains(video.id),
                    onLike: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            if likedVideos.contains(video.id) {
                                likedVideos.remove(video.id)
                            } else {
                                likedVideos.insert(video.id)
                            }
                        }
                    },
                    onWatchLater: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            if watchLaterVideos.contains(video.id) {
                                watchLaterVideos.remove(video.id)
                            } else {
                                watchLaterVideos.insert(video.id)
                            }
                        }
                    }
                )
                .padding(.horizontal, AppTheme.Spacing.md)
                .onAppear {
                    if video.id == filteredVideos.last?.id {
                        loadMoreContent()
                    }
                }
            }
        }
        .padding(.top, AppTheme.Spacing.md)
    }
    
    private func loadMoreContent() {
        guard !isLoading else { return }
        // Load more content logic
    }
}

// MARK: - Enhanced Video Card
struct EnhancedVideoCard: View {
    let video: Video
    let isLiked: Bool
    let isWatchLater: Bool
    let onLike: () -> Void
    let onWatchLater: () -> Void
    
    @State private var showingContextMenu: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var isPressed: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enhanced thumbnail with multiple overlays
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    SkeletonView()
                        .aspectRatio(16/9, contentMode: .fill)
                }
                .cornerRadius(AppTheme.CornerRadius.lg)
                .clipped()
                .overlay(
                    // Gradient overlay for better text readability
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.3)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .cornerRadius(AppTheme.CornerRadius.lg)
                )
                
                // Multiple overlays
                HStack {
                    VStack(spacing: 4) {
                        // Quality badge
                        if video.duration > 3600 {
                            Text("4K")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(AppTheme.Colors.primary)
                                .cornerRadius(2)
                        }
                        
                        // Duration
                        Text(video.formattedDuration)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                .padding(12)
            }
            
            // Enhanced video info
            HStack(alignment: .top, spacing: 12) {
                // Creator avatar with online status
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                Image(systemName: "person.circle")
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            )
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    
                    // Online status
                    if video.creator.isCreator {
                        Circle()
                            .fill(AppTheme.Colors.success)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.Colors.background, lineWidth: 2)
                            )
                    }
                }
                
                // Title and metadata
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(AppTheme.Typography.headline)
                        .lineLimit(2)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text(video.creator.displayName)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        if video.creator.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        Text("•")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("\(video.formattedViews) views")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("•")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text(video.timeAgo)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Enhanced more menu
                Menu {
                    Button(action: onWatchLater) {
                        Label(
                            isWatchLater ? "Remove from Watch Later" : "Save to Watch Later",
                            systemImage: isWatchLater ? "bookmark.fill" : "bookmark"
                        )
                    }
                    
                    Button(action: {}) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {}) {
                        Label("Report", systemImage: "exclamationmark.triangle")
                    }
                    
                    Button(action: {}) {
                        Label("Not Interested", systemImage: "hand.thumbsdown")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(8)
                }
            }
            
            // Enhanced action buttons
            HStack(spacing: 32) {
                // Like button with animation
                Button(action: onLike) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(isLiked ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                            .scaleEffect(isLiked ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                        
                        Text("\(video.likeCount + (isLiked ? 1 : 0))")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Comments
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("\(video.commentCount)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Share
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("Share")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Watch later toggle
                Button(action: onWatchLater) {
                    Image(systemName: isWatchLater ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundColor(isWatchLater ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                        .scaleEffect(isWatchLater ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isWatchLater)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .offset(dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
        .onTapGesture {
            // Play video
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

// MARK: - Supporting Views and Extensions

struct AnimatedButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    init(icon: String, isActive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.isActive = isActive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                .padding(8)
                .background(
                    Circle()
                        .fill(isActive ? AppTheme.Colors.primary.opacity(0.1) : Color.clear)
                )
                .scaleEffect(isActive ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NotificationButton: View {
    @State private var badgeCount: Int = 3
    
    var body: some View {
        Button(action: {}) {
            ZStack {
                Image(systemName: "bell")
                    .font(.title2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(AppTheme.Colors.primary)
                        .clipShape(Circle())
                        .offset(x: 10, y: -10)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SkeletonView: View {
    @State private var isAnimating: Bool = false
    
    var body: some View {
        Rectangle()
            .fill(AppTheme.Colors.surface)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.4), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 200 : -200)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct PaginationLoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                .scaleEffect(0.8)
            
            Text("Loading more videos...")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding()
    }
}

// MARK: - Story Model
struct Story: Identifiable {
    let id: String
    let creator: User
    let isLive: Bool
    let isViewed: Bool
    let thumbnail: String
    
    init(id: String = UUID().uuidString, creator: User, isLive: Bool = false, isViewed: Bool = false, thumbnail: String = "") {
        self.id = id
        self.creator = creator
        self.isLive = isLive
        self.isViewed = isViewed
        self.thumbnail = thumbnail
    }
}

extension Story {
    static let sampleStories: [Story] = [
        Story(creator: User.sampleUsers[0], isLive: true),
        Story(creator: User.sampleUsers[1], isViewed: true),
        Story(creator: User.sampleUsers[0], isLive: false),
    ]
}

// MARK: - Enhanced Content Filter
enum ContentFilter: String, CaseIterable {
    case all = "all"
    case trending = "trending"
    case gaming = "gaming"
    case music = "music"
    case education = "education"
    case technology = "technology"
    case entertainment = "entertainment"
    case sports = "sports"
    case news = "news"
    case live = "live"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .trending: return "Trending"
        case .gaming: return "Gaming"
        case .music: return "Music"
        case .education: return "Education"
        case .technology: return "Technology"
        case .entertainment: return "Entertainment"
        case .sports: return "Sports"
        case .news: return "News"
        case .live: return "Live"
        }
    }
}

#Preview {
    HomeView()
}