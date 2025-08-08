//
//  EditProfileView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import PhotosUI

// MARK: - Safe Edit Profile View
struct SafeEditProfileView: View {
    @Binding var user: User
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        SafeViewWrapper {
            EditProfileView(user: $user, dismiss: dismiss)
        } fallback: {
            EditProfileFallback(dismiss: dismiss)
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Binding var user: User
    let dismiss: DismissAction
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var website: String = ""
    @State private var selectedProfileImage: PhotosPickerItem?
    @State private var selectedBannerImage: PhotosPickerItem?
    @State private var isSaving = false
    @State private var showingImagePicker = false
    @State private var imagePickerType: ImagePickerType = .profile
    
    private enum ImagePickerType {
        case profile, banner
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header Section
                    profileHeaderSection
                    
                    // Form Fields
                    formFieldsSection
                    
                    // Social Links Section
                    socialLinksSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
        .onAppear {
            initializeFields()
        }
        .photosPicker(
            isPresented: $showingImagePicker,
            selection: imagePickerType == .profile ? $selectedProfileImage : $selectedBannerImage,
            matching: .images,
            photoLibrary: .shared()
        )
    }
    
    // MARK: - Profile Header Section
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Banner Image
            ZStack {
                if let bannerURL = user.bannerImageURL {
                    CachedAsyncImage(url: URL(string: bannerURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(AppTheme.Colors.surface)
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary.opacity(0.3), AppTheme.Colors.secondary.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Button(action: {
                    imagePickerType = .banner
                    showingImagePicker = true
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            
            // Profile Image
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
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(AppTheme.Colors.textTertiary)
                            )
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(String(user.displayName.prefix(1)))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                
                Button(action: {
                    imagePickerType = .profile
                    showingImagePicker = true
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(.black.opacity(0.8))
                        .clipShape(Circle())
                }
                .offset(x: 25, y: 25)
            }
            .offset(y: -40)
        }
    }
    
    // MARK: - Form Fields Section
    private var formFieldsSection: some View {
        VStack(spacing: 20) {
            ModernTextField(
                title: "Display Name",
                text: $displayName,
                icon: "person.fill"
            )
            
            ModernTextField(
                title: "Username",
                text: $username,
                icon: "at",
                prefix: "@"
            )
            
            ModernTextEditor(
                title: "Bio",
                text: $bio,
                icon: "text.quote",
                placeholder: "Tell people about yourself..."
            )
            
            ModernTextField(
                title: "Location",
                text: $location,
                icon: "location.fill"
            )
            
            ModernTextField(
                title: "Website",
                text: $website,
                icon: "globe",
                keyboardType: .URL
            )
        }
    }
    
    // MARK: - Social Links Section
    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Social Links")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Text("Connect your social media accounts")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(SocialPlatform.allCases, id: \.rawValue) { platform in
                    SocialLinkCard(
                        platform: platform,
                        existingLink: user.socialLinks.first { $0.platform == platform }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Actions
    private func initializeFields() {
        displayName = user.displayName
        username = user.username
        bio = user.bio ?? ""
        location = user.location ?? ""
        website = user.website ?? ""
    }
    
    private func saveProfile() {
        isSaving = true
        
        // Simulate save operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Update user with new values
            var updatedUser = user
            updatedUser = User(
                id: user.id,
                username: username.isEmpty ? user.username : username,
                displayName: displayName.isEmpty ? user.displayName : displayName,
                email: user.email,
                profileImageURL: user.profileImageURL,
                bannerImageURL: user.bannerImageURL,
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
                membershipTiers: user.membershipTiers
            )
            
            user = updatedUser
            isSaving = false
            
            // Notify that profile was updated
            NotificationCenter.default.post(name: .userProfileUpdated, object: updatedUser)
            
            HapticManager.shared.impact(style: .light)
            dismiss()
        }
    }
}

// MARK: - Modern Text Field
struct ModernTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let prefix: String?
    let keyboardType: UIKeyboardType
    
    init(title: String, text: Binding<String>, icon: String, prefix: String? = nil, keyboardType: UIKeyboardType = .default) {
        self.title = title
        self._text = text
        self.icon = icon
        self.prefix = prefix
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                    .frame(width: 20)
                
                if let prefix = prefix {
                    Text(prefix)
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                TextField("", text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .URL ? .never : .words)
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.textTertiary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Modern Text Editor
struct ModernTextEditor: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                        .frame(width: 20)
                    
                    Text("Bio")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("\(text.count)/150")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                TextEditor(text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(height: 80)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 16))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }
                    }
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.textTertiary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Social Link Card
struct SocialLinkCard: View {
    let platform: SocialPlatform
    let existingLink: SocialLink?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: platform.iconName)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 24)
            
            Text(platform.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            if existingLink != nil {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.primary)
            } else {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
            }
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(existingLink != nil ? AppTheme.Colors.primary.opacity(0.3) : AppTheme.Colors.textTertiary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Edit Profile Fallback
struct EditProfileFallback: View {
    let dismiss: DismissAction
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.Colors.textTertiary)
                
                VStack(spacing: 8) {
                    Text("Profile Editor Unavailable")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                    Text("Unable to load profile editor at this time.")
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(ProfileRetryButtonStyle())
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SafeEditProfileView(user: .constant(User.sampleUsers[0]))
}