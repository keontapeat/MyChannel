//
//  ThermonuclearFeaturedManager.swift
//  MyChannel
//
//  🔥💥😤 THERMONUCLEAR FEATURED VIDEO MANAGER
//  Makes adding/removing featured videos EASY AS F***!
//  Swipe left to delete, tap + to add. That's it.
//

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

struct ThermonuclearFeaturedManager: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = FeaturedManager()
    @State private var showingVideoSelector = false
    @State private var searchText = ""
    @State private var allVideos: [Video] = []
    @State private var isLoadingVideos = false
    @State private var showAllVideos = false
    
    // Camera Roll upload state
    @State private var showingCameraRollPicker = false
    @State private var cameraRollPickerItem: PhotosPickerItem?
    @State private var showingUploadSheet = false
    @State private var pendingUploadURL: URL?
    @State private var pendingUploadThumbnail: UIImage?
    @State private var pendingUploadDuration: TimeInterval = 0
    @StateObject private var cameraRollUploader = CameraRollFeaturedUploader()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 🔥 HEADER
                    thermonuclearHeader
                    
                    // 📊 STATS
                    statsBar
                    
                    // ⭐ FEATURED VIDEOS LIST
                    if manager.isLoading {
                        loadingView
                    } else if manager.featuredVideos.isEmpty {
                        emptyStateView
                    } else {
                        featuredVideosList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
            }
            .sheet(isPresented: $showingVideoSelector) {
                videoSelectorSheet
            }
            .photosPicker(
                isPresented: $showingCameraRollPicker,
                selection: $cameraRollPickerItem,
                matching: .videos,
                photoLibrary: .shared()
            )
            .sheet(isPresented: $showingUploadSheet) {
                if let url = pendingUploadURL {
                    CameraRollUploadSheet(
                        videoURL: url,
                        thumbnail: pendingUploadThumbnail,
                        duration: pendingUploadDuration,
                        uploader: cameraRollUploader
                    ) { video in
                        Task { await manager.addFeaturedVideo(video) }
                        showingUploadSheet = false
                        pendingUploadURL = nil
                        pendingUploadThumbnail = nil
                    } onCancel: {
                        showingUploadSheet = false
                        pendingUploadURL = nil
                        pendingUploadThumbnail = nil
                    }
                }
            }
            .onChange(of: cameraRollPickerItem) { item in
                guard let item else { return }
                Task { await loadCameraRollVideo(item: item) }
            }
            .task {
                await manager.loadFeaturedVideos()
            }
            .alert("Error", isPresented: .constant(manager.errorMessage != nil)) {
                Button("OK") {
                    manager.errorMessage = nil
                }
            } message: {
                if let error = manager.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Header
    private var thermonuclearHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Featured Videos")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Pin up to 20 videos on your Home feed")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Text("Viewers see these first. Keep them fresh with your best content.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator).opacity(0.5))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Stats Bar
    private var statsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                statCard(
                    title: "FEATURED",
                    value: "\(manager.featuredVideos.count)/20",
                    subtitle: "Live on Home",
                    icon: "star.fill"
                )
                
                statCard(
                    title: "SLOTS OPEN",
                    value: "\(max(0, 20 - manager.featuredVideos.count))",
                    subtitle: "Ready to pin",
                    icon: "plus.circle"
                )
                
                statCard(
                    title: "VIEWS",
                    value: manager.totalViews,
                    subtitle: "From featured reel",
                    icon: "eye.fill"
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func statCard(title: String, value: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(width: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Featured Videos List (DRAG TO REORDER! 🔥)
    private var featuredVideosList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(manager.featuredVideos) { video in
                    FeaturedVideoRow(
                        video: video,
                        position: (manager.featuredVideos.firstIndex(where: { $0.id == video.id }) ?? 0) + 1,
                        total: manager.featuredVideos.count
                    ) {
                        await manager.removeFeaturedVideo(video)
                    } onMove: { from, to in
                        await manager.reorderVideos(from: from, to: to)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: manager.featuredVideos)
        }
    }
    
    // MARK: - Add Button
    private var addButton: some View {
        Menu {
            Button {
                showingVideoSelector = true
            } label: {
                Label("Add from my videos", systemImage: "play.rectangle")
            }
            Button {
                showingCameraRollPicker = true
            } label: {
                Label("Upload from Camera Roll", systemImage: "photo.on.rectangle.angled")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Add")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(manager.canAddMore ? .primary : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemGray5))
            )
        }
        .disabled(!manager.canAddMore)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Featured Videos")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Pin videos to the top of Home so every viewer sees them first.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            HStack(spacing: 12) {
                Button {
                    showingVideoSelector = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("My Videos")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.label))
                    )
                }
                Button {
                    showingCameraRollPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Camera Roll")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(.systemGray5))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading featured videos...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Video Selector Sheet
    private var videoSelectorSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search + scope toggle
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField(showAllVideos ? "Search all videos..." : "Search your videos...", text: $searchText)
                            .font(.system(size: 15, weight: .regular))
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Picker("Source", selection: $showAllVideos) {
                        Text("My Videos").tag(false)
                        Text("All Videos").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(.separator).opacity(0.5))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
                
                // Videos list
                if isLoadingVideos {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredVideos.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.secondary)
                        Text("No videos found")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredVideos) { video in
                                SelectableVideoRow(video: video, isSelected: manager.isVideoFeatured(video)) {
                                    await addVideo(video)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(showAllVideos ? "All Videos" : "My Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingVideoSelector = false
                    }
                }
            }
            .task(id: showAllVideos) {
                await loadUserVideos()
            }
        }
    }
    
    private var filteredVideos: [Video] {
        if searchText.isEmpty {
            return allVideos
        }
        return allVideos.filter { video in
            video.title.localizedCaseInsensitiveContains(searchText) ||
            video.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadUserVideos() async {
        isLoadingVideos = true
        defer { isLoadingVideos = false }
        allVideos = []
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            var query = db.collection("videos")
                .order(by: "viewCount", descending: true)
                .limit(to: 200)
            
            if !showAllVideos {
                query = db.collection("videos")
                    .whereField("creatorId", isEqualTo: AuthenticationManager.shared.currentUser?.id ?? "")
                    .order(by: "createdAt", descending: true)
                    .limit(to: 100)
            }
            
            let snapshot = try await query.getDocuments()
            allVideos = snapshot.documents.compactMap { doc in
                try? doc.data(as: Video.self)
            }
        } catch {
            print("❌ Error loading videos: \(error)")
        }
        #endif
    }
    
    private func addVideo(_ video: Video) async {
        await manager.addFeaturedVideo(video)
        showingVideoSelector = false
    }
    
    // MARK: - Camera Roll Load
    private func loadCameraRollVideo(item: PhotosPickerItem) async {
        do {
            guard let movie = try await item.loadTransferable(type: CameraRollMovie.self) else { return }
            let url = movie.url
            
            // Read duration + generate thumbnail
            let asset = AVAsset(url: url)
            let duration = try await asset.load(.duration)
            let durationSecs = CMTimeGetSeconds(duration)
            
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 360)
            let thumbTime = CMTime(seconds: min(1.0, durationSecs * 0.1), preferredTimescale: 600)
            var thumbnail: UIImage?
            if let cgImg = try? await generator.image(at: thumbTime).image {
                thumbnail = UIImage(cgImage: cgImg)
            }
            
            await MainActor.run {
                self.pendingUploadURL = url
                self.pendingUploadThumbnail = thumbnail
                self.pendingUploadDuration = durationSecs
                self.cameraRollPickerItem = nil
                self.showingUploadSheet = true
            }
        } catch {
            print("❌ [CameraRoll] Failed to load video: \(error)")
        }
    }
}

