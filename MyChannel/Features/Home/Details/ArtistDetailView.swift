import SwiftUI

struct ArtistDetailView: View {
    let name: String
    let avatarURL: String
    let videos: [Video]
    let totalViews: Int
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVideo: Video?
    @State private var isFollowing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader(title: "Top Videos")
                        
                        LazyVStack(spacing: 14) {
                            ForEach(videos) { video in
                                ArtistVideoRow(video: video) {
                                    selectedVideo = video
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $selectedVideo) { v in
                VideoDetailView(video: v)
            }
        }
        .preferredColorScheme(.light)
    }
    
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    AppTheme.Colors.primary.opacity(0.22),
                    AppTheme.Colors.secondary.opacity(0.22),
                    AppTheme.Colors.background
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 240)
            .overlay(
                AppAsyncImage(url: URL(string: avatarURL)) { img in
                    img
                        .resizable()
                        .scaledToFill()
                        .opacity(0.16)
                        .blur(radius: 20)
                        .clipped()
                } placeholder: {
                    Color.clear
                }
            )
            
            HStack(alignment: .center, spacing: 16) {
                ProfileAvatarView(urlString: avatarURL, size: 84, showsRing: true)
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 3))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("\(videos.count) videos • \(format(totalViews)) total views")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isFollowing.toggle()
                            }
                            HapticManager.shared.impact(style: .light)
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isFollowing ? AppTheme.Colors.textPrimary : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(isFollowing ? .white : AppTheme.Colors.primary)
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            share()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .padding(10)
                                .background(AppTheme.Colors.background, in: Circle())
                                .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(AppTheme.Colors.textPrimary)
            Spacer()
        }
    }
    
    private func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }
    
    private func share() {
        let text = "Listen to \(name) on MyChannel"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
    }
}

private struct ArtistVideoRow: View {
    let video: Video
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                MultiSourceAsyncImage(urls: video.posterCandidates) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6))
                }
                .frame(width: 140, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    Text(video.formattedDuration)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .padding(6),
                    alignment: .bottomTrailing
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    Text("\(video.formattedViewCount) views • \(video.creator.displayName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Artist Detail") {
    let friendUser = User(username: "artist", displayName: "Top Artist", email: "artist@mc.com", profileImageURL: "https://i.pravatar.cc/200?u=artist", isVerified: true, isCreator: true)
    let vids = Array(Video.sampleVideos.prefix(6)).map {
        Video(
            id: $0.id,
            title: $0.title,
            description: $0.description,
            thumbnailURL: $0.thumbnailURL,
            videoURL: $0.videoURL,
            duration: $0.duration,
            viewCount: Int.random(in: 30_000...1_500_000),
            likeCount: $0.likeCount,
            commentCount: $0.commentCount,
            creator: friendUser,
            category: .music,
            tags: $0.tags,
            isPublic: true,
            quality: $0.quality,
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .youtube,
            externalID: $0.externalID,
            isVerified: true
        )
    }
    return ArtistDetailView(name: "Top Artist", avatarURL: friendUser.profileImageURL ?? "", videos: vids, totalViews: vids.reduce(0) { $0 + $1.viewCount })
}