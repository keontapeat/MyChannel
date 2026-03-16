//
//  AlbumDetailView.swift
//  MyChannel
//
//  Immersive album page for MyChannel Music.
//

import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    let tracks: [Song]
    
    @EnvironmentObject private var musicPlayer: MusicPlayerService
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                controlsRow
                trackList
                creditsSection
            }
            .padding(.bottom, 40)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var header: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.Colors.surface)
                .frame(width: 220, height: 220)
                .overlay(
                    Group {
                        if let url = album.artworkURL {
                            AppAsyncImage(
                                url: url,
                                content: { image in
                                    image.resizable().scaledToFill()
                                },
                                placeholder: { Color.gray.opacity(0.2) }
                            )
                        } else {
                            Image(systemName: "square.stack")
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                )
                .shadow(radius: 18)
            
            VStack(spacing: 4) {
                Text(album.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(album.type == .album ? "Album" : (album.type == .ep ? "EP" : "Single"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                if let date = album.releaseDate {
                    let year = Calendar.current.component(.year, from: date)
                    let genre = album.genres.first ?? "Music"
                    Text("\(year) • \(genre)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                if let label = album.label {
                    Text(label)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 24)
    }
    
    private var controlsRow: some View {
        HStack(spacing: 20) {
            Button {
                HapticManager.shared.impact(style: .medium)
                if let first = tracks.first {
                    musicPlayer.play(song: first, inQueue: tracks)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Play")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(Capsule())
            }
            
            Button {
                HapticManager.shared.impact(style: .light)
                if !tracks.isEmpty {
                    let shuffled = tracks.shuffled()
                    musicPlayer.play(song: shuffled[0], inQueue: shuffled)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                    Text("Shuffle")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                )
            }
        }
        .padding(.top, 8)
    }
    
    private var trackList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, song in
                Button {
                    HapticManager.shared.impact(style: .light)
                    musicPlayer.play(song: song, inQueue: tracks)
                } label: {
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(width: 22)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                if song.isExplicit {
                                    Text("E")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.gray)
                                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                }
                                
                                if let primary = song.artistIds.first {
                                    Text(primary)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Text(song.formattedDuration)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Credits")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Songwriters, producers, and contributors coming soon. This section will pull detailed metadata from your backend.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
}

