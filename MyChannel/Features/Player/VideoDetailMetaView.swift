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
    let onShare: () -> Void
    let onMore: () -> Void
    let onComment: () -> Void
    var onChapters: (() -> Void)? = nil
    var onProfileTap: (() -> Void)? = nil
    var dynamicViewCount: Int? = nil // 🔥 REAL-TIME: Override view count for live updates
    
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
                    
                    // Bottom safe area padding
                    Spacer()
                        .frame(height: 120)
                }
            }
        }
        .background(AppTheme.Colors.background)
        .onAppear {
            impactFeedback.prepare()
        }
        .sheet(isPresented: $showingTipSheet) {
            TipSheet(video: video)
        }
        .sheet(isPresented: $showingSuperThanks) {
            SuperThanksSheet(video: video)
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
                if !premiumService.isPremium {
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
                YouTubeActionPill(icon: "heart.circle", title: "Thanks") {
                    showingSuperThanks = true
                    HapticManager.shared.impact(style: .light)
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
                    print("📺 Navigate to channel: \(channelName)")
                },
                onHashtagTap: { hashtag in
                    print("🔍 Navigate to hashtag: \(hashtag)")
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
            
            // Comments preview placeholder
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<min(2, max(0, video.commentCount)), id: \.self) { _ in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Rectangle()
                                .fill(AppTheme.Colors.surface)
                                .frame(height: 12)
                                .frame(maxWidth: 120)
                            
                            Rectangle()
                                .fill(AppTheme.Colors.surface.opacity(0.7))
                                .frame(height: 10)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .redacted(reason: .placeholder)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - 🔥 PREMIUM: Action Methods with Enhanced Haptics
    private func performLikeAction() {
        // 🔥 PREMIUM: Enhanced bounce animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            likeAnimationScale = 1.4
            isLiked.toggle()
            if isLiked { isDisliked = false }
        }
        
        // 🔥 PREMIUM: Double bounce for satisfying feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                likeAnimationScale = 0.9
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                likeAnimationScale = 1.0
            }
        }
        
        // 🔥 PREMIUM: Stronger haptic for like, lighter for unlike
        if isLiked {
            HapticManager.shared.notification(type: .success)
        } else {
            HapticManager.shared.impact(style: .light)
        }
    }
    
    private func performDislikeAction() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isDisliked.toggle()
            if isDisliked { isLiked = false }
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
    }
    
    @State private var showingDownloadQualitySheet: Bool = false
    
    private func performDownloadAction() {
        // 🔥 YOUTUBE PARITY: Check if premium user - show upsell if not
        guard premiumService.isPremium else {
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
        // 🔥 PREMIUM: Enhanced subscribe animation with celebratory bounce
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            subscribeButtonScale = isSubscribed ? 0.9 : 1.15
            isSubscribed.toggle()
        }
        
        // 🔥 PREMIUM: Bounce back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                subscribeButtonScale = 1.0
            }
        }
        
        // 🔥 PREMIUM: Celebration haptic for subscribe, subtle for unsubscribe
        if isSubscribed {
            HapticManager.shared.notification(type: .success)
        } else {
            HapticManager.shared.impact(style: .light)
        }
    }
    
    // MARK: - Helper Methods
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - 🔥 YOUTUBE 2024 EXACT: Combined Like/Dislike Pill
/// Exact replica of YouTube's combined like/dislike button with separator
struct YouTubeLikeDislikePill: View {
    let likeCount: Int
    let isLiked: Bool
    let isDisliked: Bool
    var likeScale: CGFloat = 1.0
    let onLike: () -> Void
    let onDislike: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Like Button
            Button(action: onLike) {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isLiked ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                    
                    Text(formatCount(likeCount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .scaleEffect(likeScale)
            }
            .buttonStyle(PillPressedButtonStyle())
            .accessibilityLabel(isLiked ? "Unlike" : "Like")
            .accessibilityValue("\(likeCount) likes")
            
            // Separator Line (YouTube exact style)
            Rectangle()
                .fill(AppTheme.Colors.textSecondary.opacity(0.3))
                .frame(width: 1, height: 18)
            
            // Dislike Button
            Button(action: onDislike) {
                Image(systemName: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDisliked ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(PillPressedButtonStyle())
            .accessibilityLabel(isDisliked ? "Remove dislike" : "Dislike")
        }
        .background(
            Capsule()
                .fill(AppTheme.Colors.surface)
        )
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

// MARK: - 🔥 FIX: Custom ButtonStyle that doesn't block ScrollView gestures
/// Uses configuration.isPressed instead of DragGesture to detect pressed state
struct PillPressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 🔥 YOUTUBE 2024 EXACT: Action Pill Button
/// Simple pill button matching YouTube's exact style
/// 🔥 FIX: Uses PillPressedButtonStyle instead of DragGesture to allow ScrollView scrolling
struct YouTubeActionPill: View {
    let icon: String
    let title: String
    var iconColor: Color? = nil
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(iconColor ?? (isActive ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary))
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.surface)
            )
        }
        .buttonStyle(PillPressedButtonStyle())
        .accessibilityLabel("\(title) button")
    }
}

