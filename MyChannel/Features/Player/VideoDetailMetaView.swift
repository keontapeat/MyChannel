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
    
    // MARK: - Animation States
    @State private var likeAnimationScale: CGFloat = 1.0
    @State private var subscribeButtonScale: CGFloat = 1.0
    @State private var scrollOffset: CGFloat = 0
    @State private var actionButtonsOpacity: Double = 1.0
    
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
    }
    
    // MARK: - Professional Title Section
    private var professionalTitleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(video.title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.Colors.textPrimary, AppTheme.Colors.textPrimary.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .lineLimit(expandedDescription ? nil : 2)
                .multilineTextAlignment(.leading)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: expandedDescription)
                .accessibilityLabel("Video title: \(video.title)")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Enhanced Stats Section
    private var videoStatsSection: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "eye")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("\(video.formattedViewCount) views")
                    .font(.system(size: 14, weight: .medium))
            }
            
            Circle()
                .fill(AppTheme.Colors.textSecondary.opacity(0.6))
                .frame(width: 3, height: 3)
            
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(video.timeAgo)
                    .font(.system(size: 14, weight: .medium))
            }
            
            Spacer()
        }
        .foregroundColor(AppTheme.Colors.textSecondary)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(video.formattedViewCount) views, \(video.timeAgo)")
    }
    
    // MARK: - YouTube-Style Action Buttons
    private var youtubeActionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
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
                
                // Dislike Button
                VideoMetaActionButton(
                    icon: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                    title: "Dislike",
                    isActive: isDisliked,
                    activeColor: AppTheme.Colors.error
                ) {
                    performDislikeAction()
                }
                
                // Share Button with Pulse Effect
                VideoMetaActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    hasSpecialEffect: true
                ) {
                    performShareAction()
                }
                
                // Save Button
                VideoMetaActionButton(
                    icon: isWatchLater ? "bookmark.fill" : "bookmark",
                    title: "Save",
                    isActive: isWatchLater,
                    activeColor: AppTheme.Colors.accent ?? AppTheme.Colors.primary
                ) {
                    performSaveAction()
                }
                
                // Download Button (Premium Feature)
                VideoMetaActionButton(
                    icon: "arrow.down.circle",
                    title: "Download",
                    isPremium: true
                ) {
                    performDownloadAction()
                }
                
                // More Options
                VideoMetaActionButton(
                    icon: "ellipsis.circle",
                    title: "More"
                ) {
                    performMoreAction()
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Modern Divider
    private var modernDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.surface.opacity(0.3),
                        AppTheme.Colors.surface.opacity(0.6),
                        AppTheme.Colors.surface.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 20)
            .padding(.top, 24)
    }
    
    // MARK: - Creator Profile Section
    private var creatorProfileSection: some View {
        HStack(spacing: 16) {
            // Creator Avatar with Glow Effect
            AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.surface, AppTheme.Colors.surface.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    )
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
            
            // Creator Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(video.creator.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if video.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                            .font(.system(size: 14))
                            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 2)
                    }
                }
                
                Text("\(formatCount(video.creator.subscriberCount)) subscribers")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Professional Subscribe Button
            Button(action: performSubscribeAction) {
                HStack(spacing: 8) {
                    if !isSubscribed {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Text(isSubscribed ? "Subscribed" : "Subscribe")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSubscribed ? AppTheme.Colors.textSecondary : .white)
                }
                .padding(.horizontal, isSubscribed ? 24 : 20)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if isSubscribed {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(AppTheme.Colors.surface)
                        } else {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(
                                    color: AppTheme.Colors.primary.opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        }
                    }
                )
                .scaleEffect(subscribeButtonScale)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(isSubscribed ? AppTheme.Colors.surface : Color.clear, lineWidth: 1)
                )
            }
            .accessibilityLabel(isSubscribed ? "Unsubscribe from \(video.creator.displayName)" : "Subscribe to \(video.creator.displayName)")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Intelligent Description Section
    private var intelligentDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let previewText = String(video.description.prefix(120))
            let shouldShowMore = video.description.count > 120
            
            Text(expandedDescription ? video.description : previewText + (shouldShowMore ? "..." : ""))
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(expandedDescription ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: expandedDescription)
            
            if shouldShowMore {
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        expandedDescription.toggle()
                    }
                    let selectionFeedback = UISelectionFeedbackGenerator()
                    selectionFeedback.selectionChanged()
                }) {
                    HStack(spacing: 4) {
                        Text(expandedDescription ? "Show less" : "Show more")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Image(systemName: expandedDescription ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .rotationEffect(.degrees(expandedDescription ? 180 : 0))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.vertical, 8)
                }
                .accessibilityLabel(expandedDescription ? "Show less description" : "Show more description")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Smart Tags Section
    private var smartTagsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(video.tags.prefix(8).enumerated()), id: \.offset) { index, tag in
                    SmartTagView(tag: tag, index: index)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
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
    
    private func performDownloadAction() {
        // Handle premium download feature
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
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

// MARK: - Video Meta Action Button Component
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
            VStack(spacing: 8) {
                ZStack {
                    // Background with subtle glow
                    Circle()
                        .fill(isActive ? activeColor.opacity(0.15) : AppTheme.Colors.surface.opacity(0.8))
                        .frame(width: 48, height: 48)
                        .shadow(
                            color: isActive ? activeColor.opacity(0.3) : AppTheme.Colors.surface.opacity(0.2),
                            radius: isActive ? 8 : 4,
                            x: 0,
                            y: 2
                        )
                        .scaleEffect(pulseScale * scale)
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isActive ? activeColor : AppTheme.Colors.textSecondary)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                    
                    // Premium indicator
                    if isPremium {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                    .offset(x: 6, y: -6)
                            }
                            Spacer()
                        }
                    }
                }
                
                // Title
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
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
            pulseScale = 1.05
        }
    }
}

// MARK: - Smart Tag View Component
struct SmartTagView: View {
    let tag: String
    let index: Int
    
    @State private var animationOffset: CGFloat = 50
    @State private var opacity: Double = 0
    
    var body: some View {
        Text("#\(tag)")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppTheme.Colors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.primary.opacity(0.1),
                                AppTheme.Colors.primary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.Colors.primary.opacity(0.2), lineWidth: 1)
                    )
            )
            .offset(x: animationOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1)) {
                    animationOffset = 0
                    opacity = 1
                }
            }
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