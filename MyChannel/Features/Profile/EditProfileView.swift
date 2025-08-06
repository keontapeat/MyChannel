//
//  EditProfileView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var user: User
    
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var website: String = ""
    @State private var hasChanges: Bool = false
    @State private var isSaving: Bool = false
    @State private var isLoadingBanner: Bool = false
    @State private var isLoadingProfile: Bool = false
    
    // Image handling states
    @State private var selectedBannerItem: PhotosPickerItem?
    @State private var selectedProfileItem: PhotosPickerItem?
    @State private var bannerImage: UIImage?
    @State private var profileImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Premium background gradient
                LinearGradient(
                    colors: [
                        AppTheme.Colors.background,
                        AppTheme.Colors.background.opacity(0.95),
                        AppTheme.Colors.surface.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Premium Profile Images Section
                        premiumProfileImagesSection
                            .padding(.bottom, 32)
                        
                        VStack(spacing: 28) {
                            // Enhanced Basic Info Section
                            premiumBasicInfoSection
                            
                            // Enhanced Additional Info Section
                            premiumAdditionalInfoSection
                            
                            // Premium Advanced Settings Section
                            premiumAdvancedSettingsSection
                            
                            Spacer(minLength: 120)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if hasChanges {
                            showDiscardChangesAlert()
                        } else {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: hasChanges ? "xmark" : "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            if !hasChanges {
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        .foregroundColor(hasChanges ? AppTheme.Colors.error : AppTheme.Colors.primary)
                        .padding(.horizontal, hasChanges ? 12 : 8)
                        .padding(.vertical, 8)
                        .background(
                            hasChanges ? AppTheme.Colors.error.opacity(0.1) : AppTheme.Colors.primary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await saveChanges() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Saving...")
                                    .font(.system(size: 15, weight: .semibold))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Save")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            hasChanges ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary.opacity(0.5),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .scaleEffect(isSaving ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSaving)
                    }
                    .disabled(!hasChanges || isSaving)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear { loadUserData() }
            .onChange(of: displayName) { _, _ in checkForChanges() }
            .onChange(of: username) { _, _ in checkForChanges() }
            .onChange(of: bio) { _, _ in checkForChanges() }
            .onChange(of: location) { _, _ in checkForChanges() }
            .onChange(of: website) { _, _ in checkForChanges() }
            .onChange(of: selectedBannerItem) { _, newItem in
                Task { await processBannerImage(newItem) }
            }
            .onChange(of: selectedProfileItem) { _, newItem in
                Task { await processProfileImage(newItem) }
            }
        }
    }
    
    private var premiumProfileImagesSection: some View {
        VStack(spacing: 0) {
            // Premium Banner Section
            ZStack {
                bannerImageView
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                
                // Sophisticated gradient overlay
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Sleek Banner Controls
                VStack {
                    HStack {
                        Spacer()
                        
                        // Clean Action Buttons Row
                        HStack(spacing: 12) {
                            // Banner Edit Button
                            PhotosPicker(selection: $selectedBannerItem, matching: .images) {
                                HStack(spacing: 6) {
                                    if isLoadingBanner {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: bannerImage != nil || user.bannerImageURL != nil ? "pencil" : "plus")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text(bannerImage != nil || user.bannerImageURL != nil ? "Edit" : "Add")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial.opacity(0.8))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isLoadingBanner)
                            
                            // Delete Button (only if banner exists)
                            if bannerImage != nil || user.bannerImageURL != nil {
                                Button {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        bannerImage = nil
                                        checkForChanges()
                                    }
                                    HapticManager.shared.impact(style: .medium)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(.red.opacity(0.8))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                                        .shadow(color: .red.opacity(0.3), radius: 6, x: 0, y: 3)
                                }
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            
            // Premium Profile Image (overlapping)
            VStack(spacing: 16) {
                ZStack {
                    profileImageView
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 5
                                )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 25, x: 0, y: 12)
                    
                    // Premium Profile Edit Button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            PhotosPicker(selection: $selectedProfileItem, matching: .images) {
                                if isLoadingProfile {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                        .padding(14)
                                        .background(.ultraThinMaterial, in: Circle())
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(14)
                                        .background(AppTheme.Colors.primary, in: Circle())
                                        .overlay(Circle().stroke(.white, lineWidth: 2.5))
                                        .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 12, x: 0, y: 6)
                                }
                            }
                            .disabled(isLoadingProfile)
                            .scaleEffect(isLoadingProfile ? 0.9 : 1.0)
                        }
                    }
                }
                .offset(y: -50)
                
                Text("Profile Picture")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .offset(y: -50)
            }
        }
    }
    
    private var premiumBasicInfoSection: some View {
        PremiumCard(
            title: "Basic Information",
            icon: "person.text.rectangle.fill",
            iconColor: AppTheme.Colors.primary
        ) {
            VStack(spacing: 24) {
                PremiumTextField(
                    title: "Display Name",
                    text: $displayName,
                    prompt: "Enter your display name",
                    icon: "person.circle.fill",
                    maxLength: 50
                )
                
                PremiumTextField(
                    title: "Username",
                    text: $username,
                    prompt: "Enter your username",
                    icon: "at.circle.fill",
                    prefix: "@",
                    maxLength: 30
                )
                .textInputAutocapitalization(.never)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "text.alignleft.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text("Bio")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text("\(bio.count)/150")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(bio.count > 150 ? AppTheme.Colors.error : AppTheme.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                bio.count > 150 ? AppTheme.Colors.error.opacity(0.1) : AppTheme.Colors.surface,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    
                    TextField("Tell your viewers about yourself...", text: $bio, axis: .vertical)
                        .font(.system(size: 16))
                        .padding(16)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(16)
                        .lineLimit(3...6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    bio.count > 150 ? AppTheme.Colors.error : AppTheme.Colors.primary.opacity(0.2),
                                    lineWidth: bio.count > 150 ? 2 : 1
                                )
                        )
                }
            }
        }
    }
    
    private var premiumAdditionalInfoSection: some View {
        PremiumCard(
            title: "Additional Information",
            icon: "info.circle.fill",
            iconColor: AppTheme.Colors.secondary
        ) {
            VStack(spacing: 24) {
                PremiumTextField(
                    title: "Location",
                    text: $location,
                    prompt: "City, Country",
                    icon: "location.circle.fill",
                    maxLength: 100
                )
                
                PremiumTextField(
                    title: "Website",
                    text: $website,
                    prompt: "https://yourwebsite.com",
                    icon: "link.circle.fill",
                    maxLength: 200
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            }
        }
    }
    
    private var premiumAdvancedSettingsSection: some View {
        PremiumCard(
            title: "Advanced Settings",
            icon: "gearshape.fill",
            iconColor: Color.purple
        ) {
            VStack(spacing: 20) {
                PremiumSettingRow(
                    title: "Channel Privacy",
                    subtitle: "Control who can see your content",
                    icon: "eye.circle.fill",
                    actionText: "Manage",
                    action: { /* Handle privacy settings */ }
                )
                
                if !user.isVerified {
                    PremiumSettingRow(
                        title: "Channel Verification",
                        subtitle: "Get verified to build trust with your audience",
                        icon: "checkmark.seal.fill",
                        actionText: "Apply",
                        actionColor: .blue,
                        action: { /* Handle verification */ }
                    )
                }
                
                PremiumSettingRow(
                    title: "Content Settings",
                    subtitle: "Manage your content preferences and defaults",
                    icon: "slider.horizontal.3.circle.fill",
                    actionText: "Configure",
                    action: { /* Handle content settings */ }
                )
            }
        }
    }
    
    // MARK: - View Builders
    
    @ViewBuilder
    private var bannerImageView: some View {
        if let bannerImage = bannerImage {
            Image(uiImage: bannerImage)
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
        } else if let bannerURL = user.bannerImageURL {
            CachedAsyncImage(url: URL(string: bannerURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary.opacity(0.8), AppTheme.Colors.secondary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(16/9, contentMode: .fill)
                    .overlay(ProgressView().scaleEffect(1.2))
            }
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.primary.opacity(0.7),
                            AppTheme.Colors.secondary.opacity(0.7),
                            Color.purple.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(16/9, contentMode: .fill)
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white.opacity(0.9))
                        
                        VStack(spacing: 6) {
                            Text("Add Your Banner")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Recommended: 1920×1080 pixels")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("Perfect fit for your profile header")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(24)
                )
        }
    }
    
    @ViewBuilder
    private var profileImageView: some View {
        if let profileImage = profileImage {
            Image(uiImage: profileImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
        } else if let profileImageURL = user.profileImageURL {
            CachedAsyncImage(url: URL(string: profileImageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(ProgressView().scaleEffect(1.2))
            }
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.Colors.surface, AppTheme.Colors.surface.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("Add Photo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                )
        }
    }
    
    // MARK: - Helper Methods
    
    private func processBannerImage(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        await MainActor.run { isLoadingBanner = true }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let processedImage = await processBannerForOptimalFit(image)
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        bannerImage = processedImage
                    }
                    isLoadingBanner = false
                    checkForChanges()
                    HapticManager.shared.notification(type: .success)
                }
            }
        } catch {
            await MainActor.run {
                isLoadingBanner = false
                HapticManager.shared.notification(type: .error)
            }
        }
    }
    
    private func processProfileImage(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        await MainActor.run { isLoadingProfile = true }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let processedImage = await processProfileImageToSquare(image)
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        profileImage = processedImage
                    }
                    isLoadingProfile = false
                    checkForChanges()
                    HapticManager.shared.notification(type: .success)
                }
            }
        } catch {
            await MainActor.run {
                isLoadingProfile = false
                HapticManager.shared.notification(type: .error)
            }
        }
    }
    
    private func processBannerForOptimalFit(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let targetSize = CGSize(width: 1920, height: 1080)
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                
                let processedImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: targetSize))
                }
                
                continuation.resume(returning: processedImage)
            }
        }
    }
    
    private func processProfileImageToSquare(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let targetSize = CGSize(width: 400, height: 400)
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                
                let processedImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: targetSize))
                }
                
                continuation.resume(returning: processedImage)
            }
        }
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
                    website != (user.website ?? "") ||
                    bannerImage != nil ||
                    profileImage != nil
    }
    
    private func saveChanges() async {
        await MainActor.run { isSaving = true }
        
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        var updatedBannerURL = user.bannerImageURL
        var updatedProfileURL = user.profileImageURL
        
        if bannerImage != nil {
            updatedBannerURL = "https://updated-banner-url.com"
        }
        
        if profileImage != nil {
            updatedProfileURL = "https://updated-profile-url.com"
        }
        
        let updatedUser = User(
            id: user.id,
            username: username,
            displayName: displayName,
            email: user.email,
            profileImageURL: updatedProfileURL,
            bannerImageURL: updatedBannerURL,
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
        
        await MainActor.run {
            user = updatedUser
            isSaving = false
            hasChanges = false
            HapticManager.shared.notification(type: .success)
            dismiss()
        }
    }
    
    private func showDiscardChangesAlert() {
        dismiss()
    }
}

