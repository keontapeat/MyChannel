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
    @Binding var selectedTab: ProfileTab
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
                selectedTab: $selectedTab,
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
    @Binding var selectedTab: ProfileTab
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
            case .downloads:
                ProfileDownloadsTabView()
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
    @State private var advancedSortColumn: AdvancedSortColumn = .views
    @State private var advancedSortAscending: Bool = false
    @State private var metrixVideoId: String? = nil
    @State private var showingFilterTray: Bool = true
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    private var isManagementActive: Bool {
        guard isOwnProfile, let managementContext else { return false }
        return managementContext.isManaging.wrappedValue
    }
    
    var body: some View {
        LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
            if !pinnedVideos.isEmpty {
                PremiumPinnedSection(videos: pinnedVideos, userId: user.id) { unpinnedId in
                    pinnedIds.removeAll { $0 == unpinnedId }
                }
                    .padding(.top, 16)
            } else if videos.isEmpty && AuthenticationManager.shared.currentUser?.id == user.id {
                PremiumEmptyVideosState()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            Section {
                HStack {
                    Text("All videos")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
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
                            HapticManager.shared.impact(style: .medium)
                            if totalCount > 0 && selectedCount >= totalCount {
                                management.onSetSelections([])
                            } else {
                                management.onSetSelections(filteredVideoIDs)
                            }
                        },
                        onDelete: {
                            HapticManager.shared.notification(type: .warning)
                            management.onAction(.delete)
                        },
                        onAction: { action in
                            management.onAction(action)
                        }
                    )
                    .padding(.horizontal, 16)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .move(edge: .top))
                                .combined(with: .scale(scale: 0.95, anchor: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        )
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isManagementActive)
                }

                videosBody
                    .id(layoutMode)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .animation(.spring(response: 0.35, dampingFraction: 0.9), value: layoutMode)

                Color.clear.frame(height: 8)
            } header: {
                videoManagementHeader
            }
        }
        .padding(.bottom, 12)
        .task { pinnedIds = PinnedVideosStore.shared.getPinned(for: user.id) }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileUpdated)) { _ in
            pinnedIds = PinnedVideosStore.shared.getPinned(for: user.id)
        }
    }

    private var videoManagementHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Text("Videos")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Spacer()

                if isOwnProfile {
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        NotificationCenter.default.post(name: NSNotification.Name("ShowUpload"), object: nil)
                    } label: {
                        HStack(spacing: 8) {
                            Text("Add")
                                .font(.system(size: 15, weight: .bold))
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

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
                        Image(systemName: management.isManaging.wrappedValue ? "checkmark.circle.fill" : "slider.horizontal.3")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(management.isManaging.wrappedValue ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(management.isManaging.wrappedValue ? "Exit video management" : "Manage videos")
                }

                HStack(spacing: 6) {
                    ForEach(VideoLayoutMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                layoutMode = mode
                            }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Image(systemName: mode.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(layoutMode == mode ? .white : AppTheme.Colors.textPrimary)
                                .frame(width: 42, height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(layoutMode == mode ? AppTheme.Colors.primary : Color(.systemGray6))
                                )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }

                    Menu {
                        ForEach(SortMode.allCases, id: \.self) { mode in
                            Button(mode.title) {
                                sortMode = mode
                            }
                        }
                    } label: {
                        Image(systemName: sortMode.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            VideoFilterBar(
                searchText: $searchText,
                visibilityFilter: $visibilityFilter,
                typeFilter: $typeFilter,
                showingFilterTray: $showingFilterTray
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            AppTheme.Colors.background
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppTheme.Colors.divider.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 18, x: 0, y: 8)
                        .padding(.horizontal, 16)
                )
        )
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
    
    private var advancedSortedVideos: [Video] {
        let base = filteredVideos
        switch advancedSortColumn {
        case .views:
            return advancedSortAscending
                ? base.sorted { $0.viewCount < $1.viewCount }
                : base.sorted { $0.viewCount > $1.viewCount }
        case .ctr:
            return base // CTR served by ML; default to view order
        case .watchTime:
            return base // Watch time served by ML; default to view order
        case .revenue:
            return base // Revenue served by ML; default to view order
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
        } else if layoutMode == .advanced {
            // 🔥 ADVANCED: YouTube Studio-style table view
            VStack(spacing: 0) {
                AdvancedTableColumnHeader(
                    sortColumn: $advancedSortColumn,
                    sortAscending: $advancedSortAscending
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                LazyVStack(spacing: 0) {
                    ForEach(advancedSortedVideos, id: \.id) { video in
                        AdvancedVideoTableRow(
                            video: video,
                            ownerId: user.id,
                            onMetrixTap: { metrixVideoId = video.id }
                        )
                        .padding(.horizontal, 16)
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .sheet(item: Binding(
                get: { metrixVideoId.map { AdvancedMetrixItem(id: $0) } },
                set: { metrixVideoId = $0?.id }
            )) { item in
                NavigationStack {
                    VideoAnalyticsView(videoId: item.id)
                        .navigationTitle("Metrix")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") { metrixVideoId = nil }
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                }
            }
        } else if layoutMode == .grid2 {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(sortedVideos.enumerated()), id: \.element.id) { index, video in
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
                            if index >= sortedVideos.count - 6 {
                                Task {
                                    if !isLoadingMore {
                                        await onLoadMore?()
                                    }
                                }
                            }
                            
                            // 🔥 THERMONUCLEAR: Prefetch next 12 thumbnails
                            let prefetchRange = (index + 1)..<min(sortedVideos.count, index + 13)
                            let urls = prefetchRange.compactMap { URL(string: sortedVideos[$0].thumbnailURL) }
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
                ForEach(Array(sortedVideos.enumerated()), id: \.element.id) { index, video in
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
                            if index >= sortedVideos.count - 6 {
                                Task {
                                    if !isLoadingMore {
                                        await onLoadMore?()
                                    }
                                }
                            }
                            
                            // 🔥 THERMONUCLEAR: Prefetch next 12 thumbnails
                            let prefetchRange = (index + 1)..<min(sortedVideos.count, index + 13)
                            let urls = prefetchRange.compactMap { URL(string: sortedVideos[$0].thumbnailURL) }
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

    var title: String {
        switch self {
        case .newest: return "Newest"
        case .popular: return "Popular"
        case .oldest: return "Oldest"
        }
    }

    var icon: String {
        switch self {
        case .newest: return "arrow.up.arrow.down"
        case .popular: return "chart.bar"
        case .oldest: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - Profile Video Card
struct ProfileVideoCard: View {
    let video: Video
    var ownerId: String? = nil
    var isInManagementMode: Bool = false
    var isSelectedInManagement: Bool = false
    @EnvironmentObject private var appState: AppState
    @State private var showOptions = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var showVisibilityPicker = false
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
            if !isInManagementMode {
                profileVideoContextActions
            }
        } preview: {
            ProfileVideoContextPreviewCard(video: video)
        }
        .confirmationDialog("Change Visibility", isPresented: $showVisibilityPicker, titleVisibility: .visible) {
            Button("Public") { updateVisibility(.public) }
            Button("Unlisted") { updateVisibility(.unlisted) }
            Button("Private") { updateVisibility(.private) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete this video?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteVideo() }
            }
        } message: {
            Text("This action cannot be undone. The video will be permanently deleted.")
        }
        .sheet(isPresented: $showOptions) {
            VideoMoreOptionsSheet(
                video: video,
                isSubscribed: $isSubscribedLocal,
                isWatchLater: $isWatchLaterLocal,
                ownerId: ownerId
            )
            .onChange(of: isWatchLaterLocal) { _ in
                appState.toggleWatchLater(for: video.id)
            }
            .onChange(of: isSubscribedLocal) { _ in
                appState.toggleSubscription(for: video.creator.id)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            VideoShareSheet(items: [video.link])
        }
        .drawingGroup() // ⚡ PERFORMANCE: Flatten view hierarchy for smoother scrolling
    }

    @ViewBuilder
    private var profileVideoContextActions: some View {
        Section("Content") {
            Button {
                NotificationCenter.default.post(name: Notification.Name("OpenVideoEditor"), object: video)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                NotificationCenter.default.post(name: Notification.Name("OpenVideoAnalytics"), object: video)
            } label: {
                Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
            }

            Button {
                showVisibilityPicker = true
            } label: {
                Label("Visibility", systemImage: video.visibility.iconName)
            }
        }

        Section("Organization") {
            Button {
                showShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            if let ownerId, ownerId == video.creator.id {
                if PinnedVideosStore.shared.isPinned(video.id, for: ownerId) {
                    Button {
                        PinnedVideosStore.shared.unpin(video.id, for: ownerId)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                    } label: {
                        Label("Unpin from top", systemImage: "pin.slash")
                    }
                } else {
                    Button {
                        PinnedVideosStore.shared.pin(video.id, for: ownerId)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                    } label: {
                        Label("Pin to top", systemImage: "pin")
                    }
                }
            }
        }

        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
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

    private func updateVisibility(_ visibility: Video.VisibilityStatus) {
        Task {
            try? await VideoFirestoreService.shared.updateVideoVisibility(videoId: video.id, visibility: visibility)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
        }
    }

    private func deleteVideo() async {
        try? await VideoFirestoreService.shared.deleteVideo(videoId: video.id)
        try? await DatabaseService.shared.deleteVideo(id: video.id)
        if let ownerId, ownerId == video.creator.id {
            PinnedVideosStore.shared.unpin(video.id, for: ownerId)
        }
        ProfileCacheService.shared.removeVideoFromCache(video.id)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Video deleted successfully")
        }
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
    case advanced
    
    var icon: String {
        switch self {
        case .grid2: return "square.grid.2x2"
        case .list1: return "list.bullet"
        case .advanced: return "tablecells"
        }
    }
    
    var title: String {
        switch self {
        case .grid2: return "Grid"
        case .list1: return "List"
        case .advanced: return "Advanced"
        }
    }
}

private enum AdvancedSortColumn: String, CaseIterable {
    case views
    case ctr
    case watchTime
    case revenue
    
    var title: String {
        switch self {
        case .views: return "Views"
        case .ctr: return "CTR"
        case .watchTime: return "Avg WT"
        case .revenue: return "Rev"
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Colors.divider.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 8)
    }
}

// 🔥 PREMIUM: Selection Badge with Spring Animation
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
                    .scaleEffect(isSelected ? 1.0 : 0.8)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 1)
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
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
            .foregroundColor(action.isDestructive ? .red : AppTheme.Colors.textPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        action.isDestructive
                            ? Color.red.opacity(isEnabled ? 0.7 : 0.3)
                            : AppTheme.Colors.divider.opacity(isEnabled ? 0.5 : 0.2),
                        lineWidth: 1
                    )
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
    @Binding var showingFilterTray: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                UIKitSearchBar(
                    placeholder: "Search",
                    text: $searchText,
                    onSearch: { }
                )
                .frame(height: 42)

                Button {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        showingFilterTray.toggle()
                    }
                } label: {
                    Image(systemName: showingFilterTray ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(showingFilterTray ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if showingFilterTray {
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
                .transition(.move(edge: .top).combined(with: .opacity))
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
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
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
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var showVisibilityPicker = false
    @State private var isSubscribedLocal = false
    @State private var isWatchLaterLocal = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail - cinematic with drop shadow
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.Colors.textTertiary.opacity(0.12))
                    .overlay(
                        FullWidthThumb(urls: video.posterCandidates)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .frame(width: 120, height: 68)
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            .overlay(
                Text(video.formattedDuration)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(5),
                alignment: .bottomTrailing
            )
            
            // Video info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
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
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
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
        .contextMenu {
            if !isInManagementMode {
                profileVideoContextActions
            }
        } preview: {
            ProfileVideoContextPreviewCard(video: video)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isInManagementMode {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }

                Button {
                    showVisibilityPicker = true
                } label: {
                    Label("Visibility", systemImage: video.visibility.iconName)
                }
                .tint(.orange)

                Button {
                    NotificationCenter.default.post(name: Notification.Name("OpenVideoAnalytics"), object: video)
                } label: {
                    Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tint(.blue)
            }
        }
        .onTapGesture {
            if let onTapOverride {
                onTapOverride()
            } else {
                defaultTap()
            }
        }
        .confirmationDialog("Change Visibility", isPresented: $showVisibilityPicker, titleVisibility: .visible) {
            Button("Public") { updateVisibility(.public) }
            Button("Unlisted") { updateVisibility(.unlisted) }
            Button("Private") { updateVisibility(.private) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete this video?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteVideo() }
            }
        } message: {
            Text("This action cannot be undone. The video will be permanently deleted.")
        }
        .sheet(isPresented: $showOptions) {
            VideoMoreOptionsSheet(
                video: video,
                isSubscribed: $isSubscribedLocal,
                isWatchLater: $isWatchLaterLocal,
                ownerId: ownerId
            )
            .onChange(of: isWatchLaterLocal) { _ in
                appState.toggleWatchLater(for: video.id)
            }
            .onChange(of: isSubscribedLocal) { _ in
                appState.toggleSubscription(for: video.creator.id)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            VideoShareSheet(items: [video.link])
        }
        .drawingGroup() // ⚡ PERFORMANCE: Flatten view hierarchy for smoother scrolling
    }

    @ViewBuilder
    private var profileVideoContextActions: some View {
        Section("Content") {
            Button {
                NotificationCenter.default.post(name: Notification.Name("OpenVideoEditor"), object: video)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                NotificationCenter.default.post(name: Notification.Name("OpenVideoAnalytics"), object: video)
            } label: {
                Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
            }

            Button {
                showVisibilityPicker = true
            } label: {
                Label("Visibility", systemImage: video.visibility.iconName)
            }
        }

        Section("Organization") {
            Button {
                showShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            if let ownerId, ownerId == video.creator.id {
                if PinnedVideosStore.shared.isPinned(video.id, for: ownerId) {
                    Button {
                        PinnedVideosStore.shared.unpin(video.id, for: ownerId)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                    } label: {
                        Label("Unpin from top", systemImage: "pin.slash")
                    }
                } else {
                    Button {
                        PinnedVideosStore.shared.pin(video.id, for: ownerId)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                    } label: {
                        Label("Pin to top", systemImage: "pin")
                    }
                }
            }
        }

        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }

    private func defaultTap() {
        HapticManager.shared.impact(style: .light)
        NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
    }

    private func updateVisibility(_ visibility: Video.VisibilityStatus) {
        Task {
            try? await VideoFirestoreService.shared.updateVideoVisibility(videoId: video.id, visibility: visibility)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
        }
    }

    private func deleteVideo() async {
        try? await VideoFirestoreService.shared.deleteVideo(videoId: video.id)
        try? await DatabaseService.shared.deleteVideo(id: video.id)
        if let ownerId, ownerId == video.creator.id {
            PinnedVideosStore.shared.unpin(video.id, for: ownerId)
        }
        ProfileCacheService.shared.removeVideoFromCache(video.id)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Video deleted successfully")
        }
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

private struct ProfileVideoContextPreviewCard: View {
    let video: Video
    @State private var liveViewCount: Int = 0
    @State private var liveViewers: Int = 0
    @State private var performanceTier: PerformanceTier = .standard
    @State private var engagementRate: Double = 0
    @State private var rpm: Double = 0
    @State private var estimatedRevenue: Double = 0
    @State private var isMonetized: Bool = false
    @State private var previousViewCount: Int = 0
    @State private var viewVelocity: ViewVelocity = .stable

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        MultiSourceAsyncImage(
                            urls: video.posterCandidates,
                            content: { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            },
                            placeholder: {
                                ZStack {
                                    AppTheme.Colors.surface
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 36, weight: .light))
                                        .foregroundStyle(AppTheme.Colors.textTertiary)
                                }
                            }
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay(
                        liveMetricsOverlay,
                        alignment: .topLeading
                    )

                Text(video.formattedDuration)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(10)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: video.visibility.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    Text(video.visibility.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    Text("•")
                        .foregroundStyle(AppTheme.Colors.textTertiary)

                    Text(formatViewCount(liveViewCount))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    Text("•")
                        .foregroundStyle(AppTheme.Colors.textTertiary)

                    Text(video.uploadTimeAgo)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                if !video.description.isEmpty {
                    Text(video.description)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.Colors.divider.opacity(0.16), lineWidth: 1)
                )
        )
        .task {
            await loadLiveMetrics()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VideoViewCountUpdated"))) { notification in
            if let userInfo = notification.userInfo,
               let notificationVideoId = userInfo["videoId"] as? String,
               notificationVideoId == video.id,
               let count = userInfo["viewCount"] as? Int {
                liveViewCount = count
                updatePerformanceTier()
            }
        }
    }

    @ViewBuilder
    private var liveMetricsOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            if liveViewers > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("\(liveViewers) watching")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.7))
                .clipShape(Capsule())
            }

            HStack(spacing: 6) {
                performanceTierBadge

                if engagementRate > 0 {
                    engagementBadge
                }

                if isMonetized {
                    monetizationBadge
                }

                viewVelocityBadge
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private var monetizationBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 9, weight: .semibold))
            if rpm > 0 {
                Text("\(formatCurrency(rpm)) RPM")
                    .font(.system(size: 9, weight: .semibold))
            } else {
                Text("Monetized")
                    .font(.system(size: 9, weight: .semibold))
            }
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.15))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var viewVelocityBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: viewVelocity.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(viewVelocity.label)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(viewVelocity.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(viewVelocity.color.opacity(0.15))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var performanceTierBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: performanceTier.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(performanceTier.label)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(performanceTier.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(performanceTier.color.opacity(0.15))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var engagementBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 9, weight: .semibold))
            Text(String(format: "%.0f%%", engagementRate * 100))
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.15))
        .clipShape(Capsule())
    }

    private func loadLiveMetrics() async {
        // Store previous count for velocity calculation
        let previousCount = liveViewCount

        // Fetch real-time view count
        let viewCount = await RealtimeViewTracker.shared.getViewCount(for: video.id)
        await MainActor.run {
            liveViewCount = viewCount
            updatePerformanceTier()
            updateViewVelocity(previous: previousCount, current: viewCount)
        }

        // Fetch live viewers
        let viewers = RealtimeViewTracker.shared.getLiveViewers(for: video.id)
        await MainActor.run {
            liveViewers = viewers
        }

        // Fetch engagement metrics
        if let engagement = RealtimeViewTracker.shared.getEngagement(for: video.id) {
            await MainActor.run {
                engagementRate = engagement.completionRate
            }
        }

        // Fetch analytics data (RPM, monetization status)
        if let analytics = await StudioAnalyticsService.shared.fetchVideoAnalytics(videoId: video.id) {
            await MainActor.run {
                rpm = analytics.rpm
                isMonetized = analytics.rpm > 0
                // Estimate revenue: views / 1000 * RPM
                estimatedRevenue = Double(analytics.views) / 1000.0 * analytics.rpm
            }
        }
    }

    private func updatePerformanceTier() {
        performanceTier = PerformanceTier.forViewCount(liveViewCount)
    }

    private func updateViewVelocity(previous: Int, current: Int) {
        let change = current - previous
        let threshold = max(1, previous / 20) // 5% change threshold

        if change > threshold {
            viewVelocity = .accelerating
        } else if change < -threshold {
            viewVelocity = .decelerating
        } else {
            viewVelocity = .stable
        }
    }

    private func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM views", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK views", Double(count) / 1_000)
        } else {
            return "\(count) views"
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        if value >= 1 {
            return String(format: "$%.0f", value)
        } else {
            return String(format: "$%.2f", value)
        }
    }
}

