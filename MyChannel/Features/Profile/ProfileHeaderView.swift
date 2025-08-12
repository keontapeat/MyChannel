import SwiftUI

struct ProfileHeaderView: View {
    let user: User
    let scrollOffset: CGFloat
    @Binding var isFollowing: Bool
    @Binding var showingEditProfile: Bool
    @Binding var showingSettings: Bool
    
    @EnvironmentObject private var appState: AppState

    private let headerHeight: CGFloat = 365
    private let profileImageSize: CGFloat = 80
    
    private var isCurrentUserProfile: Bool {
        return appState.currentUser?.id == user.id
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack {
                    // Prefer video banner if available
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
                            fallbackBanner()
                        }
                    } else {
                        fallbackBanner()
                    }

                    LinearGradient(
                        colors: [Color.black.opacity(0.2), Color.black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .ignoresSafeArea(.all)

            VStack {
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
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
            }
            
            VStack {
                Spacer()
                profileInfoSection
                Spacer()
                    .frame(height: 40)
            }
        }
        // Keep original placement (no parallax offset) so header does not shift unexpectedly.
    }
    
    // MARK: - Profile Info Section
    private var profileInfoSection: some View {
        VStack(spacing: 16) {
            // Profile Image
            profileImageView
            
            // User name and verification
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .padding(.horizontal, 20)
                }
            }
            
            // Stats Row
            HStack(spacing: 32) {
                StatItem(value: formatCount(user.subscriberCount), label: "Subscribers")
                StatItem(value: formatCount(user.videoCount), label: "Videos")
                
                if let totalViews = user.totalViews {
                    StatItem(value: formatCount(totalViews), label: "Views")
                }
            }
            
            // Action Buttons Row - THE BUTTONS YOU WANT! 🎯
            actionButtonsRow
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Profile Image View
    private var profileImageView: some View {
        ZStack {
            if let profileImageURL = user.profileImageURL {
                CachedAsyncImage(url: URL(string: profileImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        )
                }
            } else {
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .overlay(
                        Text(String(user.displayName.prefix(1)))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: profileImageSize, height: profileImageSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 4))
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Action Buttons Row 🚀
    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            if isCurrentUserProfile {
                // Edit Profile Button - This will show for YOUR profile
                Button(action: {
                    showingEditProfile = true
                    HapticManager.shared.impact(style: .light)
                }) {
                    Text("Edit Profile")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                }
            } else {
                // Follow Button Only - This shows for other people's profiles
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
                        .background(isFollowing ? .white : AppTheme.Colors.primary)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Simplified Fallback Banner
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
    
    // MARK: - Helper Functions
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

// MARK: - Lightweight video banner background
import AVFoundation
private struct ProfileVideoBackground: View {
    let url: URL
    var isMuted: Bool = true
    var contentMode: BannerContentMode = .fill
    @State private var player: AVPlayer = AVPlayer()
    @State private var isReady = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        FlicksPlayerLayerView(player: player, videoGravity: contentMode == .fill ? .resizeAspectFill : .resizeAspect)
            .onAppear { setup() }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active: if isReady { player.play() }
                case .inactive, .background: player.pause()
                @unknown default: break
                }
            }
            .onDisappear { player.pause() }
            .allowsHitTesting(false)
            .clipped()
    }
    
    private func setup() {
        let item = AVPlayerItem(url: url)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
            // loop
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

#Preview {
    ZStack {
        Color.black
        
        ProfileHeaderView(
            user: User.sampleUsers[0],
            scrollOffset: 0,
            isFollowing: .constant(false),
            showingEditProfile: .constant(false),
            showingSettings: .constant(false)
        )
        .environmentObject({
            let appState = AppState()
            appState.currentUser = User.sampleUsers[0] // Set current user for preview
            return appState
        }())
    }
    .ignoresSafeArea()
}