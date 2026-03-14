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

        let current = appState?.currentUser ?? authManager?.currentUser ?? User.defaultUser
        user = current

        // 🔥 LOAD ONLY REAL UPLOADED VIDEOS: No mock/fallback data
        do {
            let uploadedVideos = try await VideoFirestoreService.shared.getUserVideos(userId: current.id)
            // Only show real videos - NO mock data
            userVideos = uploadedVideos
            watchHistory = Array(uploadedVideos.reversed())
            
            // Update user video count to match actual count
            var updatedUser = current
            updatedUser = User(
                id: current.id,
                username: current.username,
                displayName: current.displayName,
                email: current.email,
                profileImageURL: current.profileImageURL,
                bannerImageURL: current.bannerImageURL,
                bio: current.bio,
                subscriberCount: current.subscriberCount,
                videoCount: uploadedVideos.count, // 🔥 EXACT COUNT from real videos
                isVerified: current.isVerified,
                isCreator: current.isCreator,
                createdAt: current.createdAt,
                location: current.location,
                website: current.website,
                showWebsiteOnProfile: current.showWebsiteOnProfile,
                showOnlineStatus: current.showOnlineStatus,
                socialLinks: current.socialLinks,
                followerCount: current.followerCount,
                followingCount: current.followingCount,
                joinDate: current.joinDate,
                totalViews: uploadedVideos.reduce(0) { $0 + $1.viewCount }, // 🔥 REAL TOTAL VIEWS
                totalEarnings: current.totalEarnings,
                membershipTiers: current.membershipTiers,
                bannerVideoURL: current.bannerVideoURL,
                bannerVideoMuted: current.bannerVideoMuted,
                bannerVideoContentMode: current.bannerVideoContentMode
            )
            user = updatedUser
        } catch {
            print("❌ Error loading user videos: \(error)")
            // NO FALLBACK - Show empty if no videos exist
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


