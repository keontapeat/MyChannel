//
//  EditProfileView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Edit Profile View (Enhanced)
struct EditProfileView: View {
    @Binding var user: User
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var website: String = ""
    @State private var showWebsiteOnProfile: Bool = false
    @State private var showOnlineStatus: Bool = false
    @State private var selectedProfileImage: PhotosPickerItem?
    @State private var selectedBannerImage: PhotosPickerItem?
    @State private var selectedBannerVideo: PhotosPickerItem?
    @State private var selectedProfileUIImage: UIImage?
    @State private var selectedBannerUIImage: UIImage?
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
    @State private var bannerContentMode: UserBannerContentMode = .fill
    
    @State private var showingDefaultBannerPicker = false
    @State private var selectedDefaultBannerImageURL: String? = nil
    @State private var selectedDefaultBannerVideoURL: String? = nil
    
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
        .onChange(of: displayName) { _ in checkForChanges() }
        .onChange(of: username) { _ in checkForChanges() }
        .onChange(of: bio) { _ in checkForChanges() }
        .onChange(of: location) { _ in checkForChanges() }
        .onChange(of: website) { _ in checkForChanges() }
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
        .onChange(of: selectedProfileImage) { item in
            guard let item else { return }
            Task { await processSelectedProfileImage(item) }
        }
        .onChange(of: selectedBannerImage) { item in
            guard let item else { return }
            Task { await processSelectedBannerImage(item) }
        }
        .onChange(of: selectedBannerVideo) { item in
            guard let item else { return }
            Task { await processSelectedBannerVideo(item) }
        }
        .onChange(of: selectedProfileUIImage) { _ in hasUnsavedChanges = true }
        .onChange(of: selectedBannerUIImage) { _ in hasUnsavedChanges = true }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Clean, minimal header - professional for creators
            Color(.systemGray6)
                .frame(height: 1)
        }
    }
    
    // MARK: - Profile Images / Banner Section
    private var profileImagesSection: some View {
        VStack(spacing: 24) {
            // Banner Image
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("Cover")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                }
                
                Picker("Cover Type", selection: $isVideoCover) {
                    Text("Photo").tag(false)
                    Text("Video").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: isVideoCover) { _ in
                    hasUnsavedChanges = true
                    // Clear opposite selection when switching modes
                    if isVideoCover {
                        selectedDefaultBannerImageURL = nil
                    } else {
                        selectedDefaultBannerVideoURL = nil
                        bannerVideoLocalURL = nil
                    }
                }

                if isVideoCover {
                    // Video options
                    VStack(spacing: 8) {
                        Toggle("Mute Video", isOn: $bannerVideoMuted)
                            .tint(AppTheme.Colors.primary)
                        Picker("Scale", selection: $bannerContentMode) {
                            Text("Fill").tag(UserBannerContentMode.fill)
                            Text("Fit").tag(UserBannerContentMode.fit)
                        }
                        .pickerStyle(.segmented)
                    }
                    .onChange(of: bannerVideoMuted) { _ in hasUnsavedChanges = true }
                    .onChange(of: bannerContentMode) { _ in hasUnsavedChanges = true }

                    // Video source buttons
                    HStack(spacing: 12) {
                        Button {
                            showingVideoPicker = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Label("Pick from Library", systemImage: "video.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.primary, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingDefaultBannerPicker = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Label("Choose from Defaults", systemImage: "photo.on.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: {}) {
                        ZStack {
                            if let urlStr = selectedDefaultBannerVideoURL, let url = URL(string: urlStr) {
                                VideoBannerPreview(url: url)
                            } else if let local = bannerVideoLocalURL {
                                VideoBannerPreview(url: local)
                            } else if let currentRemote = user.bannerVideoURL, let url = URL(string: currentRemote) {
                                VideoBannerPreview(url: url)
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
                        }
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    // Photo source buttons
                    HStack(spacing: 12) {
                        Button {
                            imagePickerType = .banner
                            showingImagePicker = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Label("Pick from Library", systemImage: "photo.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.primary, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            showingDefaultBannerPicker = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Label("Choose from Defaults", systemImage: "photo.on.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: {}) {
                        ZStack {
                            if let selectedImage = selectedBannerUIImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if let urlStr = selectedDefaultBannerImageURL, let url = URL(string: urlStr) {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(AppTheme.Colors.surface)
                                }
                            } else if let bannerURL = user.bannerImageURL {
                                CachedAsyncImage(url: URL(string: bannerURL)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(AppTheme.Colors.surface)
                                }
                            } else {
                                // Clean, professional placeholder - no gradient
                                Rectangle()
                                    .fill(AppTheme.Colors.surface)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 36))
                                            .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.5))
                                    )
                            }
                        }
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Profile Image
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("Profile Photo")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    Button(action: {
                        imagePickerType = .profile
                        showingImagePicker = true
                        HapticManager.shared.impact(style: .light)
                    }) {
                        ZStack {
                            if let selectedImage = selectedProfileUIImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if let profileURL = user.profileImageURL {
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
        .sheet(isPresented: $showingDefaultBannerPicker) {
            DefaultBannerPickerView(
                mode: isVideoCover ? .video : .image,
                onSelect: { banner in
                    if banner.kind == .video {
                        selectedDefaultBannerVideoURL = banner.assetURL
                        // Clear local pick if switching to default
                        bannerVideoLocalURL = nil
                        isVideoCover = true
                    } else {
                        selectedDefaultBannerImageURL = banner.assetURL
                        isVideoCover = false
                    }
                    hasUnsavedChanges = true
                }
            )
        }
    }
    
    // MARK: - Form Fields Section
    private var formFieldsSection: some View {
        VStack(spacing: 24) {
            // Section header with progress
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Basic Information")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("\(getFieldProgress())/5 fields completed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Circular progress indicator
                ZStack {
                    Circle()
                        .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(getFieldProgress()) / 5.0)
                        .stroke(AppTheme.Colors.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: getFieldProgress())
                    
                    Text("\(Int((Double(getFieldProgress()) / 5.0) * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
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
                
                // Website field with visibility toggle
                VStack(alignment: .leading, spacing: 12) {
                    ModernTextField(
                        title: "Website",
                        text: $website,
                        icon: "globe",
                        placeholder: "https://yourwebsite.com",
                        keyboardType: .URL
                    )
                    
                    // Website visibility toggle
                    if !website.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: showWebsiteOnProfile ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(showWebsiteOnProfile ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                                .frame(width: 22)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show Website on Profile")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Text("Display your website link on your profile header")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $showWebsiteOnProfile)
                                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                                .onChange(of: showWebsiteOnProfile) { _ in
                                    hasUnsavedChanges = true
                                    HapticManager.shared.impact(style: .light)
                                }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(showWebsiteOnProfile ? AppTheme.Colors.primary.opacity(0.08) : AppTheme.Colors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(showWebsiteOnProfile ? AppTheme.Colors.primary.opacity(0.3) : AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showWebsiteOnProfile)
                    }
                }
            }
        }
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Privacy & Visibility")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                PrivacyToggleRow(
                    title: "Public Profile",
                    description: "Allow others to find and view your profile",
                    icon: "eye",
                    isOn: .constant(true)
                )
                
                Divider()
                    .padding(.leading, 56)
                
                PrivacyToggleRow(
                    title: "Show Online Status",
                    description: "Let others see when you're active",
                    icon: "circle.fill",
                    isOn: $showOnlineStatus
                )
                .onChange(of: showOnlineStatus) { _ in
                    hasUnsavedChanges = true
                    HapticManager.shared.impact(style: .light)
                }
                
                Divider()
                    .padding(.leading, 56)
                
                PrivacyToggleRow(
                    title: "Allow Messages",
                    description: "Let other users send you direct messages",
                    icon: "message",
                    isOn: .constant(true)
                )
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
            )
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
                           website != (user.website ?? "") ||
                           showWebsiteOnProfile != (user.showWebsiteOnProfile ?? false) ||
                           showOnlineStatus != (user.showOnlineStatus ?? false) ||
                           selectedProfileUIImage != nil ||
                           selectedBannerUIImage != nil ||
                           selectedDefaultBannerImageURL != nil ||
                           selectedDefaultBannerVideoURL != nil ||
                           bannerVideoLocalURL != nil
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
        showWebsiteOnProfile = user.showWebsiteOnProfile ?? false
        showOnlineStatus = user.showOnlineStatus ?? false
        isVideoCover = user.bannerVideoURL != nil
    }
    
    private func saveProfile() {
        print("💾 [EditProfile] ========== SAVE PROFILE STARTED ==========")
        print("💾 [EditProfile] hasUnsavedChanges: \(hasUnsavedChanges)")
        print("💾 [EditProfile] selectedProfileUIImage: \(selectedProfileUIImage != nil ? "YES" : "NO")")
        print("💾 [EditProfile] selectedBannerUIImage: \(selectedBannerUIImage != nil ? "YES" : "NO")")
        isSaving = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            var remoteBannerURL: String? = user.bannerVideoURL

            if isVideoCover {
                if let defaultVideoURL = selectedDefaultBannerVideoURL {
                    remoteBannerURL = defaultVideoURL
                } else if let localURL = bannerVideoLocalURL {
                    do {
                        let prepared = try await ProfileMediaUploader.prepareBannerVideo(from: localURL)
                        let remote = try await ProfileMediaUploader.uploadBannerVideo(prepared, fileName: "banner_\(user.id).mp4")
                        remoteBannerURL = remote
                    } catch {
                        print("Banner upload failed: \(error)")
                        remoteBannerURL = localURL.absoluteString
                    }
                }
            }

            // Upload profile image if selected
            var profileImageURL: String? = user.profileImageURL
            if let profileImage = selectedProfileUIImage {
                print("📤 Starting profile image upload for user: \(user.id)")
                do {
                    // UserMediaStorageService is @MainActor, so this will run on main actor
                    let uploadedURL = try await UserMediaStorageService.shared.uploadAvatar(uid: user.id, image: profileImage)
                    profileImageURL = uploadedURL
                    print("✅ Profile image uploaded successfully: \(uploadedURL)")
                    
                    // Verify the URL is valid
                    if URL(string: uploadedURL) == nil {
                        print("⚠️ Uploaded URL is invalid: \(uploadedURL)")
                    } else {
                        print("✅ Uploaded URL is valid: \(uploadedURL)")
                    }
                } catch {
                    print("🚨 Profile image upload failed: \(error.localizedDescription)")
                    print("🚨 Full error: \(error)")
                    // If upload fails, keep existing image but log the error
                    // The user can try again
                    profileImageURL = user.profileImageURL // Keep existing URL
                    print("⚠️ Keeping existing profile image URL: \(profileImageURL ?? "nil")")
                }
            } else {
                print("ℹ️ No profile image selected - keeping existing URL: \(profileImageURL ?? "nil")")
            }
            
            // Upload banner image if selected
            var imageBannerURL: String? = user.bannerImageURL
            if !isVideoCover {
                if let bannerImage = selectedBannerUIImage {
                    do {
                        let uploadedURL = try await UserMediaStorageService.shared.uploadBanner(uid: user.id, image: bannerImage)
                        imageBannerURL = uploadedURL
                    } catch {
                        print("Banner image upload failed: \(error)")
                    }
                } else if let defaultImageURL = selectedDefaultBannerImageURL {
                    imageBannerURL = defaultImageURL
                }
            }

            var updatedUser = user
            print("🔨 Creating updated user object with profileImageURL: \(profileImageURL ?? "nil")")
            updatedUser = User(
                id: user.id,
                username: username.isEmpty ? user.username : username,
                displayName: displayName.isEmpty ? user.displayName : displayName,
                email: user.email,
                profileImageURL: profileImageURL,
                bannerImageURL: isVideoCover ? nil : imageBannerURL,
                bio: bio.isEmpty ? nil : bio,
                subscriberCount: user.subscriberCount,
                videoCount: user.videoCount,
                isVerified: user.isVerified,
                isCreator: user.isCreator,
                createdAt: user.createdAt,
                location: location.isEmpty ? nil : location,
                website: website.isEmpty ? nil : website,
                showWebsiteOnProfile: showWebsiteOnProfile,
                showOnlineStatus: showOnlineStatus,
                socialLinks: user.socialLinks,
                totalViews: user.totalViews,
                totalEarnings: user.totalEarnings,
                membershipTiers: user.membershipTiers,
                bannerVideoURL: isVideoCover ? remoteBannerURL : nil,
                bannerVideoMuted: isVideoCover ? bannerVideoMuted : nil,
                bannerVideoContentMode: isVideoCover ? bannerContentMode : nil
            )
            
            print("✅ Updated user object created with profileImageURL: \(updatedUser.profileImageURL ?? "nil")")
            
            // Update all user references on main thread
            await MainActor.run {
                print("🔄 Updating user references on main thread...")
                user = updatedUser
                authManager.currentUser = updatedUser
                appState.currentUser = updatedUser
                print("✅ User references updated - authManager.currentUser.profileImageURL: \(authManager.currentUser?.profileImageURL ?? "nil")")
                print("✅ User references updated - appState.currentUser.profileImageURL: \(appState.currentUser?.profileImageURL ?? "nil")")
                
                // Keep selected images visible until user refreshes
                // This ensures the new image shows immediately after save
                // The images will be cleared when user object updates with new URLs
            }
            
            // 🔥 PERSIST TO STORAGE: Save to both UserDefaults AND Firestore for full persistence
            print("💾 Starting persistence to storage...")
            do {
                // Save to local UserDefaults (instant persistence)
                print("💾 Saving to UserDefaults...")
                try await DatabaseService.shared.saveUser(updatedUser)
                print("✅ User saved to local storage (UserDefaults) with profileImageURL: \(updatedUser.profileImageURL ?? "nil")")
                
                // Save to Firestore (cloud sync across devices)
                #if canImport(FirebaseFirestore)
                do {
                    print("💾 Saving to Firestore...")
                    try await UserFirestoreService.shared.updateUser(updatedUser)
                    print("✅ User saved to Firestore with profileImageURL: \(updatedUser.profileImageURL ?? "nil")")
                } catch {
                    print("⚠️ Firestore save failed (will retry on next launch): \(error.localizedDescription)")
                    print("⚠️ Full Firestore error: \(error)")
                }
                #endif
                
                // Force sync with auth manager and app state to ensure all references are updated
                await MainActor.run {
                    // Clear old profile image from cache if URL changed
                    if let oldURL = user.profileImageURL,
                       let newURL = updatedUser.profileImageURL,
                       oldURL != newURL {
                        // ImageCache will handle cleanup automatically
                        // Or we can clear the entire cache if needed
                        ImageCache.shared.clearCache()
                        print("🗑️ Cleared old profile image from cache")
                    }
                    
                    // Update all references again to ensure consistency
                    authManager.currentUser = updatedUser
                    appState.currentUser = updatedUser
                    user = updatedUser
                    
                    print("✅ All user references updated with profileImageURL: \(updatedUser.profileImageURL ?? "nil")")
                }
            } catch {
                print("🚨 Failed to save user profile: \(error.localizedDescription)")
            }
            
            // Capture values for closure
            let finalProfileImageURL = updatedUser.profileImageURL
            let previousProfileImageURL = user.profileImageURL
            
            await MainActor.run {
                isSaving = false
                hasUnsavedChanges = false
                
                // Clear selected images after save to trigger UI refresh from URL
                // Add delay to ensure user object is fully updated, persistence is complete, and view refreshes
                // Only clear if we successfully got a new URL
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if selectedProfileUIImage != nil {
                        if let newURL = finalProfileImageURL, let oldURL = previousProfileImageURL, newURL != oldURL {
                            print("✅ Clearing selectedProfileUIImage - triggering refresh from new URL: \(newURL)")
                            selectedProfileUIImage = nil
                        } else {
                            print("⚠️ Not clearing selectedProfileUIImage - URL didn't change or is nil")
                            print("   Old URL: \(previousProfileImageURL ?? "nil")")
                            print("   New URL: \(finalProfileImageURL ?? "nil")")
                        }
                    }
                }
                if selectedBannerUIImage != nil && imageBannerURL != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        selectedBannerUIImage = nil
                    }
                }
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showingSaveConfirmation = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showingSaveConfirmation = false }
            }
            // Post notification to refresh all profile views
            print("📢 Posting userProfileUpdated notification with profileImageURL: \(updatedUser.profileImageURL ?? "nil")")
            NotificationCenter.default.post(name: .userProfileUpdated, object: updatedUser)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
            
            HapticManager.shared.impact(style: .light)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { dismiss() }
        }
    }

    // MARK: - Image processing
    private func processSelectedProfileImage(_ item: PhotosPickerItem) async {
        print("🖼️ [EditProfile] processSelectedProfileImage called")
        do {
            if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                print("🖼️ [EditProfile] Successfully loaded image data: \(data.count) bytes")
                await MainActor.run {
                    selectedProfileUIImage = image
                    print("🖼️ [EditProfile] Set selectedProfileUIImage, calling checkForChanges()")
                    checkForChanges() // Mark as unsaved so Save button becomes enabled
                    print("🖼️ [EditProfile] hasUnsavedChanges = \(hasUnsavedChanges)")
                }
            } else {
                print("⚠️ [EditProfile] Failed to load data or create UIImage")
            }
        } catch {
            print("🚨 [EditProfile] Failed to load profile image: \(error)")
        }
    }
    
    private func processSelectedBannerImage(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                await MainActor.run {
                    selectedBannerUIImage = image
                    isVideoCover = false
                    checkForChanges() // Mark as unsaved so Save button becomes enabled
                }
            }
        } catch {
            print("Failed to load banner image: \(error)")
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
                        .onChange(of: text) { newValue in
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
                    .stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.2), lineWidth: isFocused ? 2 : 1)
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
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
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
    }
}

