import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum VideoReportReason: String, CaseIterable, Identifiable {
    case spam = "spam"
    case nudity = "nudity"
    case violence = "violence"
    case harassment = "harassment"
    case hate = "hate"
    case misinformation = "misinformation"
    case copyright = "copyright"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: return "Spam or Misleading"
        case .nudity: return "Nudity or Sexual Content"
        case .violence: return "Violence or Dangerous Content"
        case .harassment: return "Harassment or Bullying"
        case .hate: return "Hate Speech"
        case .misinformation: return "False Information"
        case .copyright: return "Copyright Violation"
        case .other: return "Something Else"
        }
    }
}

struct VideoMoreOptionsSheet: View {
    let video: Video
    @Binding var isSubscribed: Bool
    @Binding var isWatchLater: Bool
    var ownerId: String? = nil
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showReportAlert = false
    @State private var showBlockAlert = false
    @State private var showDeleteAlert = false
    @State private var showCopyToast = false
    @State private var showShareSheet = false
    @State private var showAddToPlaylist = false
    @State private var showRequestFeature = false
    @State private var selectedReportReason: VideoReportReason = .spam
    @State private var showReportReasonPicker = false
    @State private var isPinnedLocal: Bool = false
    
    private var isOwner: Bool {
        authManager.currentUser?.id == video.creator.id
    }
    
    private var resolvedOwnerId: String? {
        ownerId ?? (isOwner ? authManager.currentUser?.id : nil)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Video: \(video.title)", systemImage: "film")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(action: {
                        showShareSheet = true
                        feedback()
                    }) {
                        HStack { Label("Share", systemImage: "square.and.arrow.up"); Spacer() }
                    }
                    
                    Button(action: { showAddToPlaylist = true; feedback() }) {
                        HStack { Label("Save to playlist", systemImage: "text.badge.plus"); Spacer() }
                    }

                    Button(action: {
                        isWatchLater.toggle()
                        feedback()
                    }) {
                        HStack {
                            Label(
                                isWatchLater ? "Remove from Watch Later" : "Save to Watch Later",
                                systemImage: isWatchLater ? "bookmark.fill" : "bookmark"
                            )
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        isSubscribed.toggle()
                        feedback()
                    }) {
                        HStack {
                            Label(
                                isSubscribed ? "Unsubscribe" : "Subscribe",
                                systemImage: isSubscribed ? "bell.slash.fill" : "bell.fill"
                            )
                            Spacer()
                        }
                    }
                    
                    // Feature Video Option (for all users)
                    Button(action: {
                        showRequestFeature = true
                        feedback()
                    }) {
                        HStack {
                            Label("Feature Video", systemImage: "star.fill")
                            Spacer()
                            Text("$$")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Owner-specific actions
                if isOwner {
                    Section("Your Video") {
                        if let uid = resolvedOwnerId {
                            Button(action: {
                                if isPinnedLocal {
                                    PinnedVideosStore.shared.unpin(video.id, for: uid)
                                } else {
                                    PinnedVideosStore.shared.pin(video.id, for: uid)
                                }
                                isPinnedLocal.toggle()
                                feedback()
                            }) {
                                HStack {
                                    Label(
                                        isPinnedLocal ? "Unpin from Profile" : "Pin to Profile",
                                        systemImage: isPinnedLocal ? "pin.slash" : "pin.fill"
                                    )
                                    Spacer()
                                }
                            }
                        }
                        
                        Button(action: {
                            NotificationCenter.default.post(name: Notification.Name("OpenVideoEditor"), object: video)
                            dismiss()
                            feedback()
                        }) {
                            HStack { 
                                Label("Edit Video", systemImage: "pencil")
                                Spacer() 
                            }
                        }
                        
                        Button(action: {
                            NotificationCenter.default.post(name: Notification.Name("OpenVideoAnalytics"), object: video)
                            dismiss()
                            feedback()
                        }) {
                            HStack { 
                                Label("View Analytics", systemImage: "chart.line.uptrend.xyaxis")
                                Spacer() 
                            }
                        }
                        
                        Button(role: .destructive, action: {
                            showDeleteAlert = true
                            feedback()
                        }) {
                            Label("Delete Video", systemImage: "trash.fill")
                        }
                    }
                }
                
                Section {
                    if !isOwner {
                        Button(role: .destructive) {
                            showReportReasonPicker = true
                            feedback()
                        } label: {
                            Label("Report", systemImage: "flag.fill")
                        }
                        
                        Button(role: .destructive) {
                            showBlockAlert = true
                            feedback()
                        } label: {
                            Label("Block @\(video.creator.username)", systemImage: "hand.raised.fill")
                        }
                    }
                    
                    Button(action: {
                        UIPasteboard.general.string = "https://mychannel.app/watch/\(video.id)"
                        showCopyToast = true
                        feedback()
                    }) {
                        Label("Copy Video Link", systemImage: "link")
                    }
                }
            }
            .onAppear {
                if let uid = resolvedOwnerId {
                    isPinnedLocal = PinnedVideosStore.shared.isPinned(video.id, for: uid)
                }
            }
            .navigationTitle("More Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Report Video", isPresented: $showReportReasonPicker, titleVisibility: .visible) {
                ForEach(VideoReportReason.allCases) { reason in
                    Button(reason.title) {
                        selectedReportReason = reason
                        showReportAlert = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Why are you reporting this video?")
            }
            .alert("Report this video?", isPresented: $showReportAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Report", role: .destructive) { Task { await reportVideo(reason: selectedReportReason) } }
            } message: {
                Text(selectedReportReason.title)
            }
            .alert("Block \(video.creator.displayName)?", isPresented: $showBlockAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Block", role: .destructive) { Task { await blockUser() } }
            } message: {
                Text("They won't be able to comment on your videos or see your content. Their content will be removed from your feed immediately.")
            }
            .alert("Delete this video?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { 
                    Task { await deleteVideo() }
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone. The video will be permanently deleted.")
            }
            .overlay(
                Group {
                    if showCopyToast {
                        ToastView(text: "Link copied!")
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onAppear {
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    withAnimation {
                                        showCopyToast = false
                                    }
                                }
                            }
                    }
                },
                alignment: .bottom
            )
        }
        .presentationDetents([.medium])
        .sheet(isPresented: $showShareSheet) {
            VideoShareSheet(items: [URL(string: video.link) as Any].compactMap { $0 })
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(videoId: video.id)
        }
        .fullScreenCover(isPresented: $showRequestFeature) {
            RequestFeaturedVideoView(video: video)
        }
    }
    
    // 🔥 PREMIUM: Enhanced haptic feedback
    func feedback() {
        HapticManager.shared.impact(style: .light)
    }
    
    func successFeedback() {
        HapticManager.shared.notification(type: .success)
    }
    
    private func deleteVideo() async {
        // 🔥 FIX: Delete from Firestore first (was missing — video kept reappearing)
        try? await VideoFirestoreService.shared.deleteVideo(videoId: video.id)
        try? await DatabaseService.shared.deleteVideo(id: video.id)
        // Also unpin and remove from cache
        if let uid = resolvedOwnerId {
            PinnedVideosStore.shared.unpin(video.id, for: uid)
        }
        ProfileCacheService.shared.removeVideoFromCache(video.id)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Video deleted successfully")
    }
    
    private func reportVideo(reason: VideoReportReason = .spam) async {
        guard let reporterId = AuthenticationManager.shared.currentUser?.id else { return }
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let reportData: [String: Any] = [
            "type": "video",
            "contentId": video.id,
            "contentCreatorId": video.creator.id,
            "reporterId": reporterId,
            "reason": reason.rawValue,
            "reasonTitle": reason.title,
            "status": "pending",
            "reviewed": false,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try? await db.collection("content_reports").addDocument(data: reportData)
        #endif
        await MainActor.run {
            NotificationManager.shared.showSuccess("Report submitted. Thank you for keeping MyChannel safe.")
        }
    }
    
    private func blockUser() async {
        guard let currentUserId = AuthenticationManager.shared.currentUser?.id else { return }
        let blockedUserId = video.creator.id
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let blockData: [String: Any] = [
            "blockerId": currentUserId,
            "blockedUserId": blockedUserId,
            "blockedUserDisplayName": video.creator.displayName,
            "blockedUserUsername": video.creator.username,
            "reason": "user_initiated_block",
            "createdAt": FieldValue.serverTimestamp()
        ]
        try? await db.collection("users").document(currentUserId)
            .collection("blockedUsers").document(blockedUserId)
            .setData(blockData)
        let reportData: [String: Any] = [
            "type": "block",
            "reporterId": currentUserId,
            "blockedUserId": blockedUserId,
            "status": "actioned",
            "createdAt": FieldValue.serverTimestamp()
        ]
        try? await db.collection("content_reports").addDocument(data: reportData)
        #endif
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("UserBlocked"),
                object: nil,
                userInfo: ["blockedUserId": blockedUserId]
            )
            NotificationManager.shared.showSuccess("@\(video.creator.username) has been blocked.")
            dismiss()
        }
    }
}

