//
//  NowPlayingView.swift
//  MyChannel
//
//  Full-screen Now Playing experience for MyChannel Music.
//

import SwiftUI

struct MusicNowPlayingView: View {
    @EnvironmentObject private var musicPlayer: MusicPlayerService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()
            
            if let song = musicPlayer.currentSong {
                VStack(spacing: 24) {
                    // Handle
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    
                    // Artwork
                    artworkView(for: song)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                    
                    // Title / artist
                    VStack(spacing: 6) {
                        Text(song.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 24)
                        
                        if let primary = song.artistIds.first {
                            Text(primary)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    
                    // Progress + scrubber
                    VStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { musicPlayer.progress },
                                set: { musicPlayer.seek(toFraction: $0) }
                            ),
                            in: 0...1
                        )
                        .tint(.white)
                        
                        HStack {
                            Text(timeString(musicPlayer.currentTime))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.7))
                            
                            Spacer()
                            
                            Text(timeString(musicPlayer.duration))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Controls
                    VStack(spacing: 20) {
                        HStack(spacing: 32) {
                            Button {
                                HapticManager.shared.impact(style: .light)
                                musicPlayer.setShuffle(!musicPlayer.isShuffleEnabled)
                            } label: {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(musicPlayer.isShuffleEnabled ? .white : Color.white.opacity(0.5))
                            }
                            
                            Button {
                                HapticManager.shared.impact(style: .medium)
                                musicPlayer.skipPrevious()
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Button {
                                HapticManager.shared.impact(style: .medium)
                                musicPlayer.togglePlayPause()
                            } label: {
                                Image(systemName: musicPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(22)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
                            }
                            
                            Button {
                                HapticManager.shared.impact(style: .medium)
                                musicPlayer.skipNext()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Button {
                                HapticManager.shared.impact(style: .light)
                                cycleRepeatMode()
                            } label: {
                                Image(systemName: repeatIcon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(repeatTint)
                            }
                        }
                        
                        HStack(spacing: 28) {
                            Button {
                                HapticManager.shared.impact(style: .light)
                                musicPlayer.setCrossfadeEnabled(!musicPlayer.isCrossfadeEnabled)
                            } label: {
                                Label("Crossfade", systemImage: "waveform.path.ecg")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(musicPlayer.isCrossfadeEnabled ? 0.25 : 0.1))
                                    )
                            }
                            
                            Spacer()
                            
                            Button {
                                HapticManager.shared.impact(style: .light)
                                // Queue presentation is handled by parent using this button action.
                                NotificationCenter.default.post(name: Notification.Name("OpenMusicQueue"), object: nil)
                            } label: {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Button {
                                HapticManager.shared.impact(style: .light)
                                // AirPlay uses system route picker hosted elsewhere.
                            } label: {
                                Image(systemName: "airplayaudio")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height > 60 {
                        dismiss()
                    }
                }
        )
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppTheme.Colors.primary,
                AppTheme.Colors.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func artworkView(for song: Song) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.25))
            
            if let url = song.artworkURL {
                AppAsyncImage(
                    url: url,
                    content: { image in
                        image.resizable().scaledToFill()
                    },
                    placeholder: {
                        Color.black.opacity(0.2)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 20)
    }
    
    private var repeatIcon: String {
        switch musicPlayer.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    private var repeatTint: Color {
        switch musicPlayer.repeatMode {
        case .off: return Color.white.opacity(0.5)
        case .all, .one: return .white
        }
    }
    
    private func cycleRepeatMode() {
        switch musicPlayer.repeatMode {
        case .off: musicPlayer.setRepeatMode(.all)
        case .all: musicPlayer.setRepeatMode(.one)
        case .one: musicPlayer.setRepeatMode(.off)
        }
    }
    
    private func timeString(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let total = Int(time)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MusicNowPlayingView()
        .environmentObject(MusicPlayerService.shared)
}

//
//  NowPlayingView.swift
//  MyChannel
//
//  Full-Screen Now Playing - Apple Music Level
//

import SwiftUI

// MARK: - Full Screen Now Playing View

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = AudioPreviewPlayer.shared
    @State private var showLyrics: Bool = false
    @State private var showQueue: Bool = false
    @State private var showSleepTimer: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var artworkScale: CGFloat = 1.0
    @State private var isLiked: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background - blurred artwork
                backgroundView
                
                // Content
                VStack(spacing: 0) {
                    // Top bar
                    topBar
                    
                    Spacer()
                    
                    if showLyrics {
                        // Lyrics view
                        LyricsDisplayView()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Artwork
                        artworkView
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    // Track info
                    trackInfoView
                        .padding(.horizontal, 24)
                    
                    // Progress bar
                    progressView
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    
                    // Playback controls
                    playbackControls
                        .padding(.top, 24)
                    
                    // Volume slider
                    volumeSlider
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    
                    // Bottom actions
                    bottomActions
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheet()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    }
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
        )
        .offset(y: dragOffset)
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        ZStack {
            // Base color
            Color.black
            
            // Artwork blur
            if let artworkURL = player.currentArtworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 60)
                        .saturation(1.2)
                } placeholder: {
                    Color.black
                }
            }
            
            // Dark overlay
            LinearGradient(
                colors: [
                    .black.opacity(0.3),
                    .black.opacity(0.7),
                    .black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("PLAYING FROM")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Text("810 Radio")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Menu {
                Button {
                    showSleepTimer = true
                } label: {
                    Label("Sleep Timer", systemImage: "moon.fill")
                }
                Button {
                    // Share action
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button {
                    // Add to playlist
                } label: {
                    Label("Add to Playlist", systemImage: "plus")
                }
                Button {
                    // View artist
                } label: {
                    Label("View Artist", systemImage: "person.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    // MARK: - Artwork
    
    private var artworkView: some View {
        ZStack {
            if let artworkURL = player.currentArtworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
        .scaleEffect(player.isPlaying ? 1.0 : 0.95)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)
    }
    
    // MARK: - Track Info
    
    private var trackInfoView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentTitle ?? "Not Playing")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(player.currentArtist ?? "Unknown Artist")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isLiked.toggle()
                }
                HapticManager.shared.impact(style: .medium)
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 24))
                    .foregroundColor(isLiked ? .red : .white)
                    .scaleEffect(isLiked ? 1.2 : 1.0)
            }
        }
    }
    
    // MARK: - Progress View
    
    private var progressView: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * player.progress, height: 4)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = min(max(value.location.x / geo.size.width, 0), 1)
                            player.seek(toFraction: progress)
                        }
                )
            }
            .frame(height: 4)
            
            // Time labels
            HStack {
                Text(formatTime(player.progress * player.durationSeconds))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Text("-" + formatTime(player.durationSeconds * (1 - player.progress)))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Playback Controls
    
    private var playbackControls: some View {
        HStack(spacing: 40) {
            // Shuffle
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Previous
            Button {
                // Previous track not available in preview player
                HapticManager.shared.impact(style: .medium)
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            // Play/Pause
            Button {
                if player.isPlaying {
                    player.pause()
                } else {
                    player.resume()
                }
                HapticManager.shared.impact(style: .medium)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.black)
                        .offset(x: player.isPlaying ? 0 : 2)
                }
            }
            
            // Next
            Button {
                player.next()
                HapticManager.shared.impact(style: .medium)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            // Repeat
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    // MARK: - Volume Slider
    
    private var volumeSlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            
            Slider(value: .constant(0.7), in: 0...1)
                .tint(.white)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Bottom Actions
    
    private var bottomActions: some View {
        HStack(spacing: 50) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showLyrics.toggle()
                }
                HapticManager.shared.impact(style: .light)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 20))
                    Text("Lyrics")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(showLyrics ? .white : .white.opacity(0.5))
            }
            
            Button {
                HapticManager.shared.impact(style: .light)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 20))
                    Text("AirPlay")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.5))
            }
            
            Button {
                showQueue = true
                HapticManager.shared.impact(style: .light)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                    Text("Queue")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Lyrics Display View

struct LyricsDisplayView: View {
    @State private var currentLineIndex: Int = 2
    @State private var lyricsTimer: Timer?
    
    // Sample lyrics for demo
    private let sampleLyrics: [String] = [
        "Yeah, yeah",
        "Flint city, 810",
        "We came from nothing",
        "Now we running everything",
        "Shout out to the whole gang",
        "We been grinding all day",
        "Stack it up, get it right",
        "This that 810 life",
        "Real ones know what's up",
        "We don't fold, we stand up"
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                ForEach(Array(sampleLyrics.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.system(size: index == currentLineIndex ? 28 : 22, weight: .bold))
                        .foregroundColor(index == currentLineIndex ? .white : .white.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .scaleEffect(index == currentLineIndex ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentLineIndex)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
        }
        .onAppear {
            lyricsTimer?.invalidate()
            lyricsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                withAnimation {
                    currentLineIndex = (currentLineIndex + 1) % sampleLyrics.count
                }
            }
        }
        .onDisappear {
            lyricsTimer?.invalidate()
            lyricsTimer = nil
        }
    }
}

// MARK: - Queue View

struct QueueView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = AudioPreviewPlayer.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Now Playing
                Section {
                    if let title = player.currentTitle {
                        HStack(spacing: 12) {
                            if let url = player.currentArtworkURL {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.systemGray5))
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(player.currentArtist ?? "Unknown")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "waveform")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                } header: {
                    Text("Now Playing")
                }
                
                // Up Next
                Section {
                    ForEach(player.queue.prefix(10), id: \.trackId) { item in
                        HStack(spacing: 12) {
                            if let url = item.artworkURL {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.systemGray5))
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title ?? "Unknown Title")
                                    .font(.system(size: 16))
                                Text(item.artist ?? "Unknown Artist")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                        }
                    }
                    .onMove { from, to in
                        // Handle reorder
                    }
                } header: {
                    HStack {
                        Text("Up Next")
                        Spacer()
                        Button("Clear") {
                            HapticManager.shared.impact(style: .light)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Sleep Timer Sheet

struct SleepTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: Int? = nil
    
    let times: [(String, Int)] = [
        ("5 minutes", 5),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("45 minutes", 45),
        ("1 hour", 60),
        ("End of track", -1)
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(times, id: \.1) { time in
                    Button {
                        selectedTime = time.1
                        HapticManager.shared.impact(style: .medium)
                        // Set timer
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(time.0)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedTime == time.1 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                    }
                }
                
                if selectedTime != nil {
                    Section {
                        Button(role: .destructive) {
                            selectedTime = nil
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Text("Cancel Timer")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Visualizer View

struct VisualizerView: View {
    @State private var bars: [CGFloat] = Array(repeating: 0.3, count: 40)
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.red, .orange, .yellow],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 6, height: bars[index] * 100)
                    .animation(.easeInOut(duration: 0.1), value: bars[index])
            }
        }
        .frame(height: 100)
        .onReceive(timer) { _ in
            for i in 0..<bars.count {
                bars[i] = CGFloat.random(in: 0.2...1.0)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NowPlayingView_Previews: PreviewProvider {
    static var previews: some View {
        NowPlayingView()
    }
}
#endif

