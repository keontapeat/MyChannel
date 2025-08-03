//
//  GlobalVideoPlayerManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation
import Combine

@MainActor
class GlobalVideoPlayerManager: ObservableObject {
    static let shared = GlobalVideoPlayerManager()
    
    @Published var currentVideo: Video?
    @Published var isPlaying = false
    @Published var isMiniplayer = false
    @Published var showingFullscreen = false
    @Published var miniplayerOffset: CGFloat = 0
    @Published var currentProgress: Double = 0.0
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private let playerManager = VideoPlayerManager()
    private var cancellables = Set<AnyCancellable>()
    
    var player: AVPlayer? {
        playerManager.player
    }
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        playerManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPlaying, on: self)
            .store(in: &cancellables)
        
        playerManager.$currentProgress
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentProgress, on: self)
            .store(in: &cancellables)
        
        playerManager.$currentTime
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentTime, on: self)
            .store(in: &cancellables)
        
        playerManager.$duration
            .receive(on: DispatchQueue.main)
            .assign(to: \.duration, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Video Management
    func playVideo(_ video: Video, showFullscreen: Bool = true) {
        currentVideo = video
        playerManager.setupPlayer(with: video)
        
        if showFullscreen {
            showingFullscreen = true
            isMiniplayer = false
        } else {
            isMiniplayer = true
            showingFullscreen = false
        }
        
        // Start playing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.playerManager.play()
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func minimizePlayer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingFullscreen = false
            isMiniplayer = true
        }
    }
    
    func expandPlayer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingFullscreen = true
            isMiniplayer = false
        }
    }
    
    func closePlayer() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            playerManager.pause()
            currentVideo = nil
            isMiniplayer = false
            showingFullscreen = false
            miniplayerOffset = 0
        }
    }
    
    // MARK: - Playback Controls
    func togglePlayPause() {
        playerManager.togglePlayPause()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func seek(to progress: Double) {
        playerManager.seek(to: progress)
    }
    
    func seekForward() {
        playerManager.seekForward(10)
    }
    
    func seekBackward() {
        playerManager.seekBackward(10)
    }
    
    // MARK: - Miniplayer Gestures
    func handleMiniplayerDrag(_ translation: CGSize) {
        miniplayerOffset = max(0, translation.height)
    }
    
    func handleMiniplayerDragEnd(_ translation: CGSize) {
        let dismissThreshold: CGFloat = 100
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if translation.height > dismissThreshold {
                closePlayer()
            } else {
                miniplayerOffset = 0
            }
        }
    }
}