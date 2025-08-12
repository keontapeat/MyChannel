//
//  EditProfileView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import PhotosUI

// MARK: - Edit Profile View (Enhanced)
struct EditProfileView: View {
    @Binding var user: User
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var website: String = ""
    @State private var selectedProfileImage: PhotosPickerItem?
    @State private var selectedBannerImage: PhotosPickerItem?
    @State private var selectedBannerVideo: PhotosPickerItem?
    @State private var isSaving = false
    @State private var showingImagePicker = false
    @State private var imagePickerType: ImagePickerType = .profile
    @State private var showingSaveConfirmation = false
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    
    private enum ImagePickerType { case profile, banner }

    @State private var isVideoCover: Bool = false
    @State private var showingVideoPicker = false
    @State private var bannerVideoLocalURL: URL?
    @State private var bannerVideoMuted: Bool = true
    @State private var bannerContentMode: BannerContentMode = .fill
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Header section
                    headerSection
                    
                    // Content sections
                    VStack(spacing: 28) {
                        profileImagesSection
                        formFieldsSection
                        privacySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            
            // Save confirmation toast
            if showingSaveConfirmation {
                VStack {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.green.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile Updated!")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Your changes have been saved successfully")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.top, 70)
                .transition(.move(edge: .top).combined(with: .scale(scale: 0.8)).combined(with: .opacity))
                .zIndex(1000)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: handleBackTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: saveProfile) {
                    Group {
                        if isSaving {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Saving...")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.primary.opacity(0.8), in: Capsule())
                        } else {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(hasUnsavedChanges ? .white : AppTheme.Colors.primary)
                                .padding(.horizontal, hasUnsavedChanges ? 16 : 0)
                                .padding(.vertical, hasUnsavedChanges ? 8 : 0)
                                .background(hasUnsavedChanges ? AppTheme.Colors.primary : .clear, in: Capsule())
                                .scaleEffect(hasUnsavedChanges ? 1.05 : 1.0)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasUnsavedChanges)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSaving)
                }
                .disabled(isSaving || !hasUnsavedChanges)
            }
        }
        .onAppear {
            initializeFields()
        }
        .onChange(of: displayName) { _, _ in checkForChanges() }
        .onChange(of: username) { _, _ in checkForChanges() }
        .onChange(of: bio) { _, _ in checkForChanges() }
        .onChange(of: location) { _, _ in checkForChanges() }
        .onChange(of: website) { _, _ in checkForChanges() }
        .photosPicker(
            isPresented: $showingImagePicker,
            selection: imagePickerType == .profile ? $selectedProfileImage : $selectedBannerImage,
            matching: .images,
            photoLibrary: .shared()
        )
            .photosPicker(
                isPresented: $showingVideoPicker,
                selection: $selectedBannerVideo,
                matching: .videos,
                photoLibrary: .shared()
            )
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
            .onChange(of: selectedBannerVideo) { _, item in
                guard let item else { return }
                Task { await processSelectedBannerVideo(item) }
            }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 0) {
            ZStack {
                // Dynamic gradient background
                LinearGradient(
                    colors: [
                        AppTheme.Colors.primary.opacity(0.15),
                        AppTheme.Colors.secondary.opacity(0.1),
                        AppTheme.Colors.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)
                
                // Floating elements for depth
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 15, x: 0, y: 5)
                        
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Customize Your Profile")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Make your profile shine ✨")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.top, 25)
            }
        }
    }
    
    // MARK: - Profile Images / Banner Section
    private var profileImagesSection: some View {
        VStack(spacing: 20) {
            // Banner Image
            VStack(alignment: .leading, spacing: 12) {
                Text("Cover")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Picker("Cover Type", selection: $isVideoCover) {
                    Text("Photo").tag(false)
                    Text("Video").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: isVideoCover) { _, _ in
                    hasUnsavedChanges = true
                }

                if isVideoCover {
                    // Video options
                    VStack(spacing: 8) {
                        Toggle("Mute Video", isOn: $bannerVideoMuted)
                            .tint(AppTheme.Colors.primary)
                        Picker("Scale", selection: $bannerContentMode) {
                            Text("Fill").tag(BannerContentMode.fill)
                            Text("Fit").tag(BannerContentMode.fit)
                        }
                        .pickerStyle(.segmented)
                    }
                    .onChange(of: bannerVideoMuted) { _, _ in hasUnsavedChanges = true }
                    .onChange(of: bannerContentMode) { _, _ in hasUnsavedChanges = true }

                    Button(action: {
                        showingVideoPicker = true
                        HapticManager.shared.impact(style: .light)
                    }) {
                        ZStack {
                            if let urlString = user.bannerVideoURL, let url = URL(string: urlString) {
                                VideoBannerPreview(url: url)
                            } else if let local = bannerVideoLocalURL {
                                VideoBannerPreview(url: local)
                            } else {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.Colors.primary.opacity(0.3), AppTheme.Colors.secondary.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(.white)
                                    )
                            }
                            VStack(spacing: 8) {
                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                Text("Choose Cover Video")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(16)
                            .background(.black.opacity(0.35))
                            .cornerRadius(12)
                        }
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                Button(action: {
                    imagePickerType = .banner
                    showingImagePicker = true
                    HapticManager.shared.impact(style: .light)
                }) {
                    ZStack {
                        if let bannerURL = user.bannerImageURL {
                            CachedAsyncImage(url: URL(string: bannerURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                    )
                            }
                        } else {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary.opacity(0.3), AppTheme.Colors.secondary.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            
                            Text("Change Cover")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(16)
                        .background(.black.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Profile Image
            VStack(alignment: .leading, spacing: 12) {
                Text("Profile Photo")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 16) {
                    Button(action: {
                        imagePickerType = .profile
                        showingImagePicker = true
                        HapticManager.shared.impact(style: .light)
                    }) {
                        ZStack {
                            if let profileURL = user.profileImageURL {
                                CachedAsyncImage(url: URL(string: profileURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(AppTheme.Colors.surface)
                                        .overlay(
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                        )
                                }
                            } else {
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                                    .overlay(
                                        Text(String(user.displayName.prefix(1)))
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            Circle()
                                .fill(.black.opacity(0.5))
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                )
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppTheme.Colors.background, lineWidth: 4)
                        )
                        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Choose a profile photo")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Upload a photo that represents you well. Square images work best.")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Form Fields Section
    private var formFieldsSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Basic Information")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                // Progress indicator
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(getFieldProgress() > index ? AppTheme.Colors.primary : AppTheme.Colors.divider)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            
            VStack(spacing: 20) {
                ModernTextField(
                    title: "Display Name",
                    text: $displayName,
                    icon: "person.fill",
                    placeholder: "Your display name"
                )
                
                ModernTextField(
                    title: "Username",
                    text: $username,
                    icon: "at",
                    prefix: "@",
                    placeholder: "username"
                )
                
                ModernTextEditor(
                    title: "Bio",
                    text: $bio,
                    icon: "text.quote",
                    placeholder: "Tell people about yourself...",
                    maxLength: 150
                )
                
                ModernTextField(
                    title: "Location",
                    text: $location,
                    icon: "location.fill",
                    placeholder: "Where are you located?"
                )
                
                ModernTextField(
                    title: "Website",
                    text: $website,
                    icon: "globe",
                    placeholder: "https://yourwebsite.com",
                    keyboardType: .URL
                )
            }
        }
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        VStack(spacing: 16) {
            Text("Privacy & Visibility")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                PrivacyToggleRow(
                    title: "Public Profile",
                    description: "Allow others to find and view your profile",
                    icon: "eye",
                    isOn: .constant(true)
                )
                
                PrivacyToggleRow(
                    title: "Show Online Status",
                    description: "Let others see when you're active",
                    icon: "circle.fill",
                    isOn: .constant(false)
                )
                
                PrivacyToggleRow(
                    title: "Allow Messages",
                    description: "Let other users send you direct messages",
                    icon: "message",
                    isOn: .constant(true)
                )
            }
        }
    }
    
    // MARK: - Helper Functions
    private func handleBackTap() {
        HapticManager.shared.impact(style: .light)
        if hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
    
    private func checkForChanges() {
        hasUnsavedChanges = displayName != user.displayName ||
                           username != user.username ||
                           bio != (user.bio ?? "") ||
                           location != (user.location ?? "") ||
                           website != (user.website ?? "")
    }
    
    private func getFieldProgress() -> Int {
        var progress = 0
        if !displayName.isEmpty { progress += 1 }
        if !username.isEmpty { progress += 1 }
        if !bio.isEmpty { progress += 1 }
        if !location.isEmpty { progress += 1 }
        if !website.isEmpty { progress += 1 }
        return progress
    }
    
    private func initializeFields() {
        displayName = user.displayName
        username = user.username
        bio = user.bio ?? ""
        location = user.location ?? ""
        website = user.website ?? ""
        isVideoCover = user.bannerVideoURL != nil
    }
    
    private func saveProfile() {
        isSaving = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            var remoteBannerURL: String? = user.bannerVideoURL
            if isVideoCover, let localURL = bannerVideoLocalURL {
                // Prepare (trim/compress) and upload banner video
                do {
                    let prepared = try await ProfileMediaUploader.prepareBannerVideo(from: localURL)
                    let remote = try await ProfileMediaUploader.uploadBannerVideo(prepared, fileName: "banner_\(user.id).mp4")
                    remoteBannerURL = remote
                } catch {
                    print("Banner upload failed: \(error)")
                    // Fallback to local file path to keep UI updated; server sync can happen later
                    remoteBannerURL = localURL.absoluteString
                }
            }
            
            // Update user with new values
            var updatedUser = user
            updatedUser = User(
                id: user.id,
                username: username.isEmpty ? user.username : username,
                displayName: displayName.isEmpty ? user.displayName : displayName,
                email: user.email,
                profileImageURL: user.profileImageURL,
                bannerImageURL: isVideoCover ? nil : user.bannerImageURL,
                bio: bio.isEmpty ? nil : bio,
                subscriberCount: user.subscriberCount,
                videoCount: user.videoCount,
                isVerified: user.isVerified,
                isCreator: user.isCreator,
                createdAt: user.createdAt,
                location: location.isEmpty ? nil : location,
                website: website.isEmpty ? nil : website,
                socialLinks: user.socialLinks,
                totalViews: user.totalViews,
                totalEarnings: user.totalEarnings,
                membershipTiers: user.membershipTiers,
                bannerVideoURL: isVideoCover ? remoteBannerURL : nil,
                bannerVideoMuted: isVideoCover ? bannerVideoMuted : nil,
                bannerVideoContentMode: isVideoCover ? bannerContentMode : nil
            )
            
            user = updatedUser
            isSaving = false
            hasUnsavedChanges = false
            
            // Show success confirmation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showingSaveConfirmation = true
            }
            
            // Hide confirmation after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingSaveConfirmation = false
                }
            }
            
            // Notify that profile was updated
            NotificationCenter.default.post(name: .userProfileUpdated, object: updatedUser)
            
            // Success haptic
            HapticManager.shared.impact(style: .light)
            
            // Auto-dismiss after showing confirmation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        }
    }

    // MARK: - Video processing
    private func processSelectedBannerVideo(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self), !data.isEmpty {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = docs.appendingPathComponent("banner_\(user.id).mov")
                try? FileManager.default.removeItem(at: fileURL)
                try data.write(to: fileURL, options: .atomic)
                await MainActor.run {
                    bannerVideoLocalURL = fileURL
                    isVideoCover = true
                    hasUnsavedChanges = true
                }
            }
        } catch {
            print("Failed to load video: \(error)")
        }
    }
}

// MARK: - Simple inline preview for banner video
import AVFoundation
private struct VideoBannerPreview: View {
    let url: URL
    @State private var player = AVPlayer()
    var body: some View {
        FlicksPlayerLayerView(player: player, videoGravity: .resizeAspectFill)
            .onAppear {
                let item = AVPlayerItem(url: url)
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
                    item.seek(to: .zero, completionHandler: nil)
                    player.play()
                }
                player.replaceCurrentItem(with: item)
                player.isMuted = true
                player.play()
            }
            .onDisappear { player.pause() }
    }
}

// MARK: - Modern Text Field
struct ModernTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let prefix: String?
    let placeholder: String
    let keyboardType: UIKeyboardType
    
    @FocusState private var isFocused: Bool
    
    init(title: String, text: Binding<String>, icon: String, prefix: String? = nil, placeholder: String = "", keyboardType: UIKeyboardType = .default) {
        self.title = title
        self._text = text
        self.icon = icon
        self.prefix = prefix
        self.placeholder = placeholder
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                    .frame(width: 22)
                
                if let prefix = prefix {
                    Text(prefix)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 17))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .URL ? .never : .words)
                    .focused($isFocused)
            }
            .padding(18)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Modern Text Editor
struct ModernTextEditor: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    let maxLength: Int
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Text("\(text.count)/\(maxLength)")
                    .font(.system(size: 12))
                    .foregroundColor(text.count > maxLength ? .red : AppTheme.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                        .frame(width: 20)
                    
                    Text("About You")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .onChange(of: text) { _, newValue in
                            if newValue.count > maxLength {
                                text = String(newValue.prefix(maxLength))
                            }
                        }
                    
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 100)
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Privacy Toggle Row
struct PrivacyToggleRow: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        EditProfileView(user: .constant(User.sampleUsers[0]))
    }
}