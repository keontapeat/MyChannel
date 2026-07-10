//
//  ModernVideoPlayerView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct ModernVideoPlayerView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var playerViewModel = VideoPlayerViewModel()
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    
    @State private var showControls = true
    @State private var dragAmount = CGSize.zero
    @State private var brightness: Double = UIScreen.main.brightness
    @State private var volume: Float = AVAudioSession.sharedInstance().outputVolume
    @State private var showVolumeIndicator = false
    @State private var showBrightnessIndicator = false
    @State private var isFullscreen = true
    @State private var orientation = UIDeviceOrientation.landscapeLeft
    // Ad overlays
    @State private var currentAd: ServedAd? = nil
    @State private var adTimeRemaining: Int = 0
    @State private var canSkipAd: Bool = false
    @State private var adTimer: Timer? = nil
    
    // Double tap ripple state
    @State private var showSeekRipple = false
    @State private var seekRippleForward = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                // Video Player
                if let player = playerViewModel.player {
                    // The same AVPlayer feeds both the in-app mini player and native PiP bubble
                    ZStack {
                        RawPlayerLayerView(player: player, videoGravity: .resizeAspect)
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipped()
                        
                        // Double Tap to Seek Zones
                        HStack(spacing: 0) {
                            // Left Zone (Rewind)
                            Color.white.opacity(0.001)
                                .onTapGesture(count: 2) {
                                    HapticManager.shared.impact(style: .medium)
                                    playerViewModel.seekBackward(10)
                                    showDoubleTapIndicator(forward: false)
                                }
                                .onTapGesture(count: 1) {
                                    withAnimation(.easeInOut(duration: 0.3)) { showControls.toggle() }
                                }
                            
                            // Right Zone (Forward)
                            Color.white.opacity(0.001)
                                .onTapGesture(count: 2) {
                                    HapticManager.shared.impact(style: .medium)
                                    playerViewModel.seekForward(10)
                                    showDoubleTapIndicator(forward: true)
                                }
                                .onTapGesture(count: 1) {
                                    withAnimation(.easeInOut(duration: 0.3)) { showControls.toggle() }
                                }
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handlePlayerGesture(value, in: geometry)
                            }
                            .onEnded { _ in
                                dragAmount = .zero
                                hideIndicators()
                            }
                    )

                    if globalPlayer.isBuffering {
                        PlayerBufferingIndicator()
                    }
                } else if !globalPlayer.isPlayerReady && globalPlayer.currentVideo != nil {
                    PlayerNotReadyChrome(
                        title: video.title,
                        onRetry: { globalPlayer.ensurePlayerAttached() }
                    )
                } else {
                    // Loading placeholder
                    ModernLoadingView()
                }
                
                // Custom Controls Overlay
                if showControls {
                    ModernPlayerControlsView(
                        viewModel: playerViewModel,
                        video: video,
                        onDismiss: {
                            handleDismiss()
                        },
                        onMinimize: {
                            handleMinimize()
                        },
                        onTogglePiP: {
                            playerViewModel.togglePiP()
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Volume Indicator
                if showVolumeIndicator {
                    VStack {
                        Spacer()
                        ModernVolumeIndicator(volume: volume)
                            .padding(.leading, 50)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        Spacer()
                    }
                }
                
                // Brightness Indicator
                if showBrightnessIndicator {
                    VStack {
                        Spacer()
                        ModernBrightnessIndicator(brightness: brightness)
                            .padding(.trailing, 50)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        Spacer()
                    }
                }

                // Ad top-right pill
                VStack {
                    HStack {
                        Spacer()
                        if currentAd != nil {
                            HStack(spacing: 8) {
                                Text("Ad")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Capsule())
                                Text(String(format: "%ds", max(0, adTimeRemaining)))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                        }
                    }
                    Spacer()
                }

                // Ad bottom bar
                if let ad = currentAd {
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: { if let u = URL(string: ad.clickUrl) { openURL(u) } }) {
                                Text("Learn more")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            if canSkipAd {
                                Button(action: skipAd) {
                                    Text("Skip")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.white)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                
                // Seek Ripple Overlay
                if showSeekRipple {
                    HStack {
                        if seekRippleForward { Spacer() }
                        
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 150, height: 150)
                            
                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: seekRippleForward ? "play.fill" : "backward.fill")
                                    Image(systemName: seekRippleForward ? "play.fill" : "backward.fill")
                                    Image(systemName: seekRippleForward ? "play.fill" : "backward.fill")
                                }
                                .font(.system(size: 20))
                                
                                Text("10 seconds")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                        }
                        .padding(.horizontal, 40)
                        
                        if !seekRippleForward { Spacer() }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .ignoresSafeArea()
        .onAppear {
            startPlaybackWithAds()
            hideControlsAfterDelay()
        }
        .onDisappear {
            cleanup()
            stopAdTimer()
        }
        .onRotate { newOrientation in
            orientation = newOrientation
        }
    }
    
    private func startPlaybackWithAds() {
        // Ensure the global player doesn't interfere
        globalPlayer.stopImmediately()
        globalPlayer.showingFullscreen = false
        Task { @MainActor in
            if await StoreKitService.shared.hasActiveSubscription() {
                playerViewModel.setupPlayer(with: video)
                playerViewModel.play()
                return
            }
            
            // 🔥 NO ADS ON YOUR OWN VIDEOS - Skip ads if watching your own content
            if let currentUser = AuthenticationManager.shared.currentUser,
               video.creator.id == currentUser.id {
                print("🎬 Your own video - skipping ads, playing instantly!")
                playerViewModel.setupPlayer(with: video)
                playerViewModel.play()
                return
            }
            let personalized = UserDefaults.standard.bool(forKey: "preferences.personalizedAdsEnabled")
            if let ad = await AdsService.requestPreRoll(for: video, personalized: personalized), !ad.creativeUri.isEmpty, let u = URL(string: ad.creativeUri) {
                let adVideo = Video(
                    title: "Ad",
                    description: "Sponsored",
                    thumbnailURL: "",
                    videoURL: u.absoluteString,
                    duration: TimeInterval(ad.duration),
                    viewCount: 0,
                    likeCount: 0,
                    creator: video.creator,
                    category: .other,
                    isPublic: false
                )
                playerViewModel.setupPlayer(with: adVideo)
                playerViewModel.play()
                AdsService.fire(ad.q0)
                let dur = Double(ad.duration)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(max(0.0, dur * 0.25) * 1_000_000_000))
                    AdsService.fire(ad.q25)
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(max(0.0, dur * 0.50) * 1_000_000_000))
                    AdsService.fire(ad.q50)
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(max(0.0, dur * 0.75) * 1_000_000_000))
                    AdsService.fire(ad.q75)
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(max(0.0, dur) * 1_000_000_000))
                    AdsService.fire(ad.q100)
                    playerViewModel.setupPlayer(with: video)
                    playerViewModel.play()
                    stopAdTimer(); currentAd = nil; canSkipAd = false
                }
                currentAd = ad
                adTimeRemaining = max(0, ad.duration)
                canSkipAd = ad.duration >= 5
                startAdTimer()
                return
            }
            playerViewModel.setupPlayer(with: video)
            playerViewModel.play()
        }
    }
    
    private func handlePlayerGesture(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        let translation = value.translation
        let location = value.startLocation
        
        // Left side - brightness control
        if location.x < geometry.size.width / 2 {
            let change = -Double(translation.height) / Double(geometry.size.height)
            brightness = max(0, min(1, brightness + change))
            UIScreen.main.brightness = brightness
            
            withAnimation(.easeInOut(duration: 0.2)) {
                showBrightnessIndicator = true
            }
        }
        // Right side - volume control
        else {
            let change = -Double(translation.height) / Double(geometry.size.height)
            volume = max(0, min(1, volume + Float(change)))
            
            withAnimation(.easeInOut(duration: 0.2)) {
                showVolumeIndicator = true
            }
        }
        
        dragAmount = translation
    }
    
    private func showDoubleTapIndicator(forward: Bool) {
        seekRippleForward = forward
        withAnimation(.easeIn(duration: 0.1)) {
            showSeekRipple = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                showSeekRipple = false
            }
        }
    }
    
    private func hideIndicators() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                showVolumeIndicator = false
                showBrightnessIndicator = false
            }
        }
    }
    
    private func hideControlsAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
    
    private func handleDismiss() {
        playerViewModel.pause()
        dismiss()
    }
    
    private func handleMinimize() {
        // Start native iOS PiP
        // 🔥 FIX: Register video with GlobalVideoPlayerManager for PiP
        globalPlayer.registerLocalPlayer(video: video, player: playerViewModel.player)
        globalPlayer.startPiP()
        dismiss()
    }
    
    private func cleanup() {
        playerViewModel.cleanup()
    }
}

// MARK: - Ad helpers
extension ModernVideoPlayerView {
    private func startAdTimer() {
        stopAdTimer()
        adTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if adTimeRemaining > 0 { adTimeRemaining -= 1 }
        }
    }
    private func stopAdTimer() { adTimer?.invalidate(); adTimer = nil }
    private func skipAd() {
        stopAdTimer(); currentAd = nil; canSkipAd = false
        playerViewModel.setupPlayer(with: video)
        playerViewModel.play()
    }
}

#Preview {
    ModernVideoPlayerView(video: Video.sampleVideos[0])
}