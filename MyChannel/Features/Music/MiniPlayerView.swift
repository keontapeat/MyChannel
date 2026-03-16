//
//  MiniPlayerView.swift
//  MyChannel
//
//  Compact music mini-player anchored above the tab bar.
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var musicPlayer: MusicPlayerService
    
    var onExpand: () -> Void
    
    var body: some View {
        if let song = musicPlayer.currentSong {
            Button(action: onExpand) {
                HStack(spacing: 12) {
                    // Artwork
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Group {
                                if let url = song.artworkURL {
                                    AppAsyncImage(
                                        url: url,
                                        content: { image in
                                            image.resizable().scaledToFill()
                                        },
                                        placeholder: {
                                            Color.gray.opacity(0.2)
                                        }
                                    )
                                } else {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        )
                    
                    // Title + artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                        
                        if let primary = song.artistIds.first {
                            Text(primary)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppTheme.Colors.divider.opacity(0.5))
                                    .frame(height: 2)
                                
                                Capsule()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: CGFloat(musicPlayer.progress) * geo.size.width, height: 2)
                            }
                        }
                        .frame(height: 4)
                    }
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 16) {
                        Button {
                            HapticManager.shared.impact(style: .light)
                            musicPlayer.skipPrevious()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            musicPlayer.togglePlayPause()
                        } label: {
                            Image(systemName: musicPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(AppTheme.Colors.primary)
                                .clipShape(Circle())
                        }
                        
                        Button {
                            HapticManager.shared.impact(style: .light)
                            musicPlayer.skipNext()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    BlurView(style: .systemMaterial)
                        .overlay(
                            Divider()
                                .background(AppTheme.Colors.divider),
                            alignment: .top
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(song.title)")
        }
    }
}

private struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    let service = MusicPlayerService.shared
    return MiniPlayerView(onExpand: {})
        .environmentObject(service)
}

