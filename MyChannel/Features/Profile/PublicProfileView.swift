import SwiftUI
import FirebaseFirestore

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
    @State private var showingReportUserSheet: Bool = false
    @State private var showingBlockUserAlert: Bool = false
    @State private var showingReportAlert: Bool = false
    @State private var selectedReportReason: String = "spam"

    @State private var userVideos: [Video] = []
    @State private var watchHistory: [Video] = []
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedHighlight: StoryHighlight?

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
                    showingSettings: $showingSettings,
                    showingReportUserSheet: $showingReportUserSheet,
                    showingBlockUserAlert: $showingBlockUserAlert
                )

                StoryHighlightsTray(creatorId: editableUser.id) { highlight in
                    selectedHighlight = highlight
                }
                
                // Profile Tabs - Scrollable
                ProfileTabNavigation(
                    selectedTab: $selectedTab,
                    user: editableUser,
                    scrollOffset: scrollOffset
                )
                
                // Profile Content
                SafeProfileContentView(
                    selectedTab: $selectedTab,
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
                NavigationStack {
                    EditProfileView(user: $editableUser)
                }
                .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showingSettings) {
            if isCurrentUserProfile {
                SafeProfileSettingsView()
                    .environmentObject(appState)
            }
        }
        .sheet(item: $selectedHighlight) { highlight in
            StoryHighlightViewer(highlight: highlight)
        }
        .confirmationDialog("Report User", isPresented: $showingReportUserSheet, titleVisibility: .visible) {
            Button("Spam or misleading") { selectedReportReason = "spam"; showingReportAlert = true }
            Button("Abusive or harmful content") { selectedReportReason = "abusive"; showingReportAlert = true }
            Button("Inappropriate profile") { selectedReportReason = "inappropriate"; showingReportAlert = true }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Report this user?", isPresented: $showingReportAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Report", role: .destructive) { Task { await reportUser() } }
        } message: {
            Text("This will send a report to our moderation team for review.")
        }
        .alert("Block \(user.displayName)?", isPresented: $showingBlockUserAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) { Task { await blockUser() } }
        } message: {
            Text("You will no longer see content from this user, and they won't be able to interact with you.")
        }
        .onAppear { Task { await load() } }
    }

    private func load() async {
        // 🔥 FIX: Refresh complete profile from Firestore (passed-in user may be stale feed-card data)
        if let freshUser = try? await UserFirestoreService.shared.fetchUser(id: user.id) {
            await MainActor.run { editableUser = freshUser }
        }
        
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
        // 🔥 FIX: Use editableUser (has fresh Firestore data) not original user param
        let base = editableUser
        editableUser = base.updating(
            videoCount: videos.count,
            totalViews: videos.reduce(0) { $0 + $1.viewCount }
        )
    }

    // MARK: - Moderation Actions
    private func reportUser() async {
        guard let currentUserId = AuthenticationManager.shared.currentUser?.id else {
            await MainActor.run { NotificationManager.shared.showError("Sign in to submit a report.") }
            return
        }

        do {
            _ = try await ContentReportService.submit(
                type: .user,
                contentId: user.id,
                contentCreatorId: user.id,
                reporterId: currentUserId,
                reason: selectedReportReason
            )
            await MainActor.run {
                NotificationManager.shared.showSuccess("User reported to moderation.")
            }
        } catch {
            await MainActor.run { NotificationManager.shared.showError(error.localizedDescription) }
        }
    }
    
    private func blockUser() async {
        guard let currentUserId = AuthenticationManager.shared.currentUser?.id else { return }
        let db = Firestore.firestore()
        let blockedUserId = user.id
        
        let blockData: [String: Any] = [
            "blockerId": currentUserId,
            "blockedUserId": blockedUserId,
            "blockedUserDisplayName": user.displayName,
            "blockedUserUsername": user.username,
            "reason": "user_initiated_profile_block",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("users").document(currentUserId)
                .collection("blockedUsers").document(blockedUserId)
                .setData(blockData)
            
            // Send local notification so feeds can filter out this user's videos
            NotificationCenter.default.post(
                name: NSNotification.Name("UserBlocked"),
                object: nil,
                userInfo: ["blockedUserId": blockedUserId]
            )
            
            await MainActor.run {
                NotificationManager.shared.showSuccess("@\(user.username) has been blocked.")
                dismiss() // Return to feed
            }
        } catch {
            print("Failed to block user: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        PublicProfileView(user: User.sampleUsers.first!, prefetchedVideos: Array(Video.sampleVideos.prefix(6)))
    }
}


