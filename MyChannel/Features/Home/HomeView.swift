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
    @State private var selectedVideo: Video? = nil
    @State private var showingVideoPlayer: Bool = false
    @State private var selectedStory: Story? = nil
    @State private var showingStoryViewer: Bool = false
    
    // Enhanced stories data
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
                        
                        // Professional Stories Section
                        if showingStories {
                            ProfessionalStoriesSection(
                                stories: stories,
                                onStoryTap: { story in
                                    selectedStory = story
                                    showingStoryViewer = true
                                },
                                onAddStory: {
                                    // Handle add story
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                        
                        // Trending Carousel with clickable videos
                        ClickableTrendingCarousel(
                            videos: Video.sampleVideos.filter { $0.viewCount > 100000 },
                            onVideoTap: { video in
                                print("🎬 Trending video tapped: \(video.title)")
                                selectedVideo = video
                                showingVideoPlayer = true
                                print("🎬 State set - selectedVideo: \(selectedVideo?.title ?? "nil"), showingVideoPlayer: \(showingVideoPlayer)")
                            }
                        )

                        // Filter Chips with Enhanced Animation
                        AnimatedFilterChipsView(
                            selectedFilter: $selectedFilter,
                            scrollOffset: scrollOffset
                        )
                        
                        // Live Streams Section with clickable streams
                        ClickableLiveStreamsSection(
                            onStreamTap: { creator in
                                // Handle live stream tap
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        )
                        
                        // Main Video Feed with navigation
                        ClickableVideoFeedSection(
                            videos: Video.sampleVideos,
                            selectedFilter: selectedFilter,
                            watchLaterVideos: $watchLaterVideos,
                            likedVideos: $likedVideos,
                            isLoading: $isLoading,
                            onVideoTap: { video in
                                print("🎬 Feed video tapped: \(video.title)")
                                selectedVideo = video
                                showingVideoPlayer = true
                                print("🎬 State set - selectedVideo: \(selectedVideo?.title ?? "nil"), showingVideoPlayer: \(showingVideoPlayer)")
                            }
                        )
                        
                        // Loading indicator for pagination
                        if isLoading {
                            PaginationLoadingView()
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                .refreshable {
                    await refreshContent()
                }
                .background(AppTheme.Colors.background)
            }
        }
        .onAppear {
            loadMoreContent()
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let video = selectedVideo {
                VideoDetailView(video: video)
                    .onAppear {
                        print("🎬 VideoDetailView appeared for: \(video.title)")
                    }
                    .onDisappear {
                        print("🎬 VideoDetailView disappeared")
                        selectedVideo = nil
                    }
            } else {
                Text("No video selected")
                    .foregroundColor(.white)
                    .background(Color.black)
            }
        }
        .onChange(of: showingVideoPlayer) { oldValue, newValue in
            print("🎬 showingVideoPlayer changed: \(oldValue) -> \(newValue)")
        }
        .onChange(of: selectedVideo) { oldValue, newValue in
            print("🎬 selectedVideo changed: \(oldValue?.title ?? "nil") -> \(newValue?.title ?? "nil")")
        }
        .fullScreenCover(isPresented: $showingStoryViewer) {
            if let story = selectedStory {
                StoryViewerView(
                    stories: stories,
                    initialStory: story,
                    onDismiss: {
                        showingStoryViewer = false
                        selectedStory = nil
                    }
                )
            }
        }
    }
    
    private func refreshContent() async {
        isRefreshing = true
        // Simulate network request
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Refresh stories and videos
        stories = Story.sampleStories
        
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
    
    @State private var logoScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    // MyChannel logo using your actual red MC logo asset
                    HStack(spacing: 12) {
                        // Your actual MyChannel logo from Assets with subtle zoom animation
                        Image("MyChannel")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                            .scaleEffect(logoScale * max(0.8, 1.0 - abs(scrollOffset) / 200.0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scrollOffset)
                            .animation(.easeInOut(duration: 2.0), value: logoScale)
                            .onAppear {
                                startSubtleZoom()
                            }
                        
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
                    
                    // Enhanced action buttons
                    HStack(spacing: 16) {
                        NavigationLink(destination: SearchView()) {
                            ProfessionalActionButton(
                                icon: "magnifyingglass",
                                isActive: false
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        ProfessionalActionButton(
                            icon: "slider.horizontal.3",
                            isActive: showingFilters,
                            action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingFilters.toggle()
                                }
                            }
                        )
                        
                        NavigationLink(destination: NotificationsView()) {
                            NotificationButton()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.background,
                            AppTheme.Colors.background.opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .opacity(headerOpacity)
                )
                .overlay(
                    Rectangle()
                        .fill(AppTheme.Colors.divider.opacity(0.2))
                        .frame(height: 1)
                        .opacity(1 - headerOpacity),
                    alignment: .bottom
                )
            }
            .offset(y: scrollOffset > 0 ? -scrollOffset * 0.5 : 0)
            .opacity(headerOpacity)
        }
    }
    
    private func startSubtleZoom() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 2.0)) {
                logoScale = logoScale == 1.0 ? 1.08 : 1.0
            }
        }
    }
}