private struct DefaultProfileBanner: Identifiable, Hashable {
    enum Kind { case image, video }
    let id: String
    let title: String
    let subtitle: String
    let kind: Kind
    let assetURL: String
    let previewURL: String?
    
    static let all: [DefaultProfileBanner] = [
        .init(id: "b1", title: "Golden Hour Mountains", subtitle: "Warm cinematic tones", kind: .image, assetURL: "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=1600&q=80", previewURL: nil),
        .init(id: "b2", title: "Ocean Sunset", subtitle: "Soft gradients and waves", kind: .image, assetURL: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1600&q=80", previewURL: nil),
        .init(id: "b3", title: "City Lights", subtitle: "Modern urban vibe", kind: .image, assetURL: "https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=1600&q=80", previewURL: nil),
        .init(id: "b4", title: "Cinematic Nature", subtitle: "Subtle motion video", kind: .video, assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", previewURL: "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=1600&q=80"),
        .init(id: "b5", title: "Abstract Flow", subtitle: "Minimal gradient waves", kind: .image, assetURL: "https://images.unsplash.com/photo-154988033865ddcdfd017b?w=1600&q=80", previewURL: nil),
        .init(id: "b6", title: "Sintel Trailer", subtitle: "Cinematic video banner", kind: .video, assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4", previewURL: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1600&q=80"),
        .init(id: "b7", title: "Joyrides", subtitle: "Dynamic city motion", kind: .video, assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4", previewURL: "https://images.unsplash.com/photo-1493238792000-8113da705763?w=1600&q=80"),
        .init(id: "b8", title: "Escapes", subtitle: "Travel cinematic", kind: .video, assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4", previewURL: "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=1600&q=80"),
        .init(id: "b9", title: "Elephant Dream", subtitle: "Moody animation", kind: .video, assetURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4", previewURL: "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=1600&q=80")
    ]
}

private struct DefaultBannerPickerView: View {
    enum Mode { case image, video }
    let mode: Mode
    let onSelect: (DefaultProfileBanner) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var filtered: [DefaultProfileBanner] {
        DefaultProfileBanner.all.filter { mode == .image ? $0.kind == .image : $0.kind == .video }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(filtered) { banner in
                        Button {
                            onSelect(banner)
                            dismiss()
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                bannerThumb(banner)
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(banner.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(banner.subtitle)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                .padding(10)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Choose Banner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
    
    private func bannerThumb(_ banner: DefaultProfileBanner) -> some View {
        Group {
            if banner.kind == .video {
                ZStack {
                    CachedAsyncImage(url: URL(string: banner.previewURL ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 14).fill(AppTheme.Colors.textTertiary.opacity(0.15))
                    }
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "play.fill").foregroundStyle(.white).font(.system(size: 14, weight: .bold)))
                }
            } else {
                CachedAsyncImage(url: URL(string: banner.assetURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 14).fill(AppTheme.Colors.textTertiary.opacity(0.15))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView(user: .constant(User.sampleUsers[0]))
    }
    .environmentObject(AuthenticationManager.shared)
    .environmentObject(AppState())
    .preferredColorScheme(.light)
}