enum ViewVelocity {
    case accelerating, stable, decelerating

    var label: String {
        switch self {
        case .accelerating: return "Trending Up"
        case .stable: return "Stable"
        case .decelerating: return "Slowing"
        }
    }

    var icon: String {
        switch self {
        case .accelerating: return "arrow.up.forward"
        case .stable: return "minus"
        case .decelerating: return "arrow.down.forward"
        }
    }

    var color: Color {
        switch self {
        case .accelerating: return .green
        case .stable: return .gray
        case .decelerating: return .orange
        }
    }
}

enum PerformanceTier: CaseIterable {
    case viral, trending, performing, standard, new

    var label: String {
        switch self {
        case .viral: return "Viral"
        case .trending: return "Trending"
        case .performing: return "Performing"
        case .standard: return "Active"
        case .new: return "New"
        }
    }

    var icon: String {
        switch self {
        case .viral: return "flame.fill"
        case .trending: return "chart.line.uptrend.xyaxis"
        case .performing: return "arrow.up.circle.fill"
        case .standard: return "checkmark.circle.fill"
        case .new: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .viral: return .orange
        case .trending: return .green
        case .performing: return .blue
        case .standard: return .gray
        case .new: return .purple
        }
    }

    static func forViewCount(_ count: Int) -> PerformanceTier {
        switch count {
        case 1_000_000...: return .viral
        case 100_000..<1_000_000: return .trending
        case 10_000..<100_000: return .performing
        case 100..<10_000: return .standard
        default: return .new
        }
    }
}

