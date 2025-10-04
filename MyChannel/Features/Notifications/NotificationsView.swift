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
    
    var filteredNotifications: [NotificationItem] {
        if selectedFilter == .all {
            return notifications
        } else {
            return notifications.filter { $0.type.rawValue == selectedFilter.rawValue }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(NotificationFilter.allCases, id: \.self) { filter in
                            Button(filter.displayName) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedFilter = filter
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == filter ? AppTheme.Colors.primary : AppTheme.Colors.surface
                            )
                            .foregroundColor(
                                selectedFilter == filter ? .white : AppTheme.Colors.textPrimary
                            )
                            .cornerRadius(AppTheme.CornerRadius.md)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Notifications list
                if filteredNotifications.isEmpty {
                    NotificationsEmptyState()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredNotifications) { notification in
                                NotificationCard(notification: notification) {
                                    // Handle notification tap
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical)
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
                        markAllAsRead()
                    }
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
    }
    
    private func markAllAsRead() {
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications = notifications.map { notification in
                var updated = notification
                updated.isRead = true
                return updated
            }
        }
    }
}

// MARK: - Notification Card
struct NotificationCard: View {
    let notification: NotificationItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Notification icon
                ZStack {
                    Circle()
                        .fill(notification.type.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: notification.type.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(notification.type.color)
                }
                
                // Notification content
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(notification.isRead ? .medium : .semibold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(notification.message)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(3)
                    
                    Text(notification.timestamp.timeAgoDisplay)
                        .font(AppTheme.Typography.caption2)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                
                Spacer()
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            .background(
                notification.isRead ? AppTheme.Colors.background : AppTheme.Colors.surface
            )
            .cornerRadius(AppTheme.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
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
        
        var color: Color {
            switch self {
            case .like: return AppTheme.Colors.primary
            case .comment: return AppTheme.Colors.secondary
            case .follow: return AppTheme.Colors.accent
            case .upload: return AppTheme.Colors.success
            case .live: return AppTheme.Colors.primary
            case .system: return AppTheme.Colors.textSecondary
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
