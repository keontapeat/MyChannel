//
//  NotificationsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

// MARK: - NotificationsView

struct NotificationsView: View {
    @StateObject private var store = NotificationsStore.shared
    @State private var selectedFilter: NotificationFilter = .all
    @State private var hasAppeared = false
    @State private var showingSettings = false

    // MARK: Filtered + grouped

    private var filtered: [StoreNotificationItem] {
        guard selectedFilter != .all else { return store.items }
        return store.items.filter { $0.type.rawValue == selectedFilter.rawValue }
    }

    private var todayItems: [StoreNotificationItem] {
        filtered.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var earlierItems: [StoreNotificationItem] {
        filtered.filter { !Calendar.current.isDateInToday($0.timestamp) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterTabBar
                Divider().opacity(0.12)
                contentBody
            }
            .background(Color(.systemBackground))
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingSettings) {
                NotificationSettingsView()
            }
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    withAnimation { hasAppeared = true }
                }
            }
        }
    }

    // MARK: - Filter Tab Bar

    private var filterTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NotificationFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func filterChip(_ filter: NotificationFilter) -> some View {
        let isSelected = selectedFilter == filter
        Button {
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.displayName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? AppTheme.Colors.primary : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentBody: some View {
        if filtered.isEmpty {
            NotificationsEmptyState()
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if !todayItems.isEmpty {
                        notifSection(title: "Today", items: todayItems, offset: 0)
                    }
                    if !earlierItems.isEmpty {
                        notifSection(title: "Earlier", items: earlierItems, offset: todayItems.count)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    private func notifSection(title: String, items: [StoreNotificationItem], offset: Int) -> some View {
        Section {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                StoreNotificationCard(
                    item: item,
                    onTap: {
                        HapticManager.shared.impact(style: .light)
                        store.markRead(item.id)
                    },
                    onDelete: {
                        HapticManager.shared.notification(type: .warning)
                        store.delete(item.id)
                    }
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 16)
                .animation(
                    .spring(response: 0.38, dampingFraction: 0.82)
                    .delay(Double(offset + idx) * 0.04),
                    value: hasAppeared
                )

                if idx < items.count - 1 {
                    Divider()
                        .padding(.leading, 72)
                        .opacity(0.08)
                }
            }
        } header: {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                Spacer()
            }
            .background(Color(.systemBackground).opacity(0.95))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 14) {
                if store.unreadCount > 0 {
                    Button {
                        HapticManager.shared.notification(type: .success)
                        store.markAllRead()
                    } label: {
                        Text("Mark all read")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

// MARK: - StoreNotificationCard (ML Agent connected, YouTube-level)

struct StoreNotificationCard: View {
    let item: StoreNotificationItem
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var swipeOffset: CGFloat = 0
    @State private var isSwiping = false
    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete reveal layer
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Delete")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 72)
                .frame(maxHeight: .infinity)
                .background(Color.red)
            }
            .opacity(swipeOffset < -8 ? 1 : 0)

            // Card
            Button {
                guard !isSwiping else { return }
                onTap()
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    // Icon with source color
                    ZStack {
                        Circle()
                            .fill(sourceColor(item.source).opacity(0.12))
                            .frame(width: 46, height: 46)
                        Image(systemName: iconName(item.type, source: item.source))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(sourceColor(item.source))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // Title row
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(item.title)
                                .font(.system(size: 15, weight: item.isRead ? .regular : .semibold))
                                .foregroundColor(item.isRead ? .secondary : .primary)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }

                        // Message
                        Text(item.message)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        // Footer: time + smart badges
                        HStack(spacing: 6) {
                            Text(item.timestamp.timeAgoDisplay)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.7))
                            // ML source badge (Trending / New for you)
                            sourceBadge(item.source)
                            // Grouped count badge (e.g. "5 likes")
                            groupBadge(count: item.groupCount, type: item.type)
                        }
                    }

                    // Unread dot
                    VStack {
                        if !item.isRead {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: 8, height: 8)
                        }
                        Spacer()
                    }
                    .frame(width: 10)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    item.isRead
                        ? Color(.systemBackground)
                        : AppTheme.Colors.primary.opacity(0.03)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isPressed)
            .offset(x: swipeOffset)
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { val in
                        isSwiping = true
                        if val.translation.width < 0 {
                            swipeOffset = max(val.translation.width, -80)
                        }
                    }
                    .onEnded { val in
                        if val.translation.width < -55 {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                swipeOffset = -400
                            }
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 220_000_000)
                                onDelete()
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                swipeOffset = 0
                            }
                        }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 120_000_000)
                            isSwiping = false
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        }
        .clipped()
    }

    // MARK: - Helpers

    /// Small "🔥 Trending" badge shown only for ML-sourced items
    @ViewBuilder
    private func sourceBadge(_ source: NotificationSource) -> some View {
        switch source {
        case .viralAgent:
            Label("Trending", systemImage: "flame.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
        case .recommendAgent:
            Label("New for you", systemImage: "sparkles")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.blue)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(Color.blue.opacity(0.12)))
        default:
            EmptyView()
        }
    }

    /// Grouped count chip: "3 likes"
    @ViewBuilder
    private func groupBadge(count: Int, type: StoreNotificationType) -> some View {
        if count > 1 {
            Text("\(count) \(groupLabel(type))")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(typeColor(type))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(typeColor(type).opacity(0.12)))
        }
    }

    private func groupLabel(_ type: StoreNotificationType) -> String {
        switch type {
        case .like:    return "likes"
        case .comment: return "comments"
        case .follow:  return "follows"
        case .upload:  return "videos"
        case .live:    return "live"
        case .system:  return "alerts"
        }
    }

    private func iconName(_ type: StoreNotificationType, source: NotificationSource) -> String {
        switch source {
        case .viralAgent:     return "flame.fill"
        case .liveAgent:      return "dot.radiowaves.left.and.right"
        case .recommendAgent: return "sparkles"
        case .user:
            switch type {
            case .like:    return "heart.fill"
            case .comment: return "bubble.right.fill"
            case .follow:  return "person.badge.plus"
            case .upload:  return "arrow.up.circle.fill"
            case .live:    return "dot.radiowaves.left.and.right"
            case .system:  return "gear"
            }
        }
    }

    private func typeColor(_ type: StoreNotificationType) -> Color {
        switch type {
        case .like:    return AppTheme.Colors.primary
        case .comment: return .blue
        case .follow:  return .green
        case .upload:  return .purple
        case .live:    return .red
        case .system:  return .secondary
        }
    }

    private func sourceColor(_ source: NotificationSource) -> Color {
        switch source {
        case .user:           return typeColor(item.type)
        case .viralAgent:     return .orange
        case .liveAgent:      return .red
        case .recommendAgent: return .blue
        }
    }
}

