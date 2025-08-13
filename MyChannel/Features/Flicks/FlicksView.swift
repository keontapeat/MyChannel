//
//  FlicksView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import UIKit
import Combine
import AVFoundation
import Network

// MARK: - Flicks Components (Wrappers for quick access in this file)
struct FlicksCommentsSheet: View {
    let video: Video
    var body: some View {
        ProfessionalCommentsSheet(video: video)
    }
}

struct FlicksShareSheet: View {
    let video: Video
    var body: some View {
        ProfessionalShareSheet(video: video)
    }
}

struct FlicksCreatorProfileView: View {
    let creator: User
    var body: some View {
        ProfessionalCreatorProfileView(creator: creator)
    }
}

struct FlicksSettingsPanel: View {
    var body: some View {
        ProfessionalFlicksSettingsPanel()
    }
}

// MARK: - Component Previews
#Preview("Flicks Comments Sheet") {
    FlicksCommentsSheet(video: Video.sampleVideos.first ?? Video.sampleVideos[0])
        .preferredColorScheme(.dark)
}

#Preview("Flicks Share Sheet") {
    FlicksShareSheet(video: Video.sampleVideos.first ?? Video.sampleVideos[0])
        .preferredColorScheme(.dark)
}

#Preview("Flicks Creator Profile") {
    FlicksCreatorProfileView(creator: User.sampleUsers.first ?? User.sampleUsers[0])
        .preferredColorScheme(.dark)
}

#Preview("Flicks Settings Panel") {
    FlicksSettingsPanel()
        .preferredColorScheme(.dark)
}

// MARK: - Main Flicks View

// MARK: - Senior Level FlicksView 🔥
struct FlicksView: View {
    // When true, Flicks is embedded inside main tabs (no custom exit UI)
    var isEmbeddedInTab: Bool = false
    // MARK: - Environment
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // MARK: - Core State Management
    @State private var currentIndex: Int = 0
    @State private var videos: [Video] = []
    @State private var likedVideos: Set<String> = []
    @State private var followedCreators: Set<String> = []
    @State private var selectedCreator: User?
    @State private var subscriberCounts: [String: Int] = [:]
    @State private var showingFlicksSettings = false
    @State private var commentsVideo: Video?
    @State private var shareVideo: Video?
    @State private var showNavigationHint = false
    @State private var lastActiveVideoId: String?
    
    // MARK: - Advanced Performance State
    @State private var preloadedIndices: Set<Int> = []
    @State private var videoViewTimes: [String: TimeInterval] = [:]
    @State private var sessionStartTime = Date()
    @State private var totalWatchTime: TimeInterval = 0
    @State private var videoEngagementScores: [String: Double] = [:]
    @State private var isNetworkAvailable = true
    @State private var batteryLevel: Float = 1.0
    @State private var thermalState: ProcessInfo.ThermalState = .nominal
    
    // MARK: - Gesture & Interaction State
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var lastTapTime: Date?

    @State private var swipeVelocity: CGFloat = 0
    
    // MARK: - AI & Recommendations
    @State private var recommendationEngine = FlicksRecommendationEngine()
    @State private var userPreferences: FlicksUserPreferences = FlicksUserPreferences()
    @State private var viewingHistory: [FlicksViewEvent] = []
    
    // MARK: - System Monitoring
    @StateObject private var networkMonitor = FlicksNetworkMonitor()
    @StateObject private var performanceMonitor = FlicksPerformanceMonitor()
    
    // MARK: - Haptic & Audio Feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Publishers & Timers
    @State private var cancellables = Set<AnyCancellable>()
    @State private var viewTimeTimer: Timer?
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    verticalVideoFeed(geometry: geometry)

                    if !isEmbeddedInTab {
                        topOverlay
                            .zIndex(2)
                    }

                    // Connectivity status banner
                    connectivityBanner
                        .zIndex(2)

