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

    // Published state
    @Published var user: User = .defaultUser
    @Published var isFollowing: Bool = false
    @Published var userVideos: [Video] = []
    @Published var watchHistory: [Video] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String = ""

    func configure(authManager: AuthenticationManager, appState: AppState) {
        self.authManager = authManager
        self.appState = appState
    }

    func load() async {
        isLoading = true
        errorMessage = ""

        let current = appState?.currentUser ?? authManager?.currentUser ?? .defaultUser
        user = current

        // Placeholder: use sample videos or fallback until backend is wired
        if Video.sampleVideos.isEmpty {
            let vids = createFallbackVideos(for: current)
            userVideos = vids
            watchHistory = Array(vids.reversed())
        } else {
            userVideos = Array(Video.sampleVideos.prefix(20))
            let pool = Array(Video.sampleVideos.dropFirst(min(4, Video.sampleVideos.count)).prefix(18))
            watchHistory = pool.isEmpty ? userVideos : pool
        }

        isLoading = false
    }

    func refresh() async {
        await load()
    }

    func handleUserChange(_ newUser: User?) {
        if let newUser {
            user = newUser
            if Video.sampleVideos.isEmpty {
                let vids = createFallbackVideos(for: newUser)
                userVideos = vids
                watchHistory = Array(vids.reversed())
            } else {
                userVideos = Array(Video.sampleVideos.prefix(20))
                let pool = Array(Video.sampleVideos.dropFirst(min(4, Video.sampleVideos.count)).prefix(18))
                watchHistory = pool.isEmpty ? userVideos : pool
            }
        } else {
            user = .defaultUser
            let vids = createFallbackVideos(for: .defaultUser)
            userVideos = vids
            watchHistory = Array(vids.reversed())
        }
    }

    private func createFallbackVideos(for user: User) -> [Video] {
        [
            Video(
                title: "Welcome to MyChannel!",
                description: "Getting started with content creation",
                thumbnailURL: "https://picsum.photos/1280/720?random=1",
                videoURL: "https://example.com/video1.mp4",
                duration: 180,
                viewCount: 1234,
                likeCount: 89,
                commentCount: 23,
                creator: user,
                category: .entertainment,
                tags: ["Welcome", "Getting Started"]
            ),
            Video(
                title: "Behind the Scenes",
                description: "A look at how content is made",
                thumbnailURL: "https://picsum.photos/1280/720?random=2",
                videoURL: "https://example.com/video2.mp4",
                duration: 300,
                viewCount: 856,
                likeCount: 45,
                commentCount: 12,
                creator: user,
                category: .entertainment,
                tags: ["Behind the Scenes"]
            ),
            Video(
                title: "Creator Tips: Grow Faster",
                description: "Top tips for creators",
                thumbnailURL: "https://picsum.photos/1280/720?random=3",
                videoURL: "https://example.com/video3.mp4",
                duration: 255,
                viewCount: 2310,
                likeCount: 153,
                commentCount: 34,
                creator: user,
                category: .education,
                tags: ["Tips", "Growth"]
            )
        ]
    }
}


