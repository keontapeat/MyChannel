// ⚡ PERFORMANCE: Extracted from ProfileVideoComponents.swift — independent compilation unit.
// Advanced analytics table types compile in parallel.
import SwiftUI

// MARK: - Advanced View Support Types
struct AdvancedMetrixItem: Identifiable {
    let id: String
}

// MARK: - Advanced Table Column Header
struct AdvancedTableColumnHeader: View {
    @Binding var sortColumn: AdvancedSortColumn
    @Binding var sortAscending: Bool
    @Environment(\.horizontalSizeClass) private var hSizeClass
    // Same widths used in AdvancedVideoTableRow so columns align perfectly
    static let thumbW: CGFloat = 72
    static let thumbSpacing: CGFloat = 10
    static let statW: CGFloat = 44
    static let statWCompact: CGFloat = 40
    static let menuW: CGFloat = 32
    static let hPad: CGFloat = 16

    private var isCompact: Bool { hSizeClass != .regular }
    private var statW: CGFloat { isCompact ? Self.statWCompact : Self.statW }

    private var visibleColumns: [AdvancedSortColumn] {
        isCompact ? [.views, .ctr] : AdvancedSortColumn.allCases
    }

    var body: some View {
        HStack(spacing: 0) {
            // Leading space matching thumbnail + gap (outer hPad applied to the whole row)
            Color.clear
                .frame(width: Self.thumbW + Self.thumbSpacing, height: 1)

            // VIDEO label — flexible, covers title column
            Text("VIDEO")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(visibleColumns, id: \.self) { col in
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if sortColumn == col {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primary)
                        }
                    }
                    .frame(width: statW, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }

            // Spacer matching the 3-dot menu column
            Color.clear.frame(width: Self.menuW, height: 1)
        }
        .padding(.horizontal, Self.hPad)
        .padding(.vertical, 6)
        .background(AppTheme.Colors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 4)
    }
}

// MARK: - Advanced Video Table Row
struct AdvancedVideoTableRow: View {
    let video: Video
    let ownerId: String
    let onMetrixTap: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var showOptions = false
    @State private var showVisibilityPicker = false
    @State private var isSubscribedLocal = false
    @State private var isWatchLaterLocal = false

    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var isCompact: Bool { hSizeClass != .regular }
    private var statW: CGFloat {
        isCompact ? AdvancedTableColumnHeader.statWCompact : AdvancedTableColumnHeader.statW
    }
    private var visibleColumns: [AdvancedSortColumn] {
        isCompact ? [.views, .ctr] : AdvancedSortColumn.allCases
    }

    var body: some View {
        HStack(spacing: 0) {
            // Thumbnail — fixed 72pt, then 10pt gap
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.Colors.textTertiary.opacity(0.12))
                    .overlay(
                        FullWidthThumb(urls: video.posterCandidates)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(width: 72, height: 40)
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
            .padding(.trailing, 10)

            // Title + visibility badge — flexible, takes remaining space
            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 12, weight: .semibold))
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
            .frame(maxWidth: .infinity, alignment: .leading)

            // Stat columns — only show columns matching header
            ForEach(visibleColumns, id: \.self) { col in
                Text(col == .views ? formatViews(video.viewCount) : "—")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: statW, alignment: .trailing)
            }

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
                    .frame(width: AdvancedTableColumnHeader.menuW, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AdvancedTableColumnHeader.hPad)
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

struct AdvancedStatColumn: View {
    let value: String
    let label: String?

    var body: some View {
        Text(value)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .frame(width: 48, alignment: .trailing)
            .lineLimit(1)
    }
}

struct VisibilityBadge: View {
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
