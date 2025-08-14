import SwiftUI

struct ChannelDetailView: View {
    let name: String
    let avatarURL: String
    let subscribers: Int
    let totalViews: Int
    let videos: [Video]
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVideo: Video?
    @State private var isSubscribed = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Uploads")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        
                        LazyVStack(spacing: 14) {
                            ForEach(videos) { video in
                                ChannelVideoRow(video: video) {
                                    selectedVideo = video
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .fullScreenCover(item: $selectedVideo) { v in
                VideoDetailView(video: v)
            }
        }
        .preferredColorScheme(.light)
    }
    
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [AppTheme.Colors.primary.opacity(0.2), .white], startPoint: .top, endPoint: .bottom)
                .frame(height: 220)
                .overlay(
                    AppAsyncImage(url: URL(string: avatarURL)) { img in
                        img.resizable().scaledToFill().opacity(0.14).blur(radius: 20)
                    } placeholder: { Color.clear }
                )
            
            HStack(spacing: 16) {
                ProfileAvatarView(urlString: avatarURL, size: 72, showsRing: true)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 6)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.system(size: 24, weight: .bold))
                    Text("\(format(subscribers)) subscribers • \(format(totalViews)) views")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isSubscribed.toggle()
                        }
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Text(isSubscribed ? "Subscribed" : "Subscribe")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSubscribed ? AppTheme.Colors.textPrimary : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSubscribed ? .white : AppTheme.Colors.primary)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    private func format(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1_000) }
        return "\(n)"
    }
}

private struct ChannelVideoRow: View {
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
                    Text("\(video.formattedViewCount) views")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Channel Detail") {
    let user = User(username: "channel", displayName: "Top Channel", email: "c@mc.com", profileImageURL: "https://i.pravatar.cc/200?u=channel", isVerified: true, isCreator: true)
    let vids = Video.sampleVideos.map {
        Video(
            id: $0.id,
            title: $0.title,
            description: $0.description,
            thumbnailURL: $0.thumbnailURL,
            videoURL: $0.videoURL,
            duration: $0.duration,
            viewCount: $0.viewCount,
            likeCount: $0.likeCount,
            commentCount: $0.commentCount,
            creator: user,
            category: $0.category,
            tags: $0.tags,
            isPublic: true,
            quality: $0.quality,
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: $0.contentSource,
            externalID: $0.externalID,
            isVerified: $0.isVerified
        )
    }
    return ChannelDetailView(name: "Top Channel", avatarURL: user.profileImageURL ?? "", subscribers: 256000, totalViews: 12000000, videos: vids)
}