// MARK: - Professional Stories Section
struct ProfessionalStoriesSection: View {
    let stories: [Story]
    let onStoryTap: (Story) -> Void
    let onAddStory: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Stories")
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button("See all") {
                    // Navigate to stories feed
                }
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.sm)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Professional Add Story Button
                    ProfessionalAddStoryButton(action: onAddStory)
                    
                    // Story items with enhanced design
                    ForEach(stories) { story in
                        ProfessionalStoryItem(story: story) {
                            onStoryTap(story)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .background(AppTheme.Colors.background)
    }
}

// MARK: - Professional Story Item
struct ProfessionalStoryItem: View {
    let story: Story
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Professional gradient ring
                    ZStack {
                        if story.isViewed {
                            Circle()
                                .stroke(AppTheme.Colors.textTertiary.opacity(0.3), lineWidth: 2)
                                .frame(width: 74, height: 74)
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
                                .frame(width: 74, height: 74)
                                .shadow(
                                    color: AppTheme.Colors.primary.opacity(0.2),
                                    radius: 4,
                                    x: 0,
                                    y: 2
                                )
                        }
                    }
                    
                    // Enhanced avatar with loading state
                    AsyncImage(url: URL(string: story.creator?.profileImageURL ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            Circle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                        .font(.system(size: 32))
                                )
                        case .empty:
                            Circle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                        .scaleEffect(0.7)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 68, height: 68)
                    .clipShape(Circle())
                    
                    // Professional live indicator
                    if story.isLive {
                        VStack(spacing: 2) {
                            Spacer()
                            
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 4, height: 4)
                                    .scaleEffect(1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                                
                                Text("LIVE")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary)
                                    .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 2, x: 0, y: 1)
                            )
                        }
                        .frame(width: 68, height: 68)
                    }
                }
                
                Text(story.creator?.displayName ?? "Unknown")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .frame(width: 74)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : (story.isViewed ? 0.97 : 1.0))
        .opacity(story.isViewed ? 0.7 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: story.isViewed)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .accessibilityLabel("\(story.creator?.displayName ?? "Unknown")'s story")
        .accessibilityHint(story.isLive ? "Live story" : "Double tap to view story")
    }
}

// MARK: - Professional Add Story Button
struct ProfessionalAddStoryButton: View {
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(AppTheme.Colors.divider, lineWidth: 2)
                        .frame(width: 74, height: 74)
                    
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 68, height: 68)
                        .overlay(
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        )
                }
                
                Text("Your story")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 74)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .accessibilityLabel("Add your story")
        .accessibilityHint("Double tap to create a new story")
    }
}

