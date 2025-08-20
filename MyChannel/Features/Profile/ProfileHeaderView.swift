import SwiftUI
import AVFoundation

struct ProfileHeaderView: View {
    let user: User
    let scrollOffset: CGFloat
    @Binding var isFollowing: Bool
    @Binding var showingEditProfile: Bool
    @Binding var showingSettings: Bool

    @EnvironmentObject private var appState: AppState

    private let headerHeight: CGFloat = 410
    private let baseAvatarSize: CGFloat = 80
    private let minAvatarSize: CGFloat = 52
    private let collapseThreshold: CGFloat = 160

    private var isCurrentUserProfile: Bool {
        appState.currentUser?.id == user.id
    }

    private var collapseProgress: CGFloat {
        let p = min(max((-scrollOffset) / collapseThreshold, 0), 1)
        return p
    }

    private var currentAvatarSize: CGFloat {
        baseAvatarSize - (baseAvatarSize - minAvatarSize) * collapseProgress
    }

    private var parallaxOffset: CGFloat {
        scrollOffset > 0 ? -scrollOffset * 0.35 : 0
    }

    private var stretchAmount: CGFloat {
        max(0, scrollOffset)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background banner with parallax + stretch
            GeometryReader { _ in
                ZStack {
                    if let videoURL = user.bannerVideoURL, let url = URL(string: videoURL) {
                        ProfileVideoBackground(
                            url: url,
                            isMuted: user.bannerVideoMuted ?? true,
                            contentMode: user.bannerVideoContentMode ?? .fill
                        )
                    } else if let bannerURL = user.bannerImageURL {
                        CachedAsyncImage(url: URL(string: bannerURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            defaultBannerView()
                        }
                    } else {
                        defaultBannerView()
                    }

                    LinearGradient(
                        colors: [Color.black.opacity(0.25), Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .offset(y: parallaxOffset)
            }
            .frame(height: headerHeight + stretchAmount)
            .clipped()
            .ignoresSafeArea(.all, edges: .top)

            // Top controls
            HStack {
                Spacer()

                Button {
                    showingSettings = true
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(14)
                        .background(.black.opacity(0.55))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)

            // Main profile info
            VStack(spacing: 16) {
                Spacer()

                ProfileAvatarView(urlString: user.profileImageURL, size: currentAvatarSize)
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.5), radius: 14, x: 0, y: 6)
                    .transition(.scale.combined(with: .opacity))

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                        if user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                    }
                    .opacity(opacityForFactor(0.08))

                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .opacity(opacityForFactor(0.15))

                    if let bio = user.bio {
                        Text(bio)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            .padding(.horizontal, 20)
                            .opacity(opacityForFactor(0.25))
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

                HStack(spacing: 32) {
                    StatItem(value: formatCount(user.subscriberCount), label: "Subscribers")
                    StatItem(value: formatCount(user.videoCount), label: "Videos")
                    StatItem(value: formatCount(user.totalViews ?? estimatedTotalViews(for: user)), label: "Views")
                }
                .opacity(opacityForFactor(0.22))
                .transition(.opacity)

                actionButtonsRow
                    .opacity(opacityForFactor(0.25))
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: headerHeight, alignment: .bottom)
            .frame(maxWidth: .infinity) // ensure perfect centering
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: collapseProgress)

            // Compact sticky bar fades in while scrolling
            CollapsedProfileBar(
                user: user,
                isCurrentUser: isCurrentUserProfile,
                isFollowing: $isFollowing,
                onEdit: {
                    showingEditProfile = true
                    HapticManager.shared.impact(style: .light)
                },
                onFollowToggle: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isFollowing.toggle()
                    }
                    HapticManager.shared.impact(style: .light)
                }
            )
            .padding(.top, 10)
            .opacity(Double(collapseProgress))
        }
    }

    @ViewBuilder
    private func defaultBannerView() -> some View {
        let selected: DefaultProfileBanner = {
            if let saved = getSelectedDefaultBanner(for: user.id) {
                return saved
            }
            if let videoDefault = DefaultProfileBanner.defaults.first(where: { $0.kind == .video }) {
                setSelectedDefaultBannerID(videoDefault.id, for: user.id)
                return videoDefault
            }
            return DefaultProfileBanner.defaults.first!
        }()

        if selected.kind == .video, let url = URL(string: selected.assetURL) {
            ProfileVideoBackground(url: url, isMuted: true, contentMode: .fill)
        } else {
            CachedAsyncImage(url: URL(string: selected.assetURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                fallbackBanner()
            }
        }
    }

    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            if isCurrentUserProfile {
                Button(action: {
                    showingEditProfile = true
                    HapticManager.shared.impact(style: .light)
                }) {
                    Text("Edit Profile")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.95))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                }
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isFollowing.toggle()
                    }
                    HapticManager.shared.impact(style: .medium)
                }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isFollowing ? AppTheme.Colors.textPrimary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isFollowing ? Color.white : AppTheme.Colors.primary)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func fallbackBanner() -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [AppTheme.Colors.primary.opacity(0.8), AppTheme.Colors.secondary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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

    private func estimatedTotalViews(for user: User) -> Int {
        max(user.videoCount * 1_500, user.subscriberCount * 50)
    }

    private func opacityForFactor(_ factor: CGFloat) -> Double {
        let value = max(0, min(1, 1 - factor * collapseProgress))
        return Double(value)
    }
}

