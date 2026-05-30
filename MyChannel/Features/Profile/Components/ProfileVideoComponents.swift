// ⚡ PERFORMANCE: Extracted from ProfileVideosView.swift — independent compilation unit.
// All card/toolbar/table components compile in parallel with the 513-line main view.
import SwiftUI

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
        NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Video deleted successfully")
    }
}

enum VideoLayoutMode: String, CaseIterable {
    case grid2
    case list1
    case advanced
    
    private static let preferenceKey = "profile.videos.layoutMode"
    
    static var savedPreference: VideoLayoutMode {
        guard let rawValue = UserDefaults.standard.string(forKey: preferenceKey),
              let mode = VideoLayoutMode(rawValue: rawValue) else {
            return .list1
        }
        return mode
    }
    
    func savePreference() {
        UserDefaults.standard.set(rawValue, forKey: Self.preferenceKey)
    }
    
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

enum AdvancedSortColumn: String, CaseIterable {
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

struct VideoManagementToolbar: View {
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
struct SelectionBadge: View {
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

struct ProfileBulkActionButton: View {
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

// MARK: - Full-width single video card (YouTube-like sleek design)
struct FullWidthVideoCard: View {
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
        NotificationCenter.default.post(name: NSNotification.Name("ShowToast"), object: "Video deleted successfully")
    }
}

struct FullWidthThumb: View {
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

struct ProfileVideoContextPreviewCard: View {
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


// ⚡ Advanced table types extracted to ProfileAdvancedTable.swift
