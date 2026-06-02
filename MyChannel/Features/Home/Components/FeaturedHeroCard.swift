import SwiftUI

// MARK: - Featured Hero Card
// 🎯 DESIGN REQUIREMENTS:
// ✅ All cards MUST have 16:9 aspect ratio (enforced by parent container)
// ✅ All cards MUST show Play button overlay
// ✅ All cards MUST show category badge (top-left)
// ✅ All cards MUST show duration badge (top-right)
// ✅ All cards MUST show creator name and view count (bottom)
// ✅ All cards MUST show "+" button for Watch Later (bottom-right)
struct FeaturedHeroCard: View {
    let video: Video
    let isCompact: Bool
    let isActive: Bool
    let allowLiveInPreview: Bool
    let onPlay: () -> Void
    let onAddToList: () -> Void

    @State private var isPressed = false
    @State private var isBuffering = false
    @EnvironmentObject private var appState: AppState

    /// Whether this video URL can be played directly by AVPlayer (Firebase Storage, local files, direct MP4s).
    /// YouTube/web URLs cannot — they need the WebView-based VideoLiveThumbnailView instead.
    private var isDirectPlayable: Bool {
        let url = video.videoURL.lowercased()
        guard !url.isEmpty else { return false }
        // Firebase Storage, local file://, or direct .mp4/.m3u8 links
        return url.contains("firebasestorage.googleapis.com")
            || url.hasPrefix("file://")
            || url.hasSuffix(".mp4")
            || url.hasSuffix(".mov")
            || url.hasSuffix(".m3u8")
            || url.contains("alt=media") // Firebase Storage token URLs
    }

    var body: some View {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        GeometryReader { geo in
            ZStack {
                // MARK: Media Layer
                ZStack {
                    // 1) Static poster (always rendered as base layer)
                    posterImage

                    // 2) Video preview — only on the ACTIVE card.
                    //    Only native AVPlayer (direct MP4/HLS/Firebase) previews are
                    //    allowed. YouTube is intentionally NOT previewed here: its
                    //    WKWebView IFrame player renders its own error screen
                    //    ("This video is unavailable. Error code: 152-4") when embedding
                    //    is blocked, which would replace the thumbnail with an error.
                    //    YouTube always stays on the static `posterImage` base layer.
                    if isActive && !isPreview && isDirectPlayable {
                        // Firebase Storage / local file / direct link → native AVPlayer loop
                        MutedLoopVideoPlayer(videoURL: video.videoURL, isActive: isActive)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.35), .clear, Color.black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )

                // Overlayed content
                VStack(spacing: 12) {
                    topBadges
                    Spacer()
                    bottomContent
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
    }

    // MARK: - Poster Image
    @ViewBuilder
    private var posterImage: some View {
        FeaturedHeroPoster(video: video)
    }
    
    // MARK: - Top Badges
    @ViewBuilder
    private var topBadges: some View {
        HStack {
            // Only show the category capsule when it's a real, meaningful category.
            // A video saved as `.other` shows no badge instead of a useless "Other".
            if video.category != .other {
                HStack(spacing: 6) {
                    Image(systemName: video.category.iconName)
                    Text(video.category.displayName)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.35)))
            }

            Spacer()

            Text(video.formattedDuration)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }
    
    // MARK: - Bottom Content
    @ViewBuilder
    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(video.creator.displayName, systemImage: "person.crop.circle.fill")
                    .lineLimit(1)
                Text("·")
                Label(video.formattedViewCount, systemImage: "eye.fill")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))

            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onPlay()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Play")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onAddToList()
                    
                    // Show visual feedback
                    let saved = appState.isVideoInWatchLater(video.id)
                    let message = saved ? "Added to Watch Later" : "Removed from Watch Later"
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowToast"),
                        object: nil,
                        userInfo: ["message": message, "icon": saved ? "checkmark.circle.fill" : "xmark.circle.fill"]
                    )
                }) {
                    let saved = appState.isVideoInWatchLater(video.id)
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                        Image(systemName: saved ? "checkmark" : "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(saved ? AppTheme.Colors.primary : .black)
                    }
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Watch later")
                .accessibilityHint("Add or remove from your Watch Later")
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}

// MARK: - Featured Hero Poster (Reusable)
// 🎯 CRITICAL: Uses .scaledToFill() to ensure video fills the 16:9 container
// This prevents letterboxing or pillarboxing regardless of source aspect ratio
struct FeaturedHeroPoster: View {
    let video: Video
    
    var body: some View {
        if video.id == "shot_by_keonta_intro" || video.id == FeaturedStore.ownerIntroVideoId {
            Image("ShotByKeontaThumbnail")
                .resizable()
                .scaledToFill() // ✅ Fills 16:9 container
        } else if video.thumbnailURL.hasPrefix("asset://"),
                  let assetName = video.thumbnailURL.split(separator: "/").last.map(String.init),
                  !assetName.isEmpty {
            Image(assetName)
                .resizable()
                .scaledToFill() // ✅ Fills 16:9 container
        } else {
            MultiSourceAsyncImage(
                urls: video.posterCandidates,
                content: { image in
                    image
                        .resizable()
                        .scaledToFill() // ✅ Fills 16:9 container
                },
                placeholder: {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                }
            )
        }
    }
}
