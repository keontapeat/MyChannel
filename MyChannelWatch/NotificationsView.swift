// NotificationsView.swift
// YouTube watchOS parity: notification inbox with tap-to-open-on-phone.

import SwiftUI
import WatchKit

struct NotificationsView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        NavigationStack {
            Group {
                if store.notifications.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No notifications")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(store.notifications) { notif in
                        NotificationRow(notif: notif)
                            .onTapGesture {
                                store.markNotificationRead(notif.id)
                                if !notif.videoId.isEmpty {
                                    store.openVideo(notif.videoId)
                                }
                                WKInterfaceDevice.current().play(.click)
                            }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle(
                store.unreadNotifications > 0
                    ? "Alerts (\(store.unreadNotifications))"
                    : "Alerts"
            )
            .refreshable {
                await store.loadFeedFromFirestore()
            }
        }
    }
}

private struct NotificationRow: View {
    let notif: WatchNotification

    var body: some View {
        HStack(spacing: 8) {
            // Unread indicator
            Circle()
                .fill(notif.isRead ? Color.clear : Color.red)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(notif.title)
                    .font(.footnote.bold())
                    .lineLimit(1)
                    .opacity(notif.isRead ? 0.6 : 1)

                Text(notif.body)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(relativeDate(notif.createdAt))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func relativeDate(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
