import SwiftUI

struct VideoMoreOptionsSheet: View {
    let video: Video
    @Binding var isSubscribed: Bool
    @Binding var isWatchLater: Bool
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showReportAlert = false
    @State private var showDeleteAlert = false
    @State private var showCopyToast = false
    @State private var showShareSheet = false
    @State private var showAddToPlaylist = false
    @State private var showRequestFeature = false
    
    private var isOwner: Bool {
        authManager.currentUser?.id == video.creator.id
    }
    
    var body: some View {
        NavigationView {
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
                            showReportAlert = true
                            feedback()
                        } label: {
                            Label("Report", systemImage: "flag.fill")
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
            .navigationTitle("More Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Report this video?", isPresented: $showReportAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Report", role: .destructive) { Task { await reportVideo() } }
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
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
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
            ActivityView(activityItems: [URL(string: video.link) as Any].compactMap { $0 })
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
    
    func warningFeedback() {
        HapticManager.shared.notification(type: .warning)
    }

    private func reportVideo() async {
        guard let url = URL(string: "https://us-central1-" + (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLOUD_PROJECT") as? String ?? "") + ".cloudfunctions.net/report_content") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["type": "video", "id": video.id, "reason": "user_report"]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        // Attach Firebase ID token if available
        if let token = try? await AuthenticationManager.sharedToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        _ = try? await URLSession.shared.data(for: req)
    }
    
    private func deleteVideo() async {
        // Delete from Firestore
        try? await VideoFirestoreService.shared.deleteVideo(videoId: video.id)
        
        // Delete from local database
        try? await DatabaseService.shared.deleteVideo(id: video.id)
        
        // Refresh profile to remove deleted video
        NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
        
        // Show success toast
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Video deleted successfully")
        }
    }
}

// UIKit share sheet wrapper
import UIKit
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
        NavigationView {
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

