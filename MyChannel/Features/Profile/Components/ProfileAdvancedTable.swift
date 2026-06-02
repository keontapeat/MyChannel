// ⚡ PERFORMANCE: Extracted from ProfileVideoComponents.swift — independent compilation unit.
// Advanced analytics table types compile in parallel.
import SwiftUI

// MARK: - Advanced View Support Types
struct AdvancedMetrixItem: Identifiable {
    let id: String
}

// MARK: - Advanced Analytics Store
// 🔥 YouTube Studio parity: loads real per-video analytics (CTR, avg watch time,
// revenue) for the Advanced table layout and caches them for sorting + display.
@MainActor
final class AdvancedAnalyticsStore: ObservableObject {
    @Published private(set) var analytics: [String: StudioVideoAnalytics] = [:]
    @Published private(set) var isLoading = false

    private var loadedKey: String = ""

    /// Fetches analytics for the provided videos if not already loaded for that set.
    func load(videoIds: [String], dateRange: DateRange = .last28Days, force: Bool = false) async {
        let key = "\(dateRange.rawValue)|\(videoIds.sorted().joined(separator: ","))"
        guard force || key != loadedKey else { return }
        guard !videoIds.isEmpty else {
            analytics = [:]
            loadedKey = key
            return
        }
        isLoading = true
        let fetched = await StudioAnalyticsService.shared.fetchVideoAnalyticsBatch(videoIds: videoIds, dateRange: dateRange)
        analytics = fetched
        loadedKey = key
        isLoading = false
    }

    func analytics(for videoId: String) -> StudioVideoAnalytics? {
        analytics[videoId]
    }

    // MARK: - Sort helpers (return nil when no data → callers fall back to view order)
    func ctr(for videoId: String) -> Double? { analytics[videoId]?.ctr }
    func avgWatchTime(for videoId: String) -> TimeInterval? { analytics[videoId]?.avgViewDuration }
    func revenue(for videoId: String, viewCount: Int) -> Double? {
        guard let rpm = analytics[videoId]?.rpm else { return nil }
        return rpm * Double(viewCount) / 1000.0
    }

    // MARK: - Display formatters
    static func formatCTR(_ ctr: Double?) -> String {
        guard let ctr else { return "—" }
        return String(format: "%.1f%%", ctr * 100)
    }

    static func formatWatchTime(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    static func formatRevenue(_ revenue: Double?) -> String {
        guard let revenue, revenue > 0 else { return "—" }
        if revenue >= 1000 { return String(format: "$%.1fK", revenue / 1000) }
        return String(format: "$%.2f", revenue)
    }
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
    var analytics: StudioVideoAnalytics? = nil
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
                    HStack(spacing: 6) {
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

                        RestrictionsBadge(video: video)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Stat columns — only show columns matching header (real analytics data)
            ForEach(visibleColumns, id: \.self) { col in
                Text(statValue(for: col))
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

    private func statValue(for col: AdvancedSortColumn) -> String {
        switch col {
        case .views:
            return formatViews(video.viewCount)
        case .ctr:
            return AdvancedAnalyticsStore.formatCTR(analytics?.ctr)
        case .watchTime:
            return AdvancedAnalyticsStore.formatWatchTime(analytics?.avgViewDuration)
        case .revenue:
            guard let rpm = analytics?.rpm else { return "—" }
            return AdvancedAnalyticsStore.formatRevenue(rpm * Double(video.viewCount) / 1000.0)
        }
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

// MARK: - Restrictions Badge
// 🔥 YouTube Studio parity: surfaces per-video restrictions in the management list.
struct RestrictionsBadge: View {
    let video: Video

    private struct Restriction: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let color: Color
    }

    private var restrictions: [Restriction] {
        var items: [Restriction] = []
        if video.hasCopyrightStrike == true {
            items.append(.init(icon: "exclamationmark.shield.fill", label: "Copyright", color: .red))
        }
        if video.ageRestricted == true {
            items.append(.init(icon: "18.circle.fill", label: "18+", color: .orange))
        }
        if video.madeForKids == true {
            items.append(.init(icon: "figure.and.child.holdinghands", label: "Kids", color: .blue))
        }
        if let m = video.monetization {
            if !m.isMonetized {
                items.append(.init(icon: "dollarsign.circle", label: "Off", color: AppTheme.Colors.textTertiary))
            }
        }
        return items
    }

    var body: some View {
        if restrictions.isEmpty {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 8))
                Text("None")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(AppTheme.Colors.textTertiary)
        } else {
            HStack(spacing: 4) {
                ForEach(restrictions) { r in
                    HStack(spacing: 3) {
                        Image(systemName: r.icon)
                            .font(.system(size: 8))
                        Text(r.label)
                            .font(.system(size: 10, weight: .semibold))
                            .fixedSize()
                    }
                    .foregroundStyle(r.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(r.color.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
    }
}
