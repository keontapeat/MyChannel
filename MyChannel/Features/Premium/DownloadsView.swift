//
//  DownloadsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct DownloadsView: View {
    @StateObject private var premiumService = PremiumService.shared
    @State private var selectedSegment: DownloadSegment = .all
    @State private var sortOrder: DownloadSortOrder = .dateDescending
    @State private var searchText: String = ""
    @State private var isEditing: Bool = false
    @State private var selectedDownloads: Set<String> = []
    @State private var isSelectionMode: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var selectedVideo: Video? = nil
    @State private var showingVideoPlayer: Bool = false
    
    var filteredDownloads: [DownloadedVideo] {
        let filtered: [DownloadedVideo]
        
        switch selectedSegment {
        case .all:
            filtered = premiumService.downloadedVideos
        case .videos:
            filtered = premiumService.downloadedVideos.filter { $0.video.category != .shorts }
        case .shorts:
            filtered = premiumService.downloadedVideos.filter { $0.video.category == .shorts }
        }
        
        let searched = searchText.isEmpty ? filtered : filtered.filter {
            $0.video.title.localizedCaseInsensitiveContains(searchText) ||
            $0.video.creator.displayName.localizedCaseInsensitiveContains(searchText)
        }
        
        return searched.sorted { download1, download2 in
            switch sortOrder {
            case .dateDescending:
                return download1.downloadDate > download2.downloadDate
            case .dateAscending:
                return download1.downloadDate < download2.downloadDate
            case .sizeDescending:
                return download1.fileSize > download2.fileSize
            case .sizeAscending:
                return download1.fileSize < download2.fileSize
            case .titleAscending:
                return download1.video.title < download2.video.title
            case .titleDescending:
                return download1.video.title > download2.video.title
            }
        }
    }
    
    var totalDownloadSize: String {
        let totalBytes = filteredDownloads.reduce(Int64(0)) { (total: Int64, download: DownloadedVideo) -> Int64 in
            // Approximate sizes for each quality
            let bytes: Int64
            switch download.quality {
            case .low: bytes = 50 * 1024 * 1024 // 50MB
            case .medium: bytes = 150 * 1024 * 1024 // 150MB
            case .high: bytes = 300 * 1024 * 1024 // 300MB
            case .ultra: bytes = 1024 * 1024 * 1024 // 1GB
            }
            return total + bytes
        }
        
        return formatBytes(totalBytes)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                if premiumService.downloadedVideos.isEmpty {
                    emptyStateView
                } else {
                    mainContentView
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !premiumService.downloadedVideos.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if isSelectionMode {
                            Button("Cancel") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isSelectionMode = false
                                    selectedDownloads.removeAll()
                                }
                            }
                        } else {
                            editButton
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if isSelectionMode {
                            Button("Select All") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDownloads = Set(filteredDownloads.map { $0.id })
                                }
                            }
                        } else {
                            Menu {
                                ForEach(DownloadSortOrder.allCases, id: \.self) { order in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            sortOrder = order
                                        }
                                    }) {
                                        HStack {
                                            Text(order.displayName)
                                            if sortOrder == order {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                        }
                    }
                }
            }
            .overlay(
                isSelectionMode ? selectionToolbar : nil,
                alignment: .bottom
            )
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .disableAutocorrection(true)
        }
        .fullScreenCover(isPresented: $showingVideoPlayer) {
            if let video = selectedVideo {
                VideoDetailView(video: video)
            }
        }
        .alert("Delete Downloads", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedDownloads()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedDownloads.count) download\(selectedDownloads.count > 1 ? "s" : "")? This cannot be undone.")
        }
    }
    
    private var editButton: some View {
        Button("Edit") {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isSelectionMode = true
            }
        }
        .foregroundColor(AppTheme.Colors.primary)
    }
    
    private var selectionToolbar: some View {
        HStack(spacing: 16) {
            Button(action: {
                showingDeleteAlert = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selectedDownloads.isEmpty ? AppTheme.Colors.textTertiary : .red)
            }
            .disabled(selectedDownloads.isEmpty)
            
            Spacer()
            
            Text("\(selectedDownloads.count) selected")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isSelectionMode = false
                    selectedDownloads.removeAll()
                }
            }) {
                Text("Done")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.textPrimary.opacity(0.1), radius: 10, x: 0, y: -5)
        )
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header with stats
            downloadsHeader
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            // Segmented control
            segmentedControl
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            // Download list
            if filteredDownloads.isEmpty {
                emptySearchState
                    .padding(.top, 60)
            } else {
                downloadsList
            }
            
            Spacer()
        }
    }
    
    private var downloadsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(filteredDownloads.count) item\(filteredDownloads.count == 1 ? "" : "s")")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(totalDownloadSize)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            if isSelectionMode && !selectedDownloads.isEmpty {
                Text("\(selectedDownloads.count) selected")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    private var segmentedControl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DownloadSegment.allCases, id: \.self) { segment in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSegment = segment
                        }
                    }) {
                        Text(segment.title)
                            .font(.system(size: 14, weight: selectedSegment == segment ? .semibold : .medium))
                            .foregroundColor(selectedSegment == segment ? .white : AppTheme.Colors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedSegment == segment ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                    )
                }
            }
            .frame(height: 32)
        }
    }
    
    private var downloadsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredDownloads, id: \.id) { download in
                    DownloadItemView(
                        download: download,
                        isSelected: selectedDownloads.contains(download.id),
                        isSelectionMode: $isSelectionMode,
                        onToggleSelection: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedDownloads.contains(download.id) {
                                    selectedDownloads.remove(download.id)
                                } else {
                                    selectedDownloads.insert(download.id)
                                }
                            }
                        },
                        onDelete: {
                            deleteDownload(download)
                        },
                        onPlay: {
                            selectedVideo = download.video
                            showingVideoPlayer = true
                        }
                    )
                }
            }
            .padding(20)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            VStack(spacing: 12) {
                Text("No Downloads Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Download videos to watch them offline")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            NavigationLink(destination: PremiumSubscriptionView()) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Get MyChannel Premium")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.gradient)
                .cornerRadius(25)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No downloads found")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Try a different search term")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
    
    private func deleteDownload(_ download: DownloadedVideo) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            premiumService.deleteDownload(download)
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    private func deleteSelectedDownloads() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let downloadsToDelete = premiumService.downloadedVideos.filter { selectedDownloads.contains($0.id) }
            downloadsToDelete.forEach { download in
                premiumService.deleteDownload(download)
            }
            
            selectedDownloads.removeAll()
            isSelectionMode = false
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useMB
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Download Item View
struct DownloadItemView: View {
    let download: DownloadedVideo
    let isSelected: Bool
    @Binding var isSelectionMode: Bool
    let onToggleSelection: () -> Void
    let onDelete: () -> Void
    let onPlay: () -> Void
    
