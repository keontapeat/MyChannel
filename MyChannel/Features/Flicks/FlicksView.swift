//
//  FlicksView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct FlicksView: View {
    @State private var currentIndex: Int = 0
    @State private var videos: [Video] = []
    @State private var isLoading = true
    @State private var showingComments = false
    @State private var showingShare = false
    @State private var likedVideos: Set<String> = []
    @State private var followedCreators: Set<String> = []
    @State private var showingProfile = false
    @State private var selectedCreator: User?
    @State private var subscriberCounts: [String: Int] = [:]
    @State private var showingFlicksSettings = false
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if isLoading {
                        loadingView
                    } else {
                        verticalVideoFeed(geometry: geometry)
                    }
                    
                    // Professional top overlay with glassmorphism
                    topOverlay
                        .zIndex(2)
                }
            }
            .navigationBarHidden(true)
            .statusBarHidden()
            .onAppear {
                loadFlicksContent()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FlicksResetToFirst"))) { _ in
                resetToFirstVideo()
            }
            .sheet(isPresented: $showingComments) {
                if !videos.isEmpty && currentIndex < videos.count {
                    ProfessionalCommentsSheet(video: videos[currentIndex])
                        .presentationDetents([.height(200), .medium, .large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showingShare) {
                if !videos.isEmpty && currentIndex < videos.count {
                    ProfessionalShareSheet(video: videos[currentIndex])
                        .presentationDetents([.height(400)])
                        .presentationDragIndicator(.visible)
                }
            }
            .fullScreenCover(isPresented: $showingProfile) {
                if let creator = selectedCreator {
                    ProfessionalCreatorProfileView(creator: creator)
                }
            }
            .sheet(isPresented: $showingFlicksSettings) {
                ProfessionalFlicksSettingsPanel()
                    .presentationDetents([.height(600), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }
    
    // MARK: - Premium Loading View
    private var loadingView: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.8),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Animated pulsing logo
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                            value: UUID()
                        )
                    
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(0.3),
                            value: UUID()
                        )
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                
                VStack(spacing: 12) {
                    Text("Flicks")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text("Loading amazing content...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                // Modern loading dots
                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(.white.opacity(0.9))
                            .frame(width: 8, height: 8)
                            .scaleEffect(1.0)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: UUID()
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Professional Top Overlay
    private var topOverlay: some View {
        VStack {
            HStack {
                // Home button (left side)
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                    HapticManager.shared.impact(style: .medium)
                }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Premium title with glow effect
                Text("Flicks")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: AppTheme.Colors.primary.opacity(0.5), radius: 8, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Spacer()
                
                // Action buttons with modern styling (right side)
                HStack(spacing: 12) {
                    // Search button
                    Button(action: {
                        print("🔍 Search button tapped!")
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToSearchTab"), object: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchBar"), object: nil)
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Settings button (the white circle with settings icon)
                    Button(action: {
                        print("⚙️ Settings button tapped!")
                        showingFlicksSettings = true
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.8), .black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - Vertical Video Feed with Enhanced Progress Bar
    private func verticalVideoFeed(geometry: GeometryProxy) -> some View {
        TabView(selection: $currentIndex) {
            ForEach(0..<videos.count, id: \.self) { index in
                ProfessionalVideoPlayer(
                    video: videos[index],
                    isCurrentVideo: index == currentIndex,
                    isLiked: likedVideos.contains(videos[index].id),
                    isFollowing: followedCreators.contains(videos[index].creator.id),
                    subscriberCount: subscriberCounts[videos[index].creator.id] ?? videos[index].creator.subscriberCount,
                    videoProgress: index == currentIndex ? 1.0 : 0.0, // You can make this dynamic
                    onLike: {
                        toggleLike(for: videos[index])
                    },
                    onFollow: {
                        toggleFollow(for: videos[index].creator)
                    },
                    onComment: {
                        showingComments = true
                    },
                    onShare: {
                        showingShare = true
                    },
                    onProfileTap: {
                        selectedCreator = videos[index].creator
                        showingProfile = true
                    }
                )
                .tag(index)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea()
        .animation(AppTheme.AnimationPresets.spring, value: currentIndex)
        .onChange(of: currentIndex) { _, newValue in
            impactFeedback.impactOccurred()
            preloadNextVideos(currentIndex: newValue)
        }
    }
    
    // MARK: - Helper Methods
    private func loadFlicksContent() {
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                videos = Video.sampleVideos.shuffled()
                isLoading = false
            }
        }
    }
    
    private func resetToFirstVideo() {
        guard !videos.isEmpty && currentIndex != 0 else { return }
        
        withAnimation(AppTheme.AnimationPresets.spring) {
            currentIndex = 0
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleLike(for video: Video) {
        withAnimation(AppTheme.AnimationPresets.bouncy) {
            if likedVideos.contains(video.id) {
                likedVideos.remove(video.id)
            } else {
                likedVideos.insert(video.id)
            }
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    private func toggleFollow(for creator: User) {
        withAnimation(AppTheme.AnimationPresets.spring) {
            if followedCreators.contains(creator.id) {
                followedCreators.remove(creator.id)
                subscriberCounts[creator.id] = max(0, (subscriberCounts[creator.id] ?? creator.subscriberCount) - 1)
            } else {
                followedCreators.insert(creator.id)
                subscriberCounts[creator.id] = (subscriberCounts[creator.id] ?? creator.subscriberCount) + 1
            }
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    private func preloadNextVideos(currentIndex: Int) {
        if currentIndex >= videos.count - 3 {
            Task {
                let moreVideos = Video.sampleVideos.shuffled().prefix(5)
                await MainActor.run {
                    videos.append(contentsOf: moreVideos)
                }
            }
        }
    }
}

// MARK: - Professional Video Player with Enhanced Progress Bar
struct ProfessionalVideoPlayer: View {
    let video: Video
    let isCurrentVideo: Bool
    let isLiked: Bool
    let isFollowing: Bool
    let subscriberCount: Int
    let videoProgress: Double
    let onLike: () -> Void
    let onFollow: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onProfileTap: () -> Void
    
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var showControls = false
    @State private var controlsTimer: Timer?
    @State private var isPlaying = true
    @State private var showPlayIcon = false
    @State private var currentProgress: Double = 0.0
    
    var body: some View {
        ZStack {
            // Video Player Background
            if isCurrentVideo {
                VideoPlayer(player: playerManager.player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .onTapGesture {
                        togglePlayPause()
                        showPlayPauseIcon()
                    }
                    .onAppear {
                        setupPlayer()
                        startProgressUpdates()
                    }
                    .onDisappear {
                        playerManager.pause()
                        stopProgressUpdates()
                    }
            } else {
                // Premium thumbnail with loading state
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Rectangle()
                            .fill(.black)
                        
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            
                            Text("Loading...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            
            // Professional Play/Pause Icon
            if showPlayIcon {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .background(.ultraThinMaterial, in: Circle())
                    
                    Image(systemName: isPlaying ? "play.fill" : "pause.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .scaleEffect(showPlayIcon ? 1.0 : 0.8)
                .opacity(showPlayIcon ? 1.0 : 0.0)
                .animation(AppTheme.AnimationPresets.bouncy, value: showPlayIcon)
            }
            
            // Content overlays with professional gradients
            GeometryReader { geometry in
                ZStack {
                    // Enhanced bottom gradient for better text readability
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [
                                .clear,
                                .black.opacity(0.3),
                                .black.opacity(0.7),
                                .black.opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 350)
                        .allowsHitTesting(false)
                    }
                    
                    // Main content layout
                    HStack(alignment: .bottom) {
                        // Left side - Enhanced video info
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer()
                            
                            // Premium creator info section
                            HStack(spacing: 16) {
                                Button(action: onProfileTap) {
                                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(AppTheme.Colors.primary)
                                            .overlay(
                                                Text(String(video.creator.displayName.prefix(1)))
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(.white)
                                            )
                                    }
                                    .frame(width: 52, height: 52)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.4), lineWidth: 2.5)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text("@\(video.creator.username)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                        
                                        if video.creator.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(AppTheme.Colors.primary)
                                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                        }
                                    }
                                    
                                    Text("\(subscriberCount.formatted()) subscribers")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                }
                                
                                Spacer()
                                
                                // Premium subscribe button
                                if !isFollowing {
                                    Button(action: onFollow) {
                                        Text("Subscribe")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(.white, in: Capsule())
                                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 16)
                            
                            // Enhanced video description
                            VStack(alignment: .leading, spacing: 10) {
                                Text(video.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                
                                if !video.description.isEmpty {
                                    Text(video.description)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                }
                            }
                            .frame(maxWidth: geometry.size.width * 0.65, alignment: .leading)
                            .padding(.bottom, 120)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        // Right side - Premium action buttons
                        VStack(spacing: 28) {
                            Spacer()
                            
                            // Enhanced like button with animation
                            ProfessionalActionButton(
                                icon: isLiked ? "heart.fill" : "heart",
                                text: formatCount(video.likeCount),
                                isActive: isLiked,
                                activeColor: .red,
                                action: onLike
                            )
                            
                            // Comment button with modern styling
                            ProfessionalActionButton(
                                icon: "bubble.right.fill",
                                text: formatCount(video.commentCount),
                                action: onComment
                            )
                            
                            // Share button with enhanced design
                            ProfessionalActionButton(
                                icon: "arrowshape.turn.up.right.fill",
                                text: "Share",
                                action: onShare
                            )
                            
                            // More options with modern touch
                            ProfessionalActionButton(
                                icon: "ellipsis",
                                text: "",
                                action: { }
                            )
                            
                            // Enhanced creator mini profile
                            Button(action: onProfileTap) {
                                AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(AppTheme.Colors.primary.opacity(0.8))
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 2.5)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 120)
                    }
                }
            }
            
            // ENHANCED VIDEO PROGRESS BAR - Much More Visible!
            VStack {
                Spacer()
                
                HStack(spacing: 0) {
                    // Progress indicator with premium styling
                    ZStack(alignment: .leading) {
                        // Background track - Much more visible
                        Rectangle()
                            .fill(.white.opacity(0.4))
                            .frame(height: 4)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 2))
                        
                        // Progress fill - Bright and prominent
                        Rectangle()
                            .fill(.white)
                            .frame(width: max(4, CGFloat(currentProgress) * UIScreen.main.bounds.width), height: 4)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary, .white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 2)
                            )
                            .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
                            .animation(AppTheme.AnimationPresets.easeInOut, value: currentProgress)
                    }
                    .cornerRadius(2)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 50) // Positioned above home indicator
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func setupPlayer() {
        playerManager.setupPlayer(with: video)
        playerManager.play()
        isPlaying = true
    }
    
    private func togglePlayPause() {
        playerManager.togglePlayPause()
        isPlaying.toggle()
        HapticManager.shared.impact(style: .light)
    }
    
    private func showPlayPauseIcon() {
        withAnimation(AppTheme.AnimationPresets.bouncy) {
            showPlayIcon = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(AppTheme.AnimationPresets.spring) {
                showPlayIcon = false
            }
        }
    }
    
    private func startProgressUpdates() {
        // Simulate progress updates - Replace with real video progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if isCurrentVideo && isPlaying {
                withAnimation(.linear(duration: 0.1)) {
                    currentProgress = min(1.0, currentProgress + 0.002) // Adjust speed as needed
                }
                
                if currentProgress >= 1.0 {
                    timer.invalidate()
                }
            }
        }
    }
    
    private func stopProgressUpdates() {
        // Stop progress updates when video is not current
        currentProgress = 0.0
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Professional Action Button
struct ProfessionalActionButton: View {
    let icon: String
    let text: String
    var isActive: Bool = false
    var activeColor: Color = AppTheme.Colors.primary
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var showPulse = false
    
    var body: some View {
        Button(action: {
            action()
            triggerPulseEffect()
            HapticManager.shared.impact(style: .light)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // Pulse effect for active states
                    if showPulse {
                        Circle()
                            .fill(isActive ? activeColor.opacity(0.3) : .white.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .scaleEffect(showPulse ? 1.3 : 1.0)
                            .opacity(showPulse ? 0.0 : 1.0)
                            .animation(AppTheme.AnimationPresets.easeInOut, value: showPulse)
                    }
                    
                    // Main button background
                    Circle()
                        .fill(isActive ? activeColor.opacity(0.2) : .black.opacity(0.3))
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(isActive ? activeColor : .white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                if !text.isEmpty {
                    Text(text)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(AppTheme.AnimationPresets.bouncy, value: isPressed)
        .animation(AppTheme.AnimationPresets.spring, value: isActive)
        .onLongPressGesture(minimumDuration: 0.01) {
            // Handle long press if needed
        } onPressingChanged: { pressing in
            withAnimation(AppTheme.AnimationPresets.quick) {
                isPressed = pressing
            }
        }
    }
    
    private func triggerPulseEffect() {
        withAnimation(AppTheme.AnimationPresets.easeInOut) {
            showPulse = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showPulse = false
        }
    }
}

// MARK: - Professional Comments Sheet
struct ProfessionalCommentsSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var newComment = ""
    @State private var comments: [VideoComment] = []
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Premium handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.2))
                    .frame(width: 50, height: 5)
                    .padding(.top, 12)
                
                // Enhanced header
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Comments")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        Text("\(video.commentCount.formatted()) comments")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                // Comments list with enhanced styling
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(comments) { comment in
                            ProfessionalCommentRow(comment: comment)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(.ultraThinMaterial.opacity(0.3))
                        }
                    }
                }
                
                // Premium comment input
                VStack(spacing: 0) {
                    Divider()
                        .background(.gray.opacity(0.2))
                    
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("Y")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        HStack(spacing: 16) {
                            TextField("Add a thoughtful comment...", text: $newComment, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15, weight: .medium))
                                .focused($isTextFieldFocused)
                                .lineLimit(1...4)
                            
                            if !newComment.isEmpty {
                                Button("Post") {
                                    postComment()
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.primary, in: Capsule())
                                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .background(.ultraThinMaterial)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadComments()
        }
    }
    
    private func loadComments() {
        comments = VideoComment.sampleComments
    }
    
    private func postComment() {
        guard !newComment.isEmpty else { return }
        
        let comment = VideoComment(
            author: User.sampleUsers[0],
            text: newComment,
            likeCount: 0,
            replyCount: 0,
            createdAt: Date()
        )
        
        withAnimation(AppTheme.AnimationPresets.spring) {
            comments.insert(comment, at: 0)
        }
        
        newComment = ""
        isTextFieldFocused = false
        HapticManager.shared.impact(style: .medium)
    }
}

// MARK: - Professional Comment Row
struct ProfessionalCommentRow: View {
    let comment: VideoComment
    @State private var isLiked = false
    @State private var showReplies = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                AsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.8))
                        .overlay(
                            Text(String(comment.author.displayName.prefix(1)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text("@\(comment.author.username)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        Text(comment.timeAgo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                        
                        Spacer()
                        
                        Button(action: { }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(comment.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 24) {
                        Button(action: { toggleLike() }) {
                            HStack(spacing: 8) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundStyle(isLiked ? .red : AppTheme.Colors.textTertiary)
                                
                                if comment.likeCount > 0 {
                                    Text("\(comment.likeCount)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { }) {
                            Text("Reply")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.primary)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.top, 6)
                }
            }
            
            // Replies section with premium styling
            if comment.replyCount > 0 {
                Button(action: { showReplies.toggle() }) {
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(AppTheme.Colors.primary.opacity(0.6))
                            .frame(width: 32, height: 2)
                            .cornerRadius(1)
                        
                        Text("View \(comment.replyCount) replies")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                        
                        Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)

                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 56)
                .padding(.top, 12)
            }
        }
    }
    
    private func toggleLike() {
        withAnimation(AppTheme.AnimationPresets.bouncy) {
            isLiked.toggle()
        }
        HapticManager.shared.impact(style: .light)
    }
}

// MARK: - Professional Share Sheet
struct ProfessionalShareSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Premium handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 50, height: 5)
                    .padding(.top, 12)
                
                // Enhanced header
                HStack {
                    Text("Share")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                // Premium share options
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 24) {
                        PremiumShareOption(icon: "message.fill", title: "Messages", color: .green)
                        PremiumShareOption(icon: "envelope.fill", title: "Mail", color: .blue)
                        PremiumShareOption(icon: "square.and.arrow.up", title: "More", color: .gray)
                        PremiumShareOption(icon: "link", title: "Copy Link", color: AppTheme.Colors.primary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
    }
}

struct PremiumShareOption: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(color, in: Circle())
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Professional Creator Profile View
struct ProfessionalCreatorProfileView: View {
    let creator: User
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Premium header
                    VStack(spacing: 20) {
                        AsyncImage(url: URL(string: creator.profileImageURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .overlay(
                                    Text(String(creator.displayName.prefix(1)))
                                        .font(.system(size: 52, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                        }
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 4)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                        
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                Text(creator.displayName)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                
                                if creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(AppTheme.Colors.primary)
                                }
                            }
                            
                            Text("@\(creator.username)")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            
                            Text("\(creator.subscriberCount.formatted()) subscribers")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    // Enhanced bio
                    if let bio = creator.bio {
                        Text(bio)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Premium action buttons
                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Text("Subscribe")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.Colors.primary, in: Capsule())
                                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {}) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .frame(width: 52, height: 52)
                                .background(.ultraThinMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 24)
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.top, 60)
                .padding(.trailing, 24)
            }
        }
    }
}

// MARK: - Professional Flicks Settings Panel
struct ProfessionalFlicksSettingsPanel: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("flicks_video_quality") private var videoQuality: String = "Auto"
    @AppStorage("flicks_playback_speed") private var playbackSpeed: Double = 1.0
    @AppStorage("flicks_content_category") private var contentCategory: String = "For You"
    @AppStorage("flicks_feed_type") private var feedType: String = "For You"
    @AppStorage("flicks_auto_play") private var autoPlayNext: Bool = true
    @AppStorage("flicks_data_saver") private var dataSaverMode: Bool = false
    @AppStorage("flicks_captions") private var showCaptions: Bool = false
    
    private let videoQualities = ["Auto", "720p", "1080p", "4K"]
    private let playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private let contentCategories = ["For You", "Gaming", "Music", "Comedy", "Tech", "Sports", "Education", "Art", "Food", "Travel"]
    private let feedTypes = ["For You", "Following", "Trending"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Premium header
                    VStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.3))
                            .frame(width: 50, height: 5)
                            .padding(.top, 12)
                        
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primary)
                            
                            Text("Flicks Settings")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            
                            Spacer()
                            
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Settings sections
                    VStack(spacing: 24) {
                        // Feed Preferences
                        SettingsSection(
                            title: "Feed Preferences",
                            icon: "rectangle.stack.fill",
                            iconColor: AppTheme.Colors.primary
                        ) {
                            VStack(spacing: 16) {
                                SettingsPicker(
                                    title: "Feed Type",
                                    selection: $feedType,
                                    options: feedTypes,
                                    icon: "list.bullet"
                                )
                                
                                SettingsPicker(
                                    title: "Content Category",
                                    selection: $contentCategory,
                                    options: contentCategories,
                                    icon: "tag.fill"
                                )
                            }
                        }
                        
                        // Video Quality
                        SettingsSection(
                            title: "Video & Playback",
                            icon: "play.rectangle.fill",
                            iconColor: .blue
                        ) {
                            VStack(spacing: 16) {
                                SettingsPicker(
                                    title: "Video Quality",
                                    selection: $videoQuality,
                                    options: videoQualities,
                                    icon: "4k.tv"
                                )
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "speedometer")
                                            .foregroundStyle(.orange)
                                            .frame(width: 20)
                                        
                                        Text("Playback Speed")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(AppTheme.Colors.textPrimary)
                                        
                                        Spacer()
                                        
                                        Text("\(playbackSpeed, specifier: "%.2f")x")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                    }
                                    
                                    HStack(spacing: 8) {
                                        ForEach(playbackSpeeds, id: \.self) { speed in
                                            Button("\(speed, specifier: speed == 1.0 ? "%.0f" : "%.2f")x") {
                                                playbackSpeed = speed
                                                HapticManager.shared.impact(style: .light)
                                            }
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(playbackSpeed == speed ? .white : AppTheme.Colors.textSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                playbackSpeed == speed ? AppTheme.Colors.primary : AppTheme.Colors.surface,
                                                in: Capsule()
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Preferences
                        SettingsSection(
                            title: "Preferences",
                            icon: "gearshape.fill",
                            iconColor: .purple
                        ) {
                            VStack(spacing: 16) {
                                SettingsToggle(
                                    title: "Auto-play Next Video",
                                    subtitle: "Automatically play the next video",
                                    isOn: $autoPlayNext,
                                    icon: "play.fill"
                                )
                                
                                SettingsToggle(
                                    title: "Data Saver Mode",
                                    subtitle: "Use less data by reducing video quality",
                                    isOn: $dataSaverMode,
                                    icon: "wifi.slash"
                                )
                                
                                SettingsToggle(
                                    title: "Show Captions",
                                    subtitle: "Display closed captions when available",
                                    isOn: $showCaptions,
                                    icon: "captions.bubble"
                                )
                            }
                        }
                        
                        // Quick Actions
                        SettingsSection(
                            title: "Quick Actions",
                            icon: "bolt.fill",
                            iconColor: .yellow
                        ) {
                            VStack(spacing: 12) {
                                FlicksQuickActionButton(
                                    title: "Clear Watch History",
                                    subtitle: "Reset your viewing recommendations",
                                    icon: "trash.fill",
                                    color: .red
                                ) {
                                    // Handle clear history
                                    HapticManager.shared.impact(style: .medium)
                                }
                                
                                FlicksQuickActionButton(
                                    title: "Refresh Feed",
                                    subtitle: "Get fresh content recommendations",
                                    icon: "arrow.clockwise",
                                    color: .green
                                ) {
                                    // Handle refresh feed
                                    HapticManager.shared.impact(style: .medium)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Settings Components
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SettingsPicker: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(selection)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(option) {
                            selection = option
                            HapticManager.shared.impact(style: .light)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == option ? .white : AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selection == option ? AppTheme.Colors.primary : AppTheme.Colors.surface,
                            in: Capsule()
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(isOn ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                .onChange(of: isOn) { _, _ in
                    HapticManager.shared.impact(style: .light)
                }
        }
    }
}

struct FlicksQuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(16)
            .background(AppTheme.Colors.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FlicksView()
        .preferredColorScheme(.dark)
}