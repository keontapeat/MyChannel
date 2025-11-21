//
//  ModernVideoPlayerView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit
import Combine

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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                // Video Player
                if let player = playerViewModel.player {
                    // 🚫 NATIVE PiP DISABLED: Use custom YouTube-style mini-player instead
                    // Old: PlayerPiPContainerView (DISABLED - causes ugly native PiP)
                    // New: VideoPlayer (SwiftUI standard, works with custom mini-player)
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipped()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showControls.toggle()
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
        // Ensure the global mini/fullscreen player is hidden so we don't get two players stacked
        globalPlayer.stopImmediately()
        globalPlayer.shouldShowMiniPlayer = false
        globalPlayer.isMiniplayer = false
        globalPlayer.showingFullscreen = false
        Task { @MainActor in
            if (try? await StoreKitService.shared.hasActiveSubscription()) == true {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + max(0.0, Double(ad.duration) * 0.25)) { AdsService.fire(ad.q25) }
                DispatchQueue.main.asyncAfter(deadline: .now() + max(0.0, Double(ad.duration) * 0.50)) { AdsService.fire(ad.q50) }
                DispatchQueue.main.asyncAfter(deadline: .now() + max(0.0, Double(ad.duration) * 0.75)) { AdsService.fire(ad.q75) }
                DispatchQueue.main.asyncAfter(deadline: .now() + max(0.0, Double(ad.duration) * 1.00)) {
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
    
    private func hideIndicators() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showVolumeIndicator = false
                showBrightnessIndicator = false
            }
        }
    }
    
    private func hideControlsAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
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
        // 🚫 NATIVE PiP DISABLED: Use custom YouTube-style mini-player instead
        // Native PiP is ugly and not YouTube parity
        // This file is NOT USED but disabled anyway for safety
        
        // ❌ OLD (DISABLED): Native PiP
        // if AVPictureInPictureController.isPictureInPictureSupported() {
        //     globalPlayer.currentVideo = video
        //     globalPlayer.player?.replaceCurrentItem(with: playerViewModel.player?.currentItem)
        //     globalPlayer.togglePictureInPicture()
        // }
        
        // ✅ NEW: Custom YouTube-style mini-player
        globalPlayer.currentVideo = video
        globalPlayer.minimizePlayer()
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