// MARK: - Clickable Trending Carousel
struct ClickableTrendingCarousel: View {
    let videos: [Video]
    let onVideoTap: (Video) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                        .font(.system(size: 16))
                    
                    Text("Trending Now")
                        .font(AppTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                NavigationLink("See all", destination: TrendingView())
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(videos.filter { $0.viewCount > 100000 }.prefix(5)) { video in
                        ClickableTrendingVideoCard(video: video) {
                            onVideoTap(video)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }
}

// MARK: - Clickable Trending Video Card
struct ClickableTrendingVideoCard: View {
    let video: Video
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Enhanced thumbnail with professional overlay
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            Rectangle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppTheme.Colors.textTertiary)
                                )
                        case .empty:
                            Rectangle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                        .scaleEffect(0.8)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 180, height: 101)
                    .clipped()
                    .cornerRadius(AppTheme.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                    )
                    
                    // Professional gradient overlay
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .cornerRadius(AppTheme.CornerRadius.md)
                    
                    // Enhanced duration badge
                    HStack(spacing: 4) {
                        if video.isLive {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 4, height: 4)
                            Text("LIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text(video.formattedDuration)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    )
                    .padding(8)
                }
                
                // Professional video info
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .frame(height: 36, alignment: .top)
                    
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
                .frame(width: 180, height: 64, alignment: .top)
            }
            .frame(width: 180)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPress: { 
                isPressed = true
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            },
            onRelease: { 
                isPressed = false 
            }
        )
        .accessibilityLabel(video.title)
        .accessibilityHint("Double tap to play video")
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
        .accessibilityLabel(title)
        .accessibilityHint(isSelected ? "Currently selected filter" : "Double tap to select filter")
    }
}

// MARK: - Clickable Live Streams Section
struct ClickableLiveStreamsSection: View {
    let onStreamTap: (User) -> Void
    
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
                
                NavigationLink("See all", destination: LiveStreamsView())
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Safe array access with guards
                    ForEach(0..<min(3, User.sampleUsers.count), id: \.self) { index in
                        if !User.sampleUsers.isEmpty {
                            ClickableLiveStreamCard(
                                creator: User.sampleUsers[index],
                                viewerCount: Int.random(in: 100...5000)
                            ) {
                                onStreamTap(User.sampleUsers[index])
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
    }
}

// MARK: - Clickable Live Stream Card
struct ClickableLiveStreamCard: View {
    let creator: User
    let viewerCount: Int
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    // Professional stream preview
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary.opacity(0.3), AppTheme.Colors.secondary.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 90)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                                
                                Text("GO LIVE")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Professional live badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                        
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.primary)
                            .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 2, x: 0, y: 1)
                    )
                    .padding(6)
                }
                
                // Professional creator info
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
                        HStack(spacing: 4) {
                            Text(creator.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            if creator.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 8))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text("\(viewerCount.formatted()) watching")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                .frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .accessibilityLabel("\(creator.displayName)'s live stream")
        .accessibilityHint("Double tap to join live stream")
    }
}

