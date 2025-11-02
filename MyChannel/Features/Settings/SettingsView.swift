//
//  SettingsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var autoplayEnabled = true
    @State private var qualityPreference: PlaybackQuality = .auto
    @State private var downloadQuality: PlaybackQuality = .medium
    @State private var showingAbout = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingDeleteAccountFinalWarning = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    
    var body: some View {
        NavigationStack {
            List {
                Section("Playback") {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Toggle("Autoplay Videos", isOn: $autoplayEnabled)
                    }
                    
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Picker("Video Quality", selection: $qualityPreference) {
                            ForEach(PlaybackQuality.allCases, id: \.self) { quality in
                                Text(quality.displayName).tag(quality)
                            }
                        }
                    }
                }
                
                Section("Downloads") {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Picker("Download Quality", selection: $downloadQuality) {
                            ForEach(PlaybackQuality.allCases.filter { $0 != .auto }, id: \.self) { quality in
                                Text(quality.displayName).tag(quality)
                            }
                        }
                    }
                }
                
                Section("Notifications") {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Toggle("Push Notifications", isOn: $notificationsEnabled)
                    }
                }
                
                Section("About") {
                    Button("About MyChannel") {
                        showingAbout = true
                    }
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Button("Privacy Policy") {
                        // Open privacy policy
                    }
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Button("Terms of Service") {
                        // Open terms
                    }
                    .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Section {
                    Button(action: {
                        showingDeleteAccountConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete Account")
                                .foregroundColor(.red)
                        }
                    }
                } footer: {
                    Text("Permanently delete your account and all associated data. This action cannot be undone.")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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
        .alert("Error", isPresented: .constant(deleteError != nil)) {
            Button("OK") {
                deleteError = nil
            }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
        .overlay {
            if isDeletingAccount {
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
        }
    }
    
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
                    // Delete video file from Storage
                    if let videoURL = video.videoURL, !videoURL.isEmpty {
                        try? await VideoStorageService.shared.deleteVideo(from: videoURL)
                    }
                    // Delete thumbnail from Storage
                    if let thumbnailURL = video.thumbnailURL, !thumbnailURL.isEmpty {
                        try? await VideoStorageService.shared.deleteVideo(from: thumbnailURL)
                    }
                    // Delete video document from Firestore
                    try? await VideoFirestoreService.shared.deleteVideo(videoId: video.id)
                }
                
                // Delete user's profile images from Storage
                if let profileURL = AuthenticationManager.shared.currentUser?.profileImageURL {
                    try? await UserMediaStorageService.shared.deleteImage(from: profileURL)
                }
                if let bannerURL = AuthenticationManager.shared.currentUser?.bannerImageURL {
                    try? await UserMediaStorageService.shared.deleteImage(from: bannerURL)
                }
                
                // Delete user document from Firestore
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

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image("MyChannel")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                    
                    Text("MyChannel")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Built with SwiftUI")
                    Text("Designed for iOS 17+")
                    Text("Made with ❤️ by Keonta")
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

// MARK: - Supporting Models
enum PlaybackQuality: String, CaseIterable {
    case auto = "auto"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .low: return "Low (360p)"
        case .medium: return "Medium (720p)"
        case .high: return "High (1080p)"
        case .ultra: return "Ultra (4K)"
        }
    }
}

#Preview {
    SettingsView()
}