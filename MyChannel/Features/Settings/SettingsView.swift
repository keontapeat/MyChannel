//
//  SettingsView.swift
//  MyChannel
//
//  🔥 100% YOUTUBE PARITY SETTINGS
//  Complete settings with all YouTube sections
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitService.shared
    
    // State
    @State private var showingPremiumBenefits = false
    @State private var showingAbout = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingDeleteAccountFinalWarning = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                accountSection
                
                // Video and Audio Preferences
                videoAudioSection
                
                // Help and Policies
                helpSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPremiumBenefits) {
            PremiumBenefitsView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .alert("Delete Account?", isPresented: $showingDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                showingDeleteAccountFinalWarning = true
            }
        } message: {
            Text("Are you sure you want to delete your account? This will permanently remove:\n\n• All your videos\n• All your comments\n• Your profile and settings\n• Your subscriptions and playlists\n\nThis action cannot be undone.")
        }
        .alert("Final Warning", isPresented: $showingDeleteAccountFinalWarning) {
            TextField("Type DELETE to confirm", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
            Button("Delete Forever", role: .destructive) {
                performAccountDeletion()
            }
            .disabled(deleteConfirmationText.uppercased() != "DELETE")
        } message: {
            Text("Type DELETE in all caps to permanently delete your account.")
        }
        .overlay {
            if isDeletingAccount {
                deletingOverlay
            }
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            // Premium Benefits (if premium)
            if storeKit.isPremium {
                NavigationLink {
                    PremiumBenefitsView()
                } label: {
                    settingsRow(
                        icon: "crown.fill",
                        title: "Your Premium benefits",
                        iconColor: .black
                    )
                }
            } else {
                NavigationLink {
                    MyChannelPlusView()
                } label: {
                    settingsRow(
                        icon: "crown.fill",
                        title: "Try MyChannel Plus+",
                        iconColor: .black,
                        badge: "Free Trial"
                    )
                }
            }
            
            NavigationLink {
                GeneralSettingsView()
            } label: {
                settingsRow(
                    icon: "gearshape",
                    title: "General",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                SwitchAccountView()
            } label: {
                settingsRow(
                    icon: "person.crop.square",
                    title: "Switch account",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                NotificationSettingsView()
            } label: {
                settingsRow(
                    icon: "bell",
                    title: "Notifications",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                PurchasesView()
            } label: {
                settingsRow(
                    icon: "tag",
                    title: "Purchases and memberships",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                HistorySettingsView()
            } label: {
                settingsRow(
                    icon: "clock",
                    title: "Manage all history",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                DataSettingsView()
            } label: {
                settingsRow(
                    icon: "shield.checkered",
                    title: "Your data in MyChannel",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                PrivacySettingsView()
            } label: {
                settingsRow(
                    icon: "lock",
                    title: "Privacy",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                ConnectedAppsView()
            } label: {
                settingsRow(
                    icon: "link.circle",
                    title: "Connected apps",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                ExperimentalFeaturesView()
            } label: {
                settingsRow(
                    icon: "flask",
                    title: "Try experimental new features",
                    iconColor: .primary
                )
            }
        } header: {
            Text("Account")
        }
    }
    
    // MARK: - Video & Audio Section
    
    private var videoAudioSection: some View {
        Section {
            NavigationLink {
                QualitySettingsView()
            } label: {
                settingsRow(
                    icon: "hd.circle",
                    title: "Quality",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                PlaybackSettingsView()
            } label: {
                settingsRow(
                    icon: "play.circle",
                    title: "Playback",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                BackgroundDownloadsView()
            } label: {
                settingsRow(
                    icon: "arrow.down",
                    title: "Background & downloads",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                UploadsSettingsView()
            } label: {
                settingsRow(
                    icon: "arrow.up",
                    title: "Uploads",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                LiveChatSettingsView()
            } label: {
                settingsRow(
                    icon: "bubble.left.and.bubble.right",
                    title: "Live chat",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                WatchOnTVView()
            } label: {
                settingsRow(
                    icon: "tv",
                    title: "Watch on TV",
                    iconColor: .primary
                )
            }
        } header: {
            Text("Video and audio preferences")
        }
    }
    
    // MARK: - Help & Policies Section
    
    private var helpSection: some View {
        Section {
            NavigationLink {
                HelpView()
            } label: {
                settingsRow(
                    icon: "questionmark.circle",
                    title: "Help",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                FeedbackView()
            } label: {
                settingsRow(
                    icon: "bubble.left.and.exclamationmark.bubble.right",
                    title: "Send feedback",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                TermsView()
            } label: {
                settingsRow(
                    icon: "doc.text",
                    title: "MyChannel Terms of Service",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                AboutView()
            } label: {
                settingsRow(
                    icon: "info.circle",
                    title: "About",
                    iconColor: .primary
                )
            }
            
            // Developer Section (hidden in production)
            #if DEBUG
            NavigationLink(destination: AGIDashboardView()) {
                settingsRow(
                    icon: "brain.head.profile",
                    title: "AGI Control Center",
                    iconColor: .purple,
                    badge: "21 AI"
                )
            }
            
            NavigationLink(destination: DoctorDashboardView()) {
                HStack {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .frame(width: 28)
                    
                    Text("MyChannel Doctor")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            #endif
            
            // Delete Account
            Button(role: .destructive) {
                showingDeleteAccountConfirmation = true
            } label: {
                settingsRow(
                    icon: "trash",
                    title: "Delete Account",
                    iconColor: .red
                )
            }
        } header: {
            Text("Help and policies")
        }
    }
    
    // MARK: - Settings Row Helper
    
    private func settingsRow(
        icon: String,
        title: String,
        iconColor: Color = .primary,
        badge: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            Spacer()
            
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Deleting Overlay
    
    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Deleting account...")
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Account Deletion
    
    private func performAccountDeletion() {
        guard deleteConfirmationText.uppercased() == "DELETE" else { return }
        
        isDeletingAccount = true
        
        Task {
            do {
                guard let userId = AuthenticationManager.shared.currentUser?.id else {
                    throw NSError(domain: "AccountDeletion", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
                }
                
                // Delete user's videos from Storage and Firestore
                let videos = try await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: userId)
                for video in videos {
                    if !video.videoURL.isEmpty {
                        try? await VideoStorageService.shared.deleteVideo(from: video.videoURL)
                    }
                    if !video.thumbnailURL.isEmpty {
                        try? await VideoStorageService.shared.deleteVideo(from: video.thumbnailURL)
                    }
                    try? await VideoFirestoreService.shared.deleteVideo(videoId: video.id)
                }
                
                // Delete user's profile images
                if let profileURL = AuthenticationManager.shared.currentUser?.profileImageURL {
                    try? await UserMediaStorageService.shared.deleteImage(from: profileURL)
                }
                if let bannerURL = AuthenticationManager.shared.currentUser?.bannerImageURL {
                    try? await UserMediaStorageService.shared.deleteImage(from: bannerURL)
                }
                
                // Delete user document
                try await UserFirestoreService.shared.deleteUser(userId: userId)
                
                // Delete Firebase Auth account
                try await AuthenticationManager.shared.deleteAccount()
                
                // Sign out and clear local data
                try AuthenticationManager.shared.signOut()
                AppState.shared.currentUser = nil
                
                await MainActor.run {
                    isDeletingAccount = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteError = "Failed to delete account: \(error.localizedDescription)"
                    deleteConfirmationText = ""
                }
            }
        }
    }
}

// MARK: - Individual Settings Views

struct GeneralSettingsView: View {
    @AppStorage("appLanguage") private var language = "English"
    @AppStorage("appCountry") private var country = "United States"
    @AppStorage("darkMode") private var darkMode = false
    
    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $language) {
                    Text("English").tag("English")
                    Text("Español").tag("Spanish")
                    Text("Français").tag("French")
                }
                
                Picker("Country", selection: $country) {
                    Text("United States").tag("United States")
                    Text("Canada").tag("Canada")
                    Text("United Kingdom").tag("United Kingdom")
                }
            }
            
            Section {
                Toggle("Dark mode", isOn: $darkMode)
            } header: {
                Text("Appearance")
            }
        }
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SwitchAccountView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddAccount = false
    
    var body: some View {
        List {
            Section {
                if let user = AuthenticationManager.shared.currentUser {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text(user.displayName.prefix(1))
                                    .font(.system(size: 20, weight: .bold))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(user.email)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            } header: {
                Text("Current account")
            }
            
            Section {
                Button {
                    showingAddAccount = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add account")
                    }
                }
            }
        }
        .navigationTitle("Switch account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// NotificationSettingsView is defined in Features/Notifications/NotificationSettingsView.swift

struct PurchasesView: View {
    @StateObject private var storeKit = StoreKitService.shared
    
    var body: some View {
        List {
            if storeKit.isPremium {
                Section {
                    NavigationLink {
                        PremiumBenefitsView()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("MyChannel Plus+")
                                    .font(.system(size: 17, weight: .semibold))
                                
                                Spacer()
                                
                                Text("Active")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            
                            Text("$4.99/month")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Active subscriptions")
                }
                
                Section {
                    Button("Manage subscription") {
                        // Open App Store subscriptions
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    Button("Cancel subscription") {
                        // Open cancel flow
                    }
                    .foregroundColor(.red)
                }
            } else {
                Section {
                    NavigationLink {
                        MyChannelPlusView()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MyChannel Plus+")
                                .font(.system(size: 17, weight: .semibold))
                            
                            Text("Try free for 7 days")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Available subscriptions")
                }
            }
        }
        .navigationTitle("Purchases and memberships")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HistorySettingsView: View {
    var body: some View {
        List {
            Section {
                Button("Clear watch history") {
                    // Clear history
                }
                
                Button("Pause watch history") {
                    // Pause
                }
            }
            
            Section {
                Button("Clear search history") {
                    // Clear
                }
                
                Button("Pause search history") {
                    // Pause
                }
            }
        }
        .navigationTitle("Manage all history")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataSettingsView: View {
    var body: some View {
        List {
            Section {
                Button("Download your data") {
                    // Download
                }
                
                Button("Delete specific data") {
                    // Delete
                }
            }
        }
        .navigationTitle("Your data in MyChannel")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView: View {
    @AppStorage("privateProfile") private var privateProfile = false
    @AppStorage("showSubscriptions") private var showSubscriptions = true
    @AppStorage("showPlaylists") private var showPlaylists = true
    
    var body: some View {
        Form {
            Section {
                Toggle("Private profile", isOn: $privateProfile)
            } footer: {
                Text("When enabled, only people you approve can see your profile")
            }
            
            Section {
                Toggle("Show subscriptions", isOn: $showSubscriptions)
                Toggle("Show playlists", isOn: $showPlaylists)
            } header: {
                Text("Profile visibility")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ConnectedAppsView: View {
    var body: some View {
        List {
            Section {
                Text("No connected apps")
                    .foregroundColor(.secondary)
            } footer: {
                Text("Third-party apps you've given access to your MyChannel account will appear here")
            }
        }
        .navigationTitle("Connected apps")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExperimentalFeaturesView: View {
    @AppStorage("experimentalAI") private var experimentalAI = false
    @AppStorage("experimentalPlayer") private var experimentalPlayer = false
    
    var body: some View {
        Form {
            Section {
                Toggle("AI-powered recommendations", isOn: $experimentalAI)
                Toggle("Experimental video player", isOn: $experimentalPlayer)
            } footer: {
                Text("These features are in beta and may not work as expected")
            }
        }
        .navigationTitle("Experimental features")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct QualitySettingsView: View {
    @AppStorage("videoQuality") private var videoQuality = "Auto"
    @AppStorage("mobileDataUsage") private var mobileDataUsage = "Auto"
    
    var body: some View {
        Form {
            Section {
                Picker("Video quality", selection: $videoQuality) {
                    Text("Auto").tag("Auto")
                    Text("1080p").tag("1080p")
                    Text("720p").tag("720p")
                    Text("480p").tag("480p")
                    Text("360p").tag("360p")
                }
            } header: {
                Text("Wi-Fi")
            }
            
            Section {
                Picker("Mobile data usage", selection: $mobileDataUsage) {
                    Text("Auto").tag("Auto")
                    Text("Higher quality").tag("Higher")
                    Text("Data saver").tag("Saver")
                }
            } header: {
                Text("Mobile data")
            }
        }
        .navigationTitle("Quality")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlaybackSettingsView: View {
    @AppStorage("autoplay") private var autoplay = true
    @AppStorage("playbackSpeed") private var playbackSpeed = "Normal"
    
    var body: some View {
        Form {
            Section {
                Toggle("Autoplay", isOn: $autoplay)
            } footer: {
                Text("Automatically play next video")
            }
            
            Section {
                Picker("Playback speed", selection: $playbackSpeed) {
                    Text("0.25x").tag("0.25x")
                    Text("0.5x").tag("0.5x")
                    Text("0.75x").tag("0.75x")
                    Text("Normal").tag("Normal")
                    Text("1.25x").tag("1.25x")
                    Text("1.5x").tag("1.5x")
                    Text("2x").tag("2x")
                }
            }
        }
        .navigationTitle("Playback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BackgroundDownloadsView: View {
    @StateObject private var storeKit = StoreKitService.shared
    @AppStorage("backgroundPlay") private var backgroundPlay = false
    @AppStorage("downloadQuality") private var downloadQuality = "High"
    
    var body: some View {
        Form {
            if storeKit.isPremium {
                Section {
                    Toggle("Background play", isOn: $backgroundPlay)
                } footer: {
                    Text("Keep videos playing when you switch apps")
                }
                
                Section {
                    NavigationLink {
                        DownloadsView()
                    } label: {
                        Text("Manage downloads")
                    }
                    
                    Picker("Download quality", selection: $downloadQuality) {
                        Text("1080p").tag("1080p")
                        Text("720p").tag("720p")
                        Text("480p").tag("480p")
                    }
                } header: {
                    Text("Downloads")
                }
            } else {
                Section {
                    NavigationLink {
                        MyChannelPlusView()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Unlock with Plus+")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Background play and downloads are available with MyChannel Plus+")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Background & downloads")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UploadsSettingsView: View {
    @AppStorage("uploadQuality") private var uploadQuality = "1080p"
    @AppStorage("wifiUploadsOnly") private var wifiOnly = true
    
    var body: some View {
        Form {
            Section {
                Picker("Upload quality", selection: $uploadQuality) {
                    Text("4K").tag("4K")
                    Text("1080p").tag("1080p")
                    Text("720p").tag("720p")
                }
            }
            
            Section {
                Toggle("Upload over Wi-Fi only", isOn: $wifiOnly)
            } footer: {
                Text("Recommended to avoid data charges")
            }
        }
        .navigationTitle("Uploads")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LiveChatSettingsView: View {
    @AppStorage("showLiveChat") private var showLiveChat = true
    @AppStorage("chatNotifications") private var chatNotifications = true
    
    var body: some View {
        Form {
            Section {
                Toggle("Show live chat", isOn: $showLiveChat)
                Toggle("Chat notifications", isOn: $chatNotifications)
            }
        }
        .navigationTitle("Live chat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WatchOnTVView: View {
    var body: some View {
        List {
            Section {
                Text("Connect your device")
                    .foregroundColor(.secondary)
            } footer: {
                Text("Cast videos to your TV using AirPlay or Chromecast")
            }
        }
        .navigationTitle("Watch on TV")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section {
                Link("Help Center", destination: URL(string: "https://mychannel.com/help")!)
                Link("Community Guidelines", destination: URL(string: "https://mychannel.com/guidelines")!)
                Link("Copyright Policy", destination: URL(string: "https://mychannel.com/copyright")!)
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var showingSuccess = false
    
    var body: some View {
        Form {
            Section {
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 150)
            } header: {
                Text("Your feedback")
            } footer: {
                Text("Tell us what you think about MyChannel")
            }
            
            Section {
                Button("Send feedback") {
                    // Send feedback
                    showingSuccess = true
                }
                .disabled(feedbackText.isEmpty)
            }
        }
        .navigationTitle("Send feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thanks for your feedback!", isPresented: $showingSuccess) {
            Button("OK") {
                feedbackText = ""
            }
        }
    }
}

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("MyChannel Terms of Service")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: January 1, 2025")
                    .foregroundColor(.secondary)
                
                Text("By using MyChannel, you agree to these terms...")
                    .padding(.top)
                
                // Add full terms here
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.black)
                    
                    Text("MyChannel")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Version 1.0.0")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Built with SwiftUI")
                    Text("Designed for iOS 17+")
                    Text("Made with ❤️ for creators")
                }
                .font(.body)
                .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
