//
//  MusicVideosSection.swift
//  MyChannel
//
//  Music Videos Section - YouTube Music Style
//

import SwiftUI
import AVKit

// MARK: - Music Video Model

struct MusicVideo: Identifiable {
    let id: String
    let title: String
    let artist: String
    let thumbnailURL: String
    let videoURL: String
    let duration: TimeInterval
    let views: Int
    let isOfficial: Bool
    let releaseDate: Date
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedViews: String {
        if views >= 1_000_000 {
            return String(format: "%.1fM views", Double(views) / 1_000_000)
        } else if views >= 1_000 {
            return String(format: "%.1fK views", Double(views) / 1_000)
        }
        return "\(views) views"
    }
    
    // Sample featured artist videos
    static let featuredVideos: [MusicVideo] = [
        MusicVideo(
            id: "mv-1",
            title: "Coochie",
            artist: "YN Jay",
            thumbnailURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=pnQ0BXTfBjk",
            duration: 180,
            views: 15000000,
            isOfficial: true,
            releaseDate: Date()
        ),
        MusicVideo(
            id: "mv-2",
            title: "Ain't No Future In Yo Frontin",
            artist: "MC Breed",
            thumbnailURL: "https://i.ytimg.com/vi/3LfgZdZbv0I/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=3LfgZdZbv0I",
            duration: 240,
            views: 5000000,
            isOfficial: true,
            releaseDate: Date()
        ),
        MusicVideo(
            id: "mv-3",
            title: "What You Know About Flint",
            artist: "Dayton Family",
            thumbnailURL: "https://i.ytimg.com/vi/gPft7MPWq0k/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=gPft7MPWq0k",
            duration: 210,
            views: 2000000,
            isOfficial: true,
            releaseDate: Date()
        ),
        MusicVideo(
            id: "mv-4",
            title: "Flint Flow",
            artist: "Rio Da Yung OG",
            thumbnailURL: "https://i.ytimg.com/vi/6DZSh9vqlWc/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=6DZSh9vqlWc",
            duration: 195,
            views: 3500000,
            isOfficial: true,
            releaseDate: Date()
        ),
        MusicVideo(
            id: "mv-5",
            title: "Enbarassing",
            artist: "RMC Mike",
            thumbnailURL: "https://i.ytimg.com/vi/x_E1bq1sYdY/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=x_E1bq1sYdY",
            duration: 165,
            views: 8000000,
            isOfficial: true,
            releaseDate: Date()
        ),
        MusicVideo(
            id: "mv-6",
            title: "Vehicle City",
            artist: "Jon Connor",
            thumbnailURL: "https://i.ytimg.com/vi/0zq7cRFyCpU/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=0zq7cRFyCpU",
            duration: 220,
            views: 1200000,
            isOfficial: true,
            releaseDate: Date()
        ),
        MusicVideo(
            id: "mv-7",
            title: "Coochie World Tour",
            artist: "YN Jay",
            thumbnailURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=pnQ0BXTfBjk",
            duration: 190,
            views: 22000000,
            isOfficial: true,
            releaseDate: Date()
        ),
        MusicVideo(
            id: "mv-8",
            title: "Louie Season",
            artist: "Louie Ray",
            thumbnailURL: "https://i.ytimg.com/vi/oVP_aK7JzDw/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=oVP_aK7JzDw",
            duration: 205,
            views: 4500000,
            isOfficial: true,
            releaseDate: Date()
        ),
        MusicVideo(
            id: "mv-9",
            title: "KrispyLife",
            artist: "KrispyLife Kidd",
            thumbnailURL: "https://i.ytimg.com/vi/xv88_-pLqz8/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=xv88_-pLqz8",
            duration: 175,
            views: 3200000,
            isOfficial: true,
            releaseDate: Date()
        ),
        MusicVideo(
            id: "mv-10",
            title: "Street Vibes",
            artist: "Big Herk",
            thumbnailURL: "https://i.ytimg.com/vi/W8CiGjLlHDs/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=W8CiGjLlHDs",
            duration: 230,
            views: 900000,
            isOfficial: true,
            releaseDate: Date()
        )
    ]
}

// MARK: - Music Videos Section

struct MusicVideosSection: View {
    @State private var selectedVideo: MusicVideo?
    @State private var showVideoPlayer: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                    Text("Music Videos")
                        .font(.system(size: 22, weight: .bold))
                }
                
                Spacer()
                
                Button {
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Text("See All")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, 20)
            
            // Featured video (large)
            if let featured = MusicVideo.featuredVideos.first {
                FeaturedVideoCard(video: featured) {
                    selectedVideo = featured
                    showVideoPlayer = true
                    HapticManager.shared.impact(style: .medium)
                }
                .padding(.horizontal, 20)
            }
            
            // Video carousel
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(MusicVideo.featuredVideos.dropFirst()) { video in
                        MusicVideoCard(video: video) {
                            selectedVideo = video
                            showVideoPlayer = true
                            HapticManager.shared.impact(style: .medium)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let video = selectedVideo {
                MusicVideoPlayerView(video: video)
            }
        }
    }
}

// MARK: - Featured Video Card

struct FeaturedVideoCard: View {
    let video: MusicVideo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Play button overlay
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                        .offset(x: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if video.isOfficial {
                            Text("OFFICIAL")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.red))
                        }
                        
                        Text(video.formattedDuration)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.6)))
                    }
                    
                    Text(video.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(video.artist) • \(video.formattedViews)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(16)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Music Video Card

struct MusicVideoCard: View {
    let video: MusicVideo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    // Thumbnail
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                    }
                    .frame(width: 180, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Duration badge
                    Text(video.formattedDuration)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.7)))
                        .padding(6)
                    
                    // Play overlay
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                            .offset(x: 1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    Text(video.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(video.formattedViews)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(width: 180, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Music Video Player View

struct MusicVideoPlayerView: View {
    let video: MusicVideo
    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying: Bool = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text(video.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Menu {
                        Button {
                            // Share
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            // Add to playlist
                        } label: {
                            Label("Add to Playlist", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Video thumbnail (placeholder for actual video)
                ZStack {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                    }
                    
                    // Play/Pause overlay
                    Button {
                        isPlaying.toggle()
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
                
                Spacer()
                
                // Video info
                VStack(alignment: .leading, spacing: 12) {
                    Text(video.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack {
                        Text(video.artist)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(video.formattedViews)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Action buttons
                    HStack(spacing: 30) {
                        VideoActionButton(icon: "heart", label: "Like")
                        VideoActionButton(icon: "text.bubble", label: "Comment")
                        VideoActionButton(icon: "square.and.arrow.up", label: "Share")
                        VideoActionButton(icon: "plus", label: "Save")
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Video Action Button

struct VideoActionButton: View {
    let icon: String
    let label: String
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .light)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MusicVideosSection_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            MusicVideosSection()
        }
        .background(Color(.systemBackground))
    }
}
#endif

