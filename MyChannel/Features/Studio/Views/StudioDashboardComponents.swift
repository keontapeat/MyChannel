// ⚡ PERFORMANCE: Extracted from NuclearYouTubeStudioDashboard.swift — independent compilation unit.
// Data types, stat items, comment rows, idea rows all compile in parallel.
import SwiftUI

// MARK: - Supporting Types
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}

struct StudioDashboardComment: Identifiable {
    let id: String
    let username: String
    let text: String
    let videoTitle: String
    let avatarURL: String
    let timestamp: Date
}

struct RecentSubscriber: Identifiable {
    let id: String
    let displayName: String
    let avatarURL: String
    let subscribedAt: Date
}

struct ContentIdea: Identifiable {
    let id: String
    let title: String
    let description: String
    let trendScore: Double
}

struct CreatorNews: Identifiable {
    let id: String
    let title: String
    let description: String
    let date: Date
    let imageURL: String?
}

// MARK: - Supporting Views
struct AnalyticsStatItem: View {
    let title: String
    let value: String
    let change: Double
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                Text(String(format: "%.1f%%", abs(change)))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity)
    }
}

struct VideoStatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

struct StudioCommentRow: View {
    let comment: StudioDashboardComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(AppTheme.Colors.surface)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(comment.username.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("•")
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(timeAgo(from: comment.timestamp))
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("on \(comment.videoTitle)")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Quick actions
            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "heart")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Button(action: {}) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
}

struct IdeaRow: View {
    let idea: ContentIdea
    
    var body: some View {
        HStack(spacing: 12) {
            // Trend indicator
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(idea.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(idea.description)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Trend score
            Text("\(Int(idea.trendScore * 100))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.orange)
        }
        .padding(.vertical, 8)
    }
}

struct NewsRow: View {
    let news: CreatorNews
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(news.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(news.description)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text(formatDate(news.date))
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Studio Notifications View
struct StudioNotificationsView: View {
    @StateObject private var service = NotificationsInboxService.shared
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if service.notifications.isEmpty && !hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if service.notifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 44))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    Text("No notifications yet")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(service.notifications) { notif in
                        HStack(spacing: 12) {
                            Image(systemName: notifIconName(for: notif.type))
                                .font(.system(size: 18))
                                .foregroundColor(notifTintColor(for: notif.type))
                                .frame(width: 36, height: 36)
                                .background(notifTintColor(for: notif.type).opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(notif.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Text(notif.body)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .lineLimit(2)
                                Text(notifRelativeTime(for: notif.createdAt))
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }

                            Spacer()
                            if !notif.isRead {
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button("Mark Read") {
                                Task { try? await service.markRead(notificationId: notif.id) }
                                HapticManager.shared.impact(style: .light)
                            }
                            .tint(AppTheme.Colors.primary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Mark All Read") {
                    Task { try? await service.markAllRead(userId: AppState.shared.currentUser?.id ?? "") }
                    HapticManager.shared.impact(style: .light)
                }
                .font(.subheadline)
                .disabled(service.notifications.allSatisfy(\.isRead))
            }
        }
        .task {
            if let uid = AppState.shared.currentUser?.id {
                try? await service.fetchNotifications(userId: uid)
            }
            hasLoaded = true
        }
    }

    private func notifIconName(for type: NotificationItem.NotificationType) -> String {
        switch type {
        case .newVideo:    return "play.rectangle.fill"
        case .liveStart:   return "antenna.radiowaves.left.and.right"
        case .comment:     return "bubble.left.fill"
        case .like:        return "hand.thumbsup.fill"
        case .subscriber:  return "person.badge.plus.fill"
        case .mention:     return "at"
        case .system:      return "gear"
        case .milestone:   return "trophy.fill"
        case .storyReply:  return "bubble.right.fill"
        }
    }

    private func notifTintColor(for type: NotificationItem.NotificationType) -> Color {
        switch type {
        case .newVideo:    return .blue
        case .liveStart:   return .red
        case .comment:     return .purple
        case .like:        return .green
        case .subscriber:  return AppTheme.Colors.primary
        case .mention:     return .orange
        case .system:      return .gray
        case .milestone:   return .yellow
        case .storyReply:  return .teal
        }
    }

    private func notifRelativeTime(for date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Studio Comments View
struct StudioCommentsView: View {
    @StateObject private var commentsManager = CommentsManager()
    @State private var filterOption = "All"

    private let filters = ["All", "Recent", "Most Liked"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { f in
                        Button {
                            withAnimation { filterOption = f }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Text(f)
                                .font(.caption.bold())
                                .foregroundColor(filterOption == f ? .white : AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(filterOption == f ? AppTheme.Colors.primary : AppTheme.Colors.surface))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }

            if commentsManager.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredComments.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 44))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    Text("No comments yet")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredComments) { comment in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                AsyncImage(url: URL(string: comment.author.profileImageURL ?? "")) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle().fill(AppTheme.Colors.surface)
                                        .overlay(Image(systemName: "person.fill")
                                            .foregroundColor(AppTheme.Colors.textTertiary))
                                }
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())

                                Text(comment.author.displayName)
                                    .font(.system(size: 13, weight: .semibold))

                                Spacer()

                                Text(comment.timeAgo)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }

                            Text(comment.text)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .lineLimit(3)

                            HStack(spacing: 16) {
                                Label("\(comment.likeCount)", systemImage: "hand.thumbsup")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                                Label("\(comment.replyCount)", systemImage: "bubble.right")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let uid = AppState.shared.currentUser?.id {
                try? await commentsManager.loadCommentsForCreator(creatorId: uid)
            }
        }
    }

    private var filteredComments: [VideoComment] {
        switch filterOption {
        case "Recent":    return commentsManager.comments.sorted { $0.createdAt > $1.createdAt }
        case "Most Liked": return commentsManager.comments.sorted { $0.likeCount > $1.likeCount }
        default:          return commentsManager.comments
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        NuclearYouTubeStudioDashboard()
            .environmentObject(AppState.shared)
    }
}


