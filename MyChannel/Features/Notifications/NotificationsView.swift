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
                // YouTube-style filter tabs with bottom border indicators
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(NotificationFilter.allCases, id: \.self) { filter in
                            Button(action: {
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
                            ForEach(filteredNotifications) { notification in
                                NotificationCard(notification: notification) {
                                    // Handle notification tap
                                }
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
                        markAllAsRead()
                    }
                    .font(.system(size: 14, weight: .medium))
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
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 8, height: 8)
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
