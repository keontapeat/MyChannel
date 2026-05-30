import SwiftUI

// MARK: - 🔥 Premium Pinned Section
struct PremiumPinnedSection: View {
    let videos: [Video]
    let userId: String
    var onUnpin: ((String) -> Void)? = nil
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Premium Header
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .rotationEffect(.degrees(-45))
                
                Text("Pinned")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text("•")
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                Text("\(videos.count) video\(videos.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Full-width centered pinned videos
            VStack(spacing: 16) {
                ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                    PremiumPinnedVideoCard(video: video, userId: userId, onUnpin: onUnpin)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                            value: appeared
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onAppear {
            HapticManager.shared.impact(style: .light)
            withAnimation { appeared = true }
        }
    }
}

// MARK: - 🔥 Premium Pinned Video Card
struct PremiumPinnedVideoCard: View {
    let video: Video
    let userId: String
    var onUnpin: ((String) -> Void)? = nil
    @EnvironmentObject private var appState: AppState
    @State private var isPressed = false
    @State private var showOptions = false
    @State private var isSubscribedLocal = false
    @State private var isWatchLaterLocal = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Premium Thumbnail with Pin Badge - Full width
            ZStack(alignment: .topLeading) {
                // Thumbnail: use bundled asset for Shot By Keonta intro so it always shows
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        Group {
                            if video.id == "shot_by_keonta_intro" || video.id == "owner_intro_video" ||
                                video.thumbnailURL.contains("ShotByKeonta") {
                                Image("ShotByKeontaThumbnail")
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                PinnedCardThumb(urls: video.posterCandidates)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary.opacity(0.5), AppTheme.Colors.primary.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .aspectRatio(16/9, contentMode: .fit) // Full width 16:9 ratio
                
                // Duration Badge
                Text(video.formattedDuration)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.85))
                    .cornerRadius(6)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                
                // Pin Badge
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("PINNED")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 4, y: 2)
                )
                .padding(12)
            }
            
            // Video Info - Full width
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    ReactiveViewCountText(videoId: video.id, initialCount: video.viewCount)
                    Text("views")
                    Text("•")
                    Text(video.uploadTimeAgo)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .medium)
            GlobalVideoPlayerManager.shared.playVideo(video, showFullscreen: true)
            NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            isPressed = pressing
            if pressing { HapticManager.shared.impact(style: .light) }
        }) {
            HapticManager.shared.impact(style: .medium)
            isSubscribedLocal = appState.isSubscribedTo(video.creator.id)
            isWatchLaterLocal = appState.isVideoInWatchLater(video.id)
            showOptions = true
        }
        .contextMenu {
            Button(role: .destructive) {
                HapticManager.shared.impact(style: .medium)
                PinnedVideosStore.shared.unpin(video.id, for: userId)
                onUnpin?(video.id)
            } label: {
                Label("Unpin from profile", systemImage: "pin.slash")
            }
            
            Button {
                HapticManager.shared.impact(style: .light)
                appState.toggleWatchLater(for: video.id)
            } label: {
                Label(
                    appState.isVideoInWatchLater(video.id) ? "Remove from Watch Later" : "Add to Watch Later",
                    systemImage: appState.isVideoInWatchLater(video.id) ? "bookmark.slash" : "bookmark"
                )
            }
            
            Button {
                HapticManager.shared.impact(style: .light)
                // Share action
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $showOptions) {
            VideoMoreOptionsSheet(
                video: video,
                isSubscribed: $isSubscribedLocal,
                isWatchLater: $isWatchLaterLocal,
                ownerId: userId
            )
        }
        .accessibilityLabel("Pinned video: \(video.title)")
    }
}

// MARK: - Legacy Carousel (Deprecated)
struct PinnedVideosCarousel: View {
    let videos: [Video]
    let userId: String
    var body: some View {
        PremiumPinnedSection(videos: videos, userId: userId)
    }
}

// MARK: - Reactive View Count Component
struct ReactiveViewCountText: View {
    let videoId: String
    let initialCount: Int
    @State private var viewCount: Int
    
    init(videoId: String, initialCount: Int) {
        self.videoId = videoId
        self.initialCount = initialCount
        _viewCount = State(initialValue: initialCount)
    }
    
    var body: some View {
        Text(formatViewCount(viewCount))
            .task {
                // 🔥 FIX: Load latest count from Firestore immediately
                let latestCount = await RealtimeViewTracker.shared.getViewCount(for: videoId)
                await MainActor.run {
                    viewCount = latestCount
                    print("📊 [ReactiveViewCount] Loaded count for \(videoId): \(latestCount)")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VideoViewCountUpdated"))) { notification in
                if let userInfo = notification.userInfo,
                   let notificationVideoId = userInfo["videoId"] as? String,
                   notificationVideoId == videoId,
                   let count = userInfo["viewCount"] as? Int {
                    viewCount = count
                    print("📊 [ReactiveViewCount] Updated count for \(videoId): \(count)")
                }
            }
    }
    
    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return String(count)
        }
    }
}

// MARK: - Premium Empty Videos State
struct PremiumEmptyVideosState: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text("Your catalog is empty")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Start building your legacy — upload your first video.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                HapticManager.shared.impact(style: .medium)
                NotificationCenter.default.post(name: NSNotification.Name("ShowUpload"), object: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Upload Your First Video")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .scaleEffect(pulse ? 1.03 : 1.0)
                .shadow(color: AppTheme.Colors.primary.opacity(0.35), radius: pulse ? 12 : 6, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