// MARK: - Clickable Video Feed Section
struct ClickableVideoFeedSection: View {
    let videos: [Video]
    let selectedFilter: ContentFilter
    @Binding var watchLaterVideos: Set<String>
    @Binding var likedVideos: Set<String>;
    @Binding var isLoading: Bool
    let onVideoTap: (Video) -> Void
    
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
                ProfessionalVideoCard(
                    video: video,
                    isLiked: likedVideos.contains(video.id),
                    isWatchLater: watchLaterVideos.contains(video.id),
                    onVideoTap: {
                        onVideoTap(video)
                    },
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.1)) {
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

// MARK: - Professional Video Card
struct ProfessionalVideoCard: View {
    let video: Video
    let isLiked: Bool
    let isWatchLater: Bool
    let onVideoTap: () -> Void
    let onLike: () -> Void
    let onWatchLater: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Professional clickable thumbnail
            Button(action: {
                print("🎬 Video tapped: \(video.title)")
                onVideoTap()
            }) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        case .failure(_):
                            Rectangle()
                                .fill(AppTheme.Colors.surface)
                                .aspectRatio(16/9, contentMode: .fill)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "play.rectangle.fill")
                                            .font(.system(size: 32))
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                        
                                        Text("Video Unavailable")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                    }
                                )
                        case .empty:
                            SkeletonView()
                                .aspectRatio(16/9, contentMode: .fill)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .cornerRadius(AppTheme.CornerRadius.lg)
                    .clipped()
                    
                    // Duration badge
                    Text(video.formattedDuration)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.8))
                        )
                        .padding(12)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
            .onTapGesture {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                onVideoTap()
            }
            
            // Professional video info section with proper spacing
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Creator avatar
                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                    .font(.system(size: 20))
                            )
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    // Title and creator info
                    VStack(alignment: .leading, spacing: 6) {
                        // Video title
                        Text(video.title)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(2)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Creator name and metadata
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(video.creator.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                
                                if video.creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                Text("\(video.formattedViews) views")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                
                                Text("•")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                
                                Text(video.timeAgo)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // More menu
                    Menu {
                        Button(action: onWatchLater) {
                            Label(
                                isWatchLater ? "Remove from Watch Later" : "Save to Watch Later",
                                systemImage: isWatchLater ? "bookmark.fill" : "bookmark"
                            )
                        }
                        
                        if let shareURL = URL(string: video.videoURL) {
                            ShareLink(item: shareURL) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        } else {
                            Button(action: {}) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        Button(action: {}) {
                            Label("Not Interested", systemImage: "hand.thumbsdown")
                        }
                        
                        Button(action: {}) {
                            Label("Report", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .padding(8)
                    }
                }
                
                // Action buttons with proper spacing
                HStack(spacing: 24) {
                    // Like button
                    Button(action: onLike) {
                        HStack(spacing: 6) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 16))
                                .foregroundColor(isLiked ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                .scaleEffect(isLiked ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                            
                            Text("\(video.likeCount)")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Comments button
                    Button(action: {
                        print("💬 Comments tapped for: \(video.title)")
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text("\(video.commentCount)")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Share button
                    if let shareURL = URL(string: video.videoURL) {
                        ShareLink(item: shareURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button(action: {}) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    
                    Spacer()
                    
                    // Watch later button
                    Button(action: onWatchLater) {
                        Image(systemName: isWatchLater ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 18))
                            .foregroundColor(isWatchLater ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                            .scaleEffect(isWatchLater ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isWatchLater)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Supporting Views and Extensions

struct ProfessionalActionButton: View {
    let icon: String
    let isActive: Bool
    let action: (() -> Void)?
    
    init(icon: String, isActive: Bool = false, action: (() -> Void)? = nil) {
        self.icon = icon
        self.isActive = isActive
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                .padding(8)
                .background(
                    Circle()
                        .fill(isActive ? AppTheme.Colors.primary.opacity(0.1) : Color.clear)
                        .shadow(
                            color: isActive ? AppTheme.Colors.primary.opacity(0.2) : .clear,
                            radius: isActive ? 4 : 0,
                            x: 0,
                            y: 2
                        )
                )
                .scaleEffect(isActive ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(icon)
        .accessibilityHint(isActive ? "Active" : "Inactive")
    }
}

struct NotificationButton: View {
    @State private var badgeCount: Int = 3
    
    var body: some View {
        ZStack {
            Image(systemName: "bell")
                .font(.title2)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 2, x: 0, y: 1)
                    )
                    .offset(x: 10, y: -10)
                    .scaleEffect(badgeCount > 0 ? 1.0 : 0.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: badgeCount)
            }
        }
        .accessibilityLabel("Notifications")
        .accessibilityValue(badgeCount > 0 ? "\(badgeCount) unread notifications" : "No unread notifications")
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
        .accessibilityLabel("Loading more content")
    }
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