// MARK: - Transferable wrapper for PHPickerItem → URL
struct CameraRollMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return CameraRollMovie(url: dest)
        }
    }
}

// MARK: - Featured Video Row (SWIPE TO DELETE! 🔥)
struct FeaturedVideoRow: View {
    let video: Video
    let position: Int
    let total: Int
    let onRemove: () async -> Void
    let onMove: (Int, Int) async -> Void
    
    @State private var isPressed = false
    @State private var isRemoving = false
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background (revealed on swipe)
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Remove")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.9))
            )
            
            // Main content
            HStack(spacing: 12) {
                // Position badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.Colors.surface.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 1)
                        )
                    
                    Text("\(position)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                // Thumbnail with drag indicator
                ZStack(alignment: .topTrailing) {
                    Group {
                        if video.thumbnailURL.hasPrefix("asset://"),
                           let assetName = video.thumbnailURL.split(separator: "/").last.map(String.init),
                           !assetName.isEmpty {
                            Image(assetName)
                                .resizable()
                                .scaledToFill()
                        } else if !video.thumbnailURL.isEmpty, let url = URL(string: video.thumbnailURL) {
                            AppAsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color(.systemGray5)
                            }
                        } else {
                            Color(.systemGray5)
                                .overlay(
                                    Image(systemName: "play.rectangle")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    // Drag handle
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        .padding(4)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text(video.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 8) {
                        Label(video.formattedViewCount, systemImage: "eye.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("•")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text(video.formattedDuration)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Quick remove button
                Button {
                    isRemoving = true
                    Task {
                        await onRemove()
                        isRemoving = false
                    }
                } label: {
                    if isRemoving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .disabled(isRemoving)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 1)
                    )
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        // Only allow left swipe
                        if translation < 0 {
                            offset = translation
                            isSwiping = true
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        
                        // If swiped far enough, trigger delete
                        if translation < -100 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = -80
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                        }
                        
                        isSwiping = false
                    }
            )
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Selectable Video Row
struct SelectableVideoRow: View {
    let video: Video
    let isSelected: Bool
    let onSelect: () async -> Void
    
    @State private var isSelecting = false
    
    var body: some View {
        Button {
            guard !isSelected else { return }
            isSelecting = true
            Task {
                await onSelect()
                isSelecting = false
            }
        } label: {
            HStack(spacing: 12) {
                // Thumbnail — handles asset:// and remote URLs
                Group {
                    if video.thumbnailURL.hasPrefix("asset://"),
                       let assetName = video.thumbnailURL.split(separator: "/").last.map(String.init),
                       !assetName.isEmpty {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                    } else if !video.thumbnailURL.isEmpty, let url = URL(string: video.thumbnailURL) {
                        AppAsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color(.systemGray5)
                        }
                    } else {
                        Color(.systemGray5)
                            .overlay(
                                Image(systemName: "play.rectangle")
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label(video.formattedViewCount, systemImage: "eye.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(video.formattedDuration)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                } else if isSelecting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(.systemGray6) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(.separator) : Color(.separator).opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .disabled(isSelected || isSelecting)
    }
}

// MARK: - Featured Manager
@MainActor
class FeaturedManager: ObservableObject {
    @Published var featuredVideos: [Video] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let maxFeatured = 20
    
    var canAddMore: Bool {
        featuredVideos.count < maxFeatured
    }
    
    var totalViews: String {
        let total = featuredVideos.reduce(0) { $0 + $1.viewCount }
        return formatViews(total)
    }
    
    func loadFeaturedVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("featured_videos")
                .order(by: "priority", descending: false)
                .limit(to: maxFeatured)
                .getDocuments()
            
            // Load video details from Firestore
            var videos: [Video] = []
            for doc in snapshot.documents {
                if let videoId = doc.data()["videoId"] as? String {
                    if let video = try? await loadVideo(videoId: videoId) {
                        videos.append(video)
                    }
                }
            }
            
            let isOwner = [AuthenticationManager.shared.currentUser?.email, AppState.shared.currentUser?.email]
                .compactMap { $0?.lowercased() }
                .contains { $0 == "keontapeat@mychannel.live" || $0 == "keontapeat@gmail.com" }
            if isOwner, let intro = FeaturedStore.ownerIntroVideo() {
                let withoutIntro = videos.filter { $0.id != FeaturedStore.ownerIntroVideoId }
                featuredVideos = Array([intro] + withoutIntro).prefix(maxFeatured).map { $0 }
            } else {
                featuredVideos = videos
            }
        } catch {
            errorMessage = "Failed to load featured videos: \(error.localizedDescription)"
            print("❌ Error loading featured videos: \(error)")
        }
        #endif
    }
    
    func addFeaturedVideo(_ video: Video) async {
        guard canAddMore else {
            errorMessage = "Maximum 20 featured videos allowed"
            return
        }
        
        guard !isVideoFeatured(video) else {
            errorMessage = "Video is already featured"
            return
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let docRef = db.collection("featured_videos").document(UUID().uuidString)
            
            try await docRef.setData([
                "videoId": video.id,
                "priority": featuredVideos.count,
                "addedAt": FieldValue.serverTimestamp(),
                "addedBy": AuthenticationManager.shared.currentUser?.id ?? ""
            ])
            
            // Add to local array
            featuredVideos.append(video)
            
            print("✅ Added featured video: \(video.title)")
        } catch {
            errorMessage = "Failed to add video: \(error.localizedDescription)"
            print("❌ Error adding featured video: \(error)")
        }
        #endif
    }
    
    func removeFeaturedVideo(_ video: Video) async {
        // Owner intro is bundled and not in Firestore; only remove from local list (reappears on next load)
        if video.id == FeaturedStore.ownerIntroVideoId {
            featuredVideos.removeAll { $0.id == video.id }
            return
        }
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            
            // Find and delete the document
            let snapshot = try await db.collection("featured_videos")
                .whereField("videoId", isEqualTo: video.id)
                .getDocuments()
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
            
            // Remove from local array
            featuredVideos.removeAll { $0.id == video.id }
            
            // Update priorities
            await updatePriorities()
            
            print("✅ Removed featured video: \(video.title)")
        } catch {
            errorMessage = "Failed to remove video: \(error.localizedDescription)"
            print("❌ Error removing featured video: \(error)")
        }
        #endif
    }
    
    func isVideoFeatured(_ video: Video) -> Bool {
        featuredVideos.contains { $0.id == video.id }
    }
    
    func reorderVideos(from: Int, to: Int) async {
        guard from != to else { return }
        
        // Reorder local array
        var videos = featuredVideos
        let video = videos.remove(at: from)
        videos.insert(video, at: to)
        featuredVideos = videos
        
        // Update priorities in Firestore
        await updatePriorities()
        
        print("✅ Reordered videos: \(from) → \(to)")
    }
    
    private func updatePriorities() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        for (index, video) in featuredVideos.enumerated() {
            let snapshot = try? await db.collection("featured_videos")
                .whereField("videoId", isEqualTo: video.id)
                .getDocuments()
            
            if let doc = snapshot?.documents.first {
                try? await doc.reference.updateData(["priority": index])
            }
        }
        #endif
    }
    
    private func loadVideo(videoId: String) async throws -> Video? {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let doc = try await db.collection("videos").document(videoId).getDocument()
        return try? doc.data(as: Video.self)
        #else
        return nil
        #endif
    }
    
    private func formatViews(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Preview
#Preview {
    ThermonuclearFeaturedManager()
        .environmentObject(AppState.shared)
}

