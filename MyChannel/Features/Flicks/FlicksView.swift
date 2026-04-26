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
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct FlicksCommentsSheet: View {
    let video: Video
    var body: some View { ProfessionalCommentsSheet(video: video) }
}

struct FlicksShareSheet: View {
    let video: Video
    var body: some View { ProfessionalShareSheet(video: video) }
}

struct FlicksCreatorProfileView: View {
    let creator: User
    var body: some View { ProfessionalCreatorProfileView(creator: creator) }
}

struct FlicksSettingsPanel: View {
    var body: some View { ProfessionalFlicksSettingsPanel() }
}

// MARK: - Senior Level FlicksView (Clean Fullscreen, YouTube Shorts powered)
struct FlicksView: View {
    var isEmbeddedInTab: Bool = true

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentIndex: Int = 0
    @State private var previousIndex: Int = 0
    @State private var videos: [Video] = []
    @State private var likedVideos: Set<String> = []
    @State private var followedCreators: Set<String> = []
    @State private var subscriberCounts: [String: Int] = [:]
    @State private var commentsVideo: Video?
    @State private var shareVideo: Video?
    @State private var selectedCreator: User?

    // Performance & lifecycle
    @State private var preloadedIndices: Set<Int> = []
    @State private var videoViewTimes: [String: TimeInterval] = [:]
    @State private var viewTimeTimer: Timer?
    @State private var didEngageWithFeed = false

    @AppStorage("flicks_feed_muted") private var flicksMuted: Bool = true

    // Network/Perf monitors
    @StateObject private var networkMonitor = FlicksNetworkMonitor()
    @StateObject private var performanceMonitor = FlicksPerformanceMonitor()

    // Haptics
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    // Loading state
    @State private var isLoading = true
    @State private var loadError: String?

