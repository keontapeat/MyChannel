import SwiftUI

// MARK: - PublicProfileView
// Presents any user's channel using the same layout as your own ProfileView.
struct PublicProfileView: View {
    let user: User
    var prefetchedVideos: [Video] = []

    @EnvironmentObject private var appState: AppState
    @State private var editableUser: User
    @State private var selectedTab: ProfileTab = .videos
    @State private var isFollowing: Bool = false
    @State private var showingEditProfile: Bool = false
    @State private var showingSettings: Bool = false

    @State private var userVideos: [Video] = []
    @State private var watchHistory: [Video] = []
    @State private var scrollOffset: CGFloat = 0

    init(user: User, prefetchedVideos: [Video] = []) {
        self.user = user
        self.prefetchedVideos = prefetchedVideos
        _editableUser = State(initialValue: user)
    }

    private var isCurrentUserProfile: Bool {
        if let appUser = appState.currentUser, appUser.id == user.id { return true }
        return false
    }

    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // ⚡ YOUTUBE-STYLE: Always show content immediately (no loading state)
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Profile Header
                ProfileHeaderView(
                    user: editableUser,
                    scrollOffset: scrollOffset,
                    isFollowing: $isFollowing,
                    showingEditProfile: $showingEditProfile,
                    showingSettings: $showingSettings
                )
                
                // Profile Tabs - Scrollable
                ProfileTabNavigation(
                    selectedTab: $selectedTab,
                    user: editableUser,
                    scrollOffset: scrollOffset
                )
                
                // Profile Content
                SafeProfileContentView(
                    selectedTab: selectedTab,
                    user: editableUser,
                    videos: userVideos
                )
            }
            .ignoresSafeArea(edges: .top)
            
            // Custom Back Button (overlaid on top)
            VStack {
                HStack {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(.black.opacity(0.6)))
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 50)
                    
                    Spacer()
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditProfile) {
            if isCurrentUserProfile {
                EditProfileView(user: $editableUser)
                    .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showingSettings) {
            if isCurrentUserProfile {
                SafeProfileSettingsView()
                    .environmentObject(appState)
            }
        }
        .onAppear { Task { await load() } }
    }

    private func load() async {
        // ⚡ YOUTUBE-STYLE: Show prefetched videos immediately if available
        if !prefetchedVideos.isEmpty {
            await MainActor.run {
                self.userVideos = prefetchedVideos
                updateUserVideoCount(prefetchedVideos)
            }
            return
        }
        
        // 🔥 LOAD ONLY REAL VIDEOS: Get actual videos from Firestore in background
        let firestoreVids = await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: user.id)
        if !firestoreVids.isEmpty {
            await MainActor.run {
                self.userVideos = firestoreVids
                updateUserVideoCount(firestoreVids)
            }
            return
        }
        
        // Fallback to local cached videos only (real videos that were cached)
        if let vids = try? await DatabaseService.shared.fetchVideosByCreator(creatorId: user.id), !vids.isEmpty {
            await MainActor.run {
                self.userVideos = vids
                updateUserVideoCount(vids)
            }
            return
        }
        
        // Only use API as last resort if videos actually belong to this creator
        do {
            let resp = try await VideoAPIService.shared.getHomeFeed(page: 1, limit: 48)
            let mapped: [Video] = resp.videos.compactMap { s in
                guard s.creator.id == user.id else { return nil }
                return Video(
                    id: s.id,
                    title: s.title,
                    description: s.description ?? "",
                    thumbnailURL: s.thumbnailUrl ?? "",
                    videoURL: "",
                    duration: TimeInterval(s.duration ?? 0),
                    viewCount: s.viewCount,
                    likeCount: s.likeCount,
                    creator: user,
                    category: .entertainment
                )
            }
            await MainActor.run {
                self.userVideos = mapped
                updateUserVideoCount(mapped)
            }
        } catch {
            await MainActor.run {
                self.userVideos = [] // NO MOCK DATA - empty if no videos
                updateUserVideoCount([])
            }
        }
    }
    
    // 🔥 Update user video count to match ACTUAL videos displayed
    private func updateUserVideoCount(_ videos: [Video]) {
        let actualVideoCount = videos.count
        let totalViews = videos.reduce(0) { $0 + $1.viewCount }
        
        editableUser = User(
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            email: user.email,
            profileImageURL: user.profileImageURL,
            bannerImageURL: user.bannerImageURL,
            bio: user.bio,
            subscriberCount: user.subscriberCount,
            videoCount: actualVideoCount, // 🔥 EXACT COUNT - matches videos.count
            isVerified: user.isVerified,
            isCreator: user.isCreator,
            createdAt: user.createdAt,
            location: user.location,
            website: user.website,
            showWebsiteOnProfile: user.showWebsiteOnProfile,
            socialLinks: user.socialLinks,
            followerCount: user.followerCount,
            followingCount: user.followingCount,
            joinDate: user.joinDate,
            totalViews: totalViews, // 🔥 REAL TOTAL VIEWS from actual videos
            totalEarnings: user.totalEarnings,
            membershipTiers: user.membershipTiers,
            bannerVideoURL: user.bannerVideoURL,
            bannerVideoMuted: user.bannerVideoMuted,
            bannerVideoContentMode: user.bannerVideoContentMode
        )
    }
}

#Preview {
    NavigationStack {
        PublicProfileView(user: User.sampleUsers.first!, prefetchedVideos: Array(Video.sampleVideos.prefix(6)))
    }
}


