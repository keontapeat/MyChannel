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

    // MARK: - Free catalog (always available so new users have content instantly)
    private static let freeCatalogStorage: [Video] = SeedCatalogService.buildFreeCatalog()

    /// 50+ free-to-watch videos. Always returned (no mock flag). New users see these instantly.
    var freeCatalogVideos: [Video] {
        Self.freeCatalogStorage
    }

    // A larger lightweight catalog to keep feeds rich for new users (when mock is on)
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

        // Music – hella variety
        let music: [(String,String,String,Int)] = [
            ("71GJrAY54Ew", "Rebound (Official)", "Scatz", 500_000),
            ("F98vGhQDrB8", "YouTube Music", "MyChannel Music", 340_000),
            ("d17K2Tl_Ljg", "Hibachi (Official)", "Scatz", 420_000),
            ("dQw4w9WgXcQ", "Classic Vibes", "Music Channel", 1_200_000),
            ("9bZkp7q19f0", "Mega Hit", "Pop Hits", 890_000),
            ("kJQP7kiw5Fk", "Global Hit", "World Music", 2_100_000)
        ]
        vids += music.map { yt($0.0, title: $0.1, channel: $0.2, views: $0.3, category: VideoCategory.music) }

        // Gaming – COD, highlights, playthroughs
        let cod: [(String,String,Int)] = [
            ("x9v2Q8l2dY4", "Warzone 20 Kill Solo Win!", 2_400_000),
            ("b8r0Jk1aZsQ", "MW3 Ranked – Tactical Nuke!", 1_200_000),
            ("p7C1LkQ0vPY", "Best Kastov‑74u Class", 980_000),
            ("2vjPBrBU-TM", "Epic Clutch Moments", 1_500_000),
            ("rYEDA3JcQqw", "Pro Tips & Loadouts", 760_000)
        ]
        vids += cod.map { yt($0.0, title: $0.1, channel: "COD Highlights", views: $0.2, category: VideoCategory.gaming) }

        // Movies / trailers (free/open clips)
        let openClips: [(String,String,Int)] = [
            ("aqz-KE-bpKQ", "Big Buck Bunny (HD)", 1_500_000),
            ("eRsGyueVLvQ", "Sintel (Open Movie)", 980_000),
            ("YaG5b1YIv_g", "Tears of Steel", 1_100_000),
            ("YD4I6YF_0PM", "Elephants Dream", 890_000)
        ]
        vids += openClips.map { yt($0.0, title: $0.1, channel: "Open Movies", views: $0.2, category: VideoCategory.movies) }

        // Generic lifestyle / education / entertainment – lots of variety
        let generic: [Video] = [
            Video(title: "Nature Relaxation 4K", description: "Relaxing nature scenes", thumbnailURL: "https://picsum.photos/seed/nature_relax/400/600", videoURL: "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4", duration: 1800, viewCount: 420_000, likeCount: 24_000, commentCount: 1200, creator: User.sampleUsers[0], category: .lifestyle),
            Video(title: "Productivity Tips 2025", description: "Boost your day with 10 quick tips", thumbnailURL: "https://picsum.photos/seed/productivity/400/600", videoURL: "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4", duration: 600, viewCount: 260_000, likeCount: 15_000, commentCount: 800, creator: User.sampleUsers[2], category: .education),
            Video(title: "Quick Breakfast Ideas", description: "5 easy morning meals", thumbnailURL: "https://picsum.photos/seed/breakfast/400/600", videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", duration: 480, viewCount: 180_000, likeCount: 12_000, commentCount: 450, creator: User.sampleUsers[1], category: .cooking),
            Video(title: "10 Min Stretch Routine", description: "Wake up your body", thumbnailURL: "https://picsum.photos/seed/stretch/400/600", videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4", duration: 600, viewCount: 320_000, likeCount: 18_000, commentCount: 620, creator: User.sampleUsers[0], category: .fitness),
            Video(title: "Travel on a Budget", description: "See the world for less", thumbnailURL: "https://picsum.photos/seed/budget/400/600", videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4", duration: 900, viewCount: 410_000, likeCount: 22_000, commentCount: 890, creator: User.sampleUsers[3], category: .travel),
            Video(title: "Comedy Skits Vol 1", description: "Laugh out loud", thumbnailURL: "https://picsum.photos/seed/comedy1/400/600", videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4", duration: 420, viewCount: 890_000, likeCount: 45_000, commentCount: 2100, creator: User.sampleUsers[4], category: .entertainment),
            Video(title: "Learn to Draw", description: "Basics in 20 minutes", thumbnailURL: "https://picsum.photos/seed/draw/400/600", videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4", duration: 1200, viewCount: 156_000, likeCount: 9_200, commentCount: 380, creator: User.sampleUsers[2], category: .art),
            Video(title: "Coding for Beginners", description: "Your first app", thumbnailURL: "https://picsum.photos/seed/code1/400/600", videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4", duration: 1800, viewCount: 278_000, likeCount: 16_000, commentCount: 720, creator: User.sampleUsers[0], category: .technology)
        ]
        vids += generic

        // Jim Rohn Motivation – education / self-improvement
        let jim: [(String,String,Int)] = [
            ("wP1xG8DjYwk", "Jim Rohn – How to Set Goals", 820_000),
            ("vu3Rfx0bO0E", "Jim Rohn – The Art of Exceptional Living", 1_200_000),
            ("9FBs8m2iS_4", "Jim Rohn – Personal Development Seminar", 650_000),
            ("8CrOL-ydFMI", "Best Motivational Speech", 2_800_000),
            ("Lp7E9z5fTEs", "Success Habits", 1_100_000)
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

    // MARK: - Free catalog (always available for new users)
    private static func buildFreeCatalog() -> [Video] {
        let base = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/"
        let storage = "https://storage.googleapis.com/gtv-videos-bucket/sample/"
        let urls = [
            "\(base)BigBuckBunny.mp4",
            "\(base)Sintel.mp4",
            "\(base)ElephantsDream.mp4",
            "\(base)TearsOfSteel.mp4",
            "\(base)ForBiggerJoyrides.mp4",
            "\(base)ForBiggerEscapes.mp4",
            "\(storage)ForBiggerFun.mp4",
            "\(storage)WeAreGoingOnBullrun.mp4",
            "\(base)SubaruOutbackOnStreetAndDirt.mp4",
            "\(base)VolkswagenGTIReview.mp4"
        ]
        let creator = User.defaultUser
        let entries: [(String, String, String, Int, Int, VideoCategory)] = [
            ("free_1", "Sunset Timelapse 4K", "seed/sun1", 320_000, 890, .lifestyle),
            ("free_2", "Quick Pasta Recipe", "seed/pasta", 180_000, 420, .cooking),
            ("free_3", "Tech Review 2025", "seed/tech1", 290_000, 720, .technology),
            ("free_4", "Funny Pet Moments", "seed/pets", 510_000, 1200, .entertainment),
            ("free_5", "Tokyo Travel Vlog", "seed/tokyo", 220_000, 540, .travel),
            ("free_6", "Beat Making Tutorial", "seed/beats", 95_000, 280, .music),
            ("free_7", "15 Min Home Workout", "seed/workout", 410_000, 980, .fitness),
            ("free_8", "Digital Art Tips", "seed/art1", 67_000, 190, .art),
            ("free_9", "City Night Drive", "seed/night", 198_000, 520, .entertainment),
            ("free_10", "Lofi Study Beats", "seed/lofi", 620_000, 2100, .music),
            ("free_11", "Drone Cinematography", "seed/drone", 245_000, 610, .travel),
            ("free_12", "Street Food Tacos", "seed/tacos", 88_000, 240, .cooking),
            ("free_13", "HIIT Cardio Session", "seed/hiit", 112_000, 340, .fitness),
            ("free_14", "SwiftUI Pro Tips", "seed/swift", 78_000, 220, .technology),
            ("free_15", "Big Buck Bunny – Short", "seed/bunny", 1_100_000, 8500, .movies),
            ("free_16", "Sintel – Open Movie", "seed/sintel", 890_000, 4200, .movies),
            ("free_17", "Nature Sounds Relax", "seed/nature", 380_000, 1100, .lifestyle),
            ("free_18", "Productivity Hacks", "seed/prod", 156_000, 450, .education),
            ("free_19", "Morning Routine", "seed/morning", 275_000, 780, .lifestyle),
            ("free_20", "Gaming Highlights", "seed/game1", 445_000, 1300, .gaming),
            ("free_21", "Recipe: Easy Curry", "seed/curry", 92_000, 260, .cooking),
            ("free_22", "Yoga for Beginners", "seed/yoga", 168_000, 490, .fitness),
            ("free_23", "Photography Basics", "seed/photo", 134_000, 380, .art),
            ("free_24", "Road Trip USA", "seed/road", 201_000, 590, .travel),
            ("free_25", "Piano Cover", "seed/piano", 98_000, 310, .music),
            ("free_26", "Comedy Skit", "seed/comedy", 567_000, 1800, .entertainment),
            ("free_27", "Coding Interview Tips", "seed/code", 123_000, 360, .education),
            ("free_28", "Car Review", "seed/car", 312_000, 920, .entertainment),
            ("free_29", "Meditation Guide", "seed/meditate", 189_000, 540, .lifestyle),
            ("free_30", "Indie Game Playthrough", "seed/indie", 76_000, 210, .gaming),
            ("free_31", "Vegan Breakfast", "seed/vegan", 54_000, 165, .cooking),
            ("free_32", "Stretching Routine", "seed/stretch", 87_000, 250, .fitness),
            ("free_33", "Watercolor Tutorial", "seed/water", 43_000, 128, .art),
            ("free_34", "Island Paradise", "seed/island", 278_000, 820, .travel),
            ("free_35", "Acoustic Session", "seed/acoustic", 65_000, 195, .music),
            ("free_36", "Prank Compilation", "seed/prank", 892_000, 3100, .entertainment),
            ("free_37", "Learn Spanish Fast", "seed/spanish", 145_000, 420, .education),
            ("free_38", "Adventure Off-Road", "seed/offroad", 234_000, 690, .entertainment),
            ("free_39", "Sleep Sounds", "seed/sleep", 445_000, 1350, .lifestyle),
            ("free_40", "RPG Gameplay", "seed/rpg", 167_000, 480, .gaming),
            ("free_41", "One-Pot Meals", "seed/onepot", 72_000, 210, .cooking),
            ("free_42", "Core Workout", "seed/core", 198_000, 580, .fitness),
            ("free_43", "Sketch to Final", "seed/sketch", 56_000, 170, .art),
            ("free_44", "European Cities", "seed/europe", 334_000, 990, .travel),
            ("free_45", "Chill Beats Mix", "seed/chill", 412_000, 1250, .music),
            ("free_46", "Fail Compilation", "seed/fail", 1_020_000, 4100, .entertainment),
            ("free_47", "Math Made Simple", "seed/math", 89_000, 265, .education),
            ("free_48", "Elephants Dream Clip", "seed/elephants", 765_000, 3200, .movies),
            ("free_49", "Tears of Steel Short", "seed/tears", 654_000, 2800, .movies),
            ("free_50", "Motivation Speech", "seed/motivation", 523_000, 1900, .education)
        ]
        return entries.enumerated().map { index, e in
            let url = urls[index % urls.count]
            let (id, title, seed, viewCount, likeCount, category) = (e.0, e.1, e.2, e.3, e.4, e.5)
            return Video(
                id: id,
                title: title,
                description: "Free to watch on MyChannel",
                thumbnailURL: "https://picsum.photos/seed/\(seed)/400/600",
                videoURL: url,
                duration: Double([90, 120, 180, 240, 300, 420, 600][index % 7]),
                viewCount: viewCount,
                likeCount: likeCount,
                commentCount: max(1, likeCount / 20),
                creator: creator,
                category: category,
                tags: ["free", "watch", category.displayName.lowercased()],
                isPublic: true
            )
        }
    }
}


