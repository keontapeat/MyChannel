//
//  NotificationsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct NotificationsView: View {
    @State private var notifications: [NotificationItem] = NotificationItem.sampleNotifications
    @State private var selectedFilter: NotificationFilter = .all
    @State private var hasAppeared = false
    
    var filteredNotifications: [NotificationItem] {
        if selectedFilter == .all {
            return notifications
        } else {
            return notifications.filter { $0.type.rawValue == selectedFilter.rawValue }
        }
    }
    
    // 🔥 PREMIUM: Count of unread notifications
    private var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 🔥 PREMIUM: YouTube-style filter tabs with haptics
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(NotificationFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                // 🔥 PREMIUM: Haptic on filter change
                                HapticManager.shared.impact(style: .light)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedFilter = filter
                                }
                            }) {
                                VStack(spacing: 0) {
                                    Text(filter.displayName)
                                        .font(.system(size: 15, weight: selectedFilter == filter ? .semibold : .regular))
                                        .foregroundColor(
                                            selectedFilter == filter ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary
                                        )
                                        .padding(.horizontal, 16)
                                        .frame(height: 48)
                                    
                                    // Bottom border indicator
                                    Rectangle()
                                        .fill(AppTheme.Colors.primary)
                                        .frame(height: 2)
                                        .scaleEffect(x: selectedFilter == filter ? 1.0 : 0.0, y: 1.0, anchor: .center)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 50)
                .background(AppTheme.Colors.background)
                
                Divider()
                    .background(AppTheme.Colors.divider.opacity(0.1))
                
                // Notifications list
                if filteredNotifications.isEmpty {
                    NotificationsEmptyState()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredNotifications.enumerated()), id: \.element.id) { index, notification in
                                NotificationCard(
                                    notification: notification,
                                    onTap: {
                                        // 🔥 PREMIUM: Haptic on tap
                                        HapticManager.shared.impact(style: .light)
                                        markAsRead(notification.id)
                                    },
                                    onSwipeDelete: {
                                        // 🔥 PREMIUM: Haptic on delete
                                        HapticManager.shared.notification(type: .warning)
                                        deleteNotification(notification.id)
                                    }
                                )
                                // 🔥 PREMIUM: Staggered appear animation
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 20)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.05),
                                    value: hasAppeared
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
                
                Spacer()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mark all read") {
                        // 🔥 PREMIUM: Success haptic
                        HapticManager.shared.notification(type: .success)
                        markAllAsRead()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .onAppear {
                // 🔥 PREMIUM: Trigger staggered animation on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hasAppeared = true
                }
            }
        }
    }
    
    private func markAllAsRead() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            notifications = notifications.map { notification in
                var updated = notification
                updated.isRead = true
                return updated
            }
        }
    }
    
    private func markAsRead(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if let index = notifications.firstIndex(where: { $0.id == id }) {
                notifications[index].isRead = true
            }
        }
    }
    
    private func deleteNotification(_ id: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            notifications.removeAll { $0.id == id }
        }
    }
}

// MARK: - 🔥 PREMIUM: Notification Card with Animations
struct NotificationCard: View {
    let notification: NotificationItem
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onSwipeDelete?()
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = 0
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
struct NotificationItem: Identifiable {
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
    
    static let sampleNotifications: [NotificationItem] = [
        NotificationItem(
            title: "New like on your video",
            message: "Tech Creator liked your video 'Building the Future of SwiftUI'",
            timestamp: Calendar.current.date(byAdding: .minute, value: -30, to: Date()) ?? Date(),
            isRead: false,
            type: .like
        ),
        NotificationItem(
            title: "New comment",
            message: "Creative Artist commented: 'Amazing tutorial! Really helped me understand the concepts better.'",
            timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            isRead: false,
            type: .comment
        ),
        NotificationItem(
            title: "New follower",
            message: "Gaming Pro started following you",
            timestamp: Calendar.current.date(byAdding: .hour, value: -5, to: Date()) ?? Date(),
            isRead: true,
            type: .follow
        ),
        NotificationItem(
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
