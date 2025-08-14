import SwiftUI

struct VideoLiveThumbnailView: View {
    let video: Video
    let cornerRadius: CGFloat

    init(video: Video, cornerRadius: CGFloat = 12) {
        self.video = video
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            if video.contentSource == .youtube, let vid = video.externalID {
                YouTubePlayerView(
                    videoID: vid,
                    autoplay: true,
                    startTime: 0,
                    muted: true,
                    showControls: false
                )
                .background(Color.black)
            } else {
                LiveChannelThumbnailView(
                    streamURL: video.videoURL,
                    posterURL: video.thumbnailURL,
                    fallbackStreamURL: nil
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview("VideoLiveThumbnailView • YouTube") {
    let friend = User.sampleUsers.first ?? User.defaultUser
    let v = Video(
        id: "friend_video_yt_71GJrAY54Ew",
        title: "Friend Track • LIVE Preview",
        description: "Autoplaying preview",
        thumbnailURL: "https://i.ytimg.com/vi/71GJrAY54Ew/hqdefault.jpg",
        videoURL: "https://www.youtube.com/watch?v=71GJrAY54Ew",
        duration: 180,
        viewCount: 1_200_000,
        likeCount: 85_000,
        creator: friend,
        category: .music,
        contentSource: .youtube,
        externalID: "71GJrAY54Ew",
        isVerified: true
    )
    return VideoLiveThumbnailView(video: v)
        .frame(width: 180, height: 101)
        .background(Color(.systemGray6))
        .preferredColorScheme(.light)
}