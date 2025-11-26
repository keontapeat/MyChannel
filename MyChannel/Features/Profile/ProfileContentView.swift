//
//  ProfileContentView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

enum VideoBulkAction: CaseIterable {
    case edit
    case visibility
    case playlist
    case download
    case share
    case delete
    
    var title: String {
        switch self {
        case .edit: return "Edit"
        case .visibility: return "Visibility"
        case .playlist: return "Playlist"
        case .download: return "Download"
        case .share: return "Share"
        case .delete: return "Delete"
        }
    }
    
    var icon: String {
        switch self {
        case .edit: return "pencil"
        case .visibility: return "eye"
        case .playlist: return "text.badge.plus"
        case .download: return "arrow.down.circle"
        case .share: return "square.and.arrow.up"
        case .delete: return "trash.fill"
        }
    }
    
    var tint: Color {
        switch self {
        case .edit, .visibility, .playlist, .download, .share:
            return AppTheme.Colors.textPrimary
        case .delete:
            return AppTheme.Colors.error
        }
    }
    
    var isDestructive: Bool {
        self == .delete
    }
}

// MARK: - Video Management Context
struct VideoManagementContext {
    let isManaging: Binding<Bool>
    let selectedIDs: Binding<Set<String>>
    let onToggleSelection: (String) -> Void
    let onSetSelections: ([String]) -> Void
    let onAction: (VideoBulkAction) -> Void
    let onExit: () -> Void
    let isDeleting: Bool
}

// MARK: - Safe Profile Content View
struct SafeProfileContentView: View {
    let selectedTab: ProfileTab
    let user: User
    let videos: [Video]
    var onLoadMore: (() async -> Void)? = nil // ⚡ PERFORMANCE: Pagination callback
    var hasMoreVideos: Bool = false // ⚡ PERFORMANCE: Pagination state
    var isLoadingMore: Bool = false // ⚡ PERFORMANCE: Loading state
    var isOwnProfile: Bool = false
    var videoManagementContext: VideoManagementContext? = nil
    var isLoadingVideos: Bool = false // ⚡ PERFORMANCE: Initial loading state for skeleton
    
    var body: some View {
        SafeViewWrapper {
            ProfileContentView(
                selectedTab: selectedTab,
                user: user,
                videos: videos,
                onLoadMore: onLoadMore,
                hasMoreVideos: hasMoreVideos,
                isLoadingMore: isLoadingMore,
                isOwnProfile: isOwnProfile,
                videoManagementContext: videoManagementContext,
                isLoadingVideos: isLoadingVideos
            )
        } fallback: {
            ProfileContentFallback(selectedTab: selectedTab)
        }
    }
}

// MARK: - Profile Content View
struct ProfileContentView: View {
    let selectedTab: ProfileTab
    let user: User
    let videos: [Video]
    var onLoadMore: (() async -> Void)? = nil // ⚡ PERFORMANCE: Pagination callback
    var hasMoreVideos: Bool = false // ⚡ PERFORMANCE: Pagination state
    var isLoadingMore: Bool = false // ⚡ PERFORMANCE: Loading state
    let isOwnProfile: Bool
    var videoManagementContext: VideoManagementContext? = nil
    var isLoadingVideos: Bool = false // ⚡ PERFORMANCE: Initial loading state for skeleton
    
