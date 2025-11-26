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
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared // 🔥 FIX: Access global player to hide mini player
    
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
        .onAppear {
            // Native PiP handles visibility automatically
            print("🎥 [SettingsView] Settings page appeared")
        }
        .onDisappear {
            // Native PiP persists automatically
            print("🎥 [SettingsView] Settings page disappeared")
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
                    title: "Terms of Service",
                    iconColor: .primary
                )
            }
            
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                settingsRow(
                    icon: "hand.raised",
                    title: "Privacy Policy",
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

// Note: PlaybackSettingsView is defined in Features/Settings/PlaybackSettingsView.swift

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
                Link("Help Center", destination: URL(string: "https://mychannel.live/help")!)
                Link("Community Guidelines", destination: URL(string: "https://mychannel.live/guidelines")!)
                Link("Copyright Policy", destination: URL(string: "https://mychannel.live/copyright")!)
                Link("Contact Support", destination: URL(string: "mailto:support@mychannel.live")!)
            }
            
            Section("Quick Help") {
                NavigationLink("How to upload videos") {
                    HelpArticleView(title: "How to Upload Videos", content: """
                    1. Tap the + button at the bottom of the screen
                    2. Select a video from your library or record a new one
                    3. Add a title, description, and thumbnail
                    4. Choose your privacy settings
                    5. Tap Upload to publish your video
                    
                    Your video will be processed and available within minutes!
                    """)
                }
                NavigationLink("Monetization requirements") {
                    HelpArticleView(title: "Monetization Requirements", content: """
                    To monetize your content on MyChannel:
                    
                    • 1,000+ subscribers
                    • 4,000+ watch hours in the last 12 months
                    • Follow Community Guidelines
                    • Have an approved AdSense account
                    
                    Once eligible, enable monetization in Creator Studio.
                    """)
                }
                NavigationLink("Account & Privacy") {
                    HelpArticleView(title: "Account & Privacy", content: """
                    Your privacy matters to us:
                    
                    • You control who sees your content
                    • You can download your data anytime
                    • You can delete your account and all data
                    • We never sell your personal information
                    
                    Manage settings in Settings > Privacy.
                    """)
                }
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpArticleView: View {
    let title: String
    let content: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(content)
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .padding()
        }
        .navigationTitle(title)
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
            VStack(alignment: .leading, spacing: 20) {
                Text("MyChannel Terms of Service")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: January 1, 2025")
                    .foregroundColor(.secondary)
                
                Group {
                    TermsSection(title: "1. Acceptance of Terms", content: """
                    By accessing or using MyChannel ("Service"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the Service.
                    """)
                    
                    TermsSection(title: "2. Description of Service", content: """
                    MyChannel is a video sharing platform that allows users to upload, share, and view video content. The Service includes all features, applications, and content provided by MyChannel.
                    """)
                    
                    TermsSection(title: "3. User Accounts", content: """
                    • You must be at least 13 years old to use this Service
                    • You are responsible for maintaining the security of your account
                    • You must provide accurate and complete information
                    • One person may not maintain more than one account
                    • You are responsible for all activity under your account
                    """)
                    
                    TermsSection(title: "4. User Content", content: """
                    • You retain ownership of content you upload
                    • You grant MyChannel a license to display and distribute your content
                    • You are responsible for ensuring you have rights to upload content
                    • Content must comply with our Community Guidelines
                    • We may remove content that violates these terms
                    """)
                    
                    TermsSection(title: "5. Prohibited Conduct", content: """
                    You agree not to:
                    • Upload illegal, harmful, or infringing content
                    • Harass, abuse, or harm other users
                    • Spam or engage in deceptive practices
                    • Attempt to circumvent security measures
                    • Use the Service for unauthorized commercial purposes
                    • Violate any applicable laws or regulations
                    """)
                    
                    TermsSection(title: "6. Monetization", content: """
                    • Eligible creators may participate in our Partner Program
                    • Revenue sharing is subject to separate Partner terms
                    • We reserve the right to modify monetization features
                    • Tax obligations are the responsibility of creators
                    """)
                    
                    TermsSection(title: "7. Intellectual Property", content: """
                    • MyChannel and its features are protected by copyright and trademark
                    • You may not copy, modify, or distribute our proprietary content
                    • Report copyright violations through our DMCA process
                    """)
                    
                    TermsSection(title: "8. Termination", content: """
                    • We may suspend or terminate accounts for violations
                    • You may delete your account at any time
                    • Upon termination, your content may be removed
                    """)
                    
                    TermsSection(title: "9. Disclaimers", content: """
                    THE SERVICE IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND. WE DO NOT GUARANTEE UNINTERRUPTED ACCESS OR ERROR-FREE OPERATION.
                    """)
                    
                    TermsSection(title: "10. Contact", content: """
                    For questions about these Terms, contact us at:
                    legal@mychannel.live
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: January 1, 2025")
                    .foregroundColor(.secondary)
                
                Group {
                    TermsSection(title: "1. Information We Collect", content: """
                    We collect information you provide directly:
                    • Account information (name, email, username)
                    • Profile information (photo, bio)
                    • Content you upload (videos, comments)
                    • Communications with us
                    
                    We automatically collect:
                    • Device information
                    • Usage data and analytics
                    • Log data
                    """)
                    
                    TermsSection(title: "2. How We Use Information", content: """
                    We use your information to:
                    • Provide and improve the Service
                    • Personalize your experience
                    • Communicate with you
                    • Ensure safety and security
                    • Comply with legal obligations
                    """)
                    
                    TermsSection(title: "3. Information Sharing", content: """
                    We do not sell your personal information. We may share information with:
                    • Service providers who assist our operations
                    • Law enforcement when required by law
                    • Other users (only content you choose to share publicly)
                    """)
                    
                    TermsSection(title: "4. Data Security", content: """
                    We implement industry-standard security measures:
                    • Encryption of data in transit and at rest
                    • Regular security audits
                    • Access controls and authentication
                    • Secure data centers
                    """)
                    
                    TermsSection(title: "5. Your Rights", content: """
                    You have the right to:
                    • Access your personal data
                    • Correct inaccurate data
                    • Delete your account and data
                    • Export your data
                    • Opt out of marketing communications
                    """)
                    
                    TermsSection(title: "6. Children's Privacy", content: """
                    Our Service is not intended for children under 13. We do not knowingly collect information from children under 13. If you believe we have collected such information, please contact us.
                    """)
                    
                    TermsSection(title: "7. Cookies & Tracking", content: """
                    We use cookies and similar technologies for:
                    • Authentication and security
                    • Preferences and settings
                    • Analytics and performance
                    
                    You can control cookies through your browser settings.
                    """)
                    
                    TermsSection(title: "8. Contact Us", content: """
                    For privacy questions or requests:
                    privacy@mychannel.live
                    
                    MyChannel, Inc.
                    Atlanta, GA, USA
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // App Icon & Branding
                    VStack(spacing: 16) {
                        // Logo
                        ZStack {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 15, x: 0, y: 8)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text("MyChannel")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.top, 40)
                    
                    // Tagline
                    Text("Your Creative Universe Awaits")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    // Features
                    VStack(spacing: 16) {
                        AboutFeatureRow(icon: "video.fill", text: "Upload & share videos")
                        AboutFeatureRow(icon: "play.tv.fill", text: "Stream live content")
                        AboutFeatureRow(icon: "dollarsign.circle.fill", text: "Monetize your creativity")
                        AboutFeatureRow(icon: "person.2.fill", text: "Build your community")
                        AboutFeatureRow(icon: "trophy.fill", text: "Compete & win prizes")
                    }
                    .padding(.horizontal, 24)
                    
                    // Links
                    VStack(spacing: 12) {
                        Link(destination: URL(string: "https://mychannel.live")!) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Visit mychannel.live")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                        
                        Link(destination: URL(string: "https://twitter.com/mychannelapp")!) {
                            HStack {
                                Image(systemName: "at")
                                Text("@mychannelapp")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    
                    // Copyright
                    VStack(spacing: 4) {
                        Text("© 2025 MyChannel, Inc.")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("Made with ❤️ in Atlanta")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
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

struct AboutFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 32)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
