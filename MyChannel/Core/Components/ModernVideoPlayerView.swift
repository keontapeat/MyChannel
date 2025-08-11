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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                // Video Player
                if let player = playerViewModel.player {
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
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .ignoresSafeArea()
        .onAppear {
            setupPlayer()
            hideControlsAfterDelay()
        }
        .onDisappear {
            cleanup()
        }
        .onRotate { newOrientation in
            orientation = newOrientation
        }
    }
    
    private func setupPlayer() {
        // Ensure the global mini/fullscreen player is hidden so we don't get two players stacked
        globalPlayer.stopImmediately()
        globalPlayer.shouldShowMiniPlayer = false
        globalPlayer.isMiniplayer = false
        globalPlayer.showingFullscreen = false

        // Use the local fullscreen player only in this view
        playerViewModel.setupPlayer(with: video)
        playerViewModel.play()

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
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
        // Set up global player for mini player
        globalPlayer.currentVideo = video
        globalPlayer.player?.replaceCurrentItem(with: playerViewModel.player?.currentItem)
        globalPlayer.minimizePlayer()
        dismiss()
    }
    
    private func cleanup() {
        playerViewModel.cleanup()
    }
}

// MARK: - Modern Player Controls
struct ModernPlayerControlsView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    let video: Video
    let onDismiss: () -> Void
    let onMinimize: () -> Void
    
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
                    Button(action: onMinimize) {
                        Image(systemName: "pip.enter")
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
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentProgress: Double = 0
    @Published var playbackRate: Float = 1.0
    
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    func setupPlayer(with video: Video) {
        guard let url = URL(string: video.videoURL) else { return }
        
        player = AVPlayer(url: url)
        addTimeObserver()
        setupNotifications()
        
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