// MARK: - Compact Sticky Bar
private struct CollapsedProfileBar: View {
    let user: User
    let isCurrentUser: Bool
    @Binding var isFollowing: Bool
    let onEdit: () -> Void
    let onFollowToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(urlString: user.profileImageURL, size: 28)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

            HStack(spacing: 6) {
                Text(user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if user.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }

            Spacer()

            if isCurrentUser {
                Button("Edit") { onEdit() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.primary, in: Capsule())
            } else {
                Button(isFollowing ? "Following" : "Follow") { onFollowToggle() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isFollowing ? AppTheme.Colors.textPrimary : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isFollowing ? Color.white : AppTheme.Colors.primary, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.Colors.textSecondary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Lightweight video banner background
private struct ProfileVideoBackground: View {
    let url: URL
    var isMuted: Bool = true
    var contentMode: BannerContentMode = .fill
    @State private var player: AVPlayer = AVPlayer()
    @State private var isReady = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var endObserver: NSObjectProtocol?

    private var isInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        FlicksPlayerLayerView(player: player, videoGravity: contentMode == .fill ? .resizeAspectFill : .resizeAspect)
            .onAppear { setupAndPlay() }
            .onChange(of: scenePhase) { _, newPhase in
                guard !isInPreviews else { return }
                switch newPhase {
                case .active:
                    if isReady { player.play() }
                case .inactive, .background:
                    player.pause()
                @unknown default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                if isReady { player.play() }
            }
            .onDisappear {
                player.pause()
                if let token = endObserver {
                    NotificationCenter.default.removeObserver(token)
                    endObserver = nil
                }
            }
            .allowsHitTesting(false)
            .clipped()
    }

    private func setupAndPlay() {
        let item = AVPlayerItem(url: url)
        player.actionAtItemEnd = .none
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            item.seek(to: .zero, completionHandler: nil)
            player.play()
        }
        player.replaceCurrentItem(with: item)
        player.isMuted = isMuted
        player.play()
        isReady = true
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
    }
}

private func bannerKey(for userID: String) -> String { "defaultProfileBanner.\(userID)" }

private func getSelectedDefaultBannerID(for userID: String) -> String? {
    UserDefaults.standard.string(forKey: bannerKey(for: userID))
}

private func setSelectedDefaultBannerID(_ id: String, for userID: String) {
    UserDefaults.standard.set(id, forKey: bannerKey(for: userID))
}

private func getSelectedDefaultBanner(for userID: String) -> DefaultProfileBanner? {
    if let id = getSelectedDefaultBannerID(for: userID) {
        return DefaultProfileBanner.defaults.first(where: { $0.id == id })
    }
    return nil
}

private struct DefaultProfileBanner: Identifiable, Hashable {
    enum Kind { case image, video }
    let id: String
    let title: String
    let subtitle: String
    let kind: Kind
    let assetURL: String
    let previewURL: String?

    static let defaults: [DefaultProfileBanner] = [
        DefaultProfileBanner(
            id: "b1",
            title: "Golden Hour Mountains",
            subtitle: "Warm cinematic tones",
            kind: .image,
            assetURL: "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=1600&q=80",
            previewURL: nil
        ),
        DefaultProfileBanner(
            id: "b2",
            title: "Ocean Sunset",
            subtitle: "Soft gradients and waves",
            kind: .image,
            assetURL: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1600&q=80",
            previewURL: nil
        ),
        DefaultProfileBanner(
            id: "b3",
            title: "City Lights",
            subtitle: "Modern urban vibe",
            kind: .image,
            assetURL: "https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=1600&q=80",
            previewURL: nil
        ),
        DefaultProfileBanner(
            id: "b4",
            title: "Cinematic Nature",
            subtitle: "Subtle motion video",
            kind: .video,
            assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            previewURL: "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1600&q=80"
        ),
        DefaultProfileBanner(
            id: "b5",
            title: "Abstract Flow",
            subtitle: "Minimal gradient waves",
            kind: .image,
            assetURL: "https://images.unsplash.com/photo-154988033865ddcdfd017b?w=1600&q=80",
            previewURL: nil
        ),
        DefaultProfileBanner(
            id: "b6",
            title: "Sintel Trailer",
            subtitle: "Cinematic video banner",
            kind: .video,
            assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            previewURL: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1600&q=80"
        ),
        DefaultProfileBanner(
            id: "b7",
            title: "Joyrides",
            subtitle: "Dynamic city motion",
            kind: .video,
            assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
            previewURL: "https://images.unsplash.com/photo-1493238792000-8113da705763?w=1600&q=80"
        ),
        DefaultProfileBanner(
            id: "b8",
            title: "Escapes",
            subtitle: "Travel cinematic",
            kind: .video,
            assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
            previewURL: "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=1600&q=80"
        ),
        DefaultProfileBanner(
            id: "b9",
            title: "Elephant Dream",
            subtitle: "Moody animation",
            kind: .video,
            assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
            previewURL: "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=1600&q=80"
        )
    ]
}

#Preview("Profile Header") {
    ZStack {
        Color.black

        ProfileHeaderView(
            user: OwnerProfile.owner,
            scrollOffset: 0,
            isFollowing: .constant(false),
            showingEditProfile: .constant(false),
            showingSettings: .constant(false)
        )
        .environmentObject({
            let appState = AppState()
            appState.currentUser = OwnerProfile.owner
            return appState
        }())
    }
    .ignoresSafeArea()
    .preferredColorScheme(.light)
}