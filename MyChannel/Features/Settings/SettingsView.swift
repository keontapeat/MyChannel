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
                .background(
                    UIKitSheetConfigurator(
                        configuration: UIKitSheetConfiguration(
                            detents: [.medium(), .large()],
                            largestUndimmedDetentIdentifier: .large,
                            prefersGrabberVisible: true,
                            prefersScrollingExpandsWhenScrolledToEdge: false,
                            preferredCornerRadius: 28
                        )
                    )
                )
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
                .background(
                    UIKitSheetConfigurator(
                        configuration: UIKitSheetConfiguration(
                            detents: [.medium(), .large()],
                            largestUndimmedDetentIdentifier: .large,
                            prefersGrabberVisible: true,
                            prefersScrollingExpandsWhenScrolledToEdge: false,
                            preferredCornerRadius: 28
                        )
                    )
                )
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
            // Premium Benefits — only show when IAPs are submitted & approved
            if AppConfig.Features.enableSubscriptions {
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
            }
            
            NavigationLink {
                AppearanceSettingsView()
            } label: {
                settingsRow(
                    icon: "moon.circle",
                    title: "Appearance",
                    iconColor: .primary
                )
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

            if AppConfig.Features.enableKidsMode {
                NavigationLink {
                    KidsModeSettingsView()
                } label: {
                    settingsRow(
                        icon: "figure.child",
                        title: "Kids Mode",
                        iconColor: .blue
                    )
                }
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
    
    // 🔥 PREMIUM: Settings row with haptic feedback on tap
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
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
        }
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
                
                await PushTokenRegistrationManager.unregisterStoredToken(for: userId)

                // Delete user document
                try await UserFirestoreService.shared.deleteUser(userId: userId)

                // Delete Firebase Auth account
                try await AuthenticationManager.shared.deleteAccount()

                // Sign out and clear local data
                try await AuthenticationManager.shared.signOut()
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


// ⚡ All individual settings screens extracted to SettingsScreens.swift
