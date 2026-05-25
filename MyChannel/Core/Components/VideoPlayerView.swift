//
//  VideoPlayerView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

// Simple video player view for basic playback
struct VideoPlayerView: View {
    let video: Video
    @StateObject private var playerManager = VideoPlayerManager()
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // Ad overlays
    @State private var currentAd: ServedAd? = nil
    @State private var adTimeRemaining: Int = 0
    @State private var canSkipAd: Bool = false
    @State private var adTimer: Timer? = nil
    @State private var servingMidroll = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            RawPlayerLayerView(player: playerManager.player ?? AVPlayer(), videoGravity: .resizeAspect)
                .aspectRatio(16/9, contentMode: .fit)
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
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
                        .padding(.trailing, 12)
                    }
                }
                
                Spacer()
                if let ad = currentAd {
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
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .onAppear {
            // Setup local manager and hand off to global manager; start playback explicitly (no toggle)
            Task { @MainActor in
                // Premium gating: no ads for subscribers
                if (await StoreKitService.shared.hasActiveSubscription()) == true {
                    print("👑 Premium user - no ads")
                    playerManager.setupPlayer(with: video)
                    playerManager.play()
                    await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: true)
                    return
                }
                
                // 🔥 NO ADS ON YOUR OWN VIDEOS - Skip ads if watching your own content
                if let currentUser = AuthenticationManager.shared.currentUser,
                   video.creator.id == currentUser.id {
                    print("🎬 Your own video - skipping ads, playing instantly!")
                    playerManager.setupPlayer(with: video)
                    playerManager.play()
                    await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: true)
                    return
                }
                
                print("🎯 Checking ads for video: \(video.title)")
                print("💰 Video monetized: \(video.monetization?.isMonetized ?? false)")
                print("⚙️ App ads enabled: \(AppConfig.Features.enableAds)")
                
                let personalized = UserDefaults.standard.bool(forKey: "preferences.personalizedAdsEnabled")
                if let ad = await AdsService.requestPreRoll(for: video, personalized: personalized), !ad.creativeUri.isEmpty {
                    print("✅ Got ad: \(ad.creativeUri)")
                    if let u = URL(string: ad.creativeUri) {
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
                        playerManager.setupPlayer(with: adVideo)
                        playerManager.play()
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
                            let adRevenue = Double.random(in: 0.01...0.50)
                            await AdsService.trackAdRevenue(for: video, adRevenue: adRevenue)
                            playerManager.setupPlayer(with: video)
                            playerManager.play()
                            stopAdTimer()
                            currentAd = nil
                            canSkipAd = false
                        }
                        // overlays state
                        currentAd = ad
                        adTimeRemaining = max(0, ad.duration)
                        canSkipAd = ad.duration >= 5
                        startAdTimer()
                        await globalPlayer.adoptExternalPlayerManager(playerManager, video: adVideo, showFullscreen: true)
                        return
                    }
                }
                
                // 🔥 DOUBLE CHECK: No fallback ads on your own videos either
                if let currentUser = AuthenticationManager.shared.currentUser,
                   video.creator.id == currentUser.id {
                    print("🎬 Skipping fallback VAST ads - your video!")
                    playerManager.setupPlayer(with: video)
                    playerManager.play()
                    await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: true)
                    return
                }
                
                // Fallback VAST if no direct fill
                if (video.monetization?.isMonetized == true) || AppConfig.Features.enableAds,
                   let vast = AdsService.fallbackVAST(for: video), let resolved = await AdsService.resolveVASTMedia(from: vast) {
                    let adVideo = Video(
                        title: "Ad",
                        description: "Sponsored",
                        thumbnailURL: "",
                        videoURL: resolved.mediaURL,
                        duration: TimeInterval(resolved.duration),
                        viewCount: 0,
                        likeCount: 0,
                        creator: video.creator,
                        category: .other,
                        isPublic: false
                    )
                    playerManager.setupPlayer(with: adVideo)
                    playerManager.play()
                    currentAd = ServedAd(impressionId: nil, creativeUri: resolved.mediaURL, clickUrl: resolved.click ?? "", duration: resolved.duration, q0: "", q25: "", q50: "", q75: "", q100: "")
                    adTimeRemaining = resolved.duration
                    canSkipAd = true
                    startAdTimer()
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(Double(resolved.duration) * 1_000_000_000))
                        let adRevenue = Double.random(in: 0.01...0.50)
                        await AdsService.trackAdRevenue(for: video, adRevenue: adRevenue)
                        playerManager.setupPlayer(with: video)
                        playerManager.play()
                        stopAdTimer()
                        currentAd = nil
                        canSkipAd = false
                    }
                    await globalPlayer.adoptExternalPlayerManager(playerManager, video: adVideo, showFullscreen: true)
                    return
                } else {
                    print("❌ No ads available - playing video directly")
                }
                
                print("🎬 Setting up main video playback")
                playerManager.setupPlayer(with: video)
                playerManager.play()
                await globalPlayer.adoptExternalPlayerManager(playerManager, video: video, showFullscreen: true)
            }
        }
        .onDisappear { stopAdTimer() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RequestMidrollAd"))) { _ in
            Task { await serveMidrollIfEligible() }
        }
    }
}

