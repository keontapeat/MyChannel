import SwiftUI
import PhotosUI
import AVFoundation

struct EditProfileView: View {
    @Binding var user: User
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authManager: AuthenticationManager

    // Profile basics
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var website: String = ""

    // Avatar
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var localAvatarURL: URL?

    // Header banner (image or video)
    @State private var selectedBannerImageItem: PhotosPickerItem?
    @State private var selectedBannerVideoItem: PhotosPickerItem?
    @State private var localBannerImageURL: URL?
    @State private var localBannerVideoURL: URL?
    @State private var bannerContentMode: BannerContentMode = .fill
    @State private var bannerMuted: Bool = true
    @State private var showDefaultBanners = false
    @State private var selectedDefaultBannerID: String = ""

    // State
    @State private var isSaving = false
    @State private var hasChanges = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerBannerSection
                    
                    profilePhotoSection
                    
                    basicInfoSection
                    
                    detailsSection
                }
                .padding(.vertical, 12)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || !hasChanges)
                }
            }
            .sheet(isPresented: $showDefaultBanners) {
                DefaultBannerPickerView(
                    userID: user.id,
                    selectedID: selectedDefaultBannerID
                ) { id in
                    selectedDefaultBannerID = id
                    applyDefaultBanner(id: id)
                    markChanged()
                }
            }
            .onAppear {
                displayName = user.displayName
                username = user.username
                bio = user.bio ?? ""
                location = user.location ?? ""
                website = user.website ?? ""
                bannerContentMode = user.bannerVideoContentMode ?? .fill
                bannerMuted = user.bannerVideoMuted ?? true
                selectedDefaultBannerID = getSelectedDefaultBannerID(for: user.id) ?? ""
            }
            .onChange(of: selectedAvatarItem) { _, item in
                guard let item else { return }
                Task { await handlePickedAvatar(item) }
            }
            .onChange(of: selectedBannerImageItem) { _, item in
                guard let item else { return }
                Task { await handlePickedBannerImage(item) }
            }
            .onChange(of: selectedBannerVideoItem) { _, item in
                guard let item else { return }
                Task { await handlePickedBannerVideo(item) }
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerBannerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Header Banner")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            ZStack(alignment: .bottomTrailing) {
                bannerPreview
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                
                HStack(spacing: 8) {
                    PhotosPicker(selection: $selectedBannerImageItem, matching: .images) {
                        Label("Photo", systemImage: "photo")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    PhotosPicker(selection: $selectedBannerVideoItem, matching: .videos) {
                        Label("Video", systemImage: "film")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Button {
                        showDefaultBanners = true
                    } label: {
                        Label("Defaults", systemImage: "square.grid.2x2")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(10)
            }
            .padding(.horizontal, 16)
            
            if hasVideoBannerSelectedOrExisting {
                HStack {
                    Picker("Fill", selection: $bannerContentMode) {
                        Text("Fill").tag(BannerContentMode.fill)
                        Text("Fit").tag(BannerContentMode.fit)
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Mute", isOn: $bannerMuted)
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 16)
                .onChange(of: bannerContentMode) { _, _ in markChanged() }
                .onChange(of: bannerMuted) { _, _ in markChanged() }
            }
        }
    }
    
    private var profilePhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Profile Photo")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            HStack(spacing: 16) {
                ProfileAvatarView(
                    urlString: (localAvatarURL?.absoluteString) ?? user.profileImageURL,
                    size: 72
                )
                .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
                
                PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                    Text("Change Photo")
                        .font(.callout.weight(.semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(AppTheme.Colors.background, in: Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Basic Information")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            Group {
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: displayName) { _, _ in markChanged() }
                
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: username) { _, _ in markChanged() }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    TextEditor(text: $bio)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                        .onChange(of: bio) { _, _ in markChanged() }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            Group {
                TextField("Location", text: $location)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: location) { _, _ in markChanged() }
                
                TextField("Website", text: $website)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: website) { _, _ in markChanged() }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Banner Preview
    
    private var bannerPreview: some View {
        Group {
            if let url = localBannerImageURL {
                ImageForURL(url: url)
            } else if let url = localBannerVideoURL {
                ZStack {
                    videoThumbnailOrPlaceholder(url: url)
                    Circle().fill(.black.opacity(0.45))
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: "play.fill").foregroundStyle(.white))
                }
            } else if let bannerVideo = user.bannerVideoURL, let url = URL(string: bannerVideo) {
                ZStack {
                    videoThumbnailOrPlaceholder(url: url)
                    Circle().fill(.black.opacity(0.45))
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: "play.fill").foregroundStyle(.white))
                }
            } else if let bannerImage = user.bannerImageURL, let url = URL(string: bannerImage) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    bannerPlaceholder
                }
            } else if let selected = getSelectedDefaultBanner(for: user.id) {
                if selected.kind == .image, let url = URL(string: selected.assetURL) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        bannerPlaceholder
                    }
                } else if selected.kind == .video, let url = URL(string: selected.previewURL ?? "") {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        bannerPlaceholder
                    }
                } else {
                    bannerPlaceholder
                }
            } else {
                bannerPlaceholder
            }
        }
        .clipped()
    }
    
    private var bannerPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [AppTheme.Colors.primary.opacity(0.12), AppTheme.Colors.secondary.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.secondary)
            )
    }
    
    private var hasVideoBannerSelectedOrExisting: Bool {
        localBannerVideoURL != nil || user.bannerVideoURL != nil
    }
    
    // MARK: - Actions
    
    private func markChanged() {
        hasChanges = true
    }

    private func handlePickedAvatar(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self), !data.isEmpty {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let url = docs.appendingPathComponent("profile_\(user.id).png")
                try? FileManager.default.removeItem(at: url)
                try data.write(to: url, options: .atomic)
                await MainActor.run {
                    localAvatarURL = url
                    markChanged()
                }
            }
        } catch {
            print("Avatar pick error: \(error)")
        }
    }
    
    private func handlePickedBannerImage(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self), !data.isEmpty {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let url = docs.appendingPathComponent("banner_image_\(user.id).jpg")
                try? FileManager.default.removeItem(at: url)
                try data.write(to: url, options: .atomic)
                await MainActor.run {
                    localBannerImageURL = url
                    localBannerVideoURL = nil
                    markChanged()
                }
            }
        } catch {
            print("Banner image pick error: \(error)")
        }
    }
    
    private func handlePickedBannerVideo(_ item: PhotosPickerItem) async {
        do {
            // Save picked data to temp file
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else { return }
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("picked_\(UUID().uuidString).mov")
            try data.write(to: tmp, options: .atomic)
            
            // Prepare/trim/compress for banner
            let prepared = try await ProfileMediaUploader.prepareBannerVideo(from: tmp)
            
            // Persist to Documents
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let finalURL = docs.appendingPathComponent("banner_video_\(user.id).mp4")
            try? FileManager.default.removeItem(at: finalURL)
            try FileManager.default.copyItem(at: prepared, to: finalURL)
            
            await MainActor.run {
                localBannerVideoURL = finalURL
                localBannerImageURL = nil
                bannerMuted = true
                bannerContentMode = .fill
                markChanged()
            }
        } catch {
            print("Banner video pick error: \(error)")
        }
    }
    
    private func normalizedWebsite(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        } else {
            return "https://\(trimmed)"
        }
    }
    
    private func applyDefaultBanner(id: String) {
        guard let selected = DefaultProfileBanner.defaults.first(where: { $0.id == id }) else { return }
        if selected.kind == .image {
            localBannerImageURL = URL(string: selected.assetURL)
            localBannerVideoURL = nil
        } else {
            localBannerVideoURL = URL(string: selected.assetURL)
            localBannerImageURL = nil
        }
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }

        // Decide banner fields to save
        let bannerImageString: String? = {
            if let local = localBannerImageURL { return local.absoluteString }
            if localBannerVideoURL != nil { return nil } // prefer video if both somehow set
            return user.bannerImageURL
        }()
        let bannerVideoString: String? = {
            if let local = localBannerVideoURL { return local.absoluteString }
            if localBannerImageURL != nil { return nil }
            return user.bannerVideoURL
        }()
        
        let newUser = User(
            id: user.id,
            username: username.isEmpty ? user.username : username,
            displayName: displayName.isEmpty ? user.displayName : displayName,
            email: user.email,
            profileImageURL: (localAvatarURL?.absoluteString) ?? user.profileImageURL,
            bannerImageURL: bannerImageString,
            bio: bio.isEmpty ? nil : bio,
            subscriberCount: user.subscriberCount,
            videoCount: user.videoCount,
            isVerified: user.isVerified,
            isCreator: user.isCreator,
            createdAt: user.createdAt,
            location: location.isEmpty ? nil : location,
            website: normalizedWebsite(website),
            socialLinks: user.socialLinks,
            followerCount: user.followerCount,
            followingCount: user.followingCount,
            joinDate: user.joinDate,
            totalViews: user.totalViews,
            totalEarnings: user.totalEarnings,
            membershipTiers: user.membershipTiers,
            bannerVideoURL: bannerVideoString,
            bannerVideoMuted: bannerVideoString != nil ? bannerMuted : user.bannerVideoMuted,
            bannerVideoContentMode: bannerVideoString != nil ? bannerContentMode : user.bannerVideoContentMode
        )

        user = newUser
        if authManager.currentUser?.id == newUser.id {
            authManager.updateUser(newUser)
        }
        if appState.currentUser?.id == newUser.id {
            appState.updateUser(newUser)
        }
        NotificationCenter.default.post(name: .userProfileUpdated, object: newUser)
        HapticManager.shared.impact(style: .light)
        dismiss()
    }
}

// MARK: - Helpers

private struct ImageForURL: View {
    let url: URL
    var body: some View {
        if url.isFileURL {
            if let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.2))
            }
        } else {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.2))
            }
        }
    }
}

private func videoThumbnailOrPlaceholder(url: URL) -> some View {
    Group {
        if let thumb = generateThumbnail(url: url) {
            Image(uiImage: thumb).resizable().scaledToFill()
        } else {
            LinearGradient(
                colors: [AppTheme.Colors.backgroundSecondary, AppTheme.Colors.background],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private func generateThumbnail(url: URL) -> UIImage? {
    let asset = AVAsset(url: url)
    let gen = AVAssetImageGenerator(asset: asset)
    gen.appliesPreferredTrackTransform = true
    gen.maximumSize = CGSize(width: 800, height: 800)
    do {
        let cg = try gen.copyCGImage(at: CMTime(seconds: 0.1, preferredTimescale: 600), actualTime: nil)
        return UIImage(cgImage: cg)
    } catch {
        return nil
    }
}

#Preview("Edit Profile – Minimal") {
    NavigationStack {
        EditProfileView(user: .constant(User.sampleUsers[0]))
    }
    .preferredColorScheme(.light)
}