// MARK: - Add To Playlist Sheet
struct AddToPlaylistSheet: View {
    let videoId: String
    @StateObject private var playlistService = PlaylistFirestoreService.shared
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var playlists: [Playlist] = []
    @State private var showingCreate = false
    @State private var newTitle: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Your Playlists") {
                    ForEach(playlists) { p in
                        Button(action: { add(videoId, to: p.id) }) {
                            HStack {
                                Image(systemName: p.category.iconName)
                                Text(p.title)
                                Spacer()
                                Text("\(p.videoCount)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Save to playlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("New") { showingCreate = true } }
            }
            .task { await loadPlaylists() }
            .alert("New playlist", isPresented: $showingCreate) {
                TextField("Title", text: $newTitle)
                Button("Create") { Task { await createPlaylist() } }
                Button("Cancel", role: .cancel) { newTitle = "" }
            }
        }
    }
    
    private func add(_ videoId: String, to playlistId: String) {
        guard !isLoading else { return }
        isLoading = true
        Task {
            try? await playlistService.addVideoToPlaylist(videoId: videoId, playlistId: playlistId)
            isLoading = false
            dismiss()
        }
    }
    
    private func loadPlaylists() async {
        guard let uid = appState.currentUser?.id else { return }
        if let items = try? await playlistService.getPlaylists(for: uid) { playlists = items }
    }
    
    private func createPlaylist() async {
        guard let uid = appState.currentUser?.id, !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if let id = try? await playlistService.createPlaylist(userId: uid, title: newTitle.trimmingCharacters(in: .whitespaces)) {
            newTitle = ""; showingCreate = false
            await loadPlaylists()
            await add(videoId, to: id)
        }
    }
}

#Preview {
    VideoMoreOptionsSheet(
        video: Video.sampleVideos[0],
        isSubscribed: .constant(false),
        isWatchLater: .constant(false)
    )
}

