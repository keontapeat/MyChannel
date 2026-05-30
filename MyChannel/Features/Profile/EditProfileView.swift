//
//  EditProfileView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

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
    @State private var selectedProfileUIImage: UIImage?
    @State private var selectedBannerUIImage: UIImage?
    @State private var isSaving = false
    @State private var showingProfileImagePicker = false
    @State private var showingBannerImagePicker = false
    @State private var showingSaveConfirmation = false
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    
    @State private var isVideoCover: Bool = false
    @State private var showingUIKitVideoPicker = false
    @State private var bannerVideoLocalURL: URL?
    @State private var bannerVideoMuted: Bool = true
    @State private var bannerContentMode: UserBannerContentMode = .fill
    @State private var bannerVideoDurationText: String?
    @State private var bannerVideoSizeText: String?
    
    @State private var showingDefaultBannerPicker = false
    @State private var selectedDefaultBannerImageURL: String? = nil
    @State private var selectedDefaultBannerVideoURL: String? = nil
    
    // Perf: defer expensive image/video preview rendering until after first paint
    @State private var heavyContentReady: Bool = false
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    
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
        .task {
            initializeFields()
            // Yield one frame so the form fields paint immediately,
            // then enable the heavier banner/profile image loads.
            await Task.yield()
            await MainActor.run { heavyContentReady = true }
        }
        .onChange(of: displayName) { _ in checkForChanges() }
        .onChange(of: username) { _ in checkForChanges() }
        .onChange(of: bio) { _ in checkForChanges() }
        .onChange(of: location) { _ in checkForChanges() }
        .onChange(of: website) { _ in checkForChanges() }
        .photosPicker(
            isPresented: $showingProfileImagePicker,
            selection: $selectedProfileImage,
            matching: .images,
            photoLibrary: .shared()
        )
        .photosPicker(
            isPresented: $showingBannerImagePicker,
            selection: $selectedBannerImage,
            matching: .images,
            photoLibrary: .shared()
        )
        .sheet(isPresented: $showingUIKitVideoPicker) {
            UIKitBannerVideoPicker { url in
                guard let url else { return }
                Task { await processSelectedBannerVideoURL(url) }
            }
        }
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
                
                coverTypeSelector

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
                            showingUIKitVideoPicker = true
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Label("Pick & Trim Video", systemImage: "video.badge.plus")
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

                    if let duration = bannerVideoDurationText, let size = bannerVideoSizeText {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                            Text("\(duration) • \(size) • Auto-trims to 15s on save")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 10))
                    }

                    ZStack {
                        if heavyContentReady, let urlStr = selectedDefaultBannerVideoURL, let url = URL(string: urlStr) {
                            VideoBannerPreview(url: url, isMuted: bannerVideoMuted, contentMode: bannerContentMode)
                        } else if heavyContentReady, let local = bannerVideoLocalURL {
                            VideoBannerPreview(url: local, isMuted: bannerVideoMuted, contentMode: bannerContentMode)
                        } else if heavyContentReady, let currentRemote = user.bannerVideoURL, let url = URL(string: currentRemote) {
                            VideoBannerPreview(url: url, isMuted: bannerVideoMuted, contentMode: bannerContentMode)
                        } else {
                            Rectangle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Image(systemName: "video.fill")
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
                    .allowsHitTesting(false)
                } else {
                    // Photo source buttons
                    HStack(spacing: 12) {
                        Button {
                            showingBannerImagePicker = true
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

                    ZStack {
                        if let selectedImage = selectedBannerUIImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if heavyContentReady, let urlStr = selectedDefaultBannerImageURL, let url = URL(string: urlStr) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(AppTheme.Colors.surface)
                            }
                        } else if heavyContentReady, let bannerURL = user.bannerImageURL {
                            CachedAsyncImage(url: URL(string: bannerURL)) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(AppTheme.Colors.surface)
                            }
                        } else {
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
                    .allowsHitTesting(false)
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
                        showingProfileImagePicker = true
                        HapticManager.shared.impact(style: .light)
                    }) {
                        ZStack {
                            if let selectedImage = selectedProfileUIImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if heavyContentReady, let profileURL = user.profileImageURL {
                                CachedAsyncImage(url: URL(string: profileURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(AppTheme.Colors.surface)
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
    }
    
    private var coverTypeSelector: some View {
        HStack(spacing: 0) {
            coverTypeButton(title: "Photo", isSelected: !isVideoCover) {
                setCoverType(video: false)
            }
            
            coverTypeButton(title: "Video", isSelected: isVideoCover) {
                setCoverType(video: true)
            }
        }
        .padding(2)
        .background(Color(.systemGray5), in: Capsule())
    }
    
    private func coverTypeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(isSelected ? Color.white : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
    
    private func setCoverType(video: Bool) {
        guard isVideoCover != video else { return }
        isVideoCover = video
        hasUnsavedChanges = true
        if video {
            selectedDefaultBannerImageURL = nil
            selectedBannerImage = nil
            selectedBannerUIImage = nil
        } else {
            selectedDefaultBannerVideoURL = nil
            bannerVideoLocalURL = nil
        }
        HapticManager.shared.impact(style: .light)
    }
    
    // MARK: - Form Fields Section
    private var formFieldsSection: some View {
        let progress = getFieldProgress()
        return VStack(spacing: 24) {
            // Section header with progress
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Basic Information")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("\(progress)/5 fields completed")
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
                        .trim(from: 0, to: CGFloat(progress) / 5.0)
                        .stroke(AppTheme.Colors.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                    
                    Text("\(Int((Double(progress) / 5.0) * 100))%")
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
        bannerVideoMuted = user.bannerVideoMuted ?? true
        bannerContentMode = user.bannerVideoContentMode ?? .fill
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
                await MainActor.run {
                    selectedBannerImage = nil
                    selectedBannerUIImage = nil
                    selectedDefaultBannerImageURL = nil
                }
                if let defaultVideoURL = selectedDefaultBannerVideoURL {
                    remoteBannerURL = defaultVideoURL
                } else if let localURL = bannerVideoLocalURL {
                    do {
                        let prepared = try await ProfileMediaUploader.prepareBannerVideo(from: localURL)
                        let remote = try await ProfileMediaUploader.uploadBannerVideo(prepared, uid: user.id)
                        remoteBannerURL = remote
                    } catch {
                        print("Banner upload failed: \(error)")
                        // Never persist file:// URLs — they break after relaunch. Keep last known remote URL.
                        remoteBannerURL = user.bannerVideoURL
                    }
                }
            }

            // Upload profile image and banner image in parallel
            print("📤 Starting parallel uploads for user: \(user.id)")
            let capturedProfileImage = selectedProfileUIImage
            let capturedBannerImage = (!isVideoCover) ? selectedBannerUIImage : nil
            let capturedDefaultBannerURL = (!isVideoCover) ? selectedDefaultBannerImageURL : nil
            let existingProfileURL = user.profileImageURL
            let existingBannerURL = user.bannerImageURL
            let uid = user.id
            let (profileImageURL, imageBannerURL): (String?, String?) = await withTaskGroup(of: (Bool, String?).self) { group in
                group.addTask {
                    guard let img = capturedProfileImage else {
                        print("ℹ️ No profile image selected - keeping existing URL: \(existingProfileURL ?? "nil")")
                        return (true, existingProfileURL)
                    }
                    do {
                        let url = try await UserMediaStorageService.shared.uploadAvatar(uid: uid, image: img)
                        print("✅ Profile image uploaded successfully: \(url)")
                        return (true, url)
                    } catch {
                        print("🚨 Profile image upload failed: \(error.localizedDescription)")
                        return (true, existingProfileURL)
                    }
                }
                group.addTask {
                    guard let img = capturedBannerImage else {
                        return (false, capturedDefaultBannerURL ?? existingBannerURL)
                    }
                    do {
                        let url = try await UserMediaStorageService.shared.uploadBanner(uid: uid, image: img)
                        return (false, url)
                    } catch {
                        print("Banner image upload failed: \(error)")
                        return (false, existingBannerURL)
                    }
                }
                var profileURL: String? = existingProfileURL
                var bannerURL: String? = existingBannerURL
                for await (isProfile, url) in group {
                    if isProfile { profileURL = url } else { bannerURL = url }
                }
                return (profileURL, bannerURL)
            }
            print("✅ Parallel uploads complete — profile: \(profileImageURL ?? "nil"), banner: \(imageBannerURL ?? "nil")")

            let previousProfileImageURL = existingProfileURL
            let previousBannerImageURL = existingBannerURL
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
                    // Evict only the old avatar/banner URLs so other cached images are unaffected
                    if let old = previousProfileImageURL.flatMap(URL.init) { ImageCache.shared.remove(for: old) }
                    if let old = previousBannerImageURL.flatMap(URL.init) { ImageCache.shared.remove(for: old) }
                    print("🗑️ Evicted old avatar/banner from image cache")
                    
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
            
            await MainActor.run {
                isSaving = false
                hasUnsavedChanges = false
                
                // Clear selected profile image whenever we have a new URL from Storage
                // (covers first-ever upload where previousProfileImageURL is nil)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if selectedProfileUIImage != nil, finalProfileImageURL != nil {
                        print("✅ Clearing selectedProfileUIImage - new URL: \(finalProfileImageURL!)")
                        selectedProfileUIImage = nil
                    } else if finalProfileImageURL == nil {
                        print("⚠️ Upload may have failed — previousURL: \(previousProfileImageURL ?? "nil"), newURL: nil")
                    }
                }
                if selectedBannerUIImage != nil && imageBannerURL != nil {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        selectedBannerUIImage = nil
                    }
                }
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingSaveConfirmation = true
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingSaveConfirmation = false
                    }
                }
                
                ProfileCacheService.shared.clearCache()
                
                print("📢 Posting userProfileUpdated notification with profileImageURL: \(updatedUser.profileImageURL ?? "nil")")
                NotificationCenter.default.post(name: .userProfileUpdated, object: updatedUser)
                NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
                
                HapticManager.shared.impact(style: .light)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    dismiss()
                }
            }
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
    private func processSelectedBannerVideoURL(_ url: URL) async {
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docs.appendingPathComponent("banner_\(user.id)_\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: fileURL)
            try await Task.detached(priority: .utility) {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    try FileManager.default.copyItem(at: url, to: fileURL)
                } else {
                    try FileManager.default.copyItem(at: url, to: fileURL)
                }
            }.value
            let details = await bannerVideoDetails(for: fileURL)
            await MainActor.run {
                bannerVideoLocalURL = fileURL
                bannerVideoDurationText = details.duration
                bannerVideoSizeText = details.size
                selectedDefaultBannerVideoURL = nil
                selectedDefaultBannerImageURL = nil
                isVideoCover = true
                hasUnsavedChanges = true
            }
        } catch {
            print("Failed to import UIKit banner video: \(error)")
        }
    }

    private func bannerVideoDetails(for url: URL) async -> (duration: String, size: String) {
        let asset = AVAsset(url: url)
        let seconds = (try? await asset.load(.duration).seconds) ?? 0
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = attributes?[.size] as? Int64 ?? 0
        let durationText = seconds.isFinite ? String(format: "%.0fs", seconds) : "Video"
        let sizeText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return (durationText, sizeText)
    }
}


// ⚡ Helper components extracted to EditProfileComponents.swift
