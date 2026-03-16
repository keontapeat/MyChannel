//
//  QueueView.swift
//  MyChannel
//
//  Playback queue sheet for MyChannel Music.
//

import SwiftUI

struct MusicQueueView: View {
    @EnvironmentObject private var musicPlayer: MusicPlayerService
    
    var body: some View {
        NavigationStack {
            List {
                if let current = musicPlayer.currentSong {
                    Section("Now Playing") {
                        queueRow(for: current, isCurrent: true)
                    }
                }
                
                if !musicPlayer.queue.isEmpty {
                    Section("Up Next") {
                        ForEach(musicPlayer.queue, id: \.id) { song in
                            queueRow(for: song, isCurrent: false)
                        }
                    }
                }
                
                if !musicPlayer.previousSongs.isEmpty {
                    Section("Previously Played") {
                        ForEach(musicPlayer.previousSongs.reversed(), id: \.id) { song in
                            queueRow(for: song, isCurrent: false)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Queue")
        }
    }
    
    private func queueRow(for song: Song, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                                placeholder: { Color.gray.opacity(0.2) }
                            )
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 15, weight: isCurrent ? .semibold : .regular))
                    .foregroundColor(isCurrent ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                if let primary = song.artistIds.first {
                    Text(primary)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(song.formattedDuration)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
            musicPlayer.play(song: song, inQueue: musicPlayer.queue)
        }
    }
}

#Preview {
    MusicQueueView()
        .environmentObject(MusicPlayerService.shared)
}

