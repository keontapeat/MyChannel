import SwiftUI

struct NewReleaseCard: View {
    let song: CatalogSong
    let index: Int
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                // Album art
                AppAsyncImage(url: URL(string: song.artworkUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 30))
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                // Rank badge
                Text("#\(index)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .padding(10)
                
                // NEW badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("NEW")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.yellow)
                            )
                            .padding(10)
                    }
                }
                .frame(width: 180, height: 180)
                
                // Play overlay on hover
                if isHovered {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.4))
                        .frame(width: 180, height: 180)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        )
                }
            }
            .onTapGesture {
                if let p = song.previewUrl, let u = URL(string: p) {
                    preview.play(url: u, trackId: String(song.id), title: song.title, artist: song.artist, artworkURL: URL(string: song.artworkUrl ?? ""))
                }
                HapticManager.shared.impact(style: .medium)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)
                
                Text(song.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct SpatialAudioCard: View {
    let song: CatalogSong
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                AppAsyncImage(url: URL(string: song.artworkUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemGray5))
                }
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                // Spatial Audio badge
                HStack(spacing: 4) {
                    Image(systemName: "airpodspro")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Spatial")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.cyan.opacity(0.9))
                )
                .padding(8)
            }
            .onTapGesture {
                if let p = song.previewUrl, let u = URL(string: p) {
                    preview.play(url: u, trackId: String(song.id), title: song.title, artist: song.artist, artworkURL: URL(string: song.artworkUrl ?? ""))
                }
                HapticManager.shared.impact(style: .medium)
            }
            
            Text(song.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            
            Text(song.artist)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct GenreCard: View {
    let genre: MusicGenre
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: genre.icon)
                        .font(.system(size: 22, weight: .semibold))
                    Text(genre.rawValue)
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
            }
            .foregroundColor(.white)
            .padding(16)
            .frame(height: 80)
            .background(genre.color)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct MusicPlaylistCard: View {
    let playlist: CuratedPlaylist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Playlist artwork
                ZStack {
                    LinearGradient(
                        colors: playlist.imageColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: playlist.icon)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: playlist.imageColors.first?.opacity(0.4) ?? .clear, radius: 10, x: 0, y: 5)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    Text(playlist.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct RadioStationCard: View {
    let station: RadioStation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    // Station icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [station.color, station.color.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 100, height: 100)
                    
                    // Live indicator
                    if station.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .offset(x: -5, y: 5)
                    }
                }
                
                Text(station.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                
                Text(station.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 100)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ChartCard: View {
    let chart: MusicChart
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Chart icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [chart.color, chart.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: chart.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 56, height: 56)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chart.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(chart.updateFrequency)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
            .frame(width: 260)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentlyPlayedCard: View {
    let song: CatalogSong
    @ObservedObject private var preview = AudioPreviewPlayer.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                AppAsyncImage(url: URL(string: song.artworkUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Play button overlay
                Button {
                    if let p = song.previewUrl, let u = URL(string: p) {
                        preview.play(url: u, trackId: String(song.id), title: song.title, artist: song.artist, artworkURL: URL(string: song.artworkUrl ?? ""))
                    }
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    Image(systemName: preview.currentTrackId == String(song.id) && preview.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                }
                .padding(6)
            }
            
            Text(song.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)
            
            Text(song.artist)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)
        }
    }
}

struct DiscoverArtistCircleCard: View {
    let artist: CatalogArtist
    
    /// Check if this is a featured friend for the glow effect
    private var isFeaturedFriend: Bool {
        FeaturedFriendArtist.friends.contains { $0.appleMusicId == artist.id }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            AppAsyncImage(url: URL(string: artist.artworkUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "music.mic")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isFeaturedFriend ? Color.red : Color(.systemGray4),
                        lineWidth: isFeaturedFriend ? 2 : 0.5
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            
            Text(artist.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 90)
        }
        .contentShape(Rectangle())
    }
}

struct DiscoverMixCard: View {
    let title: String
    let subtitle: String
    let colors: [Color]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 140)
        }
        .buttonStyle(ScaleButtonStyle())
        .contentShape(Rectangle())
    }
}

struct FriendActivityCard: View {
    let name: String
    let track: String
    let artist: String
    let isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(String(name.prefix(1)))
                            .font(.system(size: 24, weight: .semibold))
                    )
                
                if isPlaying {
                    Circle()
                        .fill(.green)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                }
            }
            
            VStack(spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                
                if isPlaying {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                        Text(track)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(track)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 80)
        .contentShape(Rectangle())
    }
}

struct ConcertPreviewCard: View {
    let artist: String
    let venue: String
    let date: String
    let imageURL: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    AppAsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5))
                    }
                    .frame(width: 200, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Date badge
                    Text(date)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .padding(10)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(artist)
                        .font(.system(size: 14, weight: .semibold))
                    Text(venue)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .frame(width: 200)
        }
        .buttonStyle(ScaleButtonStyle())
        .contentShape(Rectangle())
    }
}

struct BehindTheMusicCard: View {
    let title: String
    let artist: String
    let imageURL: String
    let duration: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    AppAsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5))
                    }
                    .frame(width: 180, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Play overlay
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                }
                
                // Duration badge
                Text(duration)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.7)))
                    .padding(8)
            }
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            
            Text(artist)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(width: 180)
        .contentShape(Rectangle())
    }
}

struct TopArtistSquareCard: View {
    let artist: CatalogArtist
    let rank: Int
    
    private var isFeaturedFriend: Bool {
        FeaturedFriendArtist.friends.contains { $0.appleMusicId == artist.id }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AppAsyncImage(url: URL(string: artist.artworkUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "music.mic")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isFeaturedFriend ? Color.red : Color(.systemGray4),
                            lineWidth: isFeaturedFriend ? 2 : 0.5
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                
                Text("#\(rank)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
                    .offset(x: 4, y: 4)
            }
            
            Text(artist.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 90)
        }
        .contentShape(Rectangle())
    }
}

struct TopChartSquareCard: View {
    let song: CatalogSong
    let rank: Int
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AppAsyncImage(url: URL(string: song.artworkUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                
                Text("#\(rank)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
                    .offset(x: 4, y: 4)
            }
            
            Text(song.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 90)
        }
        .contentShape(Rectangle())
    }
}

