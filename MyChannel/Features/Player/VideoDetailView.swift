//  VideoDetailView.swift
//  MyChannel

import SwiftUI
import AVKit
import Combine

struct VideoDetailView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared

    // MARK: - Player States
    @State private var showPlayer = false
    @State private var isPlayerReady = false
    @State private var isBuffering = false
    @State private var playbackRate: Float = 1.0
    @State private var isFullscreen = false
    @State private var showPlayerControls = true
    @State private var playerControlsTimer: Timer?
    @State private var isDraggingSeeker = false
    @State private var videoQuality: VideoQuality = .auto

    // MARK: - Interaction States
    @State private var isLiked = false
    @State private var isDisliked = false
    @State private var isSubscribed = false
    @State private var isWatchLater = false
    @State private var showingCommentComposer = false
    @State private var showingShareSheet = false
    @State private var showingMoreOptions = false
    @State private var showingQualitySelector = false
    @State private var showingPlaybackSpeedSelector = false

    // MARK: - UI States
    @State private var expandedDescription = false
    @State private var isViewAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            VideoPlayerView(video: video)
                .frame(maxHeight: UIScreen.main.bounds.height * 0.3)

            VideoDetailMetaView(video: video,
                                isSubscribed: $isSubscribed,
                                isWatchLater: $isWatchLater,
                                isLiked: $isLiked,
                                isDisliked: $isDisliked,
                                expandedDescription: $expandedDescription,
                                onShare: { showingShareSheet = true },
                                onMore: { showingMoreOptions = true },
                                onComment: { showingCommentComposer = true })
        }
        .sheet(isPresented: $showingCommentComposer) {
            CommentComposerView(video: video) { _ in }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingShareSheet) {
            VideoShareSheet(items: [video.link])
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingMoreOptions) {
            VideoMoreOptionsSheet(video: video,
                                  isSubscribed: $isSubscribed,
                                  isWatchLater: $isWatchLater)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingQualitySelector) {
            VideoQualitySelector(selectedQuality: $videoQuality) { quality in
                videoQuality = quality
            }
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showingPlaybackSpeedSelector) {
            PlaybackSpeedSelector(selectedSpeed: $playbackRate) { speed in
                playbackRate = speed
            }
            .presentationDetents([.fraction(0.4)])
        }
        .onAppear {
            if !isViewAppeared {
                globalPlayer.playVideo(video, showFullscreen: true)
                isViewAppeared = true
            }
        }
        .onDisappear {
            playerControlsTimer?.invalidate()
            if globalPlayer.isPlaying && globalPlayer.currentVideo?.id == video.id {
                globalPlayer.minimizePlayer()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                globalPlayer.togglePlayPause()
            }
        }
    }
}

#Preview {
    NavigationView {
        VideoDetailView(video: Video.sampleVideos[0])
    }
}