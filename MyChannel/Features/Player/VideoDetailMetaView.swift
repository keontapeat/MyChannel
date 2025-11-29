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
    
    // MARK: - Performance Optimization
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // MARK: - Video Title Section
                    professionalTitleSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    // MARK: - Stats & Metadata
                    videoStatsSection
                        .transition(.slide.combined(with: .opacity))
                    
                    // MARK: - YouTube-Style Action Buttons
                    youtubeActionButtons
                        .opacity(actionButtonsOpacity)
                        .scaleEffect(actionButtonsOpacity)
                        .transition(.scale.combined(with: .opacity))
                    
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
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, 
                                      value: geo.frame(in: .named("scroll")).minY)
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                withAnimation(.easeOut(duration: 0.3)) {
                    scrollOffset = value
                    actionButtonsOpacity = max(0.6, min(1.0, 1 + (value / 200)))
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
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - 🔥 YOUTUBE 2024 STYLE: Minimal Stats Section
    private var videoStatsSection: some View {
        HStack(spacing: 0) {
            // Views and time in YouTube's compact format
            Text("\(formatCount(dynamicViewCount ?? video.viewCount)) views")
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
    
    // MARK: - 🔥 YOUTUBE 2024 STYLE: Compact Pill Action Buttons
    private var youtubeActionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {  // 🔥 Tighter spacing for sleek look
                // Like Button with Advanced Animation
                VideoMetaActionButton(
                    icon: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                    title: formatCount(video.likeCount),
                    isActive: isLiked,
                    activeColor: AppTheme.Colors.primary,
                    scale: likeAnimationScale
                ) {
                    performLikeAction()
                }
                .accessibilityLabel(isLiked ? "Unlike" : "Like")
                .accessibilityHint("Double tap to \(isLiked ? "remove your like" : "like this video")")
                .accessibilityValue("\(video.likeCount) likes")
                
                // Dislike Button
                VideoMetaActionButton(
                    icon: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                    title: "Dislike",
                    isActive: isDisliked,
                    activeColor: AppTheme.Colors.error
                ) {
                    performDislikeAction()
                }
                .accessibilityLabel(isDisliked ? "Remove dislike" : "Dislike")
                .accessibilityHint("Double tap to \(isDisliked ? "remove your dislike" : "dislike this video")")
                
                // Share Button
                VideoMetaActionButton(
                    icon: "arrowshape.turn.up.right.fill",
                    title: "Share"
                ) {
                    performShareAction()
                }
                .accessibilityLabel("Share video")
                .accessibilityHint("Double tap to share this video with others")
                
                // Save Button
                VideoMetaActionButton(
                    icon: isWatchLater ? "bookmark.fill" : "bookmark",
                    title: "Save",
                    isActive: isWatchLater,
                    activeColor: AppTheme.Colors.accent ?? AppTheme.Colors.primary
                ) {
                    performSaveAction()
                }

                // Download Button (Premium Feature) - YouTube-style
                DownloadButtonView(video: video) {
                    performDownloadAction()
                }
                .buttonStyle(.plain)
                
                // 🔥 YOUTUBE PARITY: Clips Button
                VideoMetaActionButton(
                    icon: "scissors",
                    title: "Clip"
                ) {
                    showingClipsView = true
                    HapticManager.shared.impact(style: .light)
                }
                .accessibilityLabel("Create clip")
                .accessibilityHint("Double tap to create a shareable clip from this video")
                
                // 🔥 YOUTUBE PARITY: Super Thanks Button
                VideoMetaActionButton(
                    icon: "dollarsign.circle.fill",
                    title: "Thanks"
                ) {
                    showingSuperThanks = true
                    HapticManager.shared.impact(style: .medium)
                }
                .accessibilityLabel("Super Thanks")
                .accessibilityHint("Double tap to send a Super Thanks to the creator")
                
                // Tip Button - Real Payment Processing (if enabled)
                if video.monetization?.donationEnabled == true {
                    VideoMetaActionButton(
                        icon: "heart.fill",
                        title: "Tip"
                    ) {
                        showingTipSheet = true
                    }
                }
                
                // Chapters Button (if available)
                if let onChapters {
                    let hasModelChapters = (video.chapters?.isEmpty == false)
                    let hasParsedChapters = !video.parsedChaptersFromDescription.isEmpty
                    if hasModelChapters || hasParsedChapters {
                        VideoMetaActionButton(
                            icon: "list.bullet.rectangle",
                            title: "Chapters"
                        ) {
                            onChapters()
                        }
                    }
                }
                
                // More Options (contains less common actions)
                VideoMetaActionButton(
                    icon: "ellipsis",
                    title: "More"
                ) {
                    performMoreAction()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .padding(.top, 8)  // 🔥 Reduced padding for sleeker look
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
    
    // MARK: - Action Methods
    private func performLikeAction() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            likeAnimationScale = 1.3
            isLiked.toggle()
            if isLiked { isDisliked = false }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                likeAnimationScale = 1.0
            }
        }
        
        impactFeedback.impactOccurred(intensity: isLiked ? 0.8 : 0.4)
    }
    
    private func performDislikeAction() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isDisliked.toggle()
            if isDisliked { isLiked = false }
        }
        impactFeedback.impactOccurred(intensity: 0.6)
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
        // Check if premium user
        let premiumService = PremiumService.shared
        guard premiumService.isPremium else {
            // Show premium alert
            NotificationCenter.default.post(name: .navigateToPremium, object: nil)
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
        if let download = offlineService.downloads.first(where: { $0.videoId == video.id && $0.status == .downloading }) {
            // Already downloading - could show progress or cancel option
            return
        }
        
        // Show quality selection sheet
        showingDownloadQualitySheet = true
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    @State private var showingDownloadOptions: Bool = false
    
    private func performMoreAction() {
        onMore()
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    private func performSubscribeAction() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            subscribeButtonScale = 0.95
            isSubscribed.toggle()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                subscribeButtonScale = 1.0
            }
        }
        
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        feedbackGenerator.impactOccurred(intensity: 1.0)
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

// MARK: - 🔥 YOUTUBE 2024 STYLE: Pill-Shaped Action Button Component
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

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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