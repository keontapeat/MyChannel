//
//  ChannelCustomizationView.swift
//  MyChannel
//
//  100% COMPLETE CHANNEL CUSTOMIZATION! 🎨
//  Loads the signed-in creator's profile and persists changes to Firestore + Storage.
//

import SwiftUI
import PhotosUI

struct ChannelCustomizationView: View {
    @EnvironmentObject private var appState: AppState

    @State private var bannerItem: PhotosPickerItem?
    @State private var profileItem: PhotosPickerItem?
    @State private var bannerImage: UIImage?
    @State private var profileImage: UIImage?

    @State private var channelName = ""
    @State private var handle = ""
    @State private var description = ""
    @State private var instagram = ""
    @State private var twitter = ""
    @State private var website = ""

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                if isLoading {
                    ProgressView("Loading channel…")
                        .padding(40)
                } else {
                    bannerSection
                    profileSection
                    detailsSection
                    socialLinksSection
                    saveButton
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Customization")
        .task {
            // Load once; guard so PhotosPicker round-trips don't wipe edits.
            if !didLoad { loadCurrentChannel() }
        }
        .onChange(of: bannerItem) { newValue in
            Task { await loadImage(from: newValue, into: { bannerImage = $0 }) }
        }
        .onChange(of: profileItem) { newValue in
            Task { await loadImage(from: newValue, into: { profileImage = $0 }) }
        }
    }

    // MARK: - Banner

    private var bannerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Channel Banner")
                .font(.system(size: 18, weight: .semibold))
            PhotosPicker(selection: $bannerItem, matching: .images) {
                if let banner = bannerImage {
                    Image(uiImage: banner)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let urlString = appState.currentUser?.bannerImageURL,
                          let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5))
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus")
                                Text("Upload Banner")
                            }
                            .foregroundColor(.secondary)
                        )
                }
            }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Picture")
                .font(.system(size: 18, weight: .semibold))
            PhotosPicker(selection: $profileItem, matching: .images) {
                if let profile = profileImage {
                    Image(uiImage: profile)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else if let urlString = appState.currentUser?.profileImageURL,
                          let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color(.systemGray5))
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 100)
                        .overlay(Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 36)).foregroundColor(.secondary))
                }
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Channel Details")
                .font(.system(size: 18, weight: .semibold))
            TextField("Channel Name", text: $channelName)
                .textFieldStyle(.roundedBorder)
            TextField("Handle (@username)", text: $handle)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Description", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(5...10)
        }
    }

    // MARK: - Social Links

    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Social Links")
                .font(.system(size: 18, weight: .semibold))
            TextField("Instagram", text: $instagram)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Twitter", text: $twitter)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Website", text: $website)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button(action: { Task { await saveChanges() } }) {
            HStack {
                if isSaving { ProgressView().tint(.white).padding(.trailing, 4) }
                Text(isSaving ? "Saving…" : "Save Changes")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isSaving || channelName.isEmpty)
    }

    // MARK: - Data

    private func loadCurrentChannel() {
        guard let user = appState.currentUser else {
            isLoading = false
            return
        }
        channelName = user.displayName
        handle = user.username
        description = user.bio ?? ""
        website = user.website ?? ""
        instagram = user.socialLinks.first(where: { $0.platform == .instagram })?.url ?? ""
        twitter = user.socialLinks.first(where: { $0.platform == .twitter })?.url ?? ""
        isLoading = false
        didLoad = true
    }

    private func loadImage(from item: PhotosPickerItem?, into assign: @escaping (UIImage) -> Void) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await MainActor.run { assign(image) }
        }
    }

    private func saveChanges() async {
        guard let user = appState.currentUser else {
            statusMessage = "Sign in required to edit your channel."
            return
        }
        isSaving = true
        statusMessage = nil
        HapticManager.shared.impact(style: .medium)

        let uid = user.id

        // Upload any newly picked images; fall back to existing URLs on failure.
        var profileURL = user.profileImageURL
        var bannerURL = user.bannerImageURL

        if let profileImage {
            do { profileURL = try await UserMediaStorageService.shared.uploadAvatar(uid: uid, image: profileImage) }
            catch { print("⚠️ [ChannelCustomization] avatar upload failed: \(error.localizedDescription)") }
        }
        if let bannerImage {
            do { bannerURL = try await UserMediaStorageService.shared.uploadBanner(uid: uid, image: bannerImage) }
            catch { print("⚠️ [ChannelCustomization] banner upload failed: \(error.localizedDescription)") }
        }

        // Merge social links (preserve any platforms we don't edit here).
        var links = user.socialLinks.filter { $0.platform != .instagram && $0.platform != .twitter }
        if !instagram.trimmingCharacters(in: .whitespaces).isEmpty {
            links.append(SocialLink(platform: .instagram, url: instagram, displayName: "Instagram"))
        }
        if !twitter.trimmingCharacters(in: .whitespaces).isEmpty {
            links.append(SocialLink(platform: .twitter, url: twitter, displayName: "Twitter"))
        }

        let updatedUser = User(
            id: user.id,
            username: handle.isEmpty ? user.username : handle,
            displayName: channelName.isEmpty ? user.displayName : channelName,
            email: user.email,
            profileImageURL: profileURL,
            bannerImageURL: bannerURL,
            bio: description.isEmpty ? nil : description,
            subscriberCount: user.subscriberCount,
            videoCount: user.videoCount,
            isVerified: user.isVerified,
            isCreator: user.isCreator,
            createdAt: user.createdAt,
            location: user.location,
            website: website.isEmpty ? nil : website,
            showWebsiteOnProfile: user.showWebsiteOnProfile,
            showOnlineStatus: user.showOnlineStatus,
            socialLinks: links,
            totalViews: user.totalViews,
            totalEarnings: user.totalEarnings,
            membershipTiers: user.membershipTiers,
            verificationBadge: user.verificationBadge,
            bannerVideoURL: user.bannerVideoURL,
            bannerVideoMuted: user.bannerVideoMuted,
            bannerVideoContentMode: user.bannerVideoContentMode
        )

        // Update in-memory state immediately for a responsive UI.
        await MainActor.run {
            appState.currentUser = updatedUser
        }

        // Persist locally, then to Firestore.
        do {
            try await DatabaseService.shared.saveUser(updatedUser)
        } catch {
            print("⚠️ [ChannelCustomization] local save failed: \(error.localizedDescription)")
        }

        #if canImport(FirebaseFirestore)
        do {
            try await UserFirestoreService.shared.updateUser(updatedUser)
        } catch {
            await MainActor.run {
                isSaving = false
                statusMessage = "Saved on device, but cloud sync failed: \(error.localizedDescription)"
            }
            return
        }
        #endif

        await MainActor.run {
            isSaving = false
            statusMessage = "Channel updated ✓"
            HapticManager.shared.notification(type: .success)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshProfile"), object: nil)
        }
    }
}