// MARK: - Legacy NotificationCard (kept for backward compat)

struct NotificationCard: View {
    let notification: LegacyNotificationItem
    let onTap: () -> Void
    var onSwipeDelete: (() -> Void)? = nil
    
    @State private var isPressed = false
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    var body: some View {
        ZStack {
            // 🔥 PREMIUM: Delete background (revealed on swipe)
            HStack {
                Spacer()
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.red)
            .cornerRadius(12)
            
            // Main card content
            Button(action: {
                guard !isSwiping else { return }
                onTap()
            }) {
                HStack(spacing: 12) {
                    // Notification icon - neutral gray background
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: notification.type.iconName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    // Notification content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                        
                        Text(notification.message)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(3)
                        
                        Text(notification.timestamp.timeAgoDisplay)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    
                    Spacer()
                    
                    // 🔥 PREMIUM: Pulsing unread indicator
                    if !notification.isRead {
                        PulsingUnreadDot()
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            // 🔥 PREMIUM: Press scale effect
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        isSwiping = true
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -80)
                        }
                    }
                    .onEnded { value in
                        if value.translation.width < -60 {
                            // 🔥 PREMIUM: Swipe to delete
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = -400
                            }
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 200_000_000)
                                onSwipeDelete?()
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = 0
                            }
                        }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            isSwiping = false
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// 🔥 PREMIUM: Pulsing Unread Dot
struct PulsingUnreadDot: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .fill(AppTheme.Colors.primary.opacity(0.3))
                .frame(width: 16, height: 16)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.6)
            
            // Inner dot
            Circle()
                .fill(AppTheme.Colors.primary)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: false)
            ) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Notifications Empty State
struct NotificationsEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No notifications yet")
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("When you get notifications, they'll show up here")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Supporting Models
struct LegacyNotificationItem: Identifiable {
    let id: String = UUID().uuidString
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    let type: NotificationType
    
    enum NotificationType: String, CaseIterable {
        case like = "like"
        case comment = "comment"
        case follow = "follow"
        case upload = "upload"
        case live = "live"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .like: return "Likes"
            case .comment: return "Comments"
            case .follow: return "Follows"
            case .upload: return "Uploads"
            case .live: return "Live"
            case .system: return "System"
            }
        }
        
        var iconName: String {
            switch self {
            case .like: return "heart.fill"
            case .comment: return "bubble.right.fill"
            case .follow: return "person.badge.plus"
            case .upload: return "arrow.up.circle.fill"
            case .live: return "dot.radiowaves.left.and.right"
            case .system: return "gear"
            }
        }
    }
    
    static let sampleNotifications: [LegacyNotificationItem] = [
        LegacyNotificationItem(
            title: "New like on your video",
            message: "Tech Creator liked your video 'Building the Future of SwiftUI'",
            timestamp: Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date(),
            isRead: false,
            type: .like
        ),
        LegacyNotificationItem(
            title: "New comment",
            message: "Creative Artist commented: 'Amazing tutorial! Really helped me understand the concepts better.'",
            timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            isRead: false,
            type: .comment
        ),
        LegacyNotificationItem(
            title: "New follower",
            message: "Gaming Pro started following you",
            timestamp: Calendar.current.date(byAdding: .hour, value: -5, to: Date()) ?? Date(),
            isRead: true,
            type: .follow
        ),
        LegacyNotificationItem(
            title: "Video uploaded",
            message: "Music Maker uploaded a new video: 'Beat Making Tutorial'",
            timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            isRead: true,
            type: .upload
        )
    ]
}

enum NotificationFilter: String, CaseIterable {
    case all = "all"
    case like = "like"
    case comment = "comment"
    case follow = "follow"
    case upload = "upload"
    case live = "live"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .like: return "Likes"
        case .comment: return "Comments"
        case .follow: return "Follows"
        case .upload: return "Uploads"
        case .live: return "Live"
        case .system: return "System"
        }
    }
}

#Preview {
    NotificationsView()
}
