//
//  SafeProfileSettingsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif

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
    
    @AppStorage("preferences.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("preferences.autoPlayEnabled") private var autoPlayEnabled = true
    @AppStorage("appearance.darkModeEnabled") private var darkModeEnabled = false
    @State private var qualityPreference = "Auto"
    @State private var showingAccountDeletion = false
    @State private var showingSignOutConfirmation = false
    @State private var showingDataExport = false
    @State private var analyticsEnabled: Bool = FirebaseManager.shared.isAnalyticsEnabled()
    
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
                
                // Owner-only Featured Controls
                ownerFeaturedSection

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
                AuthenticationManager.shared.signOut()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .confirmationDialog("Delete Account", isPresented: $showingAccountDeletion) {
            Button("Delete Account", role: .destructive) {
                Task {
                    do {
                        try await AuthService.shared.deleteAccount()
                        NotificationManager.shared.showSuccess("Your account has been deleted.")
                    } catch {
                        NotificationManager.shared.showError("Failed to delete account: \(error.localizedDescription)")
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. Your account and all data will be permanently deleted.")
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenLanguageSettings"))) { _ in
            UIApplication.shared.topMostController()?.present(UIHostingController(rootView: LanguageSettingsView()), animated: true)
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
                NotificationCenter.default.post(name: NSNotification.Name("OpenNotificationSettings"), object: nil)
            }
            
            SettingsRow(
                icon: "shield.lefthalf.fill",
                title: "Privacy Settings",
                iconColor: .green
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
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
                SettingsIcon(systemName: "chart.bar.fill", color: .green)
                
                Text("Share Analytics")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $analyticsEnabled)
                    .tint(AppTheme.Colors.primary)
            }
            .padding(.vertical, 2)
            .onChange(of: analyticsEnabled) { newValue in
                FirebaseManager.shared.setAnalyticsEnabled(newValue)
            }

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

    // MARK: - Owner Featured Section (visible only for owner)
    private var ownerFeaturedSection: some View {
        Section {
            if isOwner {
                NavigationLink(destination: OwnerFeaturedManagerView()) {
                    HStack {
                        SettingsIcon(systemName: "star.fill", color: .yellow)
                        Text("Manage Featured (Owner)")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                    }
                }
                NavigationLink(destination: OwnerBulkFriendsView()) {
                    HStack {
                        SettingsIcon(systemName: "person.3.fill", color: .purple)
                        Text("Bulk Add Friends (Owner)")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                    }
                }
            }
        } header: {
            if isOwner { Text("Owner Tools") }
        }
    }

    private var isOwner: Bool {
        (AuthenticationManager.shared.currentUser?.email ?? "").lowercased() == "keontapeat@mychannel.live"
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

            // Permissions Shortcuts
            SettingsRow(
                icon: "bell.badge.fill",
                title: "Notification Settings",
                iconColor: .orange
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            SettingsRow(
                icon: "camera.fill",
                title: "Camera & Microphone",
                iconColor: .indigo
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            SettingsRow(
                icon: "photo.fill.on.rectangle.fill",
                title: "Photos Access",
                iconColor: .purple
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
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
                if let url = URL(string: "https://mychannel.live/help") {
                    UIApplication.shared.open(url)
                }
            }
            
            SettingsRow(
                icon: "envelope.fill",
                title: "Send Feedback",
                iconColor: .blue
            ) {
                let email = AppConfig.Social.supportEmail
                let subject = "App Feedback"
                let message = "Describe your issue or idea here..."
                let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let bodyEncoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let mailto = "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)"
                if let url = URL(string: mailto) {
                    UIApplication.shared.open(url)
                }
            }
            
            SettingsRow(
                icon: "doc.text",
                title: "Terms of Service",
                iconColor: .brown
            ) {
                if let url = URL(string: "https://mychannel.live/terms") {
                    UIApplication.shared.open(url)
                }
            }
            
            SettingsRow(
                icon: "lock.doc",
                title: "Privacy Policy",
                iconColor: .mint
            ) {
                if let url = URL(string: "https://mychannel.live/privacy") {
                    UIApplication.shared.open(url)
                }
            }

            SettingsRow(
                icon: "square.and.arrow.up",
                title: "Export My Data",
                iconColor: .teal
            ) {
                showingDataExport = true
            }

            SettingsRow(
                icon: "star.circle.fill",
                title: "Rate MyChannel",
                iconColor: .yellow
            ) {
                #if canImport(StoreKit)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                }
                #endif
            }

            SettingsRow(
                icon: "globe",
                title: "Language",
                iconColor: .purple
            ) {
                NotificationCenter.default.post(name: NSNotification.Name("OpenLanguageSettings"), object: nil)
            }

            SettingsRow(
                icon: "link",
                title: "Validate Universal Links",
                iconColor: .gray
            ) {
                UIApplication.shared.topMostController()?.present(UIHostingController(rootView: UniversalLinkValidatorView()), animated: true)
            }
            
            HStack {
                SettingsIcon(systemName: "info.circle", color: .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
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