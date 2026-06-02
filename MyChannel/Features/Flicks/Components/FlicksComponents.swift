import SwiftUI
import AVKit
import AVFoundation
import FirebaseFirestore

struct NuclearVideoPlayerView: View {
    let flick: NuclearFlick
    let isActive: Bool
    let isMuted: Bool
    let playbackSpeed: Double
    
    @StateObject private var playerManager = VideoPlayerManager()
    @State private var hasSetup = false
    @State private var loadingTimedOut = false
    @State private var showScrubber = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 30
    @State private var isDraggingScrubber = false
    @State private var timer: Timer?

    // 🔥 Auto-captions (YouTube Shorts parity)
    @AppStorage("flicks_captions") private var captionsEnabled: Bool = false
    @State private var captionCues: [CaptionCue] = []
    @State private var captionsRequested = false
    
    private var videoUnavailable: Bool {
        playerManager.hasError || loadingTimedOut
    }

    /// The caption cue active at the current playback time.
    private var activeCue: CaptionCue? {
        captionCues.first { $0.isActive(at: currentTime) }
    }

    /// Generates auto-captions on demand (once) for YouTube-style captions.
    private func loadCaptionsIfNeeded() {
        guard captionsEnabled, !captionsRequested else { return }
        guard flick.contentSource != .youtube else { return } // YouTube provides its own captions
        captionsRequested = true
        Task {
            if let cached = FlicksCaptionService.shared.cachedCaptions(for: flick.id) {
                await MainActor.run { captionCues = cached }
                return
            }
            do {
                let cues = try await FlicksCaptionService.shared.generateCaptions(
                    for: flick.id,
                    videoURL: flick.videoURL
                )
                await MainActor.run { captionCues = cues }
            } catch {
                print("⚠️ [Flicks] Caption generation failed: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                
                // Thumbnail while player is loading or not ready (prevents black screen)
                AppAsyncImage(
                    url: URL(string: flick.thumbnailURL),
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    },
                    placeholder: {
                        Color.gray.opacity(0.3)
                    }
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .opacity(playerManager.isPlaying ? 0 : 1)
                
                // Video layer - fill entire screen
                if !videoUnavailable, let player = playerManager.player {
                    FlicksPlayerLayerView(player: player, videoGravity: .resizeAspectFill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                
                // Play/Pause icon
                if showScrubber {
                    Image(systemName: "play.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Color.white.opacity(0.8))
                        .shadow(radius: 10)
                        .transition(.scale.combined(with: .opacity))
                    
                    // Horizontal Scrubber
                    VStack {
                        Spacer()
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.caption2)
                                .foregroundColor(.white)
                            
                            GeometryReader { sliderGeo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 4)
                                        .cornerRadius(2)
                                    
                                    Rectangle()
                                        .fill(Color.red)
                                        .frame(width: max(0, sliderGeo.size.width * CGFloat(duration > 0 ? currentTime / duration : 0)), height: 4)
                                        .cornerRadius(2)
                                    
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 12, height: 12)
                                        .position(x: max(0, sliderGeo.size.width * CGFloat(duration > 0 ? currentTime / duration : 0)), y: sliderGeo.size.height / 2)
                                }
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            isDraggingScrubber = true
                                            let pct = max(0, min(1, value.location.x / sliderGeo.size.width))
                                            currentTime = pct * duration
                                            playerManager.player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                                        }
                                        .onEnded { _ in
                                            isDraggingScrubber = false
                                        }
                                )
                            }
                            .frame(height: 20)
                            
                            Text(formatTime(duration))
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24) // Float above safe area
                    }
                }
                
                // Video unavailable state (deleted/broken video) — auto-skip after brief display
                if videoUnavailable {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Video unavailable")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Skipping...")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            NotificationCenter.default.post(
                                name: .flickVideoUnavailable,
                                object: nil,
                                userInfo: ["flickId": flick.id]
                            )
                        }
                    }
                }
                
                // 🔥 Auto-captions overlay
                if captionsEnabled, let cue = activeCue {
                    VStack {
                        Spacer()
                        Text(cue.text)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.6))
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, geo.size.height * 0.28)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }

                // Loading: white spinner only while actively loading (with timeout)
                if playerManager.isLoading && !videoUnavailable && !playerManager.isPlaying {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            if isActive && !hasSetup {
                setupPlayer()
            }
            loadCaptionsIfNeeded()
        }
        .onDisappear {
            playerManager.pause()
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: isActive) { active in
            if active {
                loadCaptionsIfNeeded()
                if !hasSetup {
                    setupPlayer()
                } else if !videoUnavailable {
                    playerManager.play()
                    showScrubber = false
                    startTimer()
                }
            } else {
                playerManager.pause()
                timer?.invalidate()
                timer = nil
            }
        }
        .onChange(of: captionsEnabled) { enabled in
            if enabled { loadCaptionsIfNeeded() }
        }
        .onChange(of: isMuted) { muted in
            playerManager.player?.isMuted = muted
        }
        .onChange(of: playbackSpeed) { speed in
            playerManager.player?.rate = Float(speed)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pauseFlicksPlayback)) { _ in
            playerManager.pause()
            showScrubber = true
            timer?.invalidate()
            timer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TogglePlayPause_\(flick.id)"))) { _ in
            if playerManager.isPlaying {
                playerManager.pause()
                withAnimation { showScrubber = true }
                NotificationCenter.default.post(name: NSNotification.Name("HideFlicksUI"), object: nil)
                timer?.invalidate()
                timer = nil
            } else {
                playerManager.play()
                withAnimation { showScrubber = false }
                NotificationCenter.default.post(name: NSNotification.Name("ShowFlicksUI"), object: nil)
                startTimer()
            }
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard !isDraggingScrubber, let player = playerManager.player else { return }
            let current = player.currentTime().seconds
            let dur = player.currentItem?.duration.seconds ?? flick.duration
            if current.isFinite && !current.isNaN {
                currentTime = current
            }
            if dur.isFinite && !dur.isNaN && dur > 0 {
                duration = dur
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func setupPlayer() {
        hasSetup = true
        loadingTimedOut = false
        let video = flick.toVideo()
        playerManager.setupPlayer(with: video)
        playerManager.setLooping(true)
        playerManager.player?.isMuted = isMuted
        playerManager.player?.rate = Float(playbackSpeed)
        
        if isActive {
            playerManager.play()
            startTimer()
        }
        
        Task { @MainActor [self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if playerManager.isLoading && !playerManager.isPlaying {
                loadingTimedOut = true
                print("⏰ [NuclearFlicks] Loading timed out for flick: \(flick.id) — video likely deleted")
            }
        }
    }
}


struct CommentsModalView: View {
    let video: Video
    
    var body: some View {
        ProfessionalCommentsSheet(video: video)
    }
}


struct ShareModalView: View {
    let video: Video
    
    var body: some View {
        ProfessionalShareSheet(video: video)
    }
}


