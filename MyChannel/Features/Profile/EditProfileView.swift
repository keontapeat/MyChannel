//
//  EditProfileView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var user: User
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var website: String = ""
    @State private var showingImagePicker: Bool = false
    @State private var showingBannerPicker: Bool = false
    @State private var hasChanges: Bool = false
    @State private var isSaving: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Images Section
                    profileImagesSection
                    
                    // Basic Info Section
                    basicInfoSection
                    
                    // Additional Info Section
                    additionalInfoSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await saveChanges()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(hasChanges ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                    .disabled(!hasChanges || isSaving)
                }
            }
            .onAppear {
                loadUserData()
            }
            .onChange(of: displayName) { _, _ in checkForChanges() }
            .onChange(of: username) { _, _ in checkForChanges() }
            .onChange(of: bio) { _, _ in checkForChanges() }
            .onChange(of: location) { _, _ in checkForChanges() }
            .onChange(of: website) { _, _ in checkForChanges() }
        }
    }
    
    private var profileImagesSection: some View {
        VStack(spacing: 16) {
            Text("Profile Images")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Banner Image
            VStack(spacing: 8) {
                ZStack {
                    if let bannerURL = user.bannerImageURL {
                        CachedAsyncImage(url: URL(string: bannerURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .aspectRatio(16/9, contentMode: .fill)
                        }
                    } else {
                        Rectangle()
                            .fill(AppTheme.Colors.surface)
                            .aspectRatio(16/9, contentMode: .fill)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            )
                    }
                    
                    // Edit Banner Button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            Button {
                                showingBannerPicker = true
                                HapticManager.shared.impact(style: .light)
                            } label: {
                                Image(systemName: "camera.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
                            .padding()
                        }
                    }
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                
                Text("Banner Image")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            // Profile Image
            VStack(spacing: 8) {
                ZStack {
                    if let profileImageURL = user.profileImageURL {
                        CachedAsyncImage(url: URL(string: profileImageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(AppTheme.Colors.surface)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.title)
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                )
                        }
                    } else {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.title)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            )
                    }
                    
                    // Edit Profile Image Button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            Button {
                                showingImagePicker = true
                                HapticManager.shared.impact(style: .light)
                            } label: {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
                        }
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                
                Text("Profile Picture")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .cardStyle()
    }
    
    private var basicInfoSection: some View {
        VStack(spacing: 16) {
            Text("Basic Information")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                ModernTextField(
                    title: "Display Name",
                    text: $displayName,
                    prompt: "Enter your display name"
                )
                
                ModernTextField(
                    title: "Username",
                    text: $username,
                    prompt: "Enter your username"
                )
                .textInputAutocapitalization(.never)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio")
                        .font(AppTheme.Typography.bodyMedium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    TextField("Tell us about yourself...", text: $bio, axis: .vertical)
                        .font(AppTheme.Typography.body)
                        .padding()
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(AppTheme.CornerRadius.md)
                        .lineLimit(3...6)
                    
                    Text("\(bio.count)/150")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(bio.count > 150 ? AppTheme.Colors.error : AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .cardStyle()
    }
    
    private var additionalInfoSection: some View {
        VStack(spacing: 16) {
            Text("Additional Information")
                .font(AppTheme.Typography.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                ModernTextField(
                    title: "Location",
                    text: $location,
                    prompt: "City, Country"
                )
                
                ModernTextField(
                    title: "Website",
                    text: $website,
                    prompt: "https://yourwebsite.com"
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            }
        }
        .cardStyle()
    }
    
    private func loadUserData() {
        displayName = user.displayName
        username = user.username
        bio = user.bio ?? ""
        location = user.location ?? ""
        website = user.website ?? ""
    }
    
    private func checkForChanges() {
        hasChanges = displayName != user.displayName ||
                    username != user.username ||
                    bio != (user.bio ?? "") ||
                    location != (user.location ?? "") ||
                    website != (user.website ?? "")
    }
    
    private func saveChanges() async {
        isSaving = true
        
        // Simulate save delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Update user object
        // In a real app, you'd save to your backend here
        let updatedUser = User(
            id: user.id,
            username: username,
            displayName: displayName,
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
        hasChanges = false
        
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
}

struct ModernTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.Typography.bodyMedium)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            TextField(prompt, text: $text)
                .font(AppTheme.Typography.body)
                .padding()
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)
        }
    }
}

#Preview {
    EditProfileView(user: .constant(User.sampleUsers[0]))
}