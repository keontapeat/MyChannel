import SwiftUI

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
    
    @State private var layoutMode: VideoLayoutMode = VideoLayoutMode.savedPreference
    @State private var sortMode: SortMode = .newest
    @State private var pinnedIds: [String] = []
    @State private var searchText: String = ""
    @State private var visibilityFilter: VideoVisibilityFilter = .all
    @State private var typeFilter: VideoTypeFilter = .all
    @State private var advancedSortColumn: AdvancedSortColumn = .views
    @State private var advancedSortAscending: Bool = false
    @StateObject private var analyticsStore = AdvancedAnalyticsStore()
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
        LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if isOwnProfile {
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        NotificationCenter.default.post(name: NSNotification.Name("ShowUpload"), object: nil)
                    } label: {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                Text("Add")
                                    .font(.system(size: 14, weight: .bold))
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minWidth: 82)
                        .frame(height: 38)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: AppTheme.Colors.primary.opacity(0.24), radius: 10, x: 0, y: 5)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
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
                                .frame(width: 38, height: 38)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(management.isManaging.wrappedValue ? "Exit video management" : "Manage videos")
                    }

                    ForEach(VideoLayoutMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                layoutMode = mode
                                mode.savePreference()
                            }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Image(systemName: mode.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(layoutMode == mode ? .white : AppTheme.Colors.textPrimary)
                                .frame(width: 38, height: 38)
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
                            .frame(width: 38, height: 38)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.Colors.divider.opacity(0.18), lineWidth: 1)
                        )
                )
            }

            VideoFilterBar(
                searchText: $searchText,
                visibilityFilter: $visibilityFilter,
                typeFilter: $typeFilter,
                showingFilterTray: $showingFilterTray
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
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
        var pinned = filteredVideos.filter { set.contains($0.id) }

        if isOwnerProfile,
           let intro = ownerIntroVideo(),
           !pinned.contains(where: { $0.id == intro.id }) {
            pinned.insert(intro, at: 0)
        }

        return pinned
    }

    private var isOwnerProfile: Bool {
        let ownerUIDs: Set<String> = ["7EAoUc1aKsNRqR4cYBIOYVGB3Mf2"]
        let ownerEmails: Set<String> = ["keontapeat@gmail.com", "keontapeat@mychannel.live"]
        if ownerUIDs.contains(user.id) { return true }
        if ownerEmails.contains(user.email.lowercased()) { return true }
        if user.username.lowercased() == "sbkeonta_" { return true }
        if user.displayName.lowercased().contains("shot by keonta") { return true }
        return false
    }

    private func ownerIntroVideo() -> Video? {
        FeaturedStore.ownerIntroVideo()
    }
    
    private var sortedVideos: [Video] {
        switch sortMode {
        case .newest:
            return filteredVideos.sorted { $0.createdAt > $1.createdAt }
        case .popular:
            return filteredVideos.sorted { $0.viewCount > $1.viewCount }
        case .oldest:
            return filteredVideos.sorted { $0.createdAt < $1.createdAt }
        case .mostComments:
            return filteredVideos.sorted { $0.commentCount > $1.commentCount }
        case .longest:
            return filteredVideos.sorted { $0.duration > $1.duration }
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
            return base.sorted {
                let a = analyticsStore.ctr(for: $0.id) ?? -1
                let b = analyticsStore.ctr(for: $1.id) ?? -1
                return advancedSortAscending ? a < b : a > b
            }
        case .watchTime:
            return base.sorted {
                let a = analyticsStore.avgWatchTime(for: $0.id) ?? -1
                let b = analyticsStore.avgWatchTime(for: $1.id) ?? -1
                return advancedSortAscending ? a < b : a > b
            }
        case .revenue:
            return base.sorted {
                let a = analyticsStore.revenue(for: $0.id, viewCount: $0.viewCount) ?? -1
                let b = analyticsStore.revenue(for: $1.id, viewCount: $1.viewCount) ?? -1
                return advancedSortAscending ? a < b : a > b
            }
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
            // 🔥 ADVANCED: YouTube Studio-style table view with REAL analytics
            VStack(spacing: 0) {
                AdvancedTableColumnHeader(
                    sortColumn: $advancedSortColumn,
                    sortAscending: $advancedSortAscending
                )
                .padding(.bottom, 8)

                if analyticsStore.isLoading && analyticsStore.analytics.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading analytics…")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                LazyVStack(spacing: 0) {
                    ForEach(advancedSortedVideos, id: \.id) { video in
                        AdvancedVideoTableRow(
                            video: video,
                            ownerId: user.id,
                            analytics: analyticsStore.analytics(for: video.id),
                            onMetrixTap: { metrixVideoId = video.id }
                        )
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .task(id: filteredVideoIDs) {
                await analyticsStore.load(videoIds: filteredVideoIDs)
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

enum SortMode: String, CaseIterable {
    case newest
    case popular
    case oldest
    case mostComments
    case longest

    var title: String {
        switch self {
        case .newest: return "Newest"
        case .popular: return "Most viewed"
        case .oldest: return "Oldest"
        case .mostComments: return "Most comments"
        case .longest: return "Longest"
        }
    }

    var icon: String {
        switch self {
        case .newest: return "arrow.up.arrow.down"
        case .popular: return "chart.bar"
        case .oldest: return "clock.arrow.circlepath"
        case .mostComments: return "bubble.left.and.bubble.right"
        case .longest: return "timer"
        }
    }
}


// ⚡ All card/component structs extracted to ProfileVideoComponents.swift