// MARK: - Premium UI Components

struct PremiumCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: () -> Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            content()
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.Colors.cardBackground,
                    AppTheme.Colors.cardBackground.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(
            color: AppTheme.ModernEffects.cardShadow.color,
            radius: 20,
            x: 0,
            y: 8
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.Colors.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct PremiumTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let icon: String
    var prefix: String = ""
    let maxLength: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(text.count)/\(maxLength)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(text.count > maxLength ? AppTheme.Colors.error : AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        text.count > maxLength ? AppTheme.Colors.error.opacity(0.1) : AppTheme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
            
            HStack(spacing: 12) {
                if !prefix.isEmpty {
                    Text(prefix)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                        .padding(.leading, 4)
                }
                
                TextField(prompt, text: $text)
                    .font(.system(size: 16))
                    .onChange(of: text) { oldValue, newValue in
                        if newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        text.count > maxLength ? AppTheme.Colors.error : AppTheme.Colors.primary.opacity(0.2),
                        lineWidth: text.count > maxLength ? 2 : 1
                    )
            )
        }
    }
}

struct PremiumSettingRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let actionText: String
    var actionColor: Color = AppTheme.Colors.primary
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(actionColor)
                .frame(width: 40, height: 40)
                .background(actionColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: action) {
                Text(actionText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(actionColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(actionColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EditProfileView(user: .constant(User.sampleUsers[0]))
}