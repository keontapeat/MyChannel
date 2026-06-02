//
//  SubscribedChannelCard.swift
//  MyChannel
//
//  YouTube-style subscribed channel card with notification management
//

import SwiftUI

struct SubscribedChannelCard: View {
    let channel: User
    let notificationLevel: SubscriptionsViewModel.NotificationLevel
    let onUnsubscribe: () -> Void
    let onNotificationChange: (SubscriptionsViewModel.NotificationLevel) -> Void
    var onOpen: () -> Void = {}
    
    @State private var showNotificationMenu = false
    @State private var showUnsubscribeConfirmation = false
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .light)
            onOpen()
        } label: {
            HStack(spacing: 12) {
                // Channel avatar
                CachedAsyncImage(url: URL(string: channel.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                )
                
                // Channel info
                VStack(alignment: .leading, spacing: 4) {
                    // Display name
                    HStack(spacing: 6) {
                        Text(channel.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                        
                        if channel.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    
                    // Username
                    Text("@\(channel.username)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    // Subscriber count
                    Text("\(formatCount(channel.subscriberCount)) subscribers")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 8) {
                    // Notification button
                    Button(action: {
                        showNotificationMenu = true
                    }) {
                        Image(systemName: notificationLevel.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(notificationLevel == .all ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // More options (unsubscribe)
                    Button(action: {
                        showUnsubscribeConfirmation = true
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.surface)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog(
            "Notification Settings",
            isPresented: $showNotificationMenu,
            titleVisibility: .visible
        ) {
            ForEach([SubscriptionsViewModel.NotificationLevel.all,
                     SubscriptionsViewModel.NotificationLevel.personalized,
                     SubscriptionsViewModel.NotificationLevel.none], id: \.self) { level in
                Button(role: .none) {
                    onNotificationChange(level)
                } label: {
                    HStack {
                        Image(systemName: level.icon)
                        Text(level.rawValue)
                    }
                }
            }
        } message: {
            Text("Choose how you want to be notified about new videos from \(channel.displayName)")
        }
        .confirmationDialog(
            "Unsubscribe from \(channel.displayName)?",
            isPresented: $showUnsubscribeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unsubscribe", role: .destructive) {
                onUnsubscribe()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You won't get notifications about their new videos anymore.")
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

#Preview {
    SubscribedChannelCard(
        channel: User.sampleUsers[0],
        notificationLevel: .all,
        onUnsubscribe: { print("Unsubscribe") },
        onNotificationChange: { level in print("Changed to \(level)") }
    )
    .padding()
    .background(AppTheme.Colors.background)
}

