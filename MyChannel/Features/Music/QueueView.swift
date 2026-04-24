//
//  QueueView.swift
//  MyChannel
//
//  Playback queue sheet for MyChannel Music.
//

import SwiftUI

struct MusicQueueView: View {
    @EnvironmentObject private var musicPlayer: MusicPlayerService
    @State private var editingMode: Bool = false
    
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
                        ForEach(musicPlayer.queue.indices, id: \.self) { index in
                            queueRow(for: musicPlayer.queue[index], isCurrent: false, index: index)
                        }
                        .onMove(perform: moveQueue)
                        .onDelete(perform: removeFromQueue)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            withAnimation {
                                editingMode.toggle()
                            }
                        } label: {
                            Text(editingMode ? "Done" : "Edit")
                                .font(.system(size: 16, weight: .medium))
                        }
                        
                        if !musicPlayer.queue.isEmpty {
                            Button {
                                withAnimation(.spring()) {
                                    musicPlayer.clearQueue()
                                    HapticManager.shared.impact(style: .medium)
                                }
                            } label: {
                                Text("Clear")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(editingMode ? .active : .inactive))
        }
    }
    
    private func moveQueue(from source: IndexSet, to destination: Int) {
        musicPlayer.moveQueue(from: source, to: destination)
        HapticManager.shared.impact(style: .light)
    }
    
    private func removeFromQueue(at offsets: IndexSet) {
        musicPlayer.removeFromQueue(at: offsets)
        HapticManager.shared.impact(style: .medium)
    }
    
    private func clearQueue() {
        musicPlayer.clearQueue()
        HapticManager.shared.notification(type: .warning)
    }
    
    private func queueRow(for song: Song, isCurrent: Bool, index: Int? = nil) -> some View {
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

