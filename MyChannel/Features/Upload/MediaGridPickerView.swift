import SwiftUI
import Photos
import AVFoundation
import AVKit

struct MediaGridPickerView: View {
    enum Mode {
        case video
        case flicks
    }
    
    let mode: Mode
    let title: String
    let onClose: () -> Void
    let onPick: (URL) -> Void
    
    @State private var assets: [PHAsset] = []
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    private let imageManager = PHCachingImageManager()
    private let gridCols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    
    // 🔥 NUCLEAR ENHANCEMENTS
    @State private var selectedAsset: PHAsset?
    @State private var showPreview = false
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .newest
    @State private var filterDuration: DurationFilter = .all
    @State private var showFilters = false
    @State private var multiSelectMode = false
    @State private var selectedAssets: Set<String> = []
    @State private var showBatchActions = false
    
    // Album picker (camera roll folders – like YouTube: Recents → select album)
    @State private var selectedAlbumIdentifier: String? = nil // nil = Recents
    @State private var showAlbumPicker = false
    @State private var albumOptions: [AlbumOption] = []
    
    enum SortOrder: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case longest = "Longest First"
        case shortest = "Shortest First"
    }
    
    enum DurationFilter: String, CaseIterable {
        case all = "All Videos"
        case short = "< 1 min"
        case medium = "1-5 min"
        case long = "> 5 min"
    }
    
    var body: some View {
        ZStack {
            // ✅ YOUTUBE-STYLE: Always dark background for media picker
            Color(red: 15/255, green: 15/255, blue: 15/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                nuclearHeader
                
                if authStatus == .authorized || authStatus == .limited {
                    // 🔥 ALBUM ROW (tap to pick folder like YouTube – Recents, Favorites, Videos, etc.)
                    albumPickerRow
                    
                    // 🔥 VIDEO GRID
                    ScrollView {
                        LazyVGrid(columns: gridCols, spacing: 3) {
                            ForEach(filteredAssets, id: \.localIdentifier) { asset in
                                NuclearGridCell(
                                    asset: asset,
                                    manager: imageManager,
                                    isSelected: multiSelectMode && selectedAssets.contains(asset.localIdentifier),
                                    multiSelectMode: multiSelectMode
                                ) {
                                    if multiSelectMode {
                                        toggleSelection(asset)
                                    } else {
                                        selectedAsset = asset
                                        showPreview = true
                                    }
                                }
                            }
                        }
                        .padding(3)
                        .padding(.bottom, multiSelectMode ? 80 : 12)
                    }
                } else if authStatus == .denied || authStatus == .restricted {
                    nuclearPermissionView
                } else {
                    nuclearLoadingView
                }
            }
            
            // 🔥 BATCH ACTIONS BAR
            if multiSelectMode && !selectedAssets.isEmpty {
                VStack {
                    Spacer()
                    batchActionsBar
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0)
        }
        .sheet(isPresented: $showPreview) {
            if let asset = selectedAsset {
                VideoPreviewSheet(asset: asset, onSelect: {
                    export(asset: asset)
                })
            }
        }
        .sheet(isPresented: $showAlbumPicker) {
            AlbumPickerSheet(
                albums: albumOptions,
                currentIdentifier: selectedAlbumIdentifier,
                onSelect: { identifier in
                    selectedAlbumIdentifier = identifier
                    showAlbumPicker = false
                    loadAssets(from: identifier)
                },
                onDismiss: { showAlbumPicker = false }
            )
        }
        .task {
            guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
            await requestAndLoad()
        }
    }
    
    // 🔥 NUCLEAR HEADER
    private var nuclearHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    if multiSelectMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            multiSelectMode = false
                            selectedAssets.removeAll()
                        }
                    } else {
                        onClose()
                    }
                } label: {
                    Image(systemName: multiSelectMode ? "checkmark" : "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(multiSelectMode ? "Select Videos" : title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    if multiSelectMode && !selectedAssets.isEmpty {
                        Text("\(selectedAssets.count) selected")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // 🔥 MULTI-SELECT TOGGLE
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        multiSelectMode.toggle()
                        if !multiSelectMode {
                            selectedAssets.removeAll()
                        }
                    }
                } label: {
                    Image(systemName: multiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(multiSelectMode ? AppTheme.Colors.primary : .white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(multiSelectMode ? 0.15 : 0.08))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            
            // ✅ YOUTUBE-STYLE: Clean divider
            Rectangle()
                .fill(AppTheme.Colors.divider.opacity(0.3))
                .frame(height: 1)
        }
        .background(Color(red: 25/255, green: 25/255, blue: 25/255))
    }
    
    // 🔥 ALBUM ROW – tap to pick folder (Recents, Favorites, Videos, etc.) like YouTube
    private var albumPickerRow: some View {
        Button {
            HapticManager.shared.impact(style: .light)
            if albumOptions.isEmpty {
                loadAlbums()
            }
            showAlbumPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                Text(selectedAlbumTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var selectedAlbumTitle: String {
        if let id = selectedAlbumIdentifier,
           let opt = albumOptions.first(where: { $0.identifier == id }) {
            return opt.title
        }
        return "Recents"
    }
    
    // 🔥 SEARCH & FILTER BAR (kept for possible future use; not shown in UI)
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search videos...", text: $searchText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)
                    .tint(AppTheme.Colors.primary)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            
            // Filter chips
            if showFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Sort order
                        Menu {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    HStack {
                                        Text(order.rawValue)
                                        if sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(sortOrder.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary.opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .stroke(AppTheme.Colors.primary.opacity(0.4), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Duration filter
                        ForEach(DurationFilter.allCases, id: \.self) { filter in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    filterDuration = filter
                                }
                            } label: {
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(filterDuration == filter ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(filterDuration == filter ? AppTheme.Colors.primary : Color.white.opacity(0.1))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 44)
            }
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
    }
    
    // 🔥 QUICK STATS BAR
    private var quickStatsBar: some View {
        HStack(spacing: 20) {
            statItem(icon: "video.fill", value: "\(filteredAssets.count)", label: "Videos")
            
            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.2))
            
            statItem(icon: "clock.fill", value: totalDurationText, label: "Total")
            
            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.2))
            
            statItem(icon: "arrow.down.circle.fill", value: "\(mode == .flicks ? "60s" : "∞")", label: "Max")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // 🔥 BATCH ACTIONS BAR
    private var batchActionsBar: some View {
        HStack(spacing: 16) {
            Button {
                // Merge selected videos
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Merge")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
            }
            
            Button {
                // Create playlist
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Playlist")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
            }
            
            Button {
                // Upload all
                for assetId in selectedAssets {
                    if let asset = assets.first(where: { $0.localIdentifier == assetId }) {
                        export(asset: asset)
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Upload")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.primary)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.98))
                .shadow(color: .black.opacity(0.3), radius: 20, y: -10)
        )
    }
    
    // 🔥 NUCLEAR PERMISSION VIEW
    private var nuclearPermissionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.surface.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 12) {
                Text("Photos Access Required")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("We need permission to access your photo library to show your videos.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                Button {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                        Task { await requestAndLoad() }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Grant Access")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.Colors.primary)
                            .shadow(color: AppTheme.Colors.primary.opacity(0.5), radius: 20, y: 10)
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding()
    }
    
    // ✅ YOUTUBE-STYLE LOADING VIEW
    private var nuclearLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Loading your videos...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func requestAndLoad() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            let status = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
                    continuation.resume(returning: s)
                }
            }
            await MainActor.run { authStatus = status }
        } else {
            await MainActor.run { authStatus = current }
        }
        guard authStatus == .authorized || authStatus == .limited else { return }
        await MainActor.run { loadAlbums() }
        loadAssets(from: selectedAlbumIdentifier)
    }
    
    // 🔥 FILTERED ASSETS
    private var filteredAssets: [PHAsset] {
        var filtered = assets
        
        // Apply duration filter
        switch filterDuration {
        case .all:
            break
        case .short:
            filtered = filtered.filter { $0.duration < 60 }
        case .medium:
            filtered = filtered.filter { $0.duration >= 60 && $0.duration <= 300 }
        case .long:
            filtered = filtered.filter { $0.duration > 300 }
        }
        
        // Apply search
        if !searchText.isEmpty {
            // Search by creation date or other metadata
            // For now, just return all (PHAsset doesn't have title/description)
        }
        
        // Apply sort
        switch sortOrder {
        case .newest:
            filtered.sort { ($0.creationDate ?? Date()) > ($1.creationDate ?? Date()) }
        case .oldest:
            filtered.sort { ($0.creationDate ?? Date()) < ($1.creationDate ?? Date()) }
        case .longest:
            filtered.sort { $0.duration > $1.duration }
        case .shortest:
            filtered.sort { $0.duration < $1.duration }
        }
        
        return filtered
    }
    
    private var totalDurationText: String {
        let total = filteredAssets.reduce(0.0) { $0 + $1.duration }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func toggleSelection(_ asset: PHAsset) {
        if selectedAssets.contains(asset.localIdentifier) {
            selectedAssets.remove(asset.localIdentifier)
        } else {
            selectedAssets.insert(asset.localIdentifier)
        }
    }
    
    private func loadAssets(from albumIdentifier: String?) {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetch: PHFetchResult<PHAsset>
        if let id = albumIdentifier, !id.isEmpty,
           let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject {
            fetch = PHAsset.fetchAssets(in: collections, options: options)
        } else {
            fetch = PHAsset.fetchAssets(with: .video, options: options)
        }
        
        var list: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in
            if mode == .flicks {
                if asset.duration <= 60.5 { list.append(asset) }
            } else {
                list.append(asset)
            }
        }
        self.assets = list
        preheatThumbnails(for: list)
    }
    
    private func loadAlbums() {
        var optionsList: [AlbumOption] = []
        let videoOptions = PHFetchOptions()
        videoOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        videoOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // Recents (all videos) first
        let allVideos = PHAsset.fetchAssets(with: .video, options: videoOptions)
        var totalCount = 0
        var firstAsset: PHAsset?
        allVideos.enumerateObjects { asset, _, _ in
            if mode == .flicks {
                if asset.duration <= 60.5 { totalCount += 1; if firstAsset == nil { firstAsset = asset } }
            } else {
                totalCount += 1
                if firstAsset == nil { firstAsset = asset }
            }
        }
        optionsList.append(AlbumOption(identifier: nil, title: "Recents", count: totalCount, thumbnailAsset: firstAsset))
        
        // Smart albums (Videos, Favorites, etc.)
        let smart = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        smart.enumerateObjects { collection, _, _ in
            let title = collection.localizedTitle ?? "Album"
            if title.lowercased() == "recents" || title.lowercased() == "all photos" { return }
            let fetchIn = PHAsset.fetchAssets(in: collection, options: videoOptions)
            var count = 0
            var first: PHAsset?
            fetchIn.enumerateObjects { asset, _, _ in
                if mode == .flicks {
                    if asset.duration <= 60.5 { count += 1; if first == nil { first = asset } }
                } else {
                    count += 1
                    if first == nil { first = asset }
                }
            }
            if count > 0 || title.lowercased() == "videos" || title.lowercased() == "favorites" {
                optionsList.append(AlbumOption(identifier: collection.localIdentifier, title: title, count: count, thumbnailAsset: first))
            }
        }
        
        // User albums
        let user = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        user.enumerateObjects { collection, _, _ in
            let fetchIn = PHAsset.fetchAssets(in: collection, options: videoOptions)
            var count = 0
            var first: PHAsset?
            fetchIn.enumerateObjects { asset, _, _ in
                if mode == .flicks {
                    if asset.duration <= 60.5 { count += 1; if first == nil { first = asset } }
                } else {
                    count += 1
                    if first == nil { first = asset }
                }
            }
            if count > 0 {
                optionsList.append(AlbumOption(identifier: collection.localIdentifier, title: collection.localizedTitle ?? "Album", count: count, thumbnailAsset: first))
            }
        }
        
        albumOptions = optionsList
    }
    
    private func preheatThumbnails(for assets: [PHAsset]) {
        let target = CGSize(width: 220, height: 220)
        let requests = assets.map { PHAssetResource.assetResources(for: $0); return $0 }
        imageManager.startCachingImages(for: requests, targetSize: target, contentMode: .aspectFill, options: nil)
    }
    
    private func export(asset: PHAsset) {
        let opts = PHVideoRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        opts.version = .current
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, info in
            guard let avAsset = avAsset else {
                let errorDesc = (info?[PHImageErrorKey] as? Error)?.localizedDescription ?? "Unknown error"
                print("❌ [MediaGridPicker] Failed to load video asset: \(errorDesc)")
                return
            }
            if let urlAsset = avAsset as? AVURLAsset {
                // Copy to temp to avoid sandbox issues with Photos library URLs
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("picked-\(UUID().uuidString).mp4")
                do {
                    try FileManager.default.copyItem(at: urlAsset.url, to: tempURL)
                    Task { @MainActor in onPick(tempURL) }
                } catch {
                    // Fallback: use original URL if copy fails
                    print("⚠️ [MediaGridPicker] Copy failed, using original URL: \(error.localizedDescription)")
                    Task { @MainActor in onPick(urlAsset.url) }
                }
                return
            }
            // Non-URL asset (slow-mo, composition, etc.) — export to temp file
            guard let export = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality) else {
                print("❌ [MediaGridPicker] Cannot create export session")
                return
            }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("picked-\(UUID().uuidString).mp4")
            export.outputURL = tempURL
            export.outputFileType = .mp4
            export.exportAsynchronously {
                Task { @MainActor in
                    switch export.status {
                    case .completed:
                        onPick(tempURL)
                    case .failed:
                        print("❌ [MediaGridPicker] Export failed: \(export.error?.localizedDescription ?? "Unknown")")
                    case .cancelled:
                        print("⚠️ [MediaGridPicker] Export cancelled")
                    default:
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Album picker (camera roll folders)
private struct AlbumOption: Identifiable {
    var id: String { identifier ?? "recents" }
    let identifier: String?
    let title: String
    let count: Int
    let thumbnailAsset: PHAsset?
}

private struct AlbumPickerSheet: View {
    let albums: [AlbumOption]
    let currentIdentifier: String?
    let onSelect: (String?) -> Void
    let onDismiss: () -> Void
    
    private let imageManager = PHCachingImageManager()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(albums) { album in
                    Button {
                        HapticManager.shared.impact(style: .light)
                        onSelect(album.identifier)
                    } label: {
                        HStack(spacing: 14) {
                            AlbumThumbnailView(asset: album.thumbnailAsset, manager: imageManager)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("\(album.count) items")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if (album.identifier == nil && currentIdentifier == nil) || (album.identifier == currentIdentifier) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
}

private struct AlbumThumbnailView: View {
    let asset: PHAsset?
    let manager: PHCachingImageManager
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "video.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(.systemGray3))
                }
            }
        }
        .onAppear {
            guard let asset else { return }
            let size = CGSize(width: 112, height: 112)
            manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: nil) { img, _ in
                Task { @MainActor in image = img }
            }
        }
    }
}

// 🔥 NUCLEAR GRID CELL
private struct NuclearGridCell: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    let isSelected: Bool
    let multiSelectMode: Bool
    let onTap: () -> Void
    
    @State private var image: UIImage? = nil
    @State private var durationText: String = "0:00"
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Thumbnail
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        // ✅ YOUTUBE-STYLE: Clean selection overlay
                        Group {
                            if isSelected {
                                Color.black.opacity(0.3)
                            } else {
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.35)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                        }
                    )
            } else {
                // Loading shimmer
                ZStack {
                    Color.white.opacity(0.08)
                    
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: UUID())
                }
            }
            
            // Selection overlay
            if multiSelectMode {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(isSelected ? AppTheme.Colors.primary : Color.black.opacity(0.5))
                                .frame(width: 28, height: 28)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(8)
                    }
                    Spacer()
                }
            }
            
            // Duration badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text(durationText)
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                    .padding(8)
                }
            }
            
            // Press effect
            if isPressed {
                Color.white.opacity(0.2)
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    isSelected ? AppTheme.Colors.primary : Color.clear,
                    lineWidth: isSelected ? 3 : 0
                )
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .task {
            let size = CGSize(width: 600, height: 600)
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isSynchronous = false
            manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { img, _ in
                if let img { self.image = img }
            }
            
            let seconds = asset.duration
            if seconds > 0 {
                durationText = formatDuration(seconds)
            } else {
                let vopts = PHVideoRequestOptions()
                vopts.deliveryMode = .fastFormat
                vopts.isNetworkAccessAllowed = true
                PHImageManager.default().requestAVAsset(forVideo: asset, options: vopts) { avAsset, _, _ in
                    if let avAsset = avAsset {
                        let totalSeconds = CMTimeGetSeconds(avAsset.duration)
                        let formatted = formatDuration(totalSeconds)
                        Task { @MainActor in durationText = formatted }
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration.rounded())
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

// 🔥 VIDEO PREVIEW SHEET
private struct VideoPreviewSheet: View {
    let asset: PHAsset
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    
                    Spacer()
                    
                    Text("Preview")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        onSelect()
                        dismiss()
                    } label: {
                        Text("Select")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Video player
                if let player {
                    RawPlayerLayerView(player: player, videoGravity: .resizeAspect)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            player.play()
                        }
                } else if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            // Load thumbnail
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1080, height: 1920),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                thumbnail = image
            }
            
            // Load video
            let vopts = PHVideoRequestOptions()
            vopts.deliveryMode = .highQualityFormat
            vopts.isNetworkAccessAllowed = true
            vopts.version = .current
            PHImageManager.default().requestAVAsset(forVideo: asset, options: vopts) { avAsset, _, _ in
                if let avAsset = avAsset {
                    Task { @MainActor in
                        if let urlAsset = avAsset as? AVURLAsset {
                            player = AVPlayer(url: urlAsset.url)
                        } else {
                            // Non-URL asset (slow-mo, etc.) — create player from composition
                            let playerItem = AVPlayerItem(asset: avAsset)
                            player = AVPlayer(playerItem: playerItem)
                        }
                    }
                }
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

#Preview("MediaGridPickerView - Video") {
    MediaGridPickerView(mode: .video, title: "Upload video", onClose: {}, onPick: { _ in })
}