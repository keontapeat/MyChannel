//
//  SafeProfileSettingsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

// MARK: - Safe Profile Settings View
struct SafeProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        SafeViewWrapper {
            ProfileSettingsView(dismiss: dismiss)
        } fallback: {
            ProfileSettingsFallbackView(dismiss: dismiss)
        }
    }
}

// MARK: - Profile Settings View
struct ProfileSettingsView: View {
    let dismiss: DismissAction
    
    @State private var notificationsEnabled = true
    @State private var autoPlayEnabled = true
    @State private var darkModeEnabled = false
    @State private var qualityPreference = "Auto"
    @State private var showingAccountDeletion = false
    @State private var showingSignOutConfirmation = false
    
    private let qualityOptions = ["Auto", "720p", "1080p", "4K"]
    
    var body: some View {
        NavigationView {
            List {
                // Account Section
                accountSection
                
                // Preferences Section
                preferencesSection
                
                // Privacy Section
                privacySection
                
                // About Section
                aboutSection
                
                // Danger Zone
                dangerZoneSection
            }
            .listStyle(InsetGroupedListStyle())
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
        .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                // Handle sign out
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .confirmationDialog("Delete Account", isPresented: $showingAccountDeletion) {
            Button("Delete Account", role: .destructive) {
                // Handle account deletion
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. Your account and all data will be permanently deleted.")
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        Section("Account") {
            SettingsRow(
                icon: "person.crop.circle",
                title: "Edit Profile",
                iconColor: AppTheme.Colors.primary
            ) {
                // Handle edit profile
            }
            
            SettingsRow(
                icon: "bell",
                title: "Notification Preferences",
                iconColor: .orange
            ) {
                // Handle notification preferences
            }
            
            SettingsRow(
                icon: "shield.lefthalf.fill",
                title: "Privacy Settings",
                iconColor: .green
            ) {
                // Handle privacy settings
            }
        }
    }
    
    // MARK: - Preferences Section
    private var preferencesSection: some View {
        Section("Preferences") {
            HStack {
                SettingsIcon(systemName: "play.circle", color: AppTheme.Colors.secondary)
                
                Text("Auto-play Videos")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $autoPlayEnabled)
                    .tint(AppTheme.Colors.primary)
            }
            .padding(.vertical, 2)
            
            HStack {
                SettingsIcon(systemName: "bell.badge", color: .orange)
                
                Text("Push Notifications")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $notificationsEnabled)
                    .tint(AppTheme.Colors.primary)
            }
            .padding(.vertical, 2)
            
            HStack {
                SettingsIcon(systemName: "moon.fill", color: .indigo)
                
                Text("Dark Mode")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $darkModeEnabled)
                    .tint(AppTheme.Colors.primary)
            }
            .padding(.vertical, 2)
            
            HStack {
                SettingsIcon(systemName: "video", color: .purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Video Quality")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text("Default playback quality")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Menu(qualityPreference) {
                    ForEach(qualityOptions, id: \.self) { option in
                        Button(option) {
                            qualityPreference = option
                        }
                    }
                }
                .foregroundStyle(AppTheme.Colors.primary)
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        Section("Privacy & Safety") {
            SettingsRow(
                icon: "hand.raised.fill",
                title: "Blocked Users",
                iconColor: .red
            ) {
                // Handle blocked users
            }
            
            SettingsRow(
                icon: "eye.slash",
                title: "Watch History",
                iconColor: .gray
            ) {
                // Handle watch history
            }
            
            SettingsRow(
                icon: "location.slash",
                title: "Location Services",
                iconColor: .blue
            ) {
                // Handle location services
            }
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section("About") {
            SettingsRow(
                icon: "questionmark.circle",
                title: "Help & Support",
                iconColor: .cyan
            ) {
                // Handle help
            }
            
            SettingsRow(
                icon: "doc.text",
                title: "Terms of Service",
                iconColor: .brown
            ) {
                // Handle terms
            }
            
            SettingsRow(
                icon: "lock.doc",
                title: "Privacy Policy",
                iconColor: .mint
            ) {
                // Handle privacy policy
            }
            
            HStack {
                SettingsIcon(systemName: "info.circle", color: .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text("1.0.0 (Build 1)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Danger Zone Section
    private var dangerZoneSection: some View {
        Section {
            Button(action: {
                showingSignOutConfirmation = true
            }) {
                HStack {
                    SettingsIcon(systemName: "rectangle.portrait.and.arrow.right", color: .orange)
                    
                    Text("Sign Out")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                    
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                showingAccountDeletion = true
            }) {
                HStack {
                    SettingsIcon(systemName: "trash", color: .red)
                    
                    Text("Delete Account")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                    
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                SettingsIcon(systemName: icon, color: iconColor)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Icon
struct SettingsIcon: View {
    let systemName: String
    let color: Color
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .cornerRadius(6)
    }
}

// MARK: - Profile Settings Fallback View
struct ProfileSettingsFallbackView: View {
    let dismiss: DismissAction
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                VStack(spacing: 8) {
                    Text("Settings Unavailable")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text("Unable to load settings")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(ProfileRetryButtonStyle())
            }
            .padding(40)
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
    }
}

#Preview {
    SafeProfileSettingsView()
}