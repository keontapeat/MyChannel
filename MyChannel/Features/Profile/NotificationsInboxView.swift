import SwiftUI

struct NotificationsInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var inbox = NotificationsInboxService.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(inbox.notifications) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(for: item.type))
                            .foregroundColor(.blue)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.subheadline.weight(.semibold))
                            Text(item.body).font(.caption).foregroundColor(.secondary)
                            Text(item.createdAt, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !item.isRead {
                            Circle().fill(Color.blue).frame(width: 8, height: 8)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { try? await inbox.markRead(notificationId: item.id) }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.Colors.surface, in: Circle())
                    }
                }
            }
        }
        .task {
            if let uid = appState.currentUser?.id {
                try? await inbox.fetchNotifications(userId: uid)
            }
        }
    }

    private func icon(for type: NotificationItem.NotificationType) -> String {
        switch type {
        case .like: return "heart.fill"
        case .comment: return "bubble.right.fill"
        case .newVideo: return "arrow.up.circle.fill"
        case .liveStart: return "livephoto"
        case .subscriber: return "person.badge.plus"
        case .mention: return "at"
        case .system: return "gear"
        case .milestone: return "flag.fill"
        }
    }
}




