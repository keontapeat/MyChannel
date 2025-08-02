//
//  VideoPlayerView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import AVKit
import Combine

struct VideoPlayerView: View {
    let video: Video
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var showControls: Bool = true
    @State private var currentTime: Double = 0
    @State private var totalTime: Double = 0
    @State private var isLoading: Bool = true
    @State private var hasError: Bool = false
    @State private var hideControlsTimer: Timer?
    @State private var timeObserver: Any?
    @State private var statusObserver: AnyCancellable?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                // Video player or demo content
                if let player = player, !hasError {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onTapGesture {
                            toggleControlsVisibility()
                        }
                        .overlay(
                            // Loading indicator
                            Group {
                                if isLoading {
                                    ZStack {
                                        Color.black.opacity(0.3)
                                        
                                        VStack(spacing: 16) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(1.5)
                                            
                                            Text("Loading video...")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .ignoresSafeArea()
                                }
                            }
                        )
                } else {
                    // Demo/Placeholder content for non-working URLs
                    DemoVideoContent(video: video, isPlaying: $isPlaying)
                        .onTapGesture {
                            toggleControlsVisibility()
                        }
                }
                
                // Custom controls overlay
                if showControls {
                    VideoControlsOverlay(
                        video: video,
                        player: player,
                        isPlaying: $isPlaying,
                        currentTime: $currentTime,
                        totalTime: $totalTime,
                        hasError: hasError,
                        onDismiss: {
                            dismiss()
                        },
                        onPlayPause: {
                            if hasError {
                                // For demo mode, just toggle the state
                                isPlaying.toggle()
                            } else {
                                isPlaying.toggle()
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .onChange(of: isPlaying) { oldValue, newValue in
            if !hasError {
                if newValue {
                    player?.play()
                    startHideControlsTimer()
                } else {
                    player?.pause()
                    cancelHideControlsTimer()
                }
            } else {
                // For demo mode
                if newValue {
                    startHideControlsTimer()
                } else {
                    cancelHideControlsTimer()
                }
            }
        }
    }
    
    private func setupPlayer() {
        // For demo purposes, since sample URLs aren't real
        // Let's create a working demo experience
        
        guard let url = URL(string: video.videoURL), 
              url.scheme != nil else {
            // URL is not valid, show demo content
            setupDemoMode()
            return
        }
        
        // Try to create real player for valid URLs
        player = AVPlayer(url: url)
        setupPlayerObservers()
        
        // Check if player can load the content
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if player?.currentItem?.status == .failed {
                setupDemoMode()
            } else {
                isLoading = false
            }
        }
    }
    
    private func setupDemoMode() {
        hasError = true
        isLoading = false
        totalTime = video.duration
        
        // Simulate video playback for demo
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if isPlaying && currentTime < totalTime {
                currentTime += 1.0
            }
            if currentTime >= totalTime {
                currentTime = 0
                isPlaying = false
            }
        }
    }
    
    private func setupPlayerObservers() {
        guard let player = player else { return }
        
        // Time observer
        let timeInterval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: timeInterval, queue: .main) { time in
            if !time.seconds.isNaN && !time.seconds.isInfinite {
                currentTime = time.seconds
            }
            
            if let duration = player.currentItem?.duration,
               !duration.seconds.isNaN && !duration.seconds.isInfinite {
                totalTime = duration.seconds
            }
        }
        
        // Status observer
        statusObserver = player.currentItem?.publisher(for: \.status)
            .sink { [weak player] status in
                DispatchQueue.main.async {
                    switch status {
                    case .readyToPlay:
                        isLoading = false
                        // Auto-play when ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isPlaying = true
                        }
                    case .failed:
                        setupDemoMode()
                    default:
                        break
                    }
                }
            }
    }
    
    private func cleanupPlayer() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        statusObserver?.cancel()
        player?.pause()
        player = nil
        cancelHideControlsTimer()
    }
    
    private func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        
        if showControls && isPlaying {
            startHideControlsTimer()
        }
    }
    
    private func startHideControlsTimer() {
        cancelHideControlsTimer()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
    
    private func cancelHideControlsTimer() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = nil
    }
}

// MARK: - Demo Video Content
struct DemoVideoContent: View {
    let video: Video
    @Binding var isPlaying: Bool
    @State private var pulseAnimation: Bool = false
    
    var body: some View {
        ZStack {
            // Demo video background with gradient
            LinearGradient(
                colors: [
                    AppTheme.Colors.primary.opacity(0.6),
                    AppTheme.Colors.secondary.opacity(0.4),
                    AppTheme.Colors.accent.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated background pattern
            VStack(spacing: 40) {
                ForEach(0..<3) { row in
                    HStack(spacing: 40) {
                        ForEach(0..<3) { col in
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 60, height: 60)
                                .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                                .animation(
                                    .easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(row + col) * 0.2),
                                    value: pulseAnimation
                                )
                        }
                    }
                }
            }
            .opacity(0.3)
            
            // Center content
            VStack(spacing: 24) {
                // Play/Pause button
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.6))
                        .frame(width: 120, height: 120)
                        .shadow(radius: 20)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .offset(x: isPlaying ? 0 : 4) // Center the play icon
                }
                .scaleEffect(isPlaying ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
                
                // Demo video info
                VStack(spacing: 12) {
                    Text("🎬 Demo Video Player")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\"" + video.title + "\"")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Label("\(video.formattedViews) views", systemImage: "eye")
                        Label(video.formattedDuration, systemImage: "clock")
                        Label(video.creator.displayName, systemImage: "person.circle")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                }
                
