//
//  ProfileSettingsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var notificationsEnabled: Bool = true
    @State private var privateProfile: Bool = false
    @State private var showAnalytics: Bool = true
    @State private var autoPlayVideos: Bool = true
    @State private var downloadQuality: DownloadQuality = .high
    @State private var showingSignOutAlert: Bool = false
    @State private var showingDeleteAccountAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Account Settings
                    accountSettingsSection
                    
                    // Privacy Settings
                    privacySettingsSection
                    
                    // Content Settings
                    contentSettingsSection
                    
                    // Notification Settings
                    notificationSettingsSection
                    
                    // Danger Zone
                    dangerZoneSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    // Handle account deletion
                    authManager.signOut()
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }
    
    private var accountSettingsSection: some View {
        VStack(spacing: 16) {
            Text("Account")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "person.circle",
                    title: "Edit Profile",
                    subtitle: "Update your profile information",
                    action: {
                        // Handle edit profile
                        HapticManager.shared.impact(style: .light)
                    }
                )
                
                Divider()
                    .padding(.leading, 48)
                
                SettingsRow(
                    icon: "key",
                    title: "Change Password",
                    subtitle: "Update your account password",
                    action: {
                        // Handle password change
                        HapticManager.shared.impact(style: .light)
                    }
                )
                
                Divider()
                    .padding(.leading, 48)
                
                SettingsRow(
                    icon: "envelope",
                    title: "Email Settings",
                    subtitle: "Manage email preferences",
                    action: {
                        // Handle email settings
                        HapticManager.shared.impact(style: .light)
                    }
                )
            }
        }
        .cardStyle()
    }
    
    private var privacySettingsSection: some View {
        VStack(spacing: 16) {
            Text("Privacy")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "lock",
                    title: "Private Profile",
                    subtitle: "Only followers can see your content",
                    isOn: $privateProfile
                )
                
                Divider()
                    .padding(.leading, 48)
                
                SettingsToggleRow(
                    icon: "chart.bar",
                    title: "Show Analytics",
                    subtitle: "Display view counts and engagement",
                    isOn: $showAnalytics
                )
                
                Divider()
                    .padding(.leading, 48)
                
                SettingsRow(
                    icon: "hand.raised",
                    title: "Blocked Users",
                    subtitle: "Manage blocked accounts",
                    action: {
                        // Handle blocked users
                        HapticManager.shared.impact(style: .light)
                    }
                )
            }
        }
        .cardStyle()
    }
    
    private var contentSettingsSection: some View {
        VStack(spacing: 16) {
            Text("Content")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "play.circle",
                    title: "Auto-Play Videos",
                    subtitle: "Videos play automatically",
                    isOn: $autoPlayVideos
                )
                
                Divider()
                    .padding(.leading, 48)
                
                SettingsPickerRow(
                    icon: "arrow.down.circle",
                    title: "Download Quality",
                    subtitle: downloadQuality.displayName,
                    selection: $downloadQuality,
                    options: DownloadQuality.allCases
                )
                
                Divider()
                    .padding(.leading, 48)
                
                SettingsRow(
                    icon: "folder",
                    title: "Downloaded Videos",
                    subtitle: "Manage offline content",
                    action: {
                        // Handle downloaded videos
                        HapticManager.shared.impact(style: .light)
                    }
                )
            }
        }
        .cardStyle()
    }
    
    private var notificationSettingsSection: some View {
        VStack(spacing: 16) {
            Text("Notifications")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "bell",
                    title: "Push Notifications",
                    subtitle: "Receive app notifications",
                    isOn: $notificationsEnabled
                )
                
                Divider()
                    .padding(.leading, 48)
                
                SettingsRow(
                    icon: "bell.badge",
                    title: "Notification Preferences",
                    subtitle: "Choose what notifications to receive",
                    action: {
                        // Handle notification preferences
                        HapticManager.shared.impact(style: .light)
                    }
                )
            }
        }
        .cardStyle()
    }
    
    private var dangerZoneSection: some View {
        VStack(spacing: 16) {
            Text("Account Actions")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.error)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "arrow.right.square",
                    title: "Sign Out",
                    subtitle: "Sign out of your account",
                    titleColor: AppTheme.Colors.error,
                    action: {
                        showingSignOutAlert = true
                        HapticManager.shared.impact(style: .medium)
                    }
                )
                
                Divider()
                    .padding(.leading, 48)
                
                SettingsRow(
                    icon: "trash",
                    title: "Delete Account",
                    subtitle: "Permanently delete your account",
                    titleColor: AppTheme.Colors.error,
                    action: {
                        showingDeleteAccountAlert = true
                        HapticManager.shared.impact(style: .heavy)
                    }
                )
            }
        }
        .cardStyle()
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let titleColor: Color
    let action: () -> Void
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        titleColor: Color = AppTheme.Colors.textPrimary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.titleColor = titleColor
        self.action = action
    }
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(titleColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
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

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Typography.bodyMedium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }
}

struct SettingsPickerRow<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
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
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
        .confirmationDialog(title, isPresented: $showingPicker) {
            ForEach(options, id: \.self) { option in
                Button(option.rawValue.capitalized) {
                    selection = option
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Download Quality Enum
enum DownloadQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium" 
    case high = "high"
    case ultra = "ultra"
    
    var displayName: String {
        switch self {
        case .low: return "Low (480p)"
        case .medium: return "Medium (720p)"
        case .high: return "High (1080p)"
        case .ultra: return "Ultra (4K)"
        }
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(AuthenticationManager.shared)
}