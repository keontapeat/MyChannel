//
//  VideoDetailMetaView.swift
//  MyChannel
//
//  Enhanced by Senior iOS Developer with YouTube-grade polish
//  Features: Advanced animations, haptics, accessibility, performance optimization
//

import SwiftUI
import Combine

// MARK: - Professional YouTube-Style Video Meta View
struct VideoDetailMetaView: View {
    // MARK: - Properties
    let video: Video
    @Binding var isSubscribed: Bool
    @Binding var isWatchLater: Bool
    @Binding var isLiked: Bool
    @Binding var isDisliked: Bool
    @Binding var expandedDescription: Bool
    var autoplayEnabled: Binding<Bool>? = nil
    let onShare: () -> Void
    let onMore: () -> Void
    let onComment: () -> Void
    var onChapters: (() -> Void)? = nil
    var onProfileTap: (() -> Void)? = nil
    var onChannelTap: ((String) -> Void)? = nil
    var onHashtagTap: ((String) -> Void)? = nil
    var dynamicViewCount: Int? = nil
    // 🔥 YOUTUBE PARITY: Related videos rail below comments
    var relatedVideos: [Video] = []
    var onSelectRelated: ((Video) -> Void)? = nil
    // 🔥 YOUTUBE PARITY: Show transcript button inside description section
    var onShowTranscript: (() -> Void)? = nil
    
    // MARK: - Services for Firestore persistence
    @StateObject private var appState = AppState.shared
    
    // MARK: - Animation States
    @State private var likeAnimationScale: CGFloat = 1.0
    @State private var subscribeButtonScale: CGFloat = 1.0
    @State private var scrollOffset: CGFloat = 0
    @State private var actionButtonsOpacity: Double = 1.0
    @State private var showingTipSheet: Bool = false
    @State private var showingSuperThanks: Bool = false  // 🔥 YOUTUBE PARITY: Super Thanks
    @State private var showingClipsView: Bool = false    // 🔥 YOUTUBE PARITY: Clips
    @State private var showingAskAI: Bool = false        // 🔥 YOUTUBE PARITY: Ask (Gemini)
    @State private var showingRemixSheet: Bool = false   // 🔥 YOUTUBE PARITY: Remix
    @State private var showingPremiumUpsell: Bool = false // 🔥 YOUTUBE PARITY: Premium upsell
    @State private var showingStopAdsUpsell: Bool = false // 🔥 YOUTUBE PARITY: Stop ads upsell
    @StateObject private var premiumService = PremiumService.shared
    @State private var previewComments: [RealTimeComment] = []
    @State private var commentsListener: Any? = nil
    
    // MARK: - Performance Optimization
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Video Title Section (Fixed at top)
            professionalTitleSection
            
            // MARK: - Stats & Metadata
            videoStatsSection
            
            // MARK: - YouTube-Style Action Buttons (OUTSIDE ScrollView for proper scrolling)
            youtubeActionButtons
            
            // MARK: - Scrollable Content Below
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // MARK: - Professional Divider
                    modernDivider
                    
