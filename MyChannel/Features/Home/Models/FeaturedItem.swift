import Foundation

enum FeaturedItem: Identifiable, Equatable {
    case video(Video)
    case friend(AssetStory)

    var id: String {
        switch self {
        case .video(let v): return "video-\(v.id)"
        case .friend(let s): return "friend-\(s.id)"
        }
    }

    static func == (lhs: FeaturedItem, rhs: FeaturedItem) -> Bool {
        lhs.id == rhs.id
    }
}
