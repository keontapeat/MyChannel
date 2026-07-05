//
//  PlaylistDetailView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import PhotosUI
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var playlistVideos: [Video] = []
    @State private var isLoading = false
    @State private var pickingThumb = false
    @State private var selectedImage: UIImage? = nil
    #if canImport(FirebaseStorage)
    @State private var uploadTask: StorageUploadTask? = nil
    #endif
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Playlist Header
                playlistHeaderSection
                
                // Videos List
                videosListSection
            }
            .padding()
        }
        .navigationTitle(playlist.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Playlist") {
                        showingEditSheet = true
                    }
                    Button("Change Thumbnail") { pickingThumb = true }
                    
                    Button("Share Playlist") {
                        let shareURL = URL(string: "https://mychannel.live/playlists/\(playlist.id)")!
                        let activityVC = UIActivityViewController(activityItems: [shareURL], applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(activityVC, animated: true)
                        }
                    }
                    
                    Divider()
                    
                    Button("Delete Playlist", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPlaylistView(playlist: playlist)
        }
        .photosPicker(isPresented: $pickingThumb, selection: .constant(nil), matching: .images, photoLibrary: .shared())
        .onChange(of: pickingThumb) { _ in }
        .alert("Delete Playlist", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePlaylist()
            }
        } message: {
            Text("Are you sure you want to delete '\(playlist.title)'? This action cannot be undone.")
        }
        .task {
            await loadPlaylistVideos()
        }
    }
    
    private var playlistHeaderSection: some View {
        VStack(spacing: 16) {
            // Thumbnail
            AsyncImage(url: URL(string: playlist.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        VStack {
                            Image(systemName: playlist.category.iconName)
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("\(playlist.videoCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                        }
                    )
            }
            .frame(height: 200)
            .cornerRadius(12)
            
            // Playlist Info
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(playlist.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if !playlist.isPublic {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: playlist.category.iconName)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // Stats
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("\(playlist.videoCount)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Videos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(formatTotalDuration())
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(playlist.createdAt.formatted(.dateTime.month().day()))
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Created")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Tags
                if !playlist.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(playlist.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.horizontal, -16)
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: playAll) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Play All")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: shufflePlay) {
                        HStack {
                            Image(systemName: "shuffle")
                            Text("Shuffle")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button(action: downloadPlaylist) {
                        Image(systemName: "arrow.down.circle")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    // MARK: - Thumbnail Upload
    private func uploadThumbnail(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let path = "playlist-thumbs/\(playlist.id).jpg"
        #if canImport(FirebaseStorage)
        let ref = Storage.storage().reference().child(path)
        do {
            let _ = try await ref.putDataAsync(data, metadata: { let md = StorageMetadata(); md.contentType = "image/jpeg"; return md }())
            let url = try await ref.downloadURL()
            try await PlaylistFirestoreService.shared.setThumbnailURL(playlistId: playlist.id, url: url.absoluteString)
        } catch {
            print("thumbnail upload error: \(error)")
        }
        #endif
    }
    
    private var videosListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Videos (\(playlistVideos.count))")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Add Videos") { }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading videos...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if playlistVideos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Videos in Playlist")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Add some videos to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Add Videos") {
                        // Navigate to search so user can find and add videos
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToSearchTab"), object: nil)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(playlistVideos.enumerated()), id: \.element.id) { index, video in
                        PlaylistVideoRow(
                            video: video,
                            index: index + 1,
                            onPlay: { playVideo(video) },
                            onRemove: { removeVideo(video) }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Actions
    private func loadPlaylistVideos() async {
        isLoading = true; defer { isLoading = false }
        let ids = (try? await PlaylistFirestoreService.shared.getPlaylistVideoIds(playlistId: playlist.id)) ?? []
        guard !ids.isEmpty else { playlistVideos = []; return }
        do {
            playlistVideos = try await VideoFirestoreService.shared.fetchMultipleVideos(videoIds: ids)
        } catch {
            print("⚠️ [PlaylistDetail] Failed to fetch videos: \(error.localizedDescription)")
            playlistVideos = []
        }
    }
    
    private func playAll() {
        guard let firstVideo = playlistVideos.first else { return }
        playVideo(firstVideo)
    }
    
    private func shufflePlay() {
        let shuffledVideos = playlistVideos.shuffled()
        guard let firstVideo = shuffledVideos.first else { return }
        playVideo(firstVideo)
    }
    
    private func playVideo(_ video: Video) {
        GlobalVideoPlayerManager.shared.playVideo(video, showFullscreen: true)
    }
    
    private func removeVideo(_ video: Video) {
        Task { try? await PlaylistFirestoreService.shared.removeVideo(playlistId: playlist.id, videoId: video.id); await loadPlaylistVideos() }
    }
    
    private func deletePlaylist() {
        Task { try? await PlaylistFirestoreService.shared.deletePlaylist(id: playlist.id); await MainActor.run { dismiss() } }
    }
    
    private func downloadPlaylist() {
        // Queue each video for offline download via the canonical OfflineDownloadService.
        Task { @MainActor in
            for video in playlistVideos {
                guard !OfflineDownloadService.shared.hasDownload(videoId: video.id) else { continue }
                _ = try? await OfflineDownloadService.shared.downloadVideo(video)
            }
        }
    }
    
    private func formatTotalDuration() -> String {
        let totalSeconds = playlistVideos.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Playlist Video Row
struct PlaylistVideoRow: View {
    let video: Video
    let index: Int
    let onPlay: () -> Void
    let onRemove: () -> Void
    
    @State private var showingActionSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Index
            Text("\(index)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            // Thumbnail
            Button(action: onPlay) {
                ZStack {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                    }
                    .frame(width: 80, height: 45)
                    .cornerRadius(6)
                    
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            .buttonStyle(.plain)
            
            // Video Info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(video.creator.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(video.formattedViewCount) views")
                    Text("•")
                    Text(video.formattedDuration)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions
            Button(action: { showingActionSheet = true }) {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .confirmationDialog("Video Options", isPresented: $showingActionSheet) {
            Button("Play", action: onPlay)
            Button("Play Next") { /* TODO */ }
            Button("Add to Queue") { /* TODO */ }
            Button("Share") { /* TODO */ }
            Button("Remove from Playlist", role: .destructive, action: onRemove)
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Edit Playlist View
struct EditPlaylistView: View {
    let playlist: Playlist
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var selectedCategory: PlaylistCategory
    @State private var isPublic: Bool
    @State private var tags: String
    
    init(playlist: Playlist) {
        self.playlist = playlist
        
        _title = State(initialValue: playlist.title)
        _description = State(initialValue: playlist.description)
        _selectedCategory = State(initialValue: playlist.category)
        _isPublic = State(initialValue: playlist.isPublic)
        _tags = State(initialValue: playlist.tags.joined(separator: ", "))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Playlist Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PlaylistCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    
                    Toggle("Public Playlist", isOn: $isPublic)
                }
                
                Section("Tags") {
                    TextField("Tags (comma separated)", text: $tags)
                }
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { saveChanges() }.disabled(title.isEmpty) }
            }
        }
    }
    
    private func saveChanges() {
        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        Task {
            try? await PlaylistFirestoreService.shared.updatePlaylist(id: playlist.id, title: title, description: description, category: selectedCategory, visibility: isPublic ? "public" : "private", tags: tagArray)
            await MainActor.run { dismiss() }
        }
    }
}

#Preview {
    NavigationStack {
        PlaylistDetailView(
            playlist: Playlist.samplePlaylists[0]
        )
    }
}