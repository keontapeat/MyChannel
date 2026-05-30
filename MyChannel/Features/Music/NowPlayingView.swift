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


// ⚡ NowPlayingView + sub-views extracted to NowPlayingComponents.swift