// MARK: - 🔥 Premium Pinned Section
struct PremiumPinnedSection: View {
    let videos: [Video]
    let userId: String
    var onUnpin: ((String) -> Void)? = nil
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Premium Header
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .rotationEffect(.degrees(-45))
                
                Text("Pinned")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Text("•")
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                Text("\(videos.count) video\(videos.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Full-width centered pinned videos
            VStack(spacing: 16) {
                ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                    PremiumPinnedVideoCard(video: video, userId: userId, onUnpin: onUnpin)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                            value: appeared
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onAppear {
            HapticManager.shared.impact(style: .light)
            withAnimation { appeared = true }
        }
    }
}

// MARK: - 🔥 Premium Pinned Video Card
struct PremiumPinnedVideoCard: View {
    let video: Video
    let userId: String
    var onUnpin: ((String) -> Void)? = nil
    @EnvironmentObject private var appState: AppState
    @State private var isPressed = false
    @State private var showOptions = false
    @State private var isSubscribedLocal = false
    @State private var isWatchLaterLocal = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Premium Thumbnail with Pin Badge - Full width
            ZStack(alignment: .topLeading) {
                // Thumbnail: use bundled asset for Shot By Keonta intro so it always shows
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        Group {
                            if video.id == "shot_by_keonta_intro" || video.id == "owner_intro_video" ||
                                video.thumbnailURL.contains("ShotByKeonta") {
                                Image("ShotByKeontaThumbnail")
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                PinnedCardThumb(urls: video.posterCandidates)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary.opacity(0.5), AppTheme.Colors.primary.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .aspectRatio(16/9, contentMode: .fit) // Full width 16:9 ratio
                
                // Duration Badge
                Text(video.formattedDuration)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.85))
                    .cornerRadius(6)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                
                // Pin Badge
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("PINNED")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 4, y: 2)
                )
                .padding(12)
            }
            
            // Video Info - Full width
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    ReactiveViewCountText(videoId: video.id, initialCount: video.viewCount)
                    Text("views")
                    Text("•")
                    Text(video.uploadTimeAgo)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .medium)
            GlobalVideoPlayerManager.shared.playVideo(video, showFullscreen: true)
            NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            isPressed = pressing
            if pressing { HapticManager.shared.impact(style: .light) }
        }) {
            HapticManager.shared.impact(style: .medium)
            isSubscribedLocal = appState.isSubscribedTo(video.creator.id)
            isWatchLaterLocal = appState.isVideoInWatchLater(video.id)
            showOptions = true
        }
        .contextMenu {
            Button(role: .destructive) {
                HapticManager.shared.impact(style: .medium)
                PinnedVideosStore.shared.unpin(video.id, for: userId)
                onUnpin?(video.id)
            } label: {
                Label("Unpin from profile", systemImage: "pin.slash")
            }
            
            Button {
                HapticManager.shared.impact(style: .light)
                appState.toggleWatchLater(for: video.id)
            } label: {
                Label(
                    appState.isVideoInWatchLater(video.id) ? "Remove from Watch Later" : "Add to Watch Later",
                    systemImage: appState.isVideoInWatchLater(video.id) ? "bookmark.slash" : "bookmark"
                )
            }
            
            Button {
                HapticManager.shared.impact(style: .light)
                // Share action
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $showOptions) {
            VideoMoreOptionsSheet(
                video: video,
                isSubscribed: $isSubscribedLocal,
                isWatchLater: $isWatchLaterLocal,
                ownerId: userId
            )
        }
        .accessibilityLabel("Pinned video: \(video.title)")
    }
}