                    // MARK: - Creator Profile Section
                    creatorProfileSection
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    
                    // MARK: - Enhanced Description
                    intelligentDescriptionSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    
                    // MARK: - Smart Tags Section
                    if !video.tags.isEmpty {
                        smartTagsSection
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // MARK: - Comments Preview
                    commentsPreviewSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    // 🔥 YOUTUBE PARITY: Related videos vertical rail
                    if !relatedVideos.isEmpty {
                        relatedVideosSection
                            .transition(.opacity)
                    }
                    
                    // Bottom safe area padding
                    Spacer()
                        .frame(height: 120)
                }
            }
        }
        .background(AppTheme.Colors.background)
        .onAppear {
            impactFeedback.prepare()
            // Sync initial state from AppState (loaded from Firestore/UserDefaults)
            isLiked = appState.likedVideos.contains(video.id)
            isSubscribed = appState.subscriptions.contains(video.creator.id)
            isWatchLater = appState.watchLaterVideos.contains(video.id)
            if commentsListener == nil {
                commentsListener = CommentsFirestoreService.shared.listen(videoId: video.id) { comments in
                    Task { @MainActor in
                        self.previewComments = Array(
                            comments
                                .filter { $0.parentId == nil }
                                .sorted { lhs, rhs in
                                    let lhsScore = commentRelevanceScore(lhs)
                                    let rhsScore = commentRelevanceScore(rhs)
                                    if lhsScore == rhsScore {
                                        return lhs.createdAt > rhs.createdAt
                                    }
                                    return lhsScore > rhsScore
                                }
                                .prefix(2)
                        )
                    }
                }
            }
        }
        .onDisappear {
            CommentsFirestoreService.shared.stop(listener: commentsListener)
            commentsListener = nil
        }
        .sheet(isPresented: $showingTipSheet) {
            // 🔥 FIX 3.1.1: Gate tip sheet behind feature flag
            if AppConfig.Features.enableTipping {
                TipSheet(video: video)
            } else {
                Text("Tipping coming soon!").font(.title3.bold()).foregroundColor(.secondary).padding()
            }
        }
        .sheet(isPresented: $showingSuperThanks) {
            // 🔥 FIX 3.1.1: Gate Super Thanks behind feature flag
            if AppConfig.Features.enableTipping {
                SuperThanksSheet(video: video)
            } else {
                Text("Super Thanks coming soon!").font(.title3.bold()).foregroundColor(.secondary).padding()
            }
        }
        .sheet(isPresented: $showingClipsView) {
            ClipsView(video: video, currentTime: 0)
        }
        .sheet(isPresented: $showingAskAI) {
            AskAISheet(video: video)
        }
        .sheet(isPresented: $showingRemixSheet) {
            RemixSheet(video: video)
        }
        .sheet(isPresented: $showingPremiumUpsell) {
            YouTubePremiumUpsellSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingStopAdsUpsell) {
            StopAdsUpsellSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingDownloadQualitySheet) {
            DownloadQualitySheet(video: video)
        }
        .confirmationDialog("Downloaded Video", isPresented: $showingDownloadOptions, titleVisibility: .visible) {
            Button("Play Offline") {
                // Navigate to offline player
            }
            Button("Delete Download", role: .destructive) {
                Task {
                    let offlineService = OfflineDownloadService.shared
                    if let download = offlineService.downloads.first(where: { $0.videoId == video.id }) {
                        try? await offlineService.deleteDownload(download.id)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - 🔥 YOUTUBE 2024 STYLE: Clean Title Section
    private var professionalTitleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(video.title)
                .font(.system(size: 17, weight: .semibold))  // 🔥 Slightly smaller, cleaner
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(expandedDescription ? nil : 2)
                .multilineTextAlignment(.leading)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: expandedDescription)
                .accessibilityLabel("Video title: \(video.title)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - 🔥 YOUTUBE 2024 STYLE: Minimal Stats Section with Animated View Count
    private var videoStatsSection: some View {
        HStack(spacing: 0) {
            // 🔥 PREMIUM: Animated view count
            AnimatedViewCountText(viewCount: dynamicViewCount ?? video.viewCount)
            
            Text(" views")
                .font(.system(size: 13, weight: .regular))
            
            Text(" • ")
                .font(.system(size: 13, weight: .regular))
            
            Text(video.timeAgo)
                .font(.system(size: 13, weight: .regular))
            
            Spacer()
        }
        .foregroundColor(AppTheme.Colors.textSecondary)
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(formatCount(dynamicViewCount ?? video.viewCount)) views, \(video.timeAgo)")
    }
    
    // MARK: - 🔥 YOUTUBE 2024 EXACT PARITY: Action Buttons Row (Scrollable)
    private var youtubeActionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 🔥 YOUTUBE EXACT: Combined Like/Dislike Pill with Separator
                YouTubeLikeDislikePill(
                    likeCount: video.likeCount,
                    isLiked: isLiked,
                    isDisliked: isDisliked,
                    likeScale: likeAnimationScale,
                    onLike: { performLikeAction() },
                    onDislike: { performDislikeAction() }
                )
                
                // 🔥 YOUTUBE EXACT: Share Button
                YouTubeActionPill(icon: "arrowshape.turn.up.right.fill", title: "Share") {
                    performShareAction()
                }
                
                // Download Button (Premium Feature)
                DownloadButtonView(video: video) {
                    performDownloadAction()
                }
                .buttonStyle(.plain)
                
                // 🔥 YOUTUBE EXACT: Stop ads Button (Shows Premium upsell)
                // 🔥 FIX 2.1(b): Hide when IAPs not submitted
                if AppConfig.Features.enableSubscriptions && !premiumService.isPremium {
                    YouTubeActionPill(icon: "slash.circle", title: "Stop ads") {
                        showingStopAdsUpsell = true
                        HapticManager.shared.impact(style: .light)
                    }
                }
                
                // Clip Button
                YouTubeActionPill(icon: "scissors", title: "Clip") {
                    showingClipsView = true
                    HapticManager.shared.impact(style: .light)
                }
                
                // Save/Bookmark Button
                YouTubeActionPill(
                    icon: isWatchLater ? "bookmark.fill" : "bookmark",
                    title: "Save",
                    isActive: isWatchLater
                ) {
                    performSaveAction()
                }
                
                // 🔥 YOUTUBE EXACT: Report Button
                YouTubeActionPill(icon: "flag", title: "Report") {
                    performMoreAction()
                }
                
                // 🔥 YOUTUBE EXACT: Thanks (Super Thanks) Button
                // 🔥 FIX 3.1.1: Hide when tipping disabled (uses Stripe, bypasses IAP)
                if AppConfig.Features.enableTipping {
                    YouTubeActionPill(icon: "heart.circle", title: "Thanks") {
                        showingSuperThanks = true
                        HapticManager.shared.impact(style: .light)
                    }
                }
                
                // 🔥 YOUTUBE EXACT: Remix Button
                YouTubeActionPill(icon: "arrow.triangle.2.circlepath", title: "Remix") {
                    showingRemixSheet = true
                    HapticManager.shared.impact(style: .light)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 52)
    }
    
    // MARK: - 🔥 YOUTUBE 2024 STYLE: Subtle Divider
    private var modernDivider: some View {
        Rectangle()
            .fill(AppTheme.Colors.surface.opacity(0.4))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }
    
    // MARK: - 🔥 YOUTUBE 2024 STYLE: Compact Creator Profile Section
    private var creatorProfileSection: some View {
        HStack(spacing: 12) {
            // Creator Avatar - Clickable
            Button(action: {
                HapticManager.shared.impact(style: .light)
                onProfileTap?()
            }) {
                AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        )
                }
                .frame(width: 40, height: 40)  // 🔥 Smaller avatar
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Creator Info - More compact
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(video.creator.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    if video.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                            .font(.system(size: 12))
                    }
                }
                
                Text("\(formatCount(video.creator.subscriberCount)) subscribers")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // 🔥 YOUTUBE 2024 STYLE: Compact Subscribe Button
            Button(action: performSubscribeAction) {
                Text(isSubscribed ? "Subscribed" : "Subscribe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSubscribed ? AppTheme.Colors.textSecondary : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSubscribed ? AppTheme.Colors.surface : AppTheme.Colors.primary)
                    )
                    .scaleEffect(subscribeButtonScale)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSubscribed ? "Unsubscribe from \(video.creator.displayName)" : "Subscribe to \(video.creator.displayName)")
            .accessibilityHint("Double tap to \(isSubscribed ? "unsubscribe from" : "subscribe to") \(video.creator.displayName)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - 🔥 YOUTUBE 2024 STYLE: Compact Description Section
    private var intelligentDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let previewText = String(video.description.prefix(100))
            let shouldShowMore = video.description.count > 100
            let displayText = expandedDescription ? video.description : previewText + (shouldShowMore ? "..." : "")
            
            // 🔥 YOUTUBE PARITY: Rich text description with clickable links, timestamps, @mentions, #hashtags
            RichTextDescriptionView(
                description: displayText,
                onLinkTap: { url in
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                },
                onTimestampTap: { time in
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SeekToTimestamp"),
                        object: time
                    )
                },
                onChannelTap: { channelName in
                    onChannelTap?(channelName)
                },
                onHashtagTap: { hashtag in
                    onHashtagTap?(hashtag)
                }
            )
            .font(.system(size: 14, weight: .regular))
            .lineLimit(expandedDescription ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: expandedDescription)
            
            if shouldShowMore {
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        expandedDescription.toggle()
                    }
                    let selectionFeedback = UISelectionFeedbackGenerator()
                    selectionFeedback.selectionChanged()
                }) {
                    Text(expandedDescription ? "Show less" : "...more")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .accessibilityLabel(expandedDescription ? "Show less description" : "Show more description")
            }

            // 🔥 YOUTUBE PARITY: Show transcript button (appears when description is expanded)
            if expandedDescription, onShowTranscript != nil {
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onShowTranscript?()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Show transcript")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(AppTheme.Colors.surface)
                    )
                }
                .accessibilityLabel("Show video transcript")
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
    
    // MARK: - 🔥 YOUTUBE 2024 STYLE: Minimal Tags Section
    private var smartTagsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(Array(video.tags.prefix(6).enumerated()), id: \.offset) { index, tag in
                    SmartTagView(tag: tag, index: index)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }
    
    // MARK: - 🔥 YOUTUBE PARITY: Related Videos Section
    private var relatedVideosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(AppTheme.Colors.surface.opacity(0.4))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            HStack {
                Text("Up next")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(relatedVideos.filter { $0.id != video.id }.prefix(20)) { related in
                    Button {
                        HapticManager.shared.impact(style: .light)
                        onSelectRelated?(related)
                    } label: {
                        relatedVideoRow(related)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func relatedVideoRow(_ video: Video) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Compact thumbnail - YouTube style (120x68)
            ZStack(alignment: .bottomTrailing) {
                AppAsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Duration badge - minimal
                Text(formatDuration(video.duration))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(2)
                    .padding(3)
            }

            // Compact meta
            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(video.creator.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)

                Text("\(formatCount(video.viewCount)) views • \(video.timeAgo)")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Minimal options button
            Button(action: {}) {
                Image(systemName: "ellipsis.vertical")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 24, height: 68)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds.rounded())
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Comments Preview Section
    private var commentsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Comments")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("(\(formatCount(video.commentCount)))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: onComment) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.Colors.primary)
                        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4)
                }
                .accessibilityLabel("Add comment")
            }
            
            if previewComments.isEmpty {
                Text("Be the first to comment")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(previewComments) { comment in
                        HStack(alignment: .top, spacing: 12) {
                            AsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        Text(String(comment.author.displayName.prefix(1)))
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    )
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(comment.author.displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .lineLimit(1)
                                    Text(comment.timeAgo)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }

                                Text(comment.text)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .lineLimit(2)

                                if comment.likeCount > 0 {
                                    Text("\(formatCount(comment.likeCount)) likes")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        // 🔥 YOUTUBE PARITY: Whole comments card opens the full comments sheet (not just the + button)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
            onComment()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Comments, \(formatCount(video.commentCount)). Tap to open.")
    }
    
    // MARK: - Action Methods (Firestore-backed)
    private func performLikeAction() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            likeAnimationScale = 1.4
            isLiked.toggle()
            if isLiked { isDisliked = false }
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { likeAnimationScale = 0.9 }
            try? await Task.sleep(nanoseconds: 100_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { likeAnimationScale = 1.0 }
        }
        // Persist to Firestore via AppState
        appState.toggleLike(for: video.id)
        if isLiked {
            HapticManager.shared.notification(type: .success)
        } else {
            HapticManager.shared.impact(style: .light)
        }
    }
    
    private func performDislikeAction() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isDisliked.toggle()
            if isDisliked {
                isLiked = false
                // Remove like from Firestore if it was liked
                if appState.likedVideos.contains(video.id) {
                    appState.toggleLike(for: video.id)
                }
            }
        }
        HapticManager.shared.impact(style: .medium)
    }
    
    private func performShareAction() {
        onShare()
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    private func performSaveAction() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isWatchLater.toggle()
        }
        impactFeedback.impactOccurred(intensity: 0.7)
        // Persist to Firestore
        if let uid = appState.currentUser?.id {
            Task {
                await UserCollectionsFirestoreService.shared.toggleWatchLater(
                    userId: uid, videoId: video.id, add: isWatchLater
                )
            }
        }
    }
    
    @State private var showingDownloadQualitySheet: Bool = false
    
    private func performDownloadAction() {
        // 🔥 YOUTUBE PARITY: Check if premium user - show upsell if not
        // 🔥 FIX 2.1(b): Only gate behind premium when IAPs are submitted
        if AppConfig.Features.enableSubscriptions && !premiumService.isPremium {
            // Show YouTube-style premium upsell
            showingPremiumUpsell = true
            HapticManager.shared.impact(style: .light)
            return
        }
        
        // Check if already downloaded
        let offlineService = OfflineDownloadService.shared
        if offlineService.isVideoAvailableOffline(video.id) {
            // Show options: Delete or Play Offline
            showingDownloadOptions = true
            return
        }
        
        // Check if downloading
        if offlineService.downloads.first(where: { $0.videoId == video.id && $0.status == .downloading }) != nil {
            // Already downloading - could show progress or cancel option
            return
        }
        
        // Show quality selection sheet
        showingDownloadQualitySheet = true
        HapticManager.shared.impact(style: .light)
    }
    
    @State private var showingDownloadOptions: Bool = false
    
    private func performMoreAction() {
        onMore()
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    private func performSubscribeAction() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            subscribeButtonScale = isSubscribed ? 0.9 : 1.15
            isSubscribed.toggle()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                subscribeButtonScale = 1.0
            }
        }
        // Persist to Firestore
        if let uid = appState.currentUser?.id {
            Task {
                await UserCollectionsFirestoreService.shared.toggleSubscription(
                    userId: uid, creatorId: video.creator.id, add: isSubscribed
                )
            }
            // Update local AppState subscriptions set
            if isSubscribed {
                appState.subscriptions.insert(video.creator.id)
            } else {
                appState.subscriptions.remove(video.creator.id)
            }
        }
        if isSubscribed {
            HapticManager.shared.notification(type: .success)
        } else {
            HapticManager.shared.impact(style: .light)
        }
    }
    
    // MARK: - Helper Methods
    private func commentRelevanceScore(_ comment: RealTimeComment) -> Double {
        let ageHours = Date().timeIntervalSince(comment.createdAt) / 3600
        let recencyBoost = max(0, 24 - ageHours) / 6
        let engagementScore = Double(comment.likeCount) * 1.2 + Double(comment.replyCount) * 2.5
        let textRichness = min(Double(comment.text.count) / 80.0, 2.0)
        return engagementScore + recencyBoost + textRichness
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}


// ⚡ Pill/button/sheet components extracted to VideoMetaComponents.swift
