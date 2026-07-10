//
//  ModernVideoPlayerChrome.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

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
                .accessibilityLabel(Text("Dismiss Video"))
                .accessibilityAddTraits(.isButton)
                
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
                    // 🔥 Phase 13: Core Media Ecosystem - AirPlay Integration
                    AirPlayView()
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                        
                    Button(action: {
                        // 🔥 FIX: Register video with GlobalVideoPlayerManager for PiP
                        GlobalVideoPlayerManager.shared.registerLocalPlayer(video: video, player: viewModel.player)
                        GlobalVideoPlayerManager.shared.startPiP()
                    }) {
                        Image(systemName: "pip.enter")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Minimize to mini player")
                    
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
            .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
            .accessibilityAddTraits(.isButton)
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
                        duration: video.duration,
                        chapters: video.parsedChapters,
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
                    .accessibilityLabel(Text("Seek Backward 10 Seconds"))
                    .accessibilityAddTraits(.isButton)
                    
                    Button(action: {
                        viewModel.togglePlayPause()
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
                    .accessibilityAddTraits(.isButton)
                    
                    Button(action: {
                        viewModel.seekForward(10)
                    }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel(Text("Seek Forward 10 Seconds"))
                    .accessibilityAddTraits(.isButton)
                    
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
                    .accessibilityLabel(Text("Playback speed, \(String(format: "%.2f", viewModel.playbackRate)) times"))
                    .accessibilityHint(Text("Opens playback speed options"))

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
                        .accessibilityLabel(Text("Subtitles, \(viewModel.selectedSubtitle?.displayName ?? "Off")"))
                        .accessibilityHint(Text("Opens subtitle language options"))
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
                        .accessibilityLabel(Text("Audio track, \(viewModel.selectedAudio?.displayName ?? "Default")"))
                        .accessibilityHint(Text("Opens audio track options"))
                    }
                    
                    Button(action: {
                        // Toggle fullscreen
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel(Text("Toggle Fullscreen"))
                    .accessibilityAddTraits(.isButton)
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
    var duration: TimeInterval = 0
    var chapters: [Video.Chapter] = []
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
                
                // Chapter Gaps
                if duration > 0 && !chapters.isEmpty {
                    ForEach(chapters) { chapter in
                        if chapter.start > 0 {
                            let xOffset = geometry.size.width * (chapter.start / duration)
                            Rectangle()
                                .fill(Color.black.opacity(0.5)) // Gap color
                                .frame(width: 2, height: isDragging ? 6 : 4)
                                .offset(x: xOffset)
                        }
                    }
                }
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                    .offset(x: geometry.size.width * displayProgress - (isDragging ? 8 : 6))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Playback Progress"))
            .accessibilityValue(Text("\(Int(displayProgress * 100)) percent"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    onSeek(min(1.0, progress + 0.1))
                case .decrement:
                    onSeek(max(0.0, progress - 0.1))
                @unknown default:
                    break
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                        dragProgress = newProgress
                    }
                    .onEnded { value in
                        isDragging = false
                        onSeek(dragProgress)
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        }
        .frame(height: 20)
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
        .accessibilityLabel("Loading video")
    }
}

// MARK: - Player Not Ready / Error Chrome
struct PlayerNotReadyChrome: View {
    let title: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.9))
            Text("Can't play this video")
                .font(.headline)
                .foregroundColor(.white)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: onRetry) {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Try again")
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Buffering Indicator
struct PlayerBufferingIndicator: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(1.4)
            .padding(20)
            .background(Color.black.opacity(0.45))
            .clipShape(Circle())
            .accessibilityLabel("Buffering")
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

// MARK: - Device Orientation Extension
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            action(UIDevice.current.orientation)
        }
    }
}
