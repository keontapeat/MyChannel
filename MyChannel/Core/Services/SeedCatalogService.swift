//
//  SeedCatalogService.swift
//  MyChannel
//
//  Created by AI Assistant on 9/27/25.
//

import Foundation

@MainActor
final class SeedCatalogService {
    static let shared = SeedCatalogService()
    private init() {}

    // A larger lightweight catalog to keep feeds rich for new users
    var seedVideos: [Video] {
        guard AppConfig.Features.enableMockData else { return [] }
        var vids: [Video] = []

        func yt(_ id: String, title: String, channel: String, views: Int, category: VideoCategory) -> Video {
            Video(
                id: "yt_\(id)",
                title: title,
                description: "Seed video",
                thumbnailURL: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg",
                videoURL: "https://www.youtube.com/watch?v=\(id)",
                duration: Double.random(in: 90...1200),
                viewCount: views,
                likeCount: Int(Double(views) * 0.06),
                commentCount: Int(Double(views) * 0.01),
                creator: User(
                    username: channel.replacingOccurrences(of: " ", with: "_").lowercased(),
                    displayName: channel,
                    email: "seed@mychannel.com",
                    profileImageURL: "https://i.pravatar.cc/200?u=\(channel)",
                    isVerified: true,
                    isCreator: true
                ),
                category: category,
                tags: [category.displayName.lowercased(), "seed"],
                isPublic: true,
                quality: [.quality720p],
                aspectRatio: .landscape,
                isLiveStream: false,
                contentSource: .youtube,
                externalID: id,
                isVerified: true
            )
        }

        // Music
        let music: [(String,String,String,Int)] = [
            ("71GJrAY54Ew", "Rebound (Official)", "Scatz", 500_000),
            ("F98vGhQDrB8", "YouTube Music F98vGhQDrB8", "MyChannel Music", 340_000),
            ("d17K2Tl_Ljg", "Hibachi (Official)", "Scatz", 420_000)
        ]
        vids += music.map { yt($0.0, title: $0.1, channel: $0.2, views: $0.3, category: VideoCategory.music) }

        // Gaming COD
        let cod: [(String,String,Int)] = [
            ("x9v2Q8l2dY4", "Warzone 20 Kill Solo Win!", 2_400_000),
            ("b8r0Jk1aZsQ", "MW3 Ranked – Tactical Nuke!", 1_200_000),
            ("p7C1LkQ0vPY", "Best Kastov‑74u Class", 980_000)
        ]
        vids += cod.map { yt($0.0, title: $0.1, channel: "COD Highlights", views: $0.2, category: VideoCategory.gaming) }

        // Movies / trailers (free/open clips)
        let openClips: [(String,String,Int)] = [
            ("aqz-KE-bpKQ", "Big Buck Bunny (HD)", 1_500_000),
            ("eRsGyueVLvQ", "Sintel (Open Movie)", 980_000)
        ]
        vids += openClips.map { yt($0.0, title: $0.1, channel: "Open Movies", views: $0.2, category: VideoCategory.movies) }

        // Add a few generic lifestyle/education seeds using picsum and sample mp4s
        let generic: [Video] = [
            Video(
                title: "Nature Relaxation 4K",
                description: "Relaxing nature scenes",
                thumbnailURL: "https://picsum.photos/seed/nature_relax/400/600",
                videoURL: "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
                duration: 1800,
                viewCount: 420_000,
                likeCount: 24_000,
                commentCount: 1200,
                creator: User.sampleUsers[0],
                category: .lifestyle
            ),
            Video(
                title: "Productivity Tips 2025",
                description: "Boost your day with 10 quick tips",
                thumbnailURL: "https://picsum.photos/seed/productivity/400/600",
                videoURL: "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
                duration: 600,
                viewCount: 260_000,
                likeCount: 15_000,
                commentCount: 800,
                creator: User.sampleUsers[2],
                category: .education
            )
        ]
        vids += generic

        // Jim Rohn Motivation Channel – seeded catalog (YouTube public IDs as examples)
        let jim: [(String,String,Int)] = [
            ("wP1xG8DjYwk", "Jim Rohn – How to Set Goals", 820_000),
            ("vu3Rfx0bO0E", "Jim Rohn – The Art of Exceptional Living", 1_200_000),
            ("9FBs8m2iS_4", "Jim Rohn – Personal Development Seminar", 650_000)
        ]
        vids += jim.map { yt($0.0, title: $0.1, channel: "Jim Rohn Motivation", views: $0.2, category: VideoCategory.education) }

        // Deduplicate by id
        var seen = Set<String>()
        let dedup = vids.filter { v in
            if seen.contains(v.id) { return false }
            seen.insert(v.id)
            return true
        }
        return dedup
    }
}


