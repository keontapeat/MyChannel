//
//  LiveTVPlayerView.swift
//  MyChannel
//
//  Created by AI Assistant on 8/12/25.
//

import SwiftUI
import AVKit
import MediaPlayer
import Network
import Combine

struct LiveTVPlayerView: View {
    let channel: LiveTVChannel
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = true
    @State private var showControls: Bool = true
    @State private var showAirPlayPicker: Bool = false
    @State private var behindLiveSeconds: Double = 0
    @State private var hasSubtitles: Bool = false
    @State private var captionsEnabled: Bool = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var backTapCount: Int = 0
    @State private var showExitHint: Bool = false
    @State private var tapResetWorkItem: DispatchWorkItem? = nil
    @State private var timeObserver: Any?
    @State private var isScrubbing: Bool = false
    @State private var dvrFraction: Double = 1.0
    @State private var isDVRAvailable: Bool = false
    @State private var showMiniGuide: Bool = false
    @State private var channels: [LiveTVChannel] = []
    @State private var isRefreshingChannels = false
    @StateObject private var networkOptimizer = NetworkOptimizer.shared
    @State private var preloadedChannels: Set<String> = []
    @State private var showSwipeHint: Bool = true
    @State private var swipeHintOpacity: Double = 1.0
    
    // 🔥 AI Watch Tracking
    @State private var watchStartTime: Date = Date()
    @State private var currentWatchingChannel: LiveTVChannel?
    @StateObject private var liveTVAI = LiveTVIntelligenceAgent.shared
    
    // 🔥 Stream error state
    @State private var streamError: StreamError?
    
    // 🔥 Pluto blocks in-app streams and serves "unavailable" video; we use Apple fallback and show this banner
    @State private var isPlayingPlutoFallback: Bool = false
    
    enum StreamError {
        case networkError
        case streamUnavailable
        case unknown
        
        var title: String {
            switch self {
            case .networkError: return "Connection Error"
            case .streamUnavailable: return "Stream Unavailable"
            case .unknown: return "Playback Error"
            }
        }
        
        var message: String {
            switch self {
            case .networkError: return "Check your internet connection and try again."
            case .streamUnavailable: return "This channel may be temporarily unavailable. Try another channel."
            case .unknown: return "Something went wrong. Please try again."
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player = player {
                RawPlayerLayerView(player: player, videoGravity: .resizeAspect)
                    .ignoresSafeArea()
            } else if let error = streamError {
                // 🔥 Stream error view with retry
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text(error.title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text(error.message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            streamError = nil
                            setupPlayer()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showMiniGuide = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "tv")
                                Text("Try Another")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading \(channel.name)...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // Overlay header + controls
            if showControls {
                VStack(alignment: .leading, spacing: 12) {
                    // Gradient for readability
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .allowsHitTesting(false)
                    .overlay(
                        HStack(spacing: 12) {
                            // Close button
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(10)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }

                            AsyncImage(url: URL(string: channel.logoURL)) { image in
                                image.resizable()
                            } placeholder: {
                                Rectangle().fill(.gray.opacity(0.3))
                            }
                            .frame(width: 48, height: 32)
                            .cornerRadius(6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(channel.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("LIVE • \(channel.category.displayName)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            Spacer()

                            Button(action: togglePlayPause) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .bold))
                                    .padding(10)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }

                            // Captions toggle (if available)
                            if hasSubtitles {
                                Button(action: toggleCaptions) {
                                    Image(systemName: captionsEnabled ? "captions.bubble.fill" : "captions.bubble")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .bold))
                                        .padding(10)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Circle())
                                }
                            }

                            // AirPlay route picker
                            Button(action: { withAnimation { showAirPlayPicker.toggle() } }) {
                                Image(systemName: "airplayaudio")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(10)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    )
                    
                    // 🔥 Pluto blocks in-app streams; when using demo fallback, show clear message
                    if isPlayingPlutoFallback {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                            Text("Pluto TV is not available in this app. For full Pluto TV, use the Pluto TV app or pluto.tv. You're watching a demo stream.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(3)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.85))
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }

                    // Channel logos row with improved image loading
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(channels) { ch in
                                Button(action: { 
                                    HapticManager.shared.impact(style: .medium)
                                    switchToChannel(ch) 
                                }) {
                                    ChannelLogoView(channel: ch, isSelected: ch.id == channel.id)
                                }
                                .buttonStyle(PressableScaleStyle(scale: 0.95))
                                .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in 
                                    HapticManager.shared.impact(style: .rigid)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showMiniGuide = true } 
                                })
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                    }

                    Divider().background(Color.white.opacity(0.2))

                    Spacer()
                    
                    // 🔥 Swipe-up hint indicator
                    if showSwipeHint {
                        VStack(spacing: 4) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                            Image(systemName: "chevron.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                            Text("Swipe up for Live Guide")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.vertical, 8)
                        .opacity(swipeHintOpacity)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: swipeHintOpacity)
                        .onAppear {
                            swipeHintOpacity = 0.4
                            // Auto-hide hint after 5 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    showSwipeHint = false
                                }
                            }
                        }
                    }

