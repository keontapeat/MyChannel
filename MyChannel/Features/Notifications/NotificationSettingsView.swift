//
//  NotificationSettingsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @StateObject private var notificationService = PushNotificationService()
    @State private var preferences = NotificationPreferences()
    @State private var showingPermissionAlert = false
    @State private var animateChanges = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    headerSection
                    permissionSection
                    preferencesSection
                    quietHoursSection
                    analyticsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
        .task {
            await loadNotificationStatus()
        }
        .alert("Enable Notifications", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications to stay updated with your favorite content and live streams.")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .scaleEffect(animateChanges ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animateChanges)
                .onAppear {
                    animateChanges = true
                }
            
            VStack(spacing: 8) {
                Text("Stay Connected")
                    .font(.title2.bold())
                
                Text("Get notified about new videos, live streams, and comments from your favorite creators")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Permission Section
    
    private var permissionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Notification Access")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: notificationService.registeredForNotifications ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(notificationService.registeredForNotifications ? .green : .red)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Push Notifications")
                            .font(.subheadline.weight(.medium))
                        
                        Text(notificationService.registeredForNotifications ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !notificationService.registeredForNotifications {
                        Button("Enable") {
                            Task {
                                let granted = await notificationService.requestNotificationPermissions()
                                if !granted {
                                    showingPermissionAlert = true
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                if notificationService.registeredForNotifications {
                    HStack {
                        Text("Analytics")
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(notificationService.notificationAnalytics.totalDelivered)")
                                .font(.caption.bold())
                            Text("Delivered")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(notificationService.notificationAnalytics.totalOpened)")
                                .font(.caption.bold())
                            Text("Opened")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(notificationService.notificationAnalytics.conversionRate * 100))%")
                                .font(.caption.bold())
                            Text("Rate")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Preferences Section
    
    private var preferencesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Content Preferences")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                PreferenceToggleRow(
                    icon: "video.circle.fill",
                    title: "Video Uploads",
                    subtitle: "New videos from subscribed channels",
                    isOn: $preferences.enableVideoUploads,
                    color: .blue
                )
                
                PreferenceToggleRow(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Live Streams",
                    subtitle: "When creators go live",
                    isOn: $preferences.enableLiveStreams,
                    color: .red
                )
                
                PreferenceToggleRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Comments & Replies",
                    subtitle: "Responses to your comments",
                    isOn: $preferences.enableComments,
                    color: .green
                )
                
                PreferenceToggleRow(
                    icon: "heart.circle.fill",
                    title: "Subscriptions",
                    subtitle: "New subscribers and activity",
                    isOn: $preferences.enableSubscriptions,
                    color: .pink
                )
            }
        }
    }
    
    // MARK: - Quiet Hours Section
    
    private var quietHoursSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quiet Hours")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "moon.circle.fill")
                        .foregroundColor(.indigo)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Do Not Disturb")
                            .font(.subheadline.weight(.medium))
                        Text("Set quiet hours to avoid notifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Start")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        DatePicker(
                            "",
                            selection: $preferences.quietHoursStart,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .scaleEffect(0.9)
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    VStack(spacing: 8) {
                        Text("End")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        DatePicker(
                            "",
                            selection: $preferences.quietHoursEnd,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .scaleEffect(0.9)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Analytics Section
    
    private var analyticsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Active Notifications")
                    .font(.headline)
                Spacer()
                
                Text("\(notificationService.activeNotifications.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            
            if notificationService.activeNotifications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No pending notifications")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(notificationService.activeNotifications.prefix(5)) { notification in
                        ActiveNotificationRow(notification: notification) {
                            notificationService.cancelNotification(identifier: notification.identifier)
                        }
                    }
                    
                    if notificationService.activeNotifications.count > 5 {
                        Text("and \(notificationService.activeNotifications.count - 5) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadNotificationStatus() async {
        await notificationService.getAuthorizationStatus()
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Supporting Views

struct PreferenceToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(width: 30, height: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: color))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ActiveNotificationRow: View {
    let notification: ActiveNotification
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                Text(notification.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(notification.scheduledDate, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Cancel") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onCancel()
                }
            }
            .font(.caption.weight(.medium))
            .foregroundColor(.red)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    NotificationSettingsView()
        .preferredColorScheme(.light)
}
