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
    @State private var backTapCount: Int = 0
    @State private var showExitHint: Bool = false
    @State private var tapResetWorkItem: DispatchWorkItem? = nil
    @State private var timeObserver: Any?
    @State private var isScrubbing: Bool = false
    @State private var dvrFraction: Double = 1.0
    @State private var isDVRAvailable: Bool = false
    @State private var showMiniGuide: Bool = false
    @State private var channels: [LiveTVChannel] = LiveTVChannel.sampleChannels
    @StateObject private var networkOptimizer = NetworkOptimizer.shared
    @State private var preloadedChannels: Set<String> = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
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

                    // Channel logos row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(channels) { ch in
                                Button(action: { switchToChannel(ch) }) {
                                    AsyncImage(url: URL(string: ch.logoURL)) { img in img.resizable() } placeholder: { Rectangle().fill(.gray.opacity(0.3)) }
                                        .frame(width: 64, height: 40)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(ch.id == channel.id ? Color.red : Color.white.opacity(0.2), lineWidth: ch.id == channel.id ? 2 : 1)
                                        )
                                }
                                .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in withAnimation { showMiniGuide = true } })
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                    }

                    Divider().background(Color.white.opacity(0.2))

                    Spacer()

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

                        // LIVE pill
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())

                        if behindLiveSeconds >= 2.0 {
                            Button(action: { goLive() }) {
                                Text("Go Live")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
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

            // Mini-Guide overlay
            if showMiniGuide {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 40, height: 5)
                        .padding(.top, 8)
                    HStack {
                        Text("Live Guide")
                            .foregroundColor(.white)
                            .font(.headline)
                        Spacer()
                        Button(action: { withAnimation { showMiniGuide = false } }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding(8)
                        }
                    }
                    .padding(.horizontal)
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(channels) { ch in
                                Button(action: { switchToChannel(ch) }) {
                                    HStack(spacing: 10) {
                                        AsyncImage(url: URL(string: ch.logoURL)) { img in img.resizable() } placeholder: { Rectangle().fill(.gray.opacity(0.3)) }
                                            .frame(width: 56, height: 36)
                                            .cornerRadius(6)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ch.name).foregroundColor(.white).font(.subheadline.weight(.semibold))
                                            Text(ch.category.displayName).foregroundColor(.white.opacity(0.8)).font(.caption)
                                        }
                                        Spacer()
                                        if ch.id == channel.id { Text("Now").foregroundColor(.red).font(.caption.weight(.bold)) }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.45)
                }
                .background(Color.black.opacity(0.85))
                .cornerRadius(16)
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .gesture(DragGesture().onEnded { value in if value.translation.height > 80 { withAnimation { showMiniGuide = false } } })
            }
        }
        .onAppear {
            setupPlayer()
            preloadAdjacentChannels()
        }
        .onDisappear {
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
        // Try primary stream URL first, then fallback if available
        let streamURLs = [channel.streamURL] + (channel.previewFallbackURL != nil ? [channel.previewFallbackURL!] : [])
        setupPlayerWithURLs(streamURLs)
    }
    
    @State private var retryCount = 0
    private let maxRetries = 2
    
    private func setupPlayerWithURLs(_ urls: [String], currentIndex: Int = 0) {
        guard currentIndex < urls.count, let url = URL(string: urls[currentIndex]) else {
            // All URLs failed
            return
        }
        
        setupPlayerWithURL(url, urls: urls, currentIndex: currentIndex)
    }
    
    private func setupPlayerWithURL(_ url: URL, urls: [String] = [], currentIndex: Int = 0) {
        // Create optimized asset with HLS-specific settings for butter-smooth playback
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false, // Live streams don't need precise timing
            AVURLAssetAllowsCellularAccessKey: true
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

        configureAudioSession()
        setupTimeObserver()
        updateSubtitleAvailability()
        updateDVRAvailability()
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
        
        // Create optimized asset
        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false,
            AVURLAssetAllowsCellularAccessKey: true
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

#Preview {
    LiveTVPlayerView(channel: LiveTVChannel.sampleChannels.first!)
}