    @State private var showingOptions: Bool = false
    @State private var isPressed: Bool = false
    
    var body: some View {
        ZStack {
            // Main content
            Button(action: {
                if isSelectionMode {
                    onToggleSelection()
                } else {
                    onPlay()
                }
            }) {
                HStack(spacing: 12) {
                    // Thumbnail
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: URL(string: download.video.thumbnailURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Rectangle()
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        Image(systemName: "play.rectangle")
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                    )
                            case .empty:
                                Rectangle()
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                            .scaleEffect(0.7)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 120, height: 68)
                        .clipped()
                        .cornerRadius(8)
                        
                        // Duration badge
                        Text(download.video.formattedDuration)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.black.opacity(0.7))
                            )
                            .padding(4)
                    }
                    
                    // Video info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(download.video.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                        
                        HStack(spacing: 6) {
                            AsyncImage(url: URL(string: download.video.creator.profileImageURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(AppTheme.Colors.surface)
                            }
                            .frame(width: 16, height: 16)
                            .clipShape(Circle())
                            
                            Text(download.video.creator.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .lineLimit(1)
                            
                            if download.video.creator.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Label(download.quality.title, systemImage: "square.and.arrow.down")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text(download.fileSize)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text(download.downloadDate, style: .relative)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                    }
                    
                    Spacer()
                    
                    // Selection indicator or options
                    if isSelectionMode {
                        Button(action: onToggleSelection) {
                            ZStack {
                                Circle()
                                    .stroke(AppTheme.Colors.textSecondary, lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                
                                if isSelected {
                                    Circle()
                                        .fill(AppTheme.Colors.primary)
                                        .frame(width: 16, height: 16)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Menu {
                            Button(action: onDelete) {
                                Label("Delete Download", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                            
                            if let shareURL = URL(string: download.video.videoURL) {
                                ShareLink(item: shareURL) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .padding(8)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.cardBackground)
                        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
                
                if !isSelectionMode {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isSelectionMode = true
                        onToggleSelection()
                    }
                }
            }
        }
    }
}

// MARK: - Download Segment
enum DownloadSegment: CaseIterable, Hashable {
    case all
    case videos
    case shorts
    
    var title: String {
        switch self {
        case .all: return "All"
        case .videos: return "Videos"
        case .shorts: return "Shorts"
        }
    }
}

// MARK: - Download Sort Order
enum DownloadSortOrder: CaseIterable, Hashable {
    case dateDescending
    case dateAscending
    case sizeDescending
    case sizeAscending
    case titleAscending
    case titleDescending
    
    var displayName: String {
        switch self {
        case .dateDescending: return "Newest First"
        case .dateAscending: return "Oldest First"
        case .sizeDescending: return "Largest First"
        case .sizeAscending: return "Smallest First"
        case .titleAscending: return "Title A-Z"
        case .titleDescending: return "Title Z-A"
        }
    }
}

#Preview {
    DownloadsView()
}