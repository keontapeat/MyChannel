//
//  NotificationPreferencesView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import UserNotifications

struct NotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    // Push Notification Settings
    @State private var pushNotificationsEnabled: Bool = true
    @State private var systemNotificationsStatus: UNAuthorizationStatus = .notDetermined
    
    // Content Notifications
    @State private var newVideoNotifications: Bool = true
    @State private var liveStreamNotifications: Bool = true
    @State private var premiumContentNotifications: Bool = false
    @State private var channelUpdatesNotifications: Bool = true
    
    // Social Notifications
    @State private var commentNotifications: Bool = true
    @State private var likeNotifications: Bool = false
    @State private var followNotifications: Bool = true
    @State private var mentionNotifications: Bool = true
    @State private var replyNotifications: Bool = true
    
    // Activity Notifications
    @State private var watchLaterReminders: Bool = true
    @State private var subscriptionReminders: Bool = false
    @State private var trendingNotifications: Bool = false
    @State private var recommendationNotifications: Bool = true
    
    // Timing Settings
    @State private var quietHoursEnabled: Bool = false
    @State private var quietStartTime: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @State private var quietEndTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var weekendNotifications: Bool = true
    
    // Frequency Settings
    @State private var notificationFrequency: NotificationFrequency = .immediate
    @State private var digestFrequency: DigestFrequency = .daily
    
    @State private var showingPermissionAlert: Bool = false
    @State private var showingSuccessAlert: Bool = false
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // System Permission Section
                    systemPermissionSection
                    
                    // Content Notifications Section
                    contentNotificationsSection
                    
                    // Social Notifications Section
                    socialNotificationsSection
                    
                    // Activity Notifications Section
                    activityNotificationsSection
                    
                    // Timing Settings Section
                    timingSettingsSection
                    
                    // Frequency Settings Section
                    frequencySettingsSection
                    
                    // Quick Actions Section
                    quickActionsSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                checkNotificationPermissions()
            }
            .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Settings") {
                    openSystemSettings()
                }
            } message: {
                Text("To receive notifications, please enable them in Settings > MyChannel > Notifications")
            }
            .alert("Preferences Saved", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your notification preferences have been updated successfully.")
            }
        }
    }
    
    // MARK: - System Permission Section
    private var systemPermissionSection: some View {
        VStack(spacing: 20) {
            // Header with status indicator
            HStack(spacing: 12) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 24))
                    .foregroundColor(systemNotificationsStatus == .authorized ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Push Notifications")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(systemPermissionStatusText)
                        .font(.system(size: 14))
                        .foregroundColor(systemNotificationsStatus == .authorized ? .green : .orange)
                }
                
                Spacer()
                
                if systemNotificationsStatus != .authorized {
                    Button("Enable") {
                        requestNotificationPermission()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(16)
            
            // System notification toggle (only if authorized)
            if systemNotificationsStatus == .authorized {
                NotificationToggleRow(
                    icon: "app.badge",
                    title: "App Notifications",
                    subtitle: "Allow MyChannel to send you notifications",
                    isOn: $pushNotificationsEnabled,
                    prominence: .primary
                )
            }
        }
    }
    
    // MARK: - Content Notifications Section
    private var contentNotificationsSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Content Updates")
            
            VStack(spacing: 0) {
                NotificationToggleRow(
                    icon: "play.rectangle",
                    title: "New Videos",
                    subtitle: "When channels you follow upload new videos",
                    isOn: $newVideoNotifications
                )
                
                Divider().padding(.leading, 64)
                
                NotificationToggleRow(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Live Streams",
                    subtitle: "When channels you follow go live",
                    isOn: $liveStreamNotifications
                )
                
                Divider().padding(.leading, 64)
                
                NotificationToggleRow(
                    icon: "crown",
                    title: "Premium Content",
                    subtitle: "Exclusive content for premium subscribers",
                    isOn: $premiumContentNotifications
                )
                
                Divider().padding(.leading, 64)
                
                NotificationToggleRow(
                    icon: "megaphone",
                    title: "Channel Announcements",
                    subtitle: "Important updates from channels you follow",
                    isOn: $channelUpdatesNotifications
                )
            }
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Social Notifications Section
    private var socialNotificationsSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Social Activity")
            
            VStack(spacing: 0) {
                NotificationToggleRow(
                    icon: "bubble.left",
                    title: "Comments",
                    subtitle: "Someone comments on your videos",
                    isOn: $commentNotifications
                )
                
                Divider().padding(.leading, 64)
                
                NotificationToggleRow(
                    icon: "heart",
                    title: "Likes",
                    subtitle: "Someone likes your content",
                    isOn: $likeNotifications
                )
                
                Divider().padding(.leading, 64)
                
                NotificationToggleRow(
                    icon: "person.badge.plus",
                    title: "New Followers",
                    subtitle: "Someone starts following you",
                    isOn: $followNotifications
                )
                
                Divider().padding(.leading, 64)
                
                NotificationToggleRow(
                    icon: "at",
                    title: "Mentions",
                    subtitle: "When someone mentions you in comments",
                    isOn: $mentionNotifications
                )
                
                Divider().padding(.leading, 64)
                
                NotificationToggleRow(
                    icon: "arrowshape.turn.up.left",
                    title: "Replies",
                    subtitle: "Replies to your comments",
                    isOn: $replyNotifications
                )
            }
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Activity Notifications Section
    private var activityNotificationsSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Personal Activity")
            
            VStack(spacing: 0) {
                NotificationToggleRow(
                    icon: "clock.badge.checkmark",
                    title: "Watch Later Reminders",
                    subtitle: "Reminds you about videos in your Watch Later list",
                    isOn: $watchLaterReminders
                )
                
                Divider().padding(.leading, 64)
                
                NotificationToggleRow(
                    icon: "calendar.badge.plus",
                    title: "Subscription Reminders",
                    subtitle: "Reminds you about subscription renewals",
                    isOn: $subscriptionReminders
                )
                
                Divider().padding(.leading, 64)
                
                NotificationToggleRow(
                    icon: "flame",
                    title: "Trending Content",
                    subtitle: "Popular videos in your interests",
                    isOn: $trendingNotifications
                )
                
                Divider().padding(.leading, 64)
                
                NotificationToggleRow(
                    icon: "lightbulb",
                    title: "Recommendations",
                    subtitle: "Personalized content suggestions",
                    isOn: $recommendationNotifications
                )
            }
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Timing Settings Section
    private var timingSettingsSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Timing & Schedule")
            
            VStack(spacing: 16) {
                // Quiet Hours Toggle
                NotificationToggleRow(
                    icon: "moon",
                    title: "Quiet Hours",
                    subtitle: "Pause notifications during specific hours",
                    isOn: $quietHoursEnabled
                )
                
                // Quiet Hours Time Settings (only shown if enabled)
                if quietHoursEnabled {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start Time")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                DatePicker(
                                    "",
                                    selection: $quietStartTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("End Time")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                DatePicker(
                                    "",
                                    selection: $quietEndTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.cardBackground)
                        .cornerRadius(12)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Weekend Notifications
                NotificationToggleRow(
                    icon: "calendar",
                    title: "Weekend Notifications",
                    subtitle: "Receive notifications on weekends",
                    isOn: $weekendNotifications
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: quietHoursEnabled)
    }
    
    // MARK: - Frequency Settings Section
    private var frequencySettingsSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Delivery Settings")
            
            VStack(spacing: 16) {
                // Notification Frequency Picker
                NotificationPickerRow(
                    icon: "timer",
                    title: "Notification Timing",
                    subtitle: notificationFrequency.description,
                    selection: $notificationFrequency,
                    options: NotificationFrequency.allCases
                )
                
                // Digest Frequency Picker
                NotificationPickerRow(
                    icon: "newspaper",
                    title: "Summary Digest",
                    subtitle: digestFrequency.description,
                    selection: $digestFrequency,
                    options: DigestFrequency.allCases
                )
            }
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Quick Actions")
            
            VStack(spacing: 12) {
                QuickActionButton(
                    icon: "checkmark.circle",
                    title: "Enable All",
                    subtitle: "Turn on all notification types",
                    color: .green
                ) {
                    enableAllNotifications()
                }
                
                QuickActionButton(
                    icon: "xmark.circle",
                    title: "Disable All",
                    subtitle: "Turn off all notification types",
                    color: .red
                ) {
                    disableAllNotifications()
                }
                
                QuickActionButton(
                    icon: "arrow.clockwise",
                    title: "Reset to Defaults",
                    subtitle: "Restore recommended settings",
                    color: AppTheme.Colors.primary
                ) {
                    resetToDefaults()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var systemPermissionStatusText: String {
        switch systemNotificationsStatus {
        case .authorized:
            return "Notifications enabled"
        case .denied:
            return "Notifications disabled in Settings"
        case .notDetermined:
            return "Permission not requested"
        case .provisional:
            return "Quiet notifications enabled"
        case .ephemeral:
            return "Temporary authorization"
        @unknown default:
            return "Unknown status"
        }
    }
    
    // MARK: - Helper Methods
    private func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                systemNotificationsStatus = settings.authorizationStatus
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    systemNotificationsStatus = .authorized
                    pushNotificationsEnabled = true
                } else {
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func openSystemSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func savePreferences() {
        isLoading = true
        HapticManager.shared.impact(style: .medium)
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
            showingSuccessAlert = true
        }
    }
    
    private func enableAllNotifications() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Content notifications
            newVideoNotifications = true
            liveStreamNotifications = true
            premiumContentNotifications = true
            channelUpdatesNotifications = true
            
            // Social notifications
            commentNotifications = true
            likeNotifications = true
            followNotifications = true
            mentionNotifications = true
            replyNotifications = true
            
            // Activity notifications
            watchLaterReminders = true
            subscriptionReminders = true
            trendingNotifications = true
            recommendationNotifications = true
        }
        
        HapticManager.shared.impact(style: .light)
    }
    
    private func disableAllNotifications() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Content notifications
            newVideoNotifications = false
            liveStreamNotifications = false
            premiumContentNotifications = false
            channelUpdatesNotifications = false
            
            // Social notifications
            commentNotifications = false
            likeNotifications = false
            followNotifications = false
            mentionNotifications = false
            replyNotifications = false
            
            // Activity notifications
            watchLaterReminders = false
            subscriptionReminders = false
            trendingNotifications = false
            recommendationNotifications = false
        }
        
        HapticManager.shared.impact(style: .light)
    }
    
    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Content notifications - mostly enabled by default
            newVideoNotifications = true
            liveStreamNotifications = true
            premiumContentNotifications = false
            channelUpdatesNotifications = true
            
            // Social notifications - selective defaults
            commentNotifications = true
            likeNotifications = false
            followNotifications = true
            mentionNotifications = true
            replyNotifications = true
            
            // Activity notifications - helpful defaults
            watchLaterReminders = true
            subscriptionReminders = false
            trendingNotifications = false
            recommendationNotifications = true
            
            // Timing settings
            quietHoursEnabled = false
            weekendNotifications = true
            
            // Frequency settings
            notificationFrequency = .immediate
            digestFrequency = .daily
        }
        
        HapticManager.shared.impact(style: .light)
    }
}

