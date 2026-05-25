//
//  ProfileViewModel.swift
//  MyChannel
//

import Foundation
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    // Inputs (injected after init to allow SwiftUI @StateObject usage)
    private var authManager: AuthenticationManager?
    private var appState: AppState?
    
    // 🔥 PERFORMANCE: Track tasks for proper cancellation
    private var loadTask: Task<Void, Never>?
    private var userChangeTask: Task<Void, Never>?

    // Published state
    @Published var user: User = User.defaultUser
    @Published var isFollowing: Bool = false
    @Published var userVideos: [Video] = []
    @Published var watchHistory: [Video] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String = ""
    
    // 🔥 PERFORMANCE: Proper deinit cleanup
    deinit {
        loadTask?.cancel()
        userChangeTask?.cancel()
        print("✅ [ProfileViewModel] Deallocated - no memory leak!")
    }

    func configure(authManager: AuthenticationManager, appState: AppState) {
        self.authManager = authManager
        self.appState = appState
    }

    func load() async {
        isLoading = true
        errorMessage = ""

        let authUser = appState?.currentUser ?? authManager?.currentUser ?? User.defaultUser

        // 🔥 FIX: Fetch complete Firestore profile first, fall back to auth object
        if let firestoreUser = try? await UserFirestoreService.shared.fetchUser(id: authUser.id) {
            user = firestoreUser
        } else {
            user = authUser
        }

        do {
            let uploadedVideos = try await VideoFirestoreService.shared.getUserVideos(userId: user.id)
            userVideos = uploadedVideos
            watchHistory = Array(uploadedVideos.reversed())
            user = user.updating(videoCount: uploadedVideos.count,
                                  totalViews: uploadedVideos.reduce(0) { $0 + $1.viewCount })
        } catch {
            print("❌ Error loading user videos: \(error)")
            userVideos = []
            watchHistory = []
        }

        isLoading = false
    }

    func refresh() async {
        await load()
    }

    func handleUserChange(_ newUser: User?) {
        if let newUser {
            user = newUser
            // 🔥 RELOAD ONLY REAL VIDEOS: No mock/fallback data
            // 🔥 PERFORMANCE: Cancel previous task and track new one
            userChangeTask?.cancel()
            userChangeTask = Task { [weak self] in
                guard let self = self else { return }
                do {
                    let uploadedVideos = try await VideoFirestoreService.shared.getUserVideos(userId: newUser.id)
                    await MainActor.run {
                        // Only show real videos - NO mock data
                        userVideos = uploadedVideos
                        watchHistory = Array(uploadedVideos.reversed())
                        
                        // Update user stats to match actual video count
                        var updatedUser = newUser
                        updatedUser = User(
                            id: newUser.id,
                            username: newUser.username,
                            displayName: newUser.displayName,
                            email: newUser.email,
                            profileImageURL: newUser.profileImageURL,
                            bannerImageURL: newUser.bannerImageURL,
                            bio: newUser.bio,
                            subscriberCount: newUser.subscriberCount,
                            videoCount: uploadedVideos.count, // 🔥 EXACT COUNT
                            isVerified: newUser.isVerified,
                            isCreator: newUser.isCreator,
                            createdAt: newUser.createdAt,
                            location: newUser.location,
                            website: newUser.website,
                            showWebsiteOnProfile: newUser.showWebsiteOnProfile,
                            showOnlineStatus: newUser.showOnlineStatus,
                            socialLinks: newUser.socialLinks,
                            followerCount: newUser.followerCount,
                            followingCount: newUser.followingCount,
                            joinDate: newUser.joinDate,
                            totalViews: uploadedVideos.reduce(0) { $0 + $1.viewCount }, // 🔥 REAL TOTAL VIEWS
                            totalEarnings: newUser.totalEarnings,
                            membershipTiers: newUser.membershipTiers,
                            bannerVideoURL: newUser.bannerVideoURL,
                            bannerVideoMuted: newUser.bannerVideoMuted,
                            bannerVideoContentMode: newUser.bannerVideoContentMode
                        )
                        user = updatedUser
                    }
                } catch {
                    print("❌ Error loading user videos: \(error)")
                    await MainActor.run {
                        // NO FALLBACK - Show empty if no videos exist
                        userVideos = []
                        watchHistory = []
                        user = newUser
                    }
                }
            }
        } else {
            user = User.defaultUser
            userVideos = []
            watchHistory = []
        }
    }
}