                    // Bottom controls: DVR slider + LIVE pill + Go Live
                    HStack(spacing: 12) {
                        if isDVRAvailable {
                            Slider(value: Binding(
                                get: { dvrFraction },
                                set: { newVal in
                                    dvrFraction = max(0, min(1, newVal))
                                    if isScrubbing { seekToFraction(dvrFraction) }
                                }
                            ), in: 0...1)
                            .tint(.white)
                            .onChange(of: isScrubbing) { _ in }
                            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in isScrubbing = true }.onEnded { _ in isScrubbing = false })
                        }

                        // LIVE pill with pulse animation
                        HStack(spacing: 6) {
                            PulsingLiveDot()
                            Text("LIVE")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.8))
                        )

                        if behindLiveSeconds >= 2.0 {
                            Button(action: { 
                                HapticManager.shared.impact(style: .medium)
                                goLive() 
                            }) {
                                Text("Go Live")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PressableScaleStyle(scale: 0.95))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 14)
                }
                .transition(.opacity)
            }

            // AirPlay route picker (animated in)
            if showAirPlayPicker {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AirPlayRouteView()
                            .frame(width: 220, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.trailing, 16)
                    }
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Double-tap to exit hint
            if showExitHint {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Tap again to exit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
                .transition(.opacity)
            }

            // Mini-Guide overlay - Premium Design
            if showMiniGuide {
                VStack(spacing: 0) {
                    // Drag handle
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                    
                    // Header
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "tv.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                            Text("Live Guide")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                        }
                        Spacer()
                        Text("\(channels.count) channels")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        // 🔥 Refresh button for 24/7 reliability
                        Button(action: {
                            guard !isRefreshingChannels else { return }
                            HapticManager.shared.impact(style: .medium)
                            isRefreshingChannels = true
                            Task {
                                await LiveTVManager.shared.refreshChannels()
                                channels = LiveTVManager.shared.channels
                                isRefreshingChannels = false
                                HapticManager.shared.notification(type: .success)
                            }
                        }) {
                            Group {
                                if isRefreshingChannels {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                        }
                        .disabled(isRefreshingChannels)
                        
                        Button(action: { 
                            HapticManager.shared.impact(style: .light)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showMiniGuide = false } 
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(channels) { ch in
                                Button(action: { 
                                    HapticManager.shared.impact(style: .medium)
                                    switchToChannel(ch) 
                                }) {
                                    HStack(spacing: 12) {
                                        // Channel logo with fallback
                                        ChannelLogoView(channel: ch, isSelected: ch.id == channel.id)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(ch.name)
                                                .foregroundColor(.white)
                                                .font(.system(size: 14, weight: .semibold))
                                                .lineLimit(1)
                                            HStack(spacing: 6) {
                                                Text(ch.category.displayName)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(ch.category.color)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(
                                                        Capsule()
                                                            .fill(ch.category.color.opacity(0.2))
                                                    )
                                                Text("•")
                                                    .foregroundColor(.white.opacity(0.3))
                                                Text(ch.quality)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if ch.id == channel.id {
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 6, height: 6)
                                                Text("NOW")
                                                    .font(.system(size: 10, weight: .black))
                                                    .foregroundColor(.red)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(Color.red.opacity(0.15))
                                            )
                                        } else {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(ch.id == channel.id ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                                    )
                                }
                                .buttonStyle(PressableScaleStyle(scale: 0.98))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.95), Color.black.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: -10)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .gesture(DragGesture().onEnded { value in 
                    if value.translation.height > 80 { 
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showMiniGuide = false } 
                    } 
                })
            }
        }
        .onAppear {
            // 🔥 Load channels from LiveTVManager for 24/7 reliability
            Task { @MainActor in
                let manager = LiveTVManager.shared
                if manager.channels.isEmpty {
                    channels = LiveTVChannel.sampleChannels
                } else {
                    channels = manager.channels
                }
            }
            
            setupPlayer()
            preloadAdjacentChannels()
            // 🔥 AI: Start tracking watch time
            watchStartTime = Date()
            currentWatchingChannel = channel
            
            // 🔥 Loading timeout - show error if stream doesn't start in 15 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [self] in
                if player == nil && streamError == nil {
                    streamError = .streamUnavailable
                    HapticManager.shared.notification(type: .warning)
                }
            }
        }
        .onDisappear {
            // 🔥 AI: Record watch event for ML training
            let watchDuration = Date().timeIntervalSince(watchStartTime)
            if let watchedChannel = currentWatchingChannel {
                let userId = appState.currentUser?.id ?? "anonymous"
                liveTVAI.recordWatchEvent(
                    userId: userId,
                    channel: watchedChannel,
                    watchDuration: watchDuration,
                    completed: watchDuration > 300 // Consider "completed" if watched > 5 min
                )
            }
            teardown()
        }
        // Gestures: single tap toggles controls, double-tap exits
        .contentShape(Rectangle())
        .onTapGesture(count: 1) { withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() } }
        .onTapGesture(count: 2) {
            dismiss()
        }
        .gesture(DragGesture(minimumDistance: 20).onEnded { value in if value.translation.height < -60 { withAnimation { showMiniGuide = true } } })
        .navigationBarBackButtonHidden(true)
    }

    private func setupPlayer() {
        isPlayingPlutoFallback = false
        // Start playback immediately — no async health check, no delay.
        // Build URL list: primary stream first, then fallback. AVPlayer tries each on failure.
        var streamURLs: [String] = []
        streamURLs.append(channel.streamURL)
        if let fallback = channel.previewFallbackURL, fallback != channel.streamURL {
            streamURLs.append(fallback)
        }
        setupPlayerWithURLs(streamURLs)
    }
    
    /// Extract Pluto channel ID from stream URL
    private func extractPlutoChannelId(from url: String) -> String? {
        // URL format: .../channel/{ID}/master.m3u8...
        guard let range = url.range(of: "/channel/"),
              let endRange = url.range(of: "/master.m3u8") else {
            return nil
        }
        let startIndex = range.upperBound
        let endIndex = endRange.lowerBound
        return String(url[startIndex..<endIndex])
    }
    
    @State private var retryCount = 0
    private let maxRetries = 2
    
    private func setupPlayerWithURLs(_ urls: [String], currentIndex: Int = 0) {
        guard currentIndex < urls.count, let url = URL(string: urls[currentIndex]) else {
            // 🔥 All URLs failed - show error state
            DispatchQueue.main.async {
                if NetworkOptimizer.shared.connectionQuality == .poor {
                    streamError = .networkError
                } else {
                    streamError = .streamUnavailable
                }
                HapticManager.shared.notification(type: .warning)
            }
            return
        }
        
        setupPlayerWithURL(url, urls: urls, currentIndex: currentIndex)
    }
    
    private func setupPlayerWithURL(_ url: URL, urls: [String] = [], currentIndex: Int = 0) {
        // Create optimized asset with HLS-specific settings for butter-smooth playback
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false, // Live streams don't need precise timing
            AVURLAssetAllowsCellularAccessKey: true,
            // 🔥 Add proper headers for Pluto TV and other streaming services
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                "Accept": "*/*",
                "Accept-Language": "en-US,en;q=0.9",
                "Connection": "keep-alive",
                "Accept-Encoding": "gzip, deflate, br",
                "Origin": "https://pluto.tv",
                "Referer": "https://pluto.tv/"
            ]
        ])
        
        let playerItem = AVPlayerItem(asset: asset)
        
        // Optimize for live streaming - balanced buffering for smooth playback
        playerItem.preferredForwardBufferDuration = 3.0 // 3 seconds for smoothness
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Adaptive bitrate - start high, let HLS adapt dynamically
        playerItem.preferredPeakBitRate = 8_000_000 // 8 Mbps max - HLS will choose best
        #if os(iOS)
        playerItem.preferredMaximumResolution = CGSize.zero // Auto-select best resolution
        #endif
        
        let player = AVPlayer(playerItem: playerItem)
        
        // Live streaming optimizations for butter-smooth playback
        player.automaticallyWaitsToMinimizeStalling = true // Smooth playback over pure low latency
        player.allowsExternalPlayback = true // Allow AirPlay
        player.preventsDisplaySleepDuringVideoPlayback = true
        
        // Error handling - retry with fallback URL if this one fails
        if !urls.isEmpty {
            observePlayerItemStatus(playerItem: playerItem, urls: urls, currentIndex: currentIndex)
        }
        
        // Network monitoring for adaptive quality
        setupNetworkMonitoring(for: playerItem)
        
        // Buffer health monitoring for smooth playback
        setupBufferMonitoring(for: playerItem)
        
        // Stall detection and recovery
        if !urls.isEmpty {
            setupStallRecovery(for: playerItem, urls: urls, currentIndex: currentIndex)
        }
        
        player.play()
        self.player = player
        isPlaying = true
        retryCount = 0
        // Show Pluto fallback banner when we're playing the demo stream instead of blocked Pluto content
        if channel.streamURL.contains("pluto.tv"),
           let fallback = channel.previewFallbackURL,
           url.absoluteString == fallback {
            isPlayingPlutoFallback = true
        }

        configureAudioSession()
        setupTimeObserver()
        updateSubtitleAvailability()
        updateDVRAvailability()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            restoreSavedPlaybackPositionIfNeeded(for: channel)
        }
    }
    
    @State private var statusObserver: NSKeyValueObservation?
    @State private var stallObserver: NSObjectProtocol?
    @State private var errorObserver: NSObjectProtocol?
    
    private func observePlayerItemStatus(playerItem: AVPlayerItem, urls: [String], currentIndex: Int) {
        statusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
            if item.status == .failed {
                // Try next URL if available
                if currentIndex + 1 < urls.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        setupPlayerWithURLs(urls, currentIndex: currentIndex + 1)
                    }
                }
            }
        }
    }
    
    @State private var networkMonitor: NWPathMonitor?
    
    private func setupNetworkMonitoring(for item: AVPlayerItem) {
        // Monitor network path and adjust bitrate dynamically for smooth streaming
        let monitor = NWPathMonitor()
        let playerRef = player
        monitor.pathUpdateHandler = { path in
            guard let currentItem = playerRef?.currentItem else { return }
            
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        // WiFi - use high bitrate for best quality
                        currentItem.preferredPeakBitRate = 8_000_000
                    } else if path.usesInterfaceType(.cellular) {
                        // Cellular - moderate bitrate, save data
                        currentItem.preferredPeakBitRate = path.isExpensive ? 2_000_000 : 4_000_000
                    } else {
                        currentItem.preferredPeakBitRate = 4_000_000
                    }
                } else {
                    // Poor connection - lower bitrate to prevent stalling
                    currentItem.preferredPeakBitRate = 1_500_000
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        networkMonitor = monitor
    }
    
    @State private var bufferObserver: NSKeyValueObservation?
    
    private func setupBufferMonitoring(for item: AVPlayerItem) {
        // Monitor buffer health to prevent stuttering - key to smooth playback
        bufferObserver = item.observe(\.loadedTimeRanges, options: [.new]) { item, _ in
            if let timeRange = item.loadedTimeRanges.first?.timeRangeValue {
                let bufferedSeconds = CMTimeGetSeconds(timeRange.duration)
                
                // Dynamic buffer management for butter-smooth playback
                if bufferedSeconds < 2.0 && !isScrubbing {
                    // Buffer running low - increase aggressively to prevent stalling
                    item.preferredForwardBufferDuration = 6.0
                } else if bufferedSeconds > 10.0 {
                    // Buffer very healthy - reduce slightly for lower latency
                    item.preferredForwardBufferDuration = 4.0
                } else {
                    // Optimal range - maintain good buffer
                    item.preferredForwardBufferDuration = 3.0
                }
            }
        }
    }
    
    private func setupStallRecovery(for item: AVPlayerItem, urls: [String], currentIndex: Int) {
        // Listen for playback stalls and recover smoothly
        let playerRef = player
        let stallObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { _ in
            guard let player = playerRef else { return }
            
            // Increase buffer to recover from stall
            item.preferredForwardBufferDuration = 6.0
            
            // Try to resume playback smoothly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                player.play()
            }
            
            // If still stalling after 3 seconds, try fallback URL
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if player.timeControlStatus != .playing && currentIndex + 1 < urls.count {
                    // Try fallback URL
                    if let nextURL = URL(string: urls[currentIndex + 1]) {
                        let nextItem = AVPlayerItem(url: nextURL)
                        player.replaceCurrentItem(with: nextItem)
                        player.play()
                    }
                }
            }
        }
        
        // Listen for playback errors and recover
        let errorObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            guard let player = playerRef else { return }
            
            // Try fallback URL if available
            if currentIndex + 1 < urls.count, let nextURL = URL(string: urls[currentIndex + 1]) {
                let nextItem = AVPlayerItem(url: nextURL)
                player.replaceCurrentItem(with: nextItem)
                player.play()
            }
        }
        
        stallObserver = stallObs
        errorObserver = errorObs
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func teardown() {
        persistPlaybackPosition(for: currentWatchingChannel ?? channel)

        // Clean up all observers properly
        networkMonitor?.cancel()
        networkMonitor = nil
        bufferObserver?.invalidate()
        bufferObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil
        
        if let stallObs = stallObserver {
            NotificationCenter.default.removeObserver(stallObs)
        }
        if let errorObs = errorObserver {
            NotificationCenter.default.removeObserver(errorObs)
        }
        stallObserver = nil
        errorObserver = nil
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
    }

    private func handleBackTap() { /* deprecated with explicit gestures */ }

    // MARK: - Live Edge / Subtitles / AirPlay
    private func setupTimeObserver() {
        guard timeObserver == nil else { return }
        guard let player = player else { return }
        let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { _ in
            updateLiveEdgeLag()
            updateDVRFraction()
        }
    }

    private func updateLiveEdgeLag() {
        guard let item = player?.currentItem else { return }
        guard let tr = item.seekableTimeRanges.last?.timeRangeValue else { return }
        let livePosition = CMTimeGetSeconds(CMTimeAdd(tr.start, tr.duration))
        let current = CMTimeGetSeconds(item.currentTime())
        let lag = max(0, livePosition - current)
        behindLiveSeconds = lag
    }

    private var isAtLiveEdge: Bool { behindLiveSeconds < 2.0 }

    private func goLive() {
        guard let item = player?.currentItem else { return }
        if let tr = item.seekableTimeRanges.last?.timeRangeValue {
            let end = CMTimeAdd(tr.start, tr.duration)
            player?.seek(to: end)
            player?.play()
            dvrFraction = 1.0
        }
    }

    private func seekToFraction(_ fraction: Double) {
        guard let item = player?.currentItem else { return }
        guard let tr = item.seekableTimeRanges.last?.timeRangeValue else { return }
        let start = CMTimeGetSeconds(tr.start)
        let duration = CMTimeGetSeconds(tr.duration)
        let target = start + duration * fraction
        let t = CMTime(seconds: target, preferredTimescale: 600)
        player?.seek(to: t)
    }

    private func updateDVRAvailability() {
        guard let item = player?.currentItem else { isDVRAvailable = false; return }
        isDVRAvailable = !(item.seekableTimeRanges.isEmpty)
    }

    private func updateDVRFraction() {
        guard let item = player?.currentItem else { return }
        guard let tr = item.seekableTimeRanges.last?.timeRangeValue else { return }
        let start = CMTimeGetSeconds(tr.start)
        let duration = CMTimeGetSeconds(tr.duration)
        guard duration > 0 else { return }
        let current = CMTimeGetSeconds(item.currentTime())
        dvrFraction = max(0, min(1, (current - start) / duration))
        updateDVRAvailability()
    }

    private func updateSubtitleAvailability() {
        guard let group = player?.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            hasSubtitles = false
            captionsEnabled = false
            return
        }
        hasSubtitles = !group.options.isEmpty
        captionsEnabled = player?.currentItem?.selectedMediaOption(in: group) != nil
    }

    private func toggleCaptions() {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
        if captionsEnabled {
            item.select(nil, in: group)
            captionsEnabled = false
        } else {
            // pick default or first option
            let option = group.defaultOption ?? group.options.first
            if let opt = option { item.select(opt, in: group); captionsEnabled = true }
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }
    }

    private func switchToChannel(_ newChannel: LiveTVChannel) {
        persistPlaybackPosition(for: currentWatchingChannel ?? channel)

        // 🔥 AI: Record watch event for the channel we're leaving
        if let previousChannel = currentWatchingChannel, previousChannel.id != newChannel.id {
            let watchDuration = Date().timeIntervalSince(watchStartTime)
            
            // Add to watch history
            AppState.shared.addLiveTVToHistory(channel: previousChannel, duration: watchDuration)
            let userId = appState.currentUser?.id ?? "anonymous"
            liveTVAI.recordWatchEvent(
                userId: userId,
                channel: previousChannel,
                watchDuration: watchDuration,
                completed: false // Switched away, so not completed
            )
        }
        
        // 🔥 AI: Start tracking new channel
        watchStartTime = Date()
        currentWatchingChannel = newChannel
        
        // Get optimal stream URL based on network quality
        let optimalURL = LiveTVService.shared.getOptimalStreamURL(
            for: newChannel,
            networkQuality: networkOptimizer.connectionQuality
        )
        
        guard let url = URL(string: optimalURL) else {
            // Fallback to original URL
            guard let fallbackURL = URL(string: newChannel.streamURL) else { return }
            switchToChannelWithURL(newChannel, url: fallbackURL)
            return
        }
        
        switchToChannelWithURL(newChannel, url: url)
    }
    
    private func switchToChannelWithURL(_ newChannel: LiveTVChannel, url: URL) {
        
        // Create optimized asset with proper headers
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false,
            AVURLAssetAllowsCellularAccessKey: true,
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                "Accept": "*/*",
                "Accept-Language": "en-US,en;q=0.9",
                "Connection": "keep-alive",
                "Accept-Encoding": "gzip, deflate, br",
                "Origin": "https://pluto.tv",
                "Referer": "https://pluto.tv/"
            ]
        ])
        
        let item = AVPlayerItem(asset: asset)
        
        // Apply same optimizations as setupPlayer
        item.preferredForwardBufferDuration = 2.0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        let networkQuality = NetworkOptimizer.shared.connectionQuality
        switch networkQuality {
        case .poor:
            item.preferredPeakBitRate = 1_000_000
        case .good:
            item.preferredPeakBitRate = 3_000_000
        case .excellent:
            item.preferredPeakBitRate = 6_000_000
        }
        
        #if os(iOS)
        item.preferredMaximumResolution = CGSize.zero
        #endif
        
        // Setup new observers
        setupNetworkMonitoring(for: item)
        setupBufferMonitoring(for: item)
        
        if player == nil {
            player = AVPlayer(playerItem: item)
            player?.automaticallyWaitsToMinimizeStalling = false
            player?.allowsExternalPlayback = true
        } else {
            // Smooth transition - preload before switching
            item.preferredForwardBufferDuration = 3.0 // Slightly more buffer for channel switch
            player?.replaceCurrentItem(with: item)
        }
        
        player?.play()
        isPlaying = true
        withAnimation { showMiniGuide = false }
        
        updateSubtitleAvailability()
        updateDVRAvailability()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            restoreSavedPlaybackPositionIfNeeded(for: newChannel)
        }
    }

    private func persistPlaybackPosition(for channel: LiveTVChannel) {
        guard isDVRAvailable,
              dvrFraction.isFinite,
              dvrFraction > 0,
              dvrFraction < 1 else { return }

        LiveTVPreviewPlaybackStore.shared.saveDVRFraction(dvrFraction, for: channel.id)
    }

    private func restoreSavedPlaybackPositionIfNeeded(for channel: LiveTVChannel) {
        guard let savedFraction = LiveTVPreviewPlaybackStore.shared.dvrFraction(for: channel.id),
              savedFraction > 0,
              savedFraction < 1 else { return }

        seekToFraction(savedFraction)
        dvrFraction = savedFraction
    }
    
    private func preloadAdjacentChannels() {
        // Preload next 2 channels for smooth switching
        guard let currentIndex = channels.firstIndex(where: { $0.id == channel.id }) else { return }
        
        let nextChannels = channels.suffix(from: min(currentIndex + 1, channels.count - 1)).prefix(2)
        
        Task {
            for nextChannel in nextChannels {
                if !preloadedChannels.contains(nextChannel.id) {
                    await LiveTVService.shared.preloadChannel(nextChannel)
                    await MainActor.run {
                        preloadedChannels.insert(nextChannel.id)
                    }
                }
            }
        }
    }
}