// MARK: - Notification Toggle Row
struct NotificationToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let prominence: NotificationProminence
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        prominence: NotificationProminence = .normal
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.prominence = prominence
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBackgroundColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: prominence == .primary ? .semibold : .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .scaleEffect(prominence == .primary ? 1.0 : 0.9)
                .onChange(of: isOn) { _, _ in
                    HapticManager.shared.impact(style: .light)
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(prominence == .primary ? AppTheme.Colors.primary.opacity(0.05) : Color.clear)
    }
    
    private var iconColor: Color {
        switch prominence {
        case .primary: return AppTheme.Colors.primary
        case .normal: return AppTheme.Colors.primary
        }
    }
    
    private var iconBackgroundColor: Color {
        switch prominence {
        case .primary: return AppTheme.Colors.primary
        case .normal: return AppTheme.Colors.primary
        }
    }
}

// MARK: - Notification Picker Row
struct NotificationPickerRow<T: CaseIterable & Hashable & CustomStringConvertible>: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var selection: T
    let options: [T]
    
    @State private var showingPicker: Bool = false
    
    var body: some View {
        Button {
            showingPicker = true
            HapticManager.shared.impact(style: .light)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog(title, isPresented: $showingPicker) {
            ForEach(options, id: \.self) { option in
                Button(option.description) {
                    selection = option
                    HapticManager.shared.impact(style: .light)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(12)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Supporting Enums
enum NotificationProminence {
    case normal
    case primary
}

enum NotificationFrequency: String, CaseIterable, CustomStringConvertible {
    case immediate = "immediate"
    case bundled = "bundled"
    case hourly = "hourly"
    case daily = "daily"
    
    var description: String {
        switch self {
        case .immediate: return "Send immediately"
        case .bundled: return "Bundle similar notifications"
        case .hourly: return "Send hourly summaries"
        case .daily: return "Send daily summaries"
        }
    }
}

enum DigestFrequency: String, CaseIterable, CustomStringConvertible {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case disabled = "disabled"
    
    var description: String {
        switch self {
        case .daily: return "Daily digest at 9 AM"
        case .weekly: return "Weekly digest on Sunday"
        case .monthly: return "Monthly digest on 1st"
        case .disabled: return "No digest emails"
        }
    }
}

#Preview {
    NotificationPreferencesView()
        .environmentObject(AuthenticationManager.shared)
}