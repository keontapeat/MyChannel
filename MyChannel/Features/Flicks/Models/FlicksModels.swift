import SwiftUI
import AVKit
import AVFoundation
import FirebaseFirestore

struct NuclearFlick: Identifiable, Hashable {
    let id: String
    let videoURL: String
    let thumbnailURL: String
    let title: String
    let description: String
    let duration: TimeInterval
    let viewCount: Int
    let likeCount: Int
    let commentCount: Int
    let shareCount: Int
    let createdAt: Date
    let creator: FlickCreator
    let tags: [String]
    let musicTrack: FlickMusicTrack?
    let contentSource: Video.ContentSource
    let externalID: String?
    
    func toVideo() -> Video {
        Video(
            id: id,
            title: title,
            description: description,
            thumbnailURL: thumbnailURL,
            videoURL: videoURL,
            duration: duration,
            viewCount: viewCount,
            likeCount: likeCount,
            commentCount: commentCount,
            createdAt: createdAt,
            creator: User(
                username: creator.username,
                displayName: creator.displayName,
                email: "",
                profileImageURL: creator.profileImageURL,
                bannerImageURL: nil,
                bio: nil,
                subscriberCount: 0,
                videoCount: 0,
                isVerified: creator.isVerified,
                isCreator: true
            ),
            category: .shorts,
            tags: tags,
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: .portrait,
            isLiveStream: false,
            contentSource: contentSource,
            externalID: externalID,
            isVerified: false
        )
    }
}


struct FlickCreator: Identifiable, Hashable {
    let id: String
    let username: String
    let displayName: String
    let profileImageURL: String
    let isVerified: Bool
}


struct FlickMusicTrack: Identifiable, Hashable {
    var id: String { "\(title)|\(artist)|\(albumArt)" }
    let title: String
    let artist: String
    let albumArt: String
}

/// Shared layout constants for the Flicks player so the tap-catcher
/// (`UIKitFlicksGestureLayer` in FlicksView) and the scrubber it sits above
/// (in `NuclearVideoPlayerView`) always agree on where the interactive
/// scrubber strip is. Keeping this in one place avoids the two views
/// drifting apart and the scrubber becoming untappable again.
enum FlicksLayout {
    /// Height of the bottom strip reserved for the scrubber's drag gesture.
    /// The full-screen tap/double-tap/long-press catcher stops above this
    /// strip so scrubber touches aren't swallowed before they arrive.
    static let scrubberHitZoneHeight: CGFloat = 64
    /// Bottom padding applied to the scrubber itself so it floats above the
    /// home indicator / custom tab bar instead of being clipped behind it.
    static let scrubberBottomPadding: CGFloat = 40
}