// MARK: - Pinned Card Thumbnail
private struct PinnedCardThumb: View {
    let urls: [URL]
    @State private var currentIndex = 0
    
    var body: some View {
        GeometryReader { geo in
            if urls.isEmpty {
                placeholder
            } else {
                AsyncImage(url: urls[currentIndex]) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                    case .failure:
                        if currentIndex < urls.count - 1 {
                            Color.clear.onAppear { currentIndex += 1 }
                        } else {
                            placeholder
                        }
                    case .empty:
                        shimmer
                    @unknown default:
                        placeholder
                    }
                }
            }
        }
        .clipped()
    }
    
    private var placeholder: some View {
        ZStack {
            AppTheme.Colors.surface
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.Colors.textTertiary.opacity(0.5))
        }
    }
    
    private var shimmer: some View {
        AppTheme.Colors.surface
            .overlay(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.surface,
                        AppTheme.Colors.surface.opacity(0.5),
                        AppTheme.Colors.surface
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

// MARK: - Legacy Carousel (Deprecated)
struct PinnedVideosCarousel: View {
    let videos: [Video]
    let userId: String
    var body: some View {
        PremiumPinnedSection(videos: videos, userId: userId)
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

// MARK: - Premium Empty Videos State
struct PremiumEmptyVideosState: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .padding(.top, 24)

            VStack(spacing: 8) {
                Text("Your catalog is empty")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Start building your legacy — upload your first video.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                HapticManager.shared.impact(style: .medium)
                NotificationCenter.default.post(name: NSNotification.Name("ShowUpload"), object: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Upload Your First Video")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .scaleEffect(pulse ? 1.03 : 1.0)
                .shadow(color: AppTheme.Colors.primary.opacity(0.35), radius: pulse ? 12 : 6, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Advanced View Support Types
private struct AdvancedMetrixItem: Identifiable {
    let id: String
}

// MARK: - Advanced Table Column Header
private struct AdvancedTableColumnHeader: View {
    @Binding var sortColumn: AdvancedSortColumn
    @Binding var sortAscending: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text("VIDEO")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(AdvancedSortColumn.allCases, id: \.self) { col in
                Button {
                    HapticManager.shared.impact(style: .light)
                    if sortColumn == col {
                        sortAscending.toggle()
                    } else {
                        sortColumn = col
                        sortAscending = false
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(col.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(sortColumn == col ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                        if sortColumn == col {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primary)
                        }
                    }
                    .frame(width: 52, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }

            // Spacer for the 3-dot column
            Spacer().frame(width: 28)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(AppTheme.Colors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Advanced Video Table Row
private struct AdvancedVideoTableRow: View {
    let video: Video
    let ownerId: String
    let onMetrixTap: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var showOptions = false
    @State private var showVisibilityPicker = false
    @State private var isSubscribedLocal = false
    @State private var isWatchLaterLocal = false

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.Colors.textTertiary.opacity(0.12))
                    .overlay(
                        FullWidthThumb(urls: video.posterCandidates)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(width: 80, height: 45)
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            .overlay(
                Text(video.formattedDuration)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(3),
                alignment: .bottomTrailing
            )

            // Title + visibility badge
            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)

                if let scheduledAt = video.scheduledAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(scheduledAt, style: .date)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                } else {
                    Button {
                        showVisibilityPicker = true
                    } label: {
                        VisibilityBadge(visibility: video.visibility)
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Change Visibility", isPresented: $showVisibilityPicker, titleVisibility: .visible) {
                        Button("Public") {
                            updateVisibility(.public)
                        }
                        Button("Unlisted") {
                            updateVisibility(.unlisted)
                        }
                        Button("Private") {
                            updateVisibility(.private)
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }
            .frame(minWidth: 80, maxWidth: 110, alignment: .leading)

            // Stat columns — Views, CTR, WatchTime, Revenue
            AdvancedStatColumn(value: formatViews(video.viewCount), label: nil)
            AdvancedStatColumn(value: "—", label: nil)
            AdvancedStatColumn(value: "—", label: nil)
            AdvancedStatColumn(value: "—", label: nil)

            // 3-dot menu
            Button {
                HapticManager.shared.impact(style: .light)
                isSubscribedLocal = appState.isSubscribedTo(video.creator.id)
                isWatchLaterLocal = appState.isVideoInWatchLater(video.id)
                showOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            onMetrixTap()
        }
        .sheet(isPresented: $showOptions) {
            VideoMoreOptionsSheet(
                video: video,
                isSubscribed: $isSubscribedLocal,
                isWatchLater: $isWatchLaterLocal,
                ownerId: ownerId
            )
            .onChange(of: isWatchLaterLocal) { _ in appState.toggleWatchLater(for: video.id) }
            .onChange(of: isSubscribedLocal) { _ in appState.toggleSubscription(for: video.creator.id) }
        }
    }

    private func formatViews(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private func updateVisibility(_ visibility: Video.VisibilityStatus) {
        Task {
            try? await VideoFirestoreService.shared.updateVideoVisibility(videoId: video.id, visibility: visibility)
        }
    }
}

private struct AdvancedStatColumn: View {
    let value: String
    let label: String?

    var body: some View {
        Text(value)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .frame(width: 52, alignment: .trailing)
            .lineLimit(1)
    }
}

private struct VisibilityBadge: View {
    let visibility: Video.VisibilityStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(badgeColor)
                .frame(width: 6, height: 6)
            Text(badgeLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(badgeColor)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.12))
        .clipShape(Capsule())
        .fixedSize()
    }

    private var badgeColor: Color {
        switch visibility {
        case .public: return .green
        case .unlisted: return .orange
        case .private: return AppTheme.Colors.textTertiary
        @unknown default: return AppTheme.Colors.textTertiary
        }
    }

    private var badgeLabel: String {
        switch visibility {
        case .public: return "Public"
        case .unlisted: return "Unlisted"
        case .private: return "Private"
        @unknown default: return "Unknown"
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

#Preview("🔥 Premium Pinned Section") {
    ScrollView {
        PremiumPinnedSection(videos: Array(Video.sampleVideos.prefix(3)), userId: "preview_user")
    }
    .background(AppTheme.Colors.background)
    .environmentObject(AppState())
}