// MARK: - Channel Logo View with Better Image Loading
private struct ChannelLogoView: View {
    let channel: LiveTVChannel
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Background gradient based on category
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            channel.category.color.opacity(0.3),
                            channel.category.color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Try to load logo image
            AsyncImage(url: URL(string: channel.logoURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                case .failure(_):
                    // Show category icon as fallback
                    VStack(spacing: 2) {
                        Image(systemName: categoryIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text(String(channel.name.prefix(6)))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                case .empty:
                    // Loading state
                    VStack(spacing: 2) {
                        Image(systemName: categoryIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        Text(String(channel.name.prefix(6)))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                @unknown default:
                    EmptyView()
                }
            }
        }
        .frame(width: 64, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.red : Color.white.opacity(0.2), lineWidth: isSelected ? 2.5 : 1)
        )
        .shadow(color: isSelected ? Color.red.opacity(0.4) : .clear, radius: 6, x: 0, y: 2)
    }
    
    private var categoryIcon: String {
        switch channel.category {
        case .anime: return "sparkles.tv"
        case .scifi: return "wand.and.stars"
        case .reality: return "person.3.fill"
        case .comedy: return "face.smiling.fill"
        case .kids: return "figure.2.and.child.holdinghands"
        case .news: return "newspaper.fill"
        case .sports: return "sportscourt.fill"
        case .movies: return "film.fill"
        case .music: return "music.note.tv.fill"
        case .entertainment: return "star.fill"
        case .documentary: return "globe.americas.fill"
        case .lifestyle: return "leaf.fill"
        case .business: return "chart.line.uptrend.xyaxis"
        case .international: return "globe"
        case .classic: return "tv.fill"
        }
    }
}

// MARK: - Pulsing Live Dot
private struct PulsingLiveDot: View {
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

#Preview {
    LiveTVPlayerView(channel: LiveTVChannel.sampleChannels.first!)
        .environmentObject(AppState())
}