    @State private var showLikeBurst = false
    @State private var likeBurstID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading Flicks…")
                        .tint(.white)
                        .foregroundColor(.white)
                } else if let loadError {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView("Flicks Unavailable", systemImage: "wifi.slash", description: Text(loadError))
                            .foregroundColor(.white)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 64))
                                .foregroundColor(.white.opacity(0.8))
                            Text("Flicks Unavailable")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(loadError)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                } else {
                    feed
                        .transition(.opacity)
                }
            }
            .statusBarHidden()
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await loadFlicksContent() }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .inactive, .background:
                if currentIndex < videos.count {
                    stopViewTimeTracking(for: videos[currentIndex])
                }
            case .active:
                if currentIndex < videos.count, viewTimeTimer == nil {
                    startViewTimeTracking(for: videos[currentIndex])
                }
            @unknown default: break
            }
        }
        .onAppear {
            didEngageWithFeed = false
        }
        .onDisappear {
            GlobalVideoPlayerManager.shared.resumeAfterLeavingFlicks()
        }
    }

    // MARK: - Fullscreen feed (NUCLEAR YOUTUBE SHORTS KILLER 🔥)
    private var feed: some View {
        GeometryReader { geo in
            ZStack {
                // 🔥 MAIN FEED: Vertical scroll with snap
                TabView(selection: $currentIndex) {
                    ForEach(videos.indices, id: \.self) { index in
                        ZStack {
                            if videos[index].contentSource == .youtube, let ytId = videos[index].externalID {
                                YouTubePlayerView(videoID: ytId, autoplay: true, startTime: 0, muted: flicksMuted, showControls: false)
                                    .background(Color.black)
                                    .ignoresSafeArea()
                            } else {
                                ProfessionalVideoPlayer(
                                    video: videos[index],
                                    isCurrentVideo: index == currentIndex,
                                    isLiked: likedVideos.contains(videos[index].id),
                                    isFollowing: followedCreators.contains(videos[index].creator.id),
                                    subscriberCount: subscriberCounts[videos[index].creator.id] ?? videos[index].creator.subscriberCount,
                                    onLike: {
                                        toggleLikeWithAnimation(for: videos[index])
                                        triggerLikeBurst()
                                    },
                                    onFollow: { toggleFollowWithAnimation(for: videos[index].creator) },
                                    onComment: { commentsVideo = videos[index] },
                                    onShare: { shareVideo = videos[index] },
                                    onProfileTap: { selectedCreator = videos[index].creator },
                                    overlayStyle: .minimal
                                )
                            }
                        }
                        .tag(index)
                        .onAppear {
                            preloadVideoIfNeeded(at: index)
                            startViewTimeTracking(for: videos[index])
                        }
                        .onDisappear {
                            stopViewTimeTracking(for: videos[index])
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.4, dampingFraction: 0.9), value: currentIndex)
                .onChange(of: currentIndex) { new in
                    engageIfNeeded()
                    impactFeedback.impactOccurred()
                    if previousIndex < videos.count { trackVideoCompletion(for: videos[previousIndex]) }
                    preloadNextVideos(currentIndex: new)
                    previousIndex = new
                }

                // 🔥 PREMIUM: Enhanced glassmorphic mute button with glow
                VStack {
                    HStack(spacing: 12) {
                        Spacer()
                        Button {
                            flicksMuted.toggle()
                            HapticManager.shared.impact(style: .rigid)
                        } label: {
                            ZStack {
                                // Glow effect when unmuted
                                if !flicksMuted {
                                    Circle()
                                        .fill(AppTheme.Colors.accent.opacity(0.3))
                                        .frame(width: 52, height: 52)
                                        .blur(radius: 8)
                                }
                                
                                // Glassmorphic background
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                flicksMuted 
                                                    ? Color.white.opacity(0.2)
                                                    : AppTheme.Colors.accent.opacity(0.5),
                                                lineWidth: 1.2
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: flicksMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .foregroundColor(flicksMuted ? .white.opacity(0.8) : .white)
                                    .font(.system(size: 17, weight: .semibold))
                                    .shadow(color: flicksMuted ? .clear : AppTheme.Colors.accent.opacity(0.5), radius: 4)
                            }
                            .frame(width: 46, height: 46)
                        }
                        .buttonStyle(FlicksPremiumScaleButtonStyle())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: flicksMuted)
                    }
                    .padding(.top, 48)
                    .padding(.trailing, 18)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .allowsHitTesting(true)

                // 🔥 PREMIUM: Enhanced scroll indicator with glow effects
                VStack(spacing: 6) {
                    ForEach(videos.indices, id: \.self) { index in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                currentIndex = index
                            }
                            HapticManager.shared.selection()
                        } label: {
                            ZStack {
                                // Glow effect for current
                                if index == currentIndex {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.4))
                                        .frame(width: 6, height: 28)
                                        .blur(radius: 4)
                                }
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        index == currentIndex 
                                            ? Color.white
                                            : Color.white.opacity(0.35)
                                    )
                                    .frame(
                                        width: index == currentIndex ? 4 : 3,
                                        height: index == currentIndex ? 22 : 10
                                    )
                                    .shadow(color: index == currentIndex ? .white.opacity(0.3) : .clear, radius: 4)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(index == currentIndex ? 1.0 : 0.9)
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: currentIndex)
                    }
                }
                .padding(.trailing, 10)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                // 🔥 PREMIUM: Enhanced like burst with particle effects
                Group {
                    if showLikeBurst {
                        ZStack {
                            // Outer glow pulse
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.red.opacity(0.4), Color.clear],
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: 120
                                    )
                                )
                                .frame(width: 240, height: 240)
                                .scaleEffect(showLikeBurst ? 1.2 : 0.5)
                            
                            // Main heart with gradient
                            Image(systemName: "heart.fill")
                                .font(.system(size: 110, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hexString: "FF6B6B"), Color(hexString: "EE5A5A"), Color(hexString: "DC4444")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color.red.opacity(0.6), radius: 24, x: 0, y: 8)
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.3).combined(with: .opacity),
                            removal: .scale(scale: 1.3).combined(with: .opacity)
                        ))
                        .id(likeBurstID)
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.6), value: showLikeBurst)
                
                // 🔥 PREMIUM: Enhanced swipe indicators with pulse animation
                VStack {
                    if currentIndex > 0 {
                        VStack(spacing: 4) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .semibold))
                                .opacity(0.5)
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 56)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    Spacer()
                    
                    if currentIndex < videos.count - 1 {
                        VStack(spacing: 4) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .opacity(0.5)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
            }
            .highPriorityGesture(
                TapGesture(count: 2).onEnded {
                    if currentIndex < videos.count {
                        toggleLikeWithAnimation(for: videos[currentIndex])
                        triggerLikeBurst()
                    }
                }
            )
        }
        // 🔥 SHEETS: Comments, Share, Profile (slide up from bottom)
        .sheet(item: $commentsVideo) { video in
            FlicksCommentsSheet(video: video)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $shareVideo) { video in
            FlicksShareSheet(video: video)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedCreator) { creator in
            FlicksCreatorProfileView(creator: creator)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Data loading (YouTube API)

    private func makeYouTubeDemoVideos() -> [Video] {
        let demoUser = User(
            username: "open_flicks",
            displayName: "Open Flicks",
            email: "demo@mychannel.app",
            profileImageURL: "https://archive.org/services/img/BigBuckBunny_124",
            bannerImageURL: nil,
            bio: "Playable open videos",
            subscriberCount: 1_000_000,
            videoCount: 100,
            isVerified: true,
            isCreator: true
        )

        let directVideos: [(title: String, url: String, thumb: String, category: VideoCategory, duration: Double)] = [
            ("Big Buck Bunny", "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", "https://archive.org/services/img/BigBuckBunny_124", .movies, 596),
            ("Sintel", "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4", "https://archive.org/services/img/Sintel", .movies, 888),
            ("Tears of Steel", "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4", "https://archive.org/services/img/TearOfSteel", .movies, 734),
            ("Elephants Dream", "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4", "https://archive.org/services/img/ElephantsDream", .movies, 653),
            ("For Bigger Blazes", "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4", "https://picsum.photos/seed/flick-blazes/720/1280", .entertainment, 15),
            ("For Bigger Escapes", "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4", "https://picsum.photos/seed/flick-escapes/720/1280", .travel, 15),
            ("For Bigger Fun", "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4", "https://picsum.photos/seed/flick-fun/720/1280", .entertainment, 60),
            ("For Bigger Joyrides", "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4", "https://picsum.photos/seed/flick-joyrides/720/1280", .lifestyle, 15),
            ("Subaru Outback Adventure", "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4", "https://picsum.photos/seed/flick-subaru/720/1280", .travel, 594),
            ("Volkswagen GTI Review", "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4", "https://picsum.photos/seed/flick-gti/720/1280", .entertainment, 654),
            ("We Are Going On Bullrun", "https://storage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4", "https://picsum.photos/seed/flick-bullrun/720/1280", .entertainment, 180),
            ("Night of the Living Dead", "https://archive.org/download/night_of_the_living_dead/night_of_the_living_dead_512kb.mp4", "https://archive.org/services/img/night_of_the_living_dead", .movies, 5760),
            ("Charade", "https://archive.org/download/Charade_1963/Charade_1963_512kb.mp4", "https://archive.org/services/img/Charade_1963", .movies, 6780),
            ("House on Haunted Hill", "https://archive.org/download/House_on_Haunted_Hill/House_on_Haunted_Hill_512kb.mp4", "https://archive.org/services/img/House_on_Haunted_Hill", .movies, 4500),
            ("Carnival of Souls", "https://archive.org/download/CarnivalofSouls/CarnivalofSouls_512kb.mp4", "https://archive.org/services/img/CarnivalofSouls", .movies, 4680),
            ("D.O.A.", "https://archive.org/download/DOA_1950/DOA_1950_512kb.mp4", "https://archive.org/services/img/DOA_1950", .movies, 4980),
            ("Detour", "https://archive.org/download/Detour/Detour_512kb.mp4", "https://archive.org/services/img/Detour", .movies, 4080),
            ("His Girl Friday", "https://archive.org/download/his_girl_friday/his_girl_friday_512kb.mp4", "https://archive.org/services/img/his_girl_friday", .movies, 5520),
            ("The General", "https://archive.org/download/TheGeneral1926/The%20General%20%281926%29.mp4", "https://archive.org/services/img/TheGeneral1926", .movies, 4500),
            ("Metropolis", "https://archive.org/download/Metropolis_201610/Metropolis.mp4", "https://archive.org/services/img/Metropolis_201610", .movies, 9180)
        ]
        let repeated = (0..<6).flatMap { batch in
            directVideos.enumerated().map { index, item in
                (id: "playable_flick_\(batch)_\(index)", item: item, title: "\(item.title) \(batch + 1)")
            }
        }
        return repeated.map { entry in
            Video(
                id: entry.id,
                title: entry.title,
                description: "Playable Flick",
                thumbnailURL: entry.item.thumb,
                videoURL: entry.item.url,
                duration: entry.item.duration,
                viewCount: Int.random(in: 100_000...9_000_000),
                likeCount: Int.random(in: 10_000...800_000),
                commentCount: Int.random(in: 2_000...50_000),
                createdAt: Date(),
                creator: demoUser,
                category: entry.item.category,
                tags: ["playable","flicks","open"],
                isPublic: true,
                quality: [.quality720p],
                aspectRatio: .portrait,
                isLiveStream: false,
                contentSource: .userUploaded,
                isVerified: true
            )
        }
    }

    private func loadFlicksContent() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        // 🔥 PRIORITY 1: Try to load from Firestore (actual uploaded videos)
        var firestoreVideos: [Video] = []
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            // Try "shorts" collection first
            let shortsSnap = try await db.collection("shorts")
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            if !shortsSnap.documents.isEmpty {
                firestoreVideos = shortsSnap.documents.compactMap { doc in
                    let d = doc.data()
                    let defaultCreator = AppState.shared.currentUser ?? User.defaultUser
                    return Video(
                        id: doc.documentID,
                        title: d["title"] as? String ?? "Untitled Flick",
                        description: d["description"] as? String ?? "",
                        thumbnailURL: d["thumbnailUrl"] as? String ?? (d["thumbnailURL"] as? String ?? ""),
                        videoURL: d["videoUrl"] as? String ?? (d["videoURL"] as? String ?? ""),
                        duration: (d["duration"] as? Double) ?? 0,
                        viewCount: (d["viewCount"] as? Int) ?? 0,
                        likeCount: (d["likeCount"] as? Int) ?? 0,
                        commentCount: (d["commentCount"] as? Int) ?? 0,
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        creator: defaultCreator,
                        category: .shorts,
                        tags: d["tags"] as? [String] ?? [],
                        isPublic: true,
                        quality: [.quality720p],
                        aspectRatio: .portrait,
                        isLiveStream: false,
                        contentSource: .userUploaded,
                        isVerified: false
                    )
                }
            }
            
            // If no shorts, try "videos" collection with portrait aspect ratio
            if firestoreVideos.isEmpty {
                let videosSnap = try await db.collection("videos")
                    .whereField("isPublic", isEqualTo: true)
                    .order(by: "createdAt", descending: true)
                    .limit(to: 50)
                    .getDocuments()
                
                firestoreVideos = videosSnap.documents.compactMap { doc in
                    let d = doc.data()
                    let defaultCreator = AppState.shared.currentUser ?? User.defaultUser
                    // Only include portrait videos (short-form)
                    let aspectRatio = (d["aspectRatio"] as? String) ?? "landscape"
                    if aspectRatio != "portrait" && d["category"] as? String != "shorts" {
                        return nil
                    }
                    
                    return Video(
                        id: doc.documentID,
                        title: d["title"] as? String ?? "Untitled Video",
                        description: d["description"] as? String ?? "",
                        thumbnailURL: d["thumbnailUrl"] as? String ?? (d["thumbnailURL"] as? String ?? ""),
                        videoURL: d["videoUrl"] as? String ?? (d["videoURL"] as? String ?? ""),
                        duration: (d["duration"] as? Double) ?? 0,
                        viewCount: (d["viewCount"] as? Int) ?? 0,
                        likeCount: (d["likeCount"] as? Int) ?? 0,
                        commentCount: (d["commentCount"] as? Int) ?? 0,
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        creator: defaultCreator,
                        category: VideoCategory(rawValue: d["category"] as? String ?? "entertainment") ?? .entertainment,
                        tags: d["tags"] as? [String] ?? [],
                        isPublic: true,
                        quality: [.quality720p],
                        aspectRatio: .portrait,
                        isLiveStream: false,
                        contentSource: .userUploaded,
                        isVerified: false
                    )
                }
            }
        } catch {
            print("⚠️ [FlicksView] Error loading from Firestore: \(error.localizedDescription)")
        }
        #endif
        
        let playableFallbacks = makeYouTubeDemoVideos()

        // If we got videos from Firestore, use them plus playable fallbacks so feed stays full.
        if !firestoreVideos.isEmpty {
            await MainActor.run {
                self.videos = mergedFlickVideos(primary: firestoreVideos, fallback: playableFallbacks, minimumCount: 100)
                self.currentIndex = 0
                print("✅ [FlicksView] Loaded \(firestoreVideos.count) videos from Firestore plus playable fallbacks")
            }
            return
        }
        
        // 🔥 PRIORITY 2: Try YouTube API if key is available
        if !AppSecrets.youtubeAPIKey.isEmpty {
            do {
                async let a = YouTubeAPIService.shared.fetchShorts(query: "funny pets", maxResults: 20)
                async let b = YouTubeAPIService.shared.fetchShorts(query: "sports highlights", maxResults: 20)
                async let c = YouTubeAPIService.shared.fetchShorts(query: "tech tips", maxResults: 20)
                let results = (try await a) + (try await b) + (try await c)
                let dedup = Array(Dictionary(grouping: results, by: { $0.id }).values.compactMap { $0.first })
                let sorted = dedup.shuffled()
                await MainActor.run {
                    self.videos = mergedFlickVideos(primary: sorted, fallback: playableFallbacks, minimumCount: 100)
                    self.currentIndex = 0
                    print("✅ [FlicksView] Loaded \(sorted.count) videos from YouTube plus playable fallbacks")
                }
            } catch {
                await MainActor.run {
                    self.loadError = nil
                    self.videos = playableFallbacks.shuffled()
                    self.currentIndex = 0
                }
            }
        } else {
            // 🔥 PRIORITY 3: Fallback to demo videos
            await MainActor.run {
                self.videos = playableFallbacks.shuffled()
                self.currentIndex = 0
                print("⚠️ [FlicksView] No Firestore videos or YouTube key. Showing \(self.videos.count) demo videos")
            }
        }
    }

    private func mergedFlickVideos(primary: [Video], fallback: [Video], minimumCount: Int) -> [Video] {
        let playablePrimary = primary.filter { video in
            guard !video.videoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            if video.contentSource == .youtube {
                return false
            }
            return URL(string: video.videoURL) != nil
        }
        var seen = Set<String>()
        var merged = (playablePrimary + fallback).filter { video in
            if seen.contains(video.id) { return false }
            seen.insert(video.id)
            return true
        }
        while merged.count < minimumCount {
            let nextBatch = fallback.map { original in
                Video(
                    id: "\(original.id)_loop_\(merged.count)",
                    title: original.title,
                    description: original.description,
                    thumbnailURL: original.thumbnailURL,
                    videoURL: original.videoURL,
                    duration: original.duration,
                    viewCount: original.viewCount,
                    likeCount: original.likeCount,
                    commentCount: original.commentCount,
                    createdAt: original.createdAt,
                    creator: original.creator,
                    category: original.category,
                    tags: original.tags,
                    isPublic: original.isPublic,
                    quality: original.quality,
                    aspectRatio: original.aspectRatio,
                    isLiveStream: original.isLiveStream,
                    contentSource: original.contentSource,
                    externalID: original.externalID,
                    isVerified: original.isVerified
                )
            }
            merged.append(contentsOf: nextBatch)
        }
        return Array(merged.shuffled().prefix(max(minimumCount, merged.count)))
    }

    // MARK: - Tracking
    private func startViewTimeTracking(for video: Video) {
        videoViewTimes[video.id] = Date().timeIntervalSince1970
        viewTimeTimer?.invalidate()
        viewTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in }
    }

    private func stopViewTimeTracking(for video: Video) {
        viewTimeTimer?.invalidate()
        viewTimeTimer = nil
        if let start = videoViewTimes[video.id] {
            let watchDuration = Date().timeIntervalSince1970 - start
            let _ = watchDuration
        }
    }

    private func trackVideoCompletion(for video: Video) {}

    // MARK: - Interactions
    private func toggleLikeWithAnimation(for video: Video) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            if likedVideos.contains(video.id) {
                likedVideos.remove(video.id)
                notificationFeedback.notificationOccurred(.warning)
            } else {
                likedVideos.insert(video.id)
                notificationFeedback.notificationOccurred(.success)
            }
        }
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

    // MARK: - Preload
    private func preloadVideoIfNeeded(at index: Int) {
        guard !preloadedIndices.contains(index), networkMonitor.isConnected else { return }
        preloadedIndices.insert(index)
        let ahead = max(2, performanceMonitor.getRecommendedPreloadCount())
        let range = max(0, index - 1)...min(videos.count - 1, index + ahead)
        Task {
            for i in range {
                await preloadVideo(at: i)
            }
        }
    }

    private func preloadVideo(at index: Int) async {
        guard index < videos.count else { return }
        if videos[index].contentSource != .youtube {
            await MainActor.run {
                VideoPlayerManager.prewarm(urlString: videos[index].videoURL)
            }
        }
    }

    private func preloadNextVideos(currentIndex: Int) {
        guard performanceMonitor.shouldPreloadVideos(), networkMonitor.isConnected else { return }
        if currentIndex >= videos.count - 3 {
            // No-op for now; YouTube feed is large enough
        }
    }

    private func triggerLikeBurst() {
        likeBurstID = UUID()
        withAnimation {
            showLikeBurst = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                showLikeBurst = false
            }
        }
    }

    private func engageIfNeeded() {
        if !didEngageWithFeed {
            GlobalVideoPlayerManager.shared.pauseForFlicksEngagement()
            didEngageWithFeed = true
        }
    }
}

extension Notification.Name {
    static let flicksPeekUpdate = Notification.Name("flicksPeekUpdate")
}

// MARK: - 🔥 Premium Button Style for Flicks
struct FlicksPremiumScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview("FlicksView - Clean Fullscreen") {
    FlicksView(isEmbeddedInTab: true)
        .preferredColorScheme(.dark)
}