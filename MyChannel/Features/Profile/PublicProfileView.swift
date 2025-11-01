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
    @State private var isLoading: Bool = true

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
        Group {
            if isLoading {
                ProfileLoadingSkeleton()
            } else {
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
            }
        }
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
        await MainActor.run {
            if !prefetchedVideos.isEmpty {
                self.userVideos = prefetchedVideos
                self.isLoading = false
                return
            }
        }
        // Try Firestore first, then local cache, then API summaries
        let firestoreVids = await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: user.id)
        if !firestoreVids.isEmpty {
            await MainActor.run {
                self.userVideos = firestoreVids
                self.isLoading = false
            }
            return
        }
        
        // Fallback to local cached videos
        if let vids = try? await DatabaseService.shared.fetchVideosByCreator(creatorId: user.id), !vids.isEmpty {
            await MainActor.run {
                self.userVideos = vids
                self.isLoading = false
            }
            return
        }
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
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }
}

#Preview {
    NavigationStack {
        PublicProfileView(user: User.sampleUsers.first!, prefetchedVideos: Array(Video.sampleVideos.prefix(6)))
    }
}


