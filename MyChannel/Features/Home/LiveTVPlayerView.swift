//
//  LiveTVPlayerView.swift
//  MyChannel
//
//  Created by AI Assistant on 8/12/25.
//

import SwiftUI
import AVKit
import MediaPlayer

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
        guard let url = URL(string: channel.streamURL) else { return }
        let player = AVPlayer(url: url)
        player.automaticallyWaitsToMinimizeStalling = false // favor low latency for live
        player.currentItem?.preferredForwardBufferDuration = 0
        player.play()
        self.player = player
        isPlaying = true

        configureAudioSession()
        setupTimeObserver()
        updateSubtitleAvailability()
        updateDVRAvailability()
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
        // Replace current item with new channel stream
        if let url = URL(string: newChannel.streamURL) {
            let item = AVPlayerItem(url: url)
            if player == nil { player = AVPlayer(playerItem: item) } else { player?.replaceCurrentItem(with: item) }
            player?.automaticallyWaitsToMinimizeStalling = false
            player?.play()
            withAnimation { showMiniGuide = false }
            updateDVRAvailability()
        }
    }
}

#Preview {
    LiveTVPlayerView(channel: LiveTVChannel.sampleChannels.first!)
}