    var body: some View {
        LazyVStack(spacing: 0) {
            switch selectedTab {
            case .videos:
                ProfileVideosView(
                    videos: videos,
                    user: user,
                    isOwnProfile: isOwnProfile,
                    onLoadMore: onLoadMore,
                    hasMoreVideos: hasMoreVideos,
                    isLoadingMore: isLoadingMore,
                    managementContext: videoManagementContext,
                    isLoadingVideos: isLoadingVideos
                )
            case .shorts:
                ProfileShortsView(videos: videos, user: user)
            case .playlists:
                ProfilePlaylistsView(user: user)
            case .community:
                ProfileCommunityView(user: user)
            case .about:
                ProfileAboutView(user: user)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
    }
}

// MARK: - Profile Videos View
struct ProfileVideosView: View {
    let videos: [Video]
    let user: User
    let isOwnProfile: Bool
    var onLoadMore: (() async -> Void)? = nil // ⚡ PERFORMANCE: Pagination callback
    var hasMoreVideos: Bool = false // ⚡ PERFORMANCE: Pagination state
    var isLoadingMore: Bool = false // ⚡ PERFORMANCE: Loading state
    var managementContext: VideoManagementContext? = nil
    var isLoadingVideos: Bool = false // ⚡ PERFORMANCE: Initial loading state for skeleton
    
    @State private var layoutMode: VideoLayoutMode = .list1
    @State private var sortMode: SortMode = .newest
    @State private var pinnedIds: [String] = []
    @State private var searchText: String = ""
    @State private var visibilityFilter: VideoVisibilityFilter = .all
    @State private var typeFilter: VideoTypeFilter = .all
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    private var isManagementActive: Bool {
        guard isOwnProfile, let managementContext else { return false }
        return managementContext.isManaging.wrappedValue
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if !pinnedVideos.isEmpty {
                PinnedVideosCarousel(videos: pinnedVideos)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                HStack {
                    Text("Pinned")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
            } else if videos.isEmpty && AuthenticationManager.shared.currentUser?.id == user.id {
                // Clean empty state - single placeholder
                VStack(spacing: 20) {
                    // Single empty placeholder banner
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.Colors.surface.opacity(0.5))
                        .frame(height: 180)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text("No featured videos yet")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    // Upload button
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        NotificationCenter.default.post(name: NSNotification.Name("ShowUpload"), object: nil)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Upload your first video")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)
            }
            
            HStack(spacing: 12) {
                Text("Videos")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                if let management = managementContext, isOwnProfile {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            if management.isManaging.wrappedValue {
                                management.onExit()
                            } else {
                                management.isManaging.wrappedValue = true
                            }
                        }
                    } label: {
                        Text(management.isManaging.wrappedValue ? "Done" : "Manage")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(management.isManaging.wrappedValue ? AppTheme.Colors.textPrimary : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(management.isManaging.wrappedValue ? AppTheme.Colors.surface : AppTheme.Colors.primary)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.Colors.divider.opacity(management.isManaging.wrappedValue ? 0.4 : 0), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(management.isManaging.wrappedValue ? "Exit video management" : "Manage videos")
                }
                
                HStack(spacing: 8) {
                    ForEach(VideoLayoutMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                layoutMode = mode
                            }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(layoutMode == mode ? .white : AppTheme.Colors.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(layoutMode == mode ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                                )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                    Menu {
                        Button("Newest") { sortMode = .newest }
                        Button("Popular") { sortMode = .popular }
                        Button("Oldest") { sortMode = .oldest }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(AppTheme.Colors.primary))
                    }
                }
                
                // If you prefer a segmented control instead, uncomment:
                // Picker("", selection: $layoutMode) {
                //     Label("Grid", systemImage: "square.grid.2x2").tag(VideoLayoutMode.grid2)
                //     Label("List", systemImage: "list.bullet").tag(VideoLayoutMode.list1)
                // }
                // .pickerStyle(.segmented)
                // .frame(maxWidth: 220)
            }
            .padding(.horizontal, 16)
            
            VideoFilterBar(
                searchText: $searchText,
                visibilityFilter: $visibilityFilter,
                typeFilter: $typeFilter
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            
            HStack {
                Text("All videos")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            
            if isManagementActive, let management = managementContext {
                let selectedCount = management.selectedIDs.wrappedValue.count
                let totalCount = filteredVideos.count
                VideoManagementToolbar(
                    selectedCount: selectedCount,
                    totalVisibleCount: totalCount,
                    isAllSelected: totalCount > 0 && selectedCount >= totalCount,
                    isDeleting: management.isDeleting,
                    onSelectOrClearAll: {
                        if totalCount > 0 && selectedCount >= totalCount {
                            management.onSetSelections([])
                        } else {
                            management.onSetSelections(filteredVideoIDs)
                        }
                    },
                    onDelete: {
                        management.onAction(.delete)
                    },
                    onAction: { action in
                        management.onAction(action)
                    }
                )
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            videosBody
                .id(layoutMode) // force a rebuild when switching modes
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: layoutMode)
            
            Color.clear.frame(height: 8)
        }
        .padding(.bottom, 12)
        .task { pinnedIds = PinnedVideosStore.shared.getPinned(for: user.id) }
    }
    
    private var filteredVideos: [Video] {
        videos.filter { video in
            matchesSearch(video) && matchesVisibilityFilter(video) && matchesTypeFilter(video)
        }
    }
    
    private var pinnedVideos: [Video] {
        let set = Set(pinnedIds)
        return filteredVideos.filter { set.contains($0.id) }
    }
    
    private var sortedVideos: [Video] {
        switch sortMode {
        case .newest:
            return filteredVideos.sorted { $0.createdAt > $1.createdAt }
        case .popular:
            return filteredVideos.sorted { $0.viewCount > $1.viewCount }
        case .oldest:
            return filteredVideos.sorted { $0.createdAt < $1.createdAt }
        }
    }
    
    private var unpinnedSortedVideos: [Video] {
        let pinnedSet = Set(pinnedVideos.map { $0.id })
        return sortedVideos.filter { !pinnedSet.contains($0.id) }
    }
    
    private var filteredVideoIDs: [String] {
        filteredVideos.map { $0.id }
    }
    
    private func openVideo(_ video: Video) {
        HapticManager.shared.impact(style: .light)
        NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
    }
    
    private func matchesSearch(_ video: Video) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        return video.title.lowercased().contains(query) ||
            video.description.lowercased().contains(query)
    }
    
    private func matchesVisibilityFilter(_ video: Video) -> Bool {
        switch visibilityFilter {
        case .all:
            return true
        case .publicOnly:
            return video.visibility == .public && video.scheduledAt == nil
        case .unlisted:
            return video.visibility == .unlisted
        case .privateOnly:
            return video.visibility == .private
        case .scheduled:
            return video.scheduledAt != nil
        }
    }
    
    private func matchesTypeFilter(_ video: Video) -> Bool {
        switch typeFilter {
        case .all:
            return true
        case .shorts:
            return video.duration <= 60
        case .longForm:
            return video.duration > 60
        case .live:
            return video.isLiveStream
        }
    }
    
    @ViewBuilder
    private var videosBody: some View {
        // ⚡ PERFORMANCE: Show skeleton while loading (only if videos are empty)
        if isLoadingVideos && videos.isEmpty {
            if layoutMode == .grid2 {
                VideosLoadingSkeletonGrid(count: 6)
                    .transition(.opacity)
            } else {
                VideosLoadingSkeletonList(count: 6)
                    .transition(.opacity)
            }
        } else if layoutMode == .grid2 {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(unpinnedSortedVideos.enumerated()), id: \.element.id) { index, video in
                    let isSelected = managementContext?.selectedIDs.wrappedValue.contains(video.id) ?? false
                    ProfileVideoCard(
                        video: video,
                        ownerId: user.id,
                        isInManagementMode: isManagementActive,
                        isSelectedInManagement: isSelected
                    )
                        .id(video.id) // ⚡ PERFORMANCE: Explicit ID for better diffing
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isManagementActive {
                                managementContext?.onToggleSelection(video.id)
                            } else {
                                openVideo(video)
                            }
                        }
                        .onAppear {
                            // 🔥 THERMONUCLEAR: Prefetch when 6 from bottom (was 3)
                            if index >= unpinnedSortedVideos.count - 6 {
                                Task {
                                    if !isLoadingMore {
                                        await onLoadMore?()
                                    }
                                }
                            }
                            
                            // 🔥 THERMONUCLEAR: Prefetch next 12 thumbnails
                            let prefetchRange = (index + 1)..<min(unpinnedSortedVideos.count, index + 13)
                            let urls = prefetchRange.compactMap { URL(string: unpinnedSortedVideos[$0].thumbnailURL) }
                            ImagePrefetcher.shared.prefetch(urls: urls)
                        }
                }
                // ⚡ PERFORMANCE: "Load More" button for pagination
                if hasMoreVideos {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .task {
                            if !isLoadingMore {
                                await onLoadMore?()
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
        } else {
            // Single video view: one full-width 16:9 card per row
            LazyVStack(spacing: 12) {
                ForEach(Array(unpinnedSortedVideos.enumerated()), id: \.element.id) { index, video in
                    let isSelected = managementContext?.selectedIDs.wrappedValue.contains(video.id) ?? false
                    FullWidthVideoCard(
                        video: video,
                        ownerId: user.id,
                        isInManagementMode: isManagementActive,
                        isSelectedInManagement: isSelected,
                        onTapOverride: isManagementActive ? {
                            managementContext?.onToggleSelection(video.id)
                        } : nil
                    )
                        .id(video.id) // ⚡ PERFORMANCE: Explicit ID for better diffing
                        .padding(.horizontal, 16)
                        .onAppear {
                            // 🔥 THERMONUCLEAR: Prefetch when 6 from bottom (was 3)
                            if index >= unpinnedSortedVideos.count - 6 {
                                Task {
                                    if !isLoadingMore {
                                        await onLoadMore?()
                                    }
                                }
                            }
                            
                            // 🔥 THERMONUCLEAR: Prefetch next 12 thumbnails
                            let prefetchRange = (index + 1)..<min(unpinnedSortedVideos.count, index + 13)
                            let urls = prefetchRange.compactMap { URL(string: unpinnedSortedVideos[$0].thumbnailURL) }
                            ImagePrefetcher.shared.prefetch(urls: urls)
                        }
                }
                // ⚡ PERFORMANCE: "Load More" button for pagination
                if hasMoreVideos {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .task {
                            if !isLoadingMore {
                                await onLoadMore?()
                            }
                        }
                }
            }
        }
    }
}

private enum SortMode: String, CaseIterable {
    case newest
    case popular
    case oldest
}

// MARK: - Profile Video Card
struct ProfileVideoCard: View {
    let video: Video
    var ownerId: String? = nil
    var isInManagementMode: Bool = false
    var isSelectedInManagement: Bool = false
    @EnvironmentObject private var appState: AppState
    @State private var showOptions = false
    @State private var isSubscribedLocal = false
    @State private var isWatchLaterLocal = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stable 16:9 container first, then draw image inside it.
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.textTertiary.opacity(0.12))
                    .overlay(
                        thumbnailView()
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .aspectRatio(16/9, contentMode: .fit) // guarantees consistent height
            .overlay(
                Text(video.formattedDuration)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.8))
                    .cornerRadius(4)
                    .padding(6),
                alignment: .bottomTrailing
            )
            .overlay(alignment: .topTrailing) {
                if !isInManagementMode {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        isSubscribedLocal = appState.isSubscribedTo(video.creator.id)
                        isWatchLaterLocal = appState.isVideoInWatchLater(video.id)
                        showOptions = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }
            .overlay(alignment: .topLeading) {
                if isInManagementMode {
                    SelectionBadge(isSelected: isSelectedInManagement)
                        .padding(8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 36, alignment: .topLeading) // keeps rows even
                
                HStack(spacing: 4) {
                    ReactiveViewCountText(videoId: video.id, initialCount: video.viewCount)
                    Text("•")
                    Text(video.uploadTimeAgo)
                }
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(height: 16, alignment: .center) // keeps rows even
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(video.title)
        .contextMenu {
            if let ownerId, ownerId == video.creator.id {
                if PinnedVideosStore.shared.isPinned(video.id, for: ownerId) {
                    Button(role: .destructive) { PinnedVideosStore.shared.unpin(video.id, for: ownerId) } label: { Label("Unpin from top", systemImage: "pin.slash") }
                } else {
                    Button { PinnedVideosStore.shared.pin(video.id, for: ownerId) } label: { Label("Pin to top", systemImage: "pin") }
                }
            }
        }
        .sheet(isPresented: $showOptions) {
            VideoMoreOptionsSheet(
                video: video,
                isSubscribed: $isSubscribedLocal,
                isWatchLater: $isWatchLaterLocal
            )
            .onChange(of: isWatchLaterLocal) { _ in
                appState.toggleWatchLater(for: video.id)
            }
            .onChange(of: isSubscribedLocal) { _ in
                appState.toggleSubscription(for: video.creator.id)
            }
        }
        .drawingGroup() // ⚡ PERFORMANCE: Flatten view hierarchy for smoother scrolling
    }
    
    @ViewBuilder
    private func thumbnailView() -> some View {
        MultiSourceAsyncImage(
            urls: video.posterCandidates,
            content: { image in
                image.resizable().scaledToFill().transition(.opacity.combined(with: .scale))
            },
            placeholder: { placeholder }
        )
        .clipped()
    }
    
    private var placeholder: some View {
        Image(systemName: "photo.on.rectangle.angled")
            .resizable()
            .scaledToFit()
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(24)
    }
}

// MARK: - Profile Shorts View
struct ProfileShortsView: View {
    let videos: [Video]
    let user: User
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ], spacing: 8) {
            ForEach(videos.prefix(12)) { video in
                ProfileShortCard(video: video)
                    .onTapGesture {
                        HapticManager.shared.impact(style: .light)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Short Card
struct ProfileShortCard: View {
    let video: Video
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let url = URL(string: video.thumbnailURL), !video.thumbnailURL.isEmpty {
                    AppAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(9/16, contentMode: .fill)
                            .clipped()
                    } placeholder: { shortPlaceholder }
                } else {
                    shortPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                    
                    ReactiveViewCountText(videoId: video.id, initialCount: video.viewCount)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6))
                .cornerRadius(4)
                .padding(6)
            }
        }
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.1), radius: 3, x: 0, y: 1)
        .contextMenu {
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Label("Save to Watch Later", systemImage: "bookmark")
            }
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .accessibilityLabel("\(video.title) short")
    }
    
    private var shortPlaceholder: some View {
        Rectangle()
            .fill(AppTheme.Colors.textTertiary.opacity(0.3))
            .aspectRatio(9/16, contentMode: .fit)
            .overlay(
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            )
    }
}