// MARK: - Ad timer helpers
extension VideoPlayerView {
    private func startAdTimer() {
        stopAdTimer()
        adTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if adTimeRemaining > 0 { adTimeRemaining -= 1 }
        }
    }
    private func stopAdTimer() { adTimer?.invalidate(); adTimer = nil }
    private func skipAd() {
        stopAdTimer()
        currentAd = nil
        canSkipAd = false
        playerManager.setupPlayer(with: video)
        playerManager.play()
    }
}

// MARK: - Midroll serving
extension VideoPlayerView {
    private func serveMidrollIfEligible() async {
        guard !servingMidroll else { return }
        servingMidroll = true
        defer { servingMidroll = false }
        let personalized = UserDefaults.standard.bool(forKey: "preferences.personalizedAdsEnabled")
        if let ad = await AdsService.requestPreRoll(for: video, personalized: personalized), !ad.creativeUri.isEmpty, let u = URL(string: ad.creativeUri) {
            let adVideo = Video(title: "Ad", description: "Sponsored", thumbnailURL: "", videoURL: u.absoluteString, duration: TimeInterval(ad.duration), viewCount: 0, likeCount: 0, creator: video.creator, category: .other, isPublic: false)
            playerManager.setupPlayer(with: adVideo)
            playerManager.play()
            AdsService.fire(ad.q0)
            let durMid = Double(ad.duration)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(max(0.0, durMid * 0.25) * 1_000_000_000))
                AdsService.fire(ad.q25)
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(max(0.0, durMid * 0.50) * 1_000_000_000))
                AdsService.fire(ad.q50)
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(max(0.0, durMid * 0.75) * 1_000_000_000))
                AdsService.fire(ad.q75)
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(max(0.0, durMid) * 1_000_000_000))
                AdsService.fire(ad.q100)
                let adRevenue = Double.random(in: 0.01...0.50)
                await AdsService.trackAdRevenue(for: video, adRevenue: adRevenue)
                playerManager.setupPlayer(with: video)
                playerManager.play()
                stopAdTimer()
                currentAd = nil
                canSkipAd = false
            }
            currentAd = ad
            adTimeRemaining = max(0, ad.duration)
            canSkipAd = ad.duration >= 5
            startAdTimer()
            await globalPlayer.adoptExternalPlayerManager(playerManager, video: adVideo, showFullscreen: true)
            return
        }
        
        // 🔥 NO MIDROLL ADS ON YOUR OWN VIDEOS
        if let currentUser = AuthenticationManager.shared.currentUser,
           video.creator.id == currentUser.id {
            print("🎬 Skipping midroll VAST ads - your video!")
            return
        }
        
        if let vast = AdsService.fallbackVAST(for: video), let resolved = await AdsService.resolveVASTMedia(from: vast) {
            let adVideo = Video(title: "Ad", description: "Sponsored", thumbnailURL: "", videoURL: resolved.mediaURL, duration: TimeInterval(resolved.duration), viewCount: 0, likeCount: 0, creator: video.creator, category: .other, isPublic: false)
            playerManager.setupPlayer(with: adVideo)
            playerManager.play()
            currentAd = ServedAd(impressionId: nil, creativeUri: resolved.mediaURL, clickUrl: resolved.click ?? "", duration: resolved.duration, q0: "", q25: "", q50: "", q75: "", q100: "")
            adTimeRemaining = resolved.duration
            canSkipAd = true
            startAdTimer()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Double(resolved.duration) * 1_000_000_000))
                playerManager.setupPlayer(with: video)
                playerManager.play()
                stopAdTimer()
                currentAd = nil
                canSkipAd = false
            }
            await globalPlayer.adoptExternalPlayerManager(playerManager, video: adVideo, showFullscreen: true)
        }
    }
}

#Preview {
    VideoPlayerView(video: Video.sampleVideos[0])
}