// MARK: - Modern Player Controls
struct ModernPlayerControlsView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    let video: Video
    let onDismiss: () -> Void
    let onMinimize: () -> Void
    let onTogglePiP: () -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Controls
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(video.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(video.creator.displayName)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: onTogglePiP) {
                        Image(systemName: viewModel.isPiPActive ? "pip.exit" : "pip.enter")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Menu {
                        Button("Report") {}
                        Button("Save to Watch Later") {}
                        Button("Share") {}
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // Center Play/Pause
            Button(action: {
                viewModel.togglePlayPause()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .scaleEffect(viewModel.isPlaying ? 0.8 : 1.0)
            .opacity(viewModel.isPlaying ? 0.3 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isPlaying)
            
            Spacer()
            
            // Bottom Controls
            VStack(spacing: 16) {
                // Progress Bar
                VStack(spacing: 8) {
                    HStack {
                        Text(viewModel.currentTimeString)
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(viewModel.durationString)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    ModernProgressBar(
                        progress: viewModel.currentProgress,
                        onSeek: { progress in
                            viewModel.seek(to: progress)
                        }
                    )
                }
                
                // Playback Controls
                HStack(spacing: 30) {
                    Button(action: {
                        viewModel.seekBackward(10)
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        viewModel.togglePlayPause()
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        viewModel.seekForward(10)
                    }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button("0.5x") { viewModel.setPlaybackRate(0.5) }
                        Button("0.75x") { viewModel.setPlaybackRate(0.75) }
                        Button("1x") { viewModel.setPlaybackRate(1.0) }
                        Button("1.25x") { viewModel.setPlaybackRate(1.25) }
                        Button("1.5x") { viewModel.setPlaybackRate(1.5) }
                        Button("2x") { viewModel.setPlaybackRate(2.0) }
                    } label: {
                        Text("\(String(format: "%.2f", viewModel.playbackRate))x")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(6)
                    }

                    if !viewModel.subtitleOptions.isEmpty {
                        Menu {
                            Button("Off") { viewModel.selectSubtitle(option: nil) }
                            Divider()
                            ForEach(Array(viewModel.subtitleOptions.enumerated()), id: \.offset) { idx, opt in
                                Button(opt.displayName) { viewModel.selectSubtitle(option: opt) }
                            }
                        } label: {
                            Text(viewModel.selectedSubtitle?.displayName ?? "Subtitles")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(6)
                        }
                    }

                    if !viewModel.audioOptions.isEmpty {
                        Menu {
                            ForEach(Array(viewModel.audioOptions.enumerated()), id: \.offset) { idx, opt in
                                Button(opt.displayName) { viewModel.selectAudio(option: opt) }
                            }
                        } label: {
                            Text(viewModel.selectedAudio?.displayName ?? "Audio")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(6)
                        }
                    }
                    
                    Button(action: {
                        // Toggle fullscreen
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Modern Progress Bar
struct ModernProgressBar: View {
    let progress: Double
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    var displayProgress: Double {
        isDragging ? dragProgress : progress
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: isDragging ? 6 : 4)
                
                // Progress
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * displayProgress, height: isDragging ? 6 : 4)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                    .offset(x: geometry.size.width * displayProgress - (isDragging ? 8 : 6))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .frame(height: 20)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    let newProgress = max(0, min(1, value.location.x / UIScreen.main.bounds.width))
                    dragProgress = newProgress
                }
                .onEnded { value in
                    isDragging = false
                    onSeek(dragProgress)
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
}

// MARK: - Modern Loading View
struct ModernLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            }
            
            Text("Loading video...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Volume Indicator
struct ModernVolumeIndicator: View {
    let volume: Float
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: volume == 0 ? "speaker.slash" : "speaker.wave.2")
                .font(.title2)
                .foregroundColor(.white)
            
            VStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { index in
                    Rectangle()
                        .fill(index < Int(volume * 10) ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 30, height: 4)
                }
            }
            
            Text("\(Int(volume * 100))%")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(16)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}

// MARK: - Brightness Indicator
struct ModernBrightnessIndicator: View {
    let brightness: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sun.max")
                .font(.title2)
                .foregroundColor(.white)
            
            VStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { index in
                    Rectangle()
                        .fill(index < Int(brightness * 10) ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 30, height: 4)
                }
            }
            
            Text("\(Int(brightness * 100))%")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(16)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}

// MARK: - Video Player ViewModel
@MainActor
class VideoPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isPiPActive = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentProgress: Double = 0
    @Published var playbackRate: Float = 1.0
    @Published var subtitleOptions: [AVMediaSelectionOption] = []
    @Published var audioOptions: [AVMediaSelectionOption] = []
    @Published var selectedSubtitle: AVMediaSelectionOption? = nil
    @Published var selectedAudio: AVMediaSelectionOption? = nil
    private var subtitleGroup: AVMediaSelectionGroup?
    private var audioGroup: AVMediaSelectionGroup?
    private var lastResumePersist: TimeInterval = 0
    private var resumeKey: String = ""
    fileprivate var quartilesFired: Set<Int> = []
    
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    func setupPlayer(with video: Video) {
        print("🎬 Setting up player for video: \(video.title)")
        print("🔗 Video URL: \(video.videoURL)")
        print("💰 Monetization: \(video.monetization?.isMonetized ?? false)")
        
        guard let url = URL(string: video.videoURL) else { 
            print("❌ Invalid video URL: \(video.videoURL)")
            return 
        }
        resumeKey = (video.id as? String) ?? video.videoURL
        player = AVPlayer(url: url)
        addTimeObserver()
        setupNotifications()
        configureMediaSelection()
        // Resume position if available
        if let t = UserDefaults.standard.object(forKey: "resume_\(resumeKey)") as? Double, t > 3 {
            player?.seek(to: CMTime(seconds: t, preferredTimescale: 1000))
        }
        
        // Set playback rate
        player?.rate = playbackRate
    }
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to progress: Double) {
        guard let player = player else { return }
        let time = duration * progress
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player.seek(to: cmTime)
    }
    
    func seekForward(_ seconds: TimeInterval) {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: seconds, preferredTimescale: 1000))
        player.seek(to: newTime)
    }
    
    func seekBackward(_ seconds: TimeInterval) {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeSubtract(currentTime, CMTime(seconds: seconds, preferredTimescale: 1000))
        player.seek(to: newTime)
    }
    
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        player?.rate = isPlaying ? rate : 0
    }
    
    private func addTimeObserver() {
        guard let player = player else { return }
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 1000),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
            
            if let duration = self?.player?.currentItem?.duration.seconds, duration.isFinite {
                self?.duration = duration
                self?.currentProgress = time.seconds / duration
            }
            // Persist resume position every ~5s
            if let s = self {
                if time.seconds - s.lastResumePersist >= 5 {
                    s.lastResumePersist = time.seconds
                    UserDefaults.standard.set(time.seconds, forKey: "resume_\(s.resumeKey)")
                }
                // GA4 quartiles
                if s.duration > 0 {
                    let pct = time.seconds / s.duration
                    if pct >= 0.25 && !s.quartilesFired.contains(25) { s.quartilesFired.insert(25); Task { await AnalyticsService.shared.trackVideoQuartile(videoId: s.resumeKey, quartile: 25) } }
                    if pct >= 0.50 && !s.quartilesFired.contains(50) { s.quartilesFired.insert(50); Task { await AnalyticsService.shared.trackVideoQuartile(videoId: s.resumeKey, quartile: 50) } }
                    if pct >= 0.75 && !s.quartilesFired.contains(75) { s.quartilesFired.insert(75); Task { await AnalyticsService.shared.trackVideoQuartile(videoId: s.resumeKey, quartile: 75) } }
                }
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.isPlaying = false
            }
            .store(in: &cancellables)
    }
    
    // MARK: Media Selection (Captions/Dubs)
    private func configureMediaSelection() {
        guard let item = player?.currentItem else { return }
        let asset = item.asset
        if let legible = asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            subtitleGroup = legible
            subtitleOptions = legible.options
        }
        if let audible = asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            audioGroup = audible
            audioOptions = audible.options
        }
    }
    
    func selectSubtitle(option: AVMediaSelectionOption?) {
        guard let group = subtitleGroup, let item = player?.currentItem else { return }
        selectedSubtitle = option
        if let option = option {
            item.select(option, in: group)
        } else {
            item.select(nil, in: group)
        }
    }
    
    func selectAudio(option: AVMediaSelectionOption?) {
        guard let group = audioGroup, let item = player?.currentItem else { return }
        selectedAudio = option
        if let option = option {
            item.select(option, in: group)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player = nil
        cancellables.removeAll()
    }

    // MARK: - PiP (DISABLED)
    func togglePiP() {
        // 🚫 NATIVE PiP DISABLED: Use custom YouTube-style mini-player instead
        // ❌ OLD: isPiPActive.toggle()
        // ✅ NEW: Minimize to custom mini-player
        GlobalVideoPlayerManager.shared.minimizePlayer()
    }
}

// MARK: - Device Orientation Extension
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            action(UIDevice.current.orientation)
        }
    }
}

#Preview {
    ModernVideoPlayerView(video: Video.sampleVideos[0])
}