// MARK: - 🔥 YOUTUBE PARITY: Ask AI Sheet (Gemini-style)
struct AskAISheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var question: String = ""
    @State private var isLoading = false
    @State private var response: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // AI Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 24)
                
                Text("Ask about this video")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Get AI-powered answers about \"\(video.title)\"")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Question Input
                TextField("Ask a question...", text: $question, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .lineLimit(3...6)
                
                // Suggested Questions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Summarize this video", "What are the key points?", "Who is the speaker?"], id: \.self) { suggestion in
                                Button(action: { question = suggestion }) {
                                    Text(suggestion)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.Colors.surface)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                // Ask Button
                Button(action: {
                    isLoading = true
                    // Simulate AI response
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isLoading = false
                        response = "This is an AI-generated response about the video."
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                            Text("Ask AI")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(24)
                }
                .disabled(question.isEmpty || isLoading)
                .opacity(question.isEmpty ? 0.5 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 🔥 YOUTUBE PARITY: Remix Sheet
struct RemixSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("Remix this video")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Create your own version using this video")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.top, 32)
                
                // Remix Options
                VStack(spacing: 12) {
                    RemixOptionRow(
                        icon: "music.note",
                        title: "Use this sound",
                        subtitle: "Create a video with the same audio"
                    )
                    
                    RemixOptionRow(
                        icon: "scissors",
                        title: "Cut",
                        subtitle: "Trim this video into a Short"
                    )
                    
                    RemixOptionRow(
                        icon: "square.on.square",
                        title: "Green Screen",
                        subtitle: "Use this video as a background"
                    )
                    
                    RemixOptionRow(
                        icon: "rectangle.on.rectangle",
                        title: "Collab",
                        subtitle: "Create a side-by-side video"
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(AppTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct RemixOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 44, height: 44)
                .background(AppTheme.Colors.surface)
                .cornerRadius(22)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
    }
}

// MARK: - 🔥 YOUTUBE 2024 STYLE: Pill-Shaped Action Button Component (Legacy)
/// Compact horizontal pill button matching YouTube's 2024 Material You design
/// - Icon + text side-by-side in a rounded pill shape
/// - Much smaller footprint than vertical stacked buttons
/// - Sleek, minimal, professional appearance
struct VideoMetaActionButton: View {
    let icon: String
    let title: String
    var isActive: Bool = false
    var activeColor: Color = AppTheme.Colors.primary
    var hasSpecialEffect: Bool = false
    var isPremium: Bool = false
    var scale: CGFloat = 1.0
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isActive ? activeColor : AppTheme.Colors.textSecondary)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                // Title
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isActive ? activeColor : AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                // Premium indicator (inline)
                if isPremium {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? activeColor.opacity(0.12) : AppTheme.Colors.surface.opacity(0.9))
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? activeColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect((isPressed ? 0.95 : 1.0) * pulseScale * scale)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: pulseScale)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onAppear {
            if hasSpecialEffect {
                startPulseAnimation()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) button")
        .accessibilityHint(isActive ? "Currently active" : "Tap to activate")
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.02
        }
    }
}

// MARK: - 🔥 YOUTUBE 2024 STYLE: Minimal Tag Pill
struct SmartTagView: View {
    let tag: String
    let index: Int
    
    var body: some View {
        Text("#\(tag)")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.Colors.surface.opacity(0.9))
            )
            .accessibilityLabel("Tag: \(tag)")
    }
}

// MARK: - 🔥 PREMIUM: Animated View Count Text
struct AnimatedViewCountText: View {
    let viewCount: Int
    
    @State private var displayedCount: Int = 0
    @State private var hasAnimated = false
    
    var body: some View {
        Text(formatCount(displayedCount))
            .font(.system(size: 13, weight: .regular))
            .contentTransition(.numericText())
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                animateCount()
            }
            .onChange(of: viewCount) { newValue in
                // Smoothly animate to new value
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    displayedCount = newValue
                }
            }
    }
    
    private func animateCount() {
        // 🔥 PREMIUM: Smooth count-up animation
        let steps = min(viewCount, 20)
        guard steps > 0 else {
            displayedCount = viewCount
            return
        }
        
        let stepDuration = 0.5 / Double(steps)
        
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let progress = Double(step) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 3) // Cubic ease-out
                let newValue = Int(Double(viewCount) * easedProgress)
                
                withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                    displayedCount = newValue
                }
            }
        }
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

// MARK: - Preview
#Preview {
    NavigationView {
        VideoDetailMetaView(
            video: Video.sampleVideos[0],
            isSubscribed: .constant(false),
            isWatchLater: .constant(false),
            isLiked: .constant(false),
            isDisliked: .constant(false),
            expandedDescription: .constant(false),
            onShare: { print("Share tapped") },
            onMore: { print("More tapped") },
            onComment: { print("Comment tapped") }
        )
        .preferredColorScheme(.light)
    }
}