// MARK: - Profile Playlists View
struct ProfilePlaylistsView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { index in
                ProfilePlaylistCard(
                    title: "My Playlist \(index + 1)",
                    videoCount: Int.random(in: 5...25),
                    thumbnailURL: "https://picsum.photos/400/300?random=\(index + 10)"
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Playlist Card
struct ProfilePlaylistCard: View {
    let title: String
    let videoCount: Int
    let thumbnailURL: String
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.textTertiary.opacity(0.3))
                    .overlay(
                        Image(systemName: "list.bullet")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    )
            }
            .frame(width: 120, height: 68)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(videoCount) videos")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Spacer()
            }
            
            Spacer()
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Community View
struct ProfileCommunityView: View {
    let user: User
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<5) { index in
                ProfileCommunityPost(
                    author: user,
                    content: "This is a sample community post \(index + 1). Thanks for following my channel!",
                    timestamp: Date().addingTimeInterval(-Double(index * 3600)),
                    likeCount: Int.random(in: 10...500),
                    commentCount: Int.random(in: 2...50)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Community Post
struct ProfileCommunityPost: View {
    let author: User
    let content: String
    let timestamp: Date
    let likeCount: Int
    let commentCount: Int
    
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: author.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.7))
                        .overlay(
                            Text(String(author.displayName.prefix(1)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(author.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        
                        if author.shouldShowVerificationBadge {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.Colors.primary)
                        }
                    }
                    
                    Text(timeAgoString(from: timestamp))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            
            // Content
            Text(content)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
            
            // Actions
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isLiked.toggle()
                    }
                    HapticManager.shared.impact(style: .light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundStyle(isLiked ? .red : AppTheme.Colors.textSecondary)
                        
                        Text("\(likeCount)")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        
                        Text("\(commentCount)")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Profile About View
struct ProfileAboutView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 24) {
            // Channel stats
            ProfileStatsSection(user: user)
            
            // Description
            if let bio = user.bio {
                ProfileDescriptionSection(bio: bio)
            }
            
            // Social links
            if !user.socialLinks.isEmpty {
                ProfileSocialLinksSection(socialLinks: user.socialLinks)
            }
            
            // Additional info
            ProfileAdditionalInfoSection(user: user)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Profile Stats Section
struct ProfileStatsSection: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Channel Statistics")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ProfileStatCard(
                    title: "Subscribers",
                    value: "\(user.subscriberCount.formatted())",
                    icon: "person.2.fill",
                    color: AppTheme.Colors.primary
                )
                
                ProfileStatCard(
                    title: "Videos",
                    value: "\(user.videoCount)",
                    icon: "play.rectangle.fill",
                    color: AppTheme.Colors.secondary
                )
                
                if let totalViews = user.totalViews {
                    ProfileStatCard(
                        title: "Total Views",
                        value: "\(totalViews.formatted())",
                        icon: "eye.fill",
                        color: .green
                    )
                }
                
                ProfileStatCard(
                    title: "Joined",
                    value: user.createdAt.formatted(.dateTime.year().month(.abbreviated)),
                    icon: "calendar.badge.plus",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Stat Card
struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Profile Description Section
struct ProfileDescriptionSection: View {
    let bio: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text(bio)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Social Links Section
struct ProfileSocialLinksSection: View {
    let socialLinks: [SocialLink]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Links")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(socialLinks) { link in
                    ProfileSocialLinkCard(link: link)
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Additional Info Section
struct ProfileAdditionalInfoSection: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            VStack(spacing: 12) {
                if let location = user.location {
                    ProfileInfoRow(icon: "location.fill", title: "Location", value: location)
                }
                
                if let website = user.website {
                    ProfileInfoRow(icon: "globe", title: "Website", value: website)
                }
                
                ProfileInfoRow(
                    icon: "calendar.badge.plus",
                    title: "Joined",
                    value: user.createdAt.formatted(.dateTime.day().month().year())
                )
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Profile Info Row
struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(width: 20, height: 20)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Profile Social Link Card (renamed to avoid conflict with EditProfileView)
struct ProfileSocialLinkCard: View {
    let link: SocialLink
    
    var body: some View {
        Button(action: {
            // Open link
        }) {
            HStack(spacing: 8) {
                Image(systemName: link.platform.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 20, height: 20)
                
                Text(link.platform.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.primary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Content Fallback
struct ProfileContentFallback: View {
    let selectedTab: ProfileTab
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab.iconName)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.textTertiary)
            
            Text("Content Unavailable")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Text("Unable to load \(selectedTab.title.lowercased())")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textTertiary)
        }
        .padding(40)
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

private enum VideoLayoutMode: String, CaseIterable {
    case grid2
    case list1
    
    var icon: String {
        switch self {
        case .grid2: return "square.grid.2x2"
        case .list1: return "list.bullet"
        }
    }
    
    var title: String {
        switch self {
        case .grid2: return "Grid"
        case .list1: return "List"
        }
    }
}

private struct VideoManagementToolbar: View {
    let selectedCount: Int
    let totalVisibleCount: Int
    let isAllSelected: Bool
    let isDeleting: Bool
    let onSelectOrClearAll: () -> Void
    let onDelete: () -> Void
    let onAction: (VideoBulkAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("\(selectedCount) selected")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    onSelectOrClearAll()
                } label: {
                    Text(isAllSelected ? "Clear All" : "Select All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Capsule()
                                        .stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(totalVisibleCount == 0)
                .opacity(totalVisibleCount == 0 ? 0.5 : 1)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(VideoBulkAction.allCases.filter { $0 != .delete }, id: \.self) { action in
                        ProfileBulkActionButton(
                            action: action,
                            isEnabled: selectedCount > 0 && !isDeleting,
                            onTap: {
                                onAction(action)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            
            Button {
                if !isDeleting && selectedCount > 0 {
                    onDelete()
                }
            } label: {
                HStack(spacing: 8) {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "trash.fill")
                        Text("Delete Selected")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedCount == 0 ? Color.red.opacity(0.4) : Color.red)
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0 || isDeleting)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct SelectionBadge: View {
    let isSelected: Bool
    
    var body: some View {
        Circle()
            .strokeBorder(.white.opacity(0.9), lineWidth: 2)
            .background(
                Circle()
                    .fill(isSelected ? AppTheme.Colors.primary : Color.black.opacity(0.45))
            )
            .frame(width: 26, height: 26)
            .overlay(
                Image(systemName: isSelected ? "checkmark" : "circle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 1)
    }
}

private struct ProfileBulkActionButton: View {
    let action: VideoBulkAction
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            guard isEnabled else { return }
            HapticManager.shared.impact(style: .light)
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(action.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(action.isDestructive ? .white : action.tint)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(action.isDestructive
                          ? (isEnabled ? action.tint : action.tint.opacity(0.4))
                          : AppTheme.Colors.backgroundSecondary.opacity(isEnabled ? 1 : 0.7))
            )
            .overlay(
                Capsule()
                    .stroke(action.isDestructive ? Color.clear : AppTheme.Colors.divider.opacity(isEnabled ? 0.5 : 0.2), lineWidth: action.isDestructive ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

private struct StockVideoBannersCarousel: View {
    let banners: [StockVideoBanner]
    @State private var current: Int = 0
    
    var body: some View {
        TabView(selection: $current) {
            ForEach(Array(banners.enumerated()), id: \.offset) { idx, banner in
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: banner.imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.Colors.textTertiary.opacity(0.15))
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(banner.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(banner.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 150)
    }
}

struct VideoFilterBar: View {
    @Binding var searchText: String
    @Binding var visibilityFilter: VideoVisibilityFilter
    @Binding var typeFilter: VideoTypeFilter
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.Colors.textTertiary)
                TextField("Search videos...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.system(size: 15))
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                    )
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VideoVisibilityFilter.allCases, id: \.self) { filter in
                        ProfileFilterChip(
                            title: filter.title,
                            isSelected: visibilityFilter == filter,
                            icon: filter.icon
                        ) {
                            visibilityFilter = filter
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                    
                    ForEach(VideoTypeFilter.allCases, id: \.self) { filter in
                        ProfileFilterChip(
                            title: filter.title,
                            isSelected: typeFilter == filter,
                            icon: filter.icon
                        ) {
                            typeFilter = filter
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                }
            }
        }
    }
}

struct ProfileFilterChip: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .background(
                Capsule()
                    .fill(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.divider.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

enum VideoVisibilityFilter: CaseIterable {
    case all, publicOnly, unlisted, privateOnly, scheduled
    
    var title: String {
        switch self {
        case .all: return "All"
        case .publicOnly: return "Public"
        case .unlisted: return "Unlisted"
        case .privateOnly: return "Private"
        case .scheduled: return "Scheduled"
        }
    }
    
    var icon: String? {
        switch self {
        case .all: return "line.3.horizontal.decrease.circle"
        case .publicOnly: return "globe"
        case .unlisted: return "link"
        case .privateOnly: return "lock.fill"
        case .scheduled: return "calendar"
        }
    }
}

enum VideoTypeFilter: CaseIterable {
    case all, shorts, longForm, live
    
    var title: String {
        switch self {
        case .all: return "Type"
        case .shorts: return "Shorts"
        case .longForm: return "Long"
        case .live: return "Live"
        }
    }
    
    var icon: String? {
        switch self {
        case .all: return "star.fill"
        case .shorts: return "play.rectangle.on.rectangle"
        case .longForm: return "rectangle.stack"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
}

private struct StockVideoBanner: Identifiable {
    let id = UUID()
    let imageURL: String
    let title: String
    let subtitle: String
    
    static let defaults: [StockVideoBanner] = [
        .init(
            imageURL: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1600&q=80",
            title: "Travel Vlog",
            subtitle: "Explore the world in 4K"
        ),
        .init(
            imageURL: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1600&q=80",
            title: "Cinematic Nature",
            subtitle: "Relaxing landscapes and skies"
        ),
        .init(
            imageURL: "https://images.unsplash.com/photo-1518770660439-b723cf961d3e?w=1600&q=80",
            title: "Tech Reviews",
            subtitle: "Latest gadgets and gear"
        ),
        .init(
            imageURL: "https://images.unsplash.com/photo-1495195134817-aeb325a55b65?w=1600&q=80",
            title: "Cooking Series",
            subtitle: "Delicious recipes made simple"
        )
    ]
}

// MARK: - Full-width single video card (YouTube-like sleek design)
private struct FullWidthVideoCard: View {
    let video: Video
    var ownerId: String? = nil
    var isInManagementMode: Bool = false
    var isSelectedInManagement: Bool = false
    var onTapOverride: (() -> Void)? = nil
    @EnvironmentObject private var appState: AppState
    @State private var showOptions = false
    @State private var isSubscribedLocal = false
    @State private var isWatchLaterLocal = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail - smaller, YouTube-like
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.Colors.textTertiary.opacity(0.12))
                    .overlay(
                        FullWidthThumb(urls: video.posterCandidates)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(width: 120, height: 68) // 16:9 ratio, compact size
            .overlay(
                Text(video.formattedDuration)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.8))
                    .cornerRadius(3)
                    .padding(4),
                alignment: .bottomTrailing
            )
            
            // Video info - takes remaining space
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Text(video.creator.displayName)
                    Text("•")
                    HStack(spacing: 2) {
                        ReactiveViewCountText(videoId: video.id, initialCount: video.viewCount)
                        Text("views")
                    }
                    Text("•")
                    Text(video.uploadTimeAgo)
                }
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(1)
            }
            
            Spacer()
            
            // Three-dot menu
            if !isInManagementMode {
                Button {
                    HapticManager.shared.impact(style: .light)
                    isSubscribedLocal = appState.isSubscribedTo(video.creator.id)
                    isWatchLaterLocal = appState.isVideoInWatchLater(video.id)
                    showOptions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .topLeading) {
            if isInManagementMode {
                SelectionBadge(isSelected: isSelectedInManagement)
                    .padding(.top, 4)
                    .padding(.leading, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(video.title)
        .contentShape(Rectangle())
        .onTapGesture {
            if let onTapOverride {
                onTapOverride()
            } else {
                defaultTap()
            }
        }
        .sheet(isPresented: $showOptions) {
            VideoMoreOptionsSheet(
                video: video,
                isSubscribed: $isSubscribedLocal,
                isWatchLater: $isWatchLaterLocal
            )
            .onChange(of: isWatchLaterLocal) { _ in
                appState.toggleWatchLater(for: video.id)
            }
            .onChange(of: isSubscribedLocal) { _ in
                appState.toggleSubscription(for: video.creator.id)
            }
        }
        .drawingGroup() // ⚡ PERFORMANCE: Flatten view hierarchy for smoother scrolling
    }
    
    private func defaultTap() {
        HapticManager.shared.impact(style: .light)
        NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
    }
}

private struct FullWidthThumb: View {
    let urls: [URL]
    var body: some View {
        MultiSourceAsyncImage(
            urls: urls,
            content: { image in
                image.resizable().scaledToFill().transition(.opacity)
            },
            placeholder: { placeholder }
        )
        .clipped()
    }
    private var placeholder: some View {
        Image(systemName: "photo.on.rectangle.angled")
            .resizable()
            .scaledToFit()
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(28)
    }
}

struct PinnedVideosCarousel: View {
    let videos: [Video]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(videos) { video in
                    FullWidthVideoCard(video: video)
                        .frame(width: 260)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Reactive View Count Component
struct ReactiveViewCountText: View {
    let videoId: String
    let initialCount: Int
    @State private var viewCount: Int
    
    init(videoId: String, initialCount: Int) {
        self.videoId = videoId
        self.initialCount = initialCount
        _viewCount = State(initialValue: initialCount)
    }
    
    var body: some View {
        Text(formatViewCount(viewCount))
            .task {
                // 🔥 FIX: Load latest count from Firestore immediately
                let latestCount = await RealtimeViewTracker.shared.getViewCount(for: videoId)
                await MainActor.run {
                    viewCount = latestCount
                    print("📊 [ReactiveViewCount] Loaded count for \(videoId): \(latestCount)")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VideoViewCountUpdated"))) { notification in
                if let userInfo = notification.userInfo,
                   let notificationVideoId = userInfo["videoId"] as? String,
                   notificationVideoId == videoId,
                   let count = userInfo["viewCount"] as? Int {
                    viewCount = count
                    print("📊 [ReactiveViewCount] Updated count for \(videoId): \(count)")
                }
            }
    }
    
    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return String(count)
        }
    }
}

#Preview("Profile Videos Layout Toggle") {
    ScrollView {
        ProfileVideosView(
            videos: Array(Video.sampleVideos.prefix(8)),
            user: User.sampleUsers.first ?? .defaultUser,
            isOwnProfile: true
        )
    }
    .background(AppTheme.Colors.background)
    .preferredColorScheme(.light)
}