                // Demo status
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.Colors.success)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                    
                    Text(isPlaying ? "Playing Demo Content" : "Demo Ready")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.3))
                .cornerRadius(16)
            }
        }
        .onAppear {
            pulseAnimation = true
        }
    }
}

// MARK: - Enhanced Video Controls Overlay
struct VideoControlsOverlay: View {
    let video: Video
    let player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var totalTime: Double
    let hasError: Bool
    let onDismiss: () -> Void
    let onPlayPause: () -> Void
    
    @State private var isSeeking: Bool = false
    
    var body: some View {
        VStack {
            // Top controls
            HStack {
                Button(action: onDismiss) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Back")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.6))
                    .cornerRadius(20)
                }
                
                Spacer()
                
                // Demo indicator
                if hasError {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.Colors.success)
                            .frame(width: 6, height: 6)
                        
                        Text("DEMO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .cornerRadius(12)
                }
                
                Menu {
                    Button(action: {}) {
                        Label("Share Video", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {}) {
                        Label("Save to Watch Later", systemImage: "bookmark")
                    }
                    
                    Button(action: {}) {
                        Label("Report", systemImage: "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .padding()
            
            Spacer()
            
            // Center play/pause button
            Button(action: onPlayPause) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.6))
                        .frame(width: 80, height: 80)
                        .shadow(radius: 10)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .offset(x: isPlaying ? 0 : 2) // Center the play icon
                }
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isPlaying ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
            
            Spacer()
            
            // Bottom controls
            VStack(spacing: 16) {
                // Progress bar
                VideoProgressBar(
                    currentTime: $currentTime,
                    totalTime: totalTime > 0 ? totalTime : video.duration,
                    isSeeking: $isSeeking,
                    onSeek: { time in
                        if !hasError {
                            let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                            player?.seek(to: cmTime)
                        } else {
                            // For demo mode
                            currentTime = time
                        }
                    }
                )
                
                // Controls row
                HStack {
                    // Time labels
                    HStack(spacing: 8) {
                        Text(timeString(from: currentTime))
                            .font(.caption)
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                        Text("/")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(timeString(from: totalTime > 0 ? totalTime : video.duration))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        Button(action: {
                            // Skip backward 10 seconds
                            if !hasError {
                                let newTime = max(0, currentTime - 10)
                                let cmTime = CMTime(seconds: newTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                                player?.seek(to: cmTime)
                            } else {
                                currentTime = max(0, currentTime - 10)
                            }
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            // Skip forward 10 seconds
                            let maxTime = totalTime > 0 ? totalTime : video.duration
                            if !hasError {
                                let newTime = min(maxTime, currentTime + 10)
                                let cmTime = CMTime(seconds: newTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                                player?.seek(to: cmTime)
                            } else {
                                currentTime = min(maxTime, currentTime + 10)
                            }
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "speaker.wave.2")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Video info
                HStack(alignment: .top, spacing: 12) {
                    AsyncImage(url: URL(string: video.creator.profileImageURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.primary)
                            .overlay(
                                Text(String(video.creator.displayName.prefix(1)))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        HStack(spacing: 4) {
                            Text(video.creator.displayName)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            if video.creator.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Text("\(video.formattedViews) views")
                            Text("•")
                            Text(video.timeAgo)
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Like and share buttons
                    VStack(spacing: 16) {
                        Button(action: {}) {
                            VStack(spacing: 4) {
                                Image(systemName: "heart")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                
                                Text("\(video.likeCount)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Button(action: {}) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                
                                Text("Share")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    private func timeString(from seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}

// MARK: - Enhanced Video Progress Bar
struct VideoProgressBar: View {
    @Binding var currentTime: Double
    let totalTime: Double
    @Binding var isSeeking: Bool
    let onSeek: (Double) -> Void
    
    @State private var dragValue: Double = 0
    
    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return isSeeking ? dragValue : currentTime / totalTime
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Progress fill
                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .cornerRadius(2)
                
                // Buffered progress (demo)
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: geometry.size.width * min(1.0, progress + 0.1), height: 4)
                    .cornerRadius(2)
                
                // Progress fill (on top)
                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .cornerRadius(2)
                
                // Thumb
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: max(8, min(geometry.size.width - 8, geometry.size.width * progress)))
                    .scaleEffect(isSeeking ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isSeeking)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isSeeking = true
                        let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                        dragValue = newProgress
                    }
                    .onEnded { value in
                        let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                        let seekTime = newProgress * totalTime
                        onSeek(seekTime)
                        isSeeking = false
                    }
            )
        }
        .frame(height: 20)
    }
}

#Preview {
    VideoPlayerView(video: Video.sampleVideos[0])
}