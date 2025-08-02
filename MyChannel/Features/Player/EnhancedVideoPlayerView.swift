//
//  EnhancedVideoPlayerView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVKit

struct EnhancedVideoPlayerView: View {
    let video: Video
    @StateObject private var playerManager = VideoPlayerManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingControls = true
    @State private var showingQualitySelector = false
    @State private var showingSubtitleSelector = false
    @State private var showingPlaybackSpeed = false
    @State private var showingMoreOptions = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Video Player
                VideoPlayer(player: playerManager.player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingControls.toggle()
                        }
                    }
                
                // Custom Controls Overlay
                if showingControls {
                    customControlsOverlay
                }
                
                // Quality Selector
                if showingQualitySelector {
                    qualitySelectorOverlay
                }
                
                // Subtitle Selector
                if showingSubtitleSelector {
                    subtitleSelectorOverlay
                }
                
                // Playback Speed Selector
                if showingPlaybackSpeed {
                    playbackSpeedOverlay
                }
                
                // More Options Menu
                if showingMoreOptions {
                    moreOptionsOverlay
                }
            }
        }
        .onAppear {
            playerManager.setupPlayer(with: video)
            hideControlsAfterDelay()
        }
        .onDisappear {
            playerManager.cleanup()
        }
    }
    
    private var customControlsOverlay: some View {
        VStack {
            // Top Controls
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(video.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { showingQualitySelector = true }) {
                        VStack(spacing: 2) {
                            Text("HD")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text(playerManager.currentQuality.displayName)
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    }
                    
                    Button(action: { showingMoreOptions = true }) {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
            }
            .padding()
            
            Spacer()
            
            // Center Play/Pause Button
            HStack {
                Button(action: { playerManager.seekBackward() }) {
                    Image(systemName: "gobackward.10")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Button(action: { playerManager.togglePlayPause() }) {
                    Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Button(action: { playerManager.seekForward() }) {
                    Image(systemName: "goforward.10")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            // Bottom Controls
            VStack(spacing: 16) {
                // Progress Bar
                VStack(spacing: 8) {
                    HStack {
                        Text(playerManager.currentTimeString)
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(playerManager.durationString)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    ProgressView(value: playerManager.progress, total: 1.0)
                        .progressViewStyle(VideoProgressViewStyle())
                        .onTapGesture { location in
                            // TODO: Implement seek on tap
                        }
                }
                
                // Control Buttons
                HStack {
                    Button(action: { showingSubtitleSelector = true }) {
                        Image(systemName: playerManager.subtitlesEnabled ? "captions.bubble.fill" : "captions.bubble")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { showingPlaybackSpeed = true }) {
                        Text("\(playerManager.playbackSpeed, specifier: "%.1f")x")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Button(action: { playerManager.toggleFullscreen() }) {
                        Image(systemName: playerManager.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear, Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var qualitySelectorOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { showingQualitySelector = false }
            
            VStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Video Quality")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("Done") {
                            showingQualitySelector = false
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        Button(action: {
                            playerManager.setQuality(quality)
                            showingQualitySelector = false
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quality.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    
                                    Text(quality.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                if playerManager.currentQuality == quality {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.black.opacity(0.9))
                .cornerRadius(16)
                .padding()
            }
        }
    }
    
    private var subtitleSelectorOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { showingSubtitleSelector = false }
            
            VStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Subtitles & Captions")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("Done") {
                            showingSubtitleSelector = false
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    
                    Button(action: {
                        playerManager.disableSubtitles()
                        showingSubtitleSelector = false
                    }) {
                        HStack {
                            Text("Off")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if !playerManager.subtitlesEnabled {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(playerManager.availableSubtitles, id: \.self) { subtitle in
                        Button(action: {
                            playerManager.enableSubtitles(subtitle)
                            showingSubtitleSelector = false
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subtitle.language)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    
                                    if subtitle.isAutoGenerated {
                                        Text("Auto-generated")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                                
                                if playerManager.currentSubtitle == subtitle {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.black.opacity(0.9))
                .cornerRadius(16)
                .padding()
            }
        }
    }
    
    private var playbackSpeedOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { showingPlaybackSpeed = false }
            
            VStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Playback Speed")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("Done") {
                            showingPlaybackSpeed = false
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    
                    ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                        Button(action: {
                            playerManager.setPlaybackSpeed(speed)
                            showingPlaybackSpeed = false
                        }) {
                            HStack {
                                Text("\(speed, specifier: speed == 1.0 ? "%.0f" : "%.2f")x")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                if speed == 1.0 {
                                    Text("Normal")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                if abs(playerManager.playbackSpeed - speed) < 0.01 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.black.opacity(0.9))
                .cornerRadius(16)
                .padding()
            }
        }
    }
    
    private var moreOptionsOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { showingMoreOptions = false }
            
            VStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("More Options")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("Done") {
                            showingMoreOptions = false
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    
                    MoreOptionButton(
                        icon: "plus.rectangle.on.folder",
                        title: "Add to Playlist",
                        action: { /* TODO */ }
                    )
                    
                    MoreOptionButton(
                        icon: "clock",
                        title: "Save to Watch Later",
                        action: { /* TODO */ }
                    )
                    
                    MoreOptionButton(
                        icon: "square.and.arrow.up",
                        title: "Share Video",
                        action: { /* TODO */ }
                    )
                    
                    MoreOptionButton(
                        icon: "flag",
                        title: "Report Video",
                        action: { /* TODO */ }
                    )
                    
                    MoreOptionButton(
                        icon: "gear",
                        title: "Video Settings",
                        action: { /* TODO */ }
                    )
                }
                .background(Color.black.opacity(0.9))
                .cornerRadius(16)
                .padding()
            }
        }
    }
    
    private func hideControlsAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if showingControls {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingControls = false
                }
            }
        }
    }
}

// MARK: - Supporting Views and Models
struct MoreOptionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding()
        }
        .buttonStyle(.plain)
    }
}

struct VideoProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0), height: 4)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Video Quality Enum
enum VideoQuality: String, CaseIterable {
    case auto = "auto"
    case quality144p = "144p"
    case quality240p = "240p"
    case quality360p = "360p"
    case quality480p = "480p"
    case quality720p = "720p"
    case quality1080p = "1080p"
    case quality1440p = "1440p"
    case quality2160p = "2160p"
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .quality144p: return "144p"
        case .quality240p: return "240p"
        case .quality360p: return "360p"
        case .quality480p: return "480p"
        case .quality720p: return "720p"
        case .quality1080p: return "1080p HD"
        case .quality1440p: return "1440p HD"
        case .quality2160p: return "2160p 4K"
        }
    }
    
    var description: String {
        switch self {
        case .auto: return "Adjusts automatically"
        case .quality144p: return "Data saver"
        case .quality240p: return "Lower quality"
        case .quality360p: return "Standard definition"
        case .quality480p: return "Standard definition"
        case .quality720p: return "High definition"
        case .quality1080p: return "Full high definition"
        case .quality1440p: return "Quad high definition"
        case .quality2160p: return "Ultra high definition"
        }
    }
}

// MARK: - Subtitle Model
struct VideoSubtitle: Hashable {
    let id: String
    let language: String
    let languageCode: String
    let isAutoGenerated: Bool
    let url: String?
    
    init(id: String = UUID().uuidString, language: String, languageCode: String, isAutoGenerated: Bool = false, url: String? = nil) {
        self.id = id
        self.language = language
        self.languageCode = languageCode
        self.isAutoGenerated = isAutoGenerated
        self.url = url
    }
}

// MARK: - Video Player Manager
class VideoPlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var currentQuality: VideoQuality = .auto
    @Published var playbackSpeed: Double = 1.0
    @Published var subtitlesEnabled = false
    @Published var currentSubtitle: VideoSubtitle?
    @Published var isFullscreen = false
    
    var currentTimeString: String {
        formatTime(currentTime)
    }
    
    var durationString: String {
        formatTime(duration)
    }
    
    let availableSubtitles: [VideoSubtitle] = [
        VideoSubtitle(language: "English", languageCode: "en"),
        VideoSubtitle(language: "Spanish", languageCode: "es"),
        VideoSubtitle(language: "French", languageCode: "fr"),
        VideoSubtitle(language: "German", languageCode: "de", isAutoGenerated: true),
        VideoSubtitle(language: "Japanese", languageCode: "ja", isAutoGenerated: true)
    ]
    
    private var timeObserver: Any?
    
    func setupPlayer(with video: Video) {
        guard let url = URL(string: video.videoURL) else { return }
        
        player = AVPlayer(url: url)
        
        // Add time observer
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.updateProgress(time: time)
        }
        
        // Get duration
        player?.currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            DispatchQueue.main.async {
                if let duration = self.player?.currentItem?.duration {
                    self.duration = CMTimeGetSeconds(duration)
                }
            }
        }
    }
    
    func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.pause()
        player = nil
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if player.rate == 0 {
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }
    
    func seekForward() {
        guard let player = player else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = min(currentTime + 10, duration)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
    
    func seekBackward() {
        guard let player = player else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = max(currentTime - 10, 0)
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
    
    func setQuality(_ quality: VideoQuality) {
        currentQuality = quality
        // TODO: Implement quality switching logic
        print("Quality changed to: \(quality.displayName)")
    }
    
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        player?.rate = Float(speed)
    }
    
    func enableSubtitles(_ subtitle: VideoSubtitle) {
        subtitlesEnabled = true
        currentSubtitle = subtitle
        // TODO: Implement subtitle loading
        print("Enabled subtitles: \(subtitle.language)")
    }
    
    func disableSubtitles() {
        subtitlesEnabled = false
        currentSubtitle = nil
        // TODO: Implement subtitle disabling
        print("Disabled subtitles")
    }
    
    func toggleFullscreen() {
        isFullscreen.toggle()
        // TODO: Implement fullscreen logic
        print("Fullscreen: \(isFullscreen)")
    }
    
    private func updateProgress(time: CMTime) {
        currentTime = CMTimeGetSeconds(time)
        if duration > 0 {
            progress = currentTime / duration
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time / 3600)
        let minutes = Int((time.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(time.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    EnhancedVideoPlayerView(video: Video.sampleVideos[0])
}