                    if !isEmbeddedInTab {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Text("Swipe from left edge to exit")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(.black.opacity(0.3), in: Capsule())
                                        .opacity(showNavigationHint ? 1 : 0)
                                        .animation(.easeInOut(duration: 0.3), value: showNavigationHint)
                                }
                                Spacer()
                            }
                            .padding(.bottom, 32)
                        }
                        .zIndex(1)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .statusBarHidden()
            .task {
                if videos.isEmpty { loadFlicksContent() }

                if !isEmbeddedInTab {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.5)) { showNavigationHint = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(.easeInOut(duration: 0.5)) { showNavigationHint = false }
                        }
                    }
                }
            }
            // Keep internal timers and UX in sync with app lifecycle
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .inactive, .background:
                    if currentIndex < videos.count {
                        lastActiveVideoId = videos[currentIndex].id
                        stopViewTimeTracking(for: videos[currentIndex])
                    }
                case .active:
                    if let resumeId = lastActiveVideoId,
                       let video = videos.first(where: { $0.id == resumeId }),
                       viewTimeTimer == nil {
                        startViewTimeTracking(for: video)
                    }
                @unknown default:
                    break
                }
            }
            .gesture(
                // Left edge swipe to exit (disabled when embedded)
                DragGesture()
                    .onEnded { value in
                        guard !isEmbeddedInTab else { return }
                        // Check if swipe started from left edge (within 50 points)
                        if value.startLocation.x < 50 && value.translation.width > 100 {
                            // Quick exit to home with haptic feedback
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                            HapticManager.shared.impact(style: .medium)
                        }
                    }
            )
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FlicksResetToFirst"))) { _ in
                resetToFirstVideo()
            }
            // Reflect connectivity in local state
            .onReceive(networkMonitor.$isConnected) { isConnected in
                isNetworkAvailable = isConnected
            }
            .sheet(item: $commentsVideo) { video in
                FlicksCommentsSheet(video: video)
                    .presentationDetents([.height(200), .medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $shareVideo) { video in
                FlicksShareSheet(video: video)
                    .presentationDetents([.height(400)])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $selectedCreator) { creator in
                FlicksCreatorProfileView(creator: creator)
            }
            .sheet(isPresented: $showingFlicksSettings) {
                FlicksSettingsPanel()
                    .presentationDetents([.height(600), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }
    
    private var topOverlay: some View {
        VStack {
            HStack {
                // Quick Exit Menu
                Menu {
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        Label("Home", systemImage: "house.fill")
                    }
                    
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToSearchTab"), object: nil)
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToProfileTab"), object: nil)
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        Label("Profile", systemImage: "person.fill")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                        Text("Exit")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .accessibilityLabel("Exit Flicks")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Flicks")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: AppTheme.Colors.primary.opacity(0.5), radius: 8, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
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
                            .accessibilityLabel("Search")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showingFlicksSettings = true
                        HapticManager.shared.impact(style: .medium)
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            .accessibilityLabel("Flicks Settings")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            Spacer()
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.black.opacity(0.8), .black.opacity(0.4), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        }
    }
    
    // MARK: - 🔥 LEGENDARY Vertical Video Feed with Advanced Gestures
    private func verticalVideoFeed(geometry: GeometryProxy) -> some View {
        ZStack {
            TabView(selection: $currentIndex) {
                ForEach(0..<videos.count, id: \.self) { index in
                    ZStack {
                        ProfessionalVideoPlayer(
                            video: videos[index],
                            isCurrentVideo: index == currentIndex,
                            isLiked: likedVideos.contains(videos[index].id),
                            isFollowing: followedCreators.contains(videos[index].creator.id),
                            subscriberCount: subscriberCounts[videos[index].creator.id] ?? videos[index].creator.subscriberCount,
                            onLike: {
                                toggleLikeWithAnimation(for: videos[index])
                            },
                            onFollow: {
                                toggleFollowWithAnimation(for: videos[index].creator)
                            },
                            onComment: {
                                commentsVideo = videos[index]
                                trackEngagement(for: videos[index], type: .comment)
                            },
                            onShare: {
                                shareVideo = videos[index]
                                trackEngagement(for: videos[index], type: .share)
                            },
                            onProfileTap: {
                                selectedCreator = videos[index].creator
                                trackEngagement(for: videos[index], type: .profileView)
                            }
                        )
                        
                        // Advanced Gesture Overlay
                        FlicksGestureOverlay(
                            video: videos[index],
                            geometry: geometry,
                            onDoubleTap: { location in
                                handleDoubleTap(location: location, video: videos[index], geometry: geometry)
                            },
                            onSingleTap: {
                                handleSingleTap(video: videos[index])
                            },
                            onLongPress: {
                                handleLongPress(video: videos[index])
                            }
                        )
                        

                    }
                    .id(videos[index].id)
                    .tag(index)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear {
                        preloadVideoIfNeeded(at: index)
                        startViewTimeTracking(for: videos[index])
                    }
                    .onDisappear {
                        stopViewTimeTracking(for: videos[index])
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea()
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .interpolatingSpring(stiffness: 300, damping: 30), value: currentIndex)
            .onChange(of: currentIndex) { oldValue, newValue in
                handleVideoChange(from: oldValue, to: newValue)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onChanged { value in
                        handleDragGesture(value: value)
                    }
                    .onEnded { value in
                        handleDragEnd(value: value, geometry: geometry)
                    }
            )
        }
    }
    

    
    private func loadFlicksContent() {
        videos = Video.sampleVideos.shuffled()
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
    
    // MARK: - 🚀 SENIOR LEVEL Methods
    
    // MARK: - Advanced Gesture Handlers
    private func handleDoubleTap(location: CGPoint, video: Video, geometry: GeometryProxy) {
        // Auto-like on double tap (no animation)
        if !likedVideos.contains(video.id) {
            toggleLikeWithAnimation(for: video)
        }
        
        // Track engagement
        trackEngagement(for: video, type: .doubleTapLike)
        
        // Haptic feedback
        notificationFeedback.notificationOccurred(.success)
    }
    
    private func handleSingleTap(video: Video) {
        // Track tap engagement
        trackEngagement(for: video, type: .tap)
        selectionFeedback.selectionChanged()
    }
    
    private func handleLongPress(video: Video) {
        // Show video options or save to watch later
        trackEngagement(for: video, type: .longPress)
        impactFeedback.impactOccurred()
    }
    
    private func handleDragGesture(value: DragGesture.Value) {
        dragOffset = value.translation
        isDragging = true
        swipeVelocity = value.verticalMomentum
    }
    
    private func handleDragEnd(value: DragGesture.Value, geometry: GeometryProxy) {
        let threshold: CGFloat = 100
        let velocity = value.verticalMomentum
        
        if abs(velocity) > 500 || abs(value.translation.height) > threshold {
            if velocity > 0 && currentIndex > 0 {
                // Swipe down - previous video
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    currentIndex -= 1
                }
            } else if velocity < 0 && currentIndex < videos.count - 1 {
                // Swipe up - next video
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                    currentIndex += 1
                }
            }
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragOffset = .zero
            isDragging = false
        }
    }
    
    private func handleVideoChange(from oldIndex: Int, to newIndex: Int) {
        impactFeedback.impactOccurred()
        
        // Track video completion
        if oldIndex < videos.count {
            let video = videos[oldIndex]
            trackVideoCompletion(for: video)
        }
        
        // Preload next videos
        preloadNextVideos(currentIndex: newIndex)
        
        // Update AI recommendations
        if newIndex < videos.count {
            recommendationEngine.updateUserPreferences(for: videos[newIndex])
        }
        
        // Performance monitoring
        performanceMonitor.trackVideoSwitch()
    }
    
    // MARK: - Enhanced Like & Follow with Animations
    private func toggleLikeWithAnimation(for video: Video) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            if likedVideos.contains(video.id) {
                likedVideos.remove(video.id)
                notificationFeedback.notificationOccurred(.warning)
            } else {
                likedVideos.insert(video.id)
                notificationFeedback.notificationOccurred(.success)
                
                // Minimal like effect handled in ProfessionalVideoPlayer
            }
        }
        
        trackEngagement(for: video, type: .like)
        updateEngagementScore(for: video, action: .like)
    }
    
    private func toggleFollowWithAnimation(for creator: User) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if followedCreators.contains(creator.id) {
                followedCreators.remove(creator.id)
                subscriberCounts[creator.id] = max(0, (subscriberCounts[creator.id] ?? creator.subscriberCount) - 1)
                notificationFeedback.notificationOccurred(.warning)
            } else {
                followedCreators.insert(creator.id)
                subscriberCounts[creator.id] = (subscriberCounts[creator.id] ?? creator.subscriberCount) + 1
                notificationFeedback.notificationOccurred(.success)
            }
        }
    }
    
    private func showLikeParticles() {
        // Create particle animation effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impactFeedback.impactOccurred()
        }
    }
    
    // MARK: - Advanced Performance & Analytics
    private func preloadVideoIfNeeded(at index: Int) {
        guard !preloadedIndices.contains(index) else { return }
        guard networkMonitor.isConnected else { return }
        
        preloadedIndices.insert(index)
        
        // Preload adjacent videos for smooth playback
        let aheadCount = max(1, performanceMonitor.getRecommendedPreloadCount())
        let preloadRange = max(0, index - 1)...min(videos.count - 1, index + aheadCount)
        
        Task {
            for i in preloadRange {
                await preloadVideo(at: i)
            }
        }
    }
    
    private func preloadVideo(at index: Int) async {
        guard index < videos.count else { return }
        // Prewarm AVPlayerItem in cache for instant start
        await MainActor.run {
            VideoPlayerManager.prewarm(urlString: videos[index].videoURL)
        }
    }
    
    private func startViewTimeTracking(for video: Video) {
        let startTime = Date()
        videoViewTimes[video.id] = startTime.timeIntervalSince1970
        
        // Start timer for this video
        viewTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            totalWatchTime += 1.0
            updateEngagementScore(for: video, action: .view)
        }
    }
    
    private func stopViewTimeTracking(for video: Video) {
        viewTimeTimer?.invalidate()
        viewTimeTimer = nil
        
        if let startTime = videoViewTimes[video.id] {
            let watchDuration = Date().timeIntervalSince1970 - startTime
            trackVideoWatchTime(for: video, duration: watchDuration)
            // Remember resume time for session
            VideoPlayerManager.rememberResume(videoId: video.id, time: watchDuration)
        }
    }
    
    private func trackVideoCompletion(for video: Video) {
        let viewEvent = FlicksViewEvent(
            videoId: video.id,
            action: .completion,
            timestamp: Date(),
            duration: videoViewTimes[video.id] ?? 0
        )
        viewingHistory.append(viewEvent)
    }
    
    private func trackVideoWatchTime(for video: Video, duration: TimeInterval) {
        let viewEvent = FlicksViewEvent(
            videoId: video.id,
            action: .watchTime,
            timestamp: Date(),
            duration: duration
        )
        viewingHistory.append(viewEvent)
    }
    
    private func trackEngagement(for video: Video, type: FlicksEngagementType) {
        let viewEvent = FlicksViewEvent(
            videoId: video.id,
            action: type.toViewAction(),
            timestamp: Date(),
            duration: 0
        )
        viewingHistory.append(viewEvent)
        
        // Send to AI backend for analysis
        Task {
            await sendEngagementToAI(event: viewEvent)
        }
    }
    
    private func updateEngagementScore(for video: Video, action: FlicksEngagementType) {
        let currentScore = videoEngagementScores[video.id] ?? 0.0
        let actionWeight = action.weight
        videoEngagementScores[video.id] = currentScore + actionWeight
    }
    
    private func sendEngagementToAI(event: FlicksViewEvent) async {
        // Connect to your AI backend
        guard let url = URL(string: "\(AppConfig.API.cloudRunBaseURL)/ai/engagement") else { return }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let eventData = try JSONEncoder().encode(event)
            request.httpBody = eventData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ Engagement sent to AI successfully")
            }
        } catch {
            print("❌ Failed to send engagement to AI: \(error)")
        }
    }
    
    // MARK: - Smart Preloading with Performance Monitoring
    private func preloadNextVideos(currentIndex: Int) {
        // Smart preloading based on performance
        let shouldPreload = performanceMonitor.shouldPreloadVideos() && networkMonitor.isConnected
        guard shouldPreload else { return }
        
        if currentIndex >= videos.count - 3 {
            Task {
                // Get AI-powered recommendations
                let recommendations = await recommendationEngine.getRecommendations(
                    based: viewingHistory,
                    preferences: userPreferences
                )
                
                let more = recommendations.isEmpty ? 
                    Array(Video.sampleVideos.shuffled().prefix(6)) : 
                    recommendations
                
                await MainActor.run {
                    videos.append(contentsOf: more)
                }
            }
        }
    }
}

// MARK: - UI Helpers
private extension FlicksView {
    var connectivityBanner: some View {
        Group {
            if !networkMonitor.isConnected {
                bannerView(icon: "wifi.slash", text: "You're offline. Some features may be unavailable.")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 56)
            } else if networkMonitor.connectionQuality == .poor {
                bannerView(icon: "wifi.exclamationmark", text: "Poor connection. Optimizing for smooth playback…")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 56)
            }
        }
        .animation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.9), value: networkMonitor.isConnected)
        .animation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.9), value: networkMonitor.connectionQuality)
    }

    func bannerView(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.55), in: Capsule())
        .overlay(
            Capsule().stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

// MARK: - Previews

#Preview("FlicksView") {
    FlicksView()
        .preferredColorScheme(.dark)
}