//
//  StoriesV2Service.swift
//  MyChannel
//
//  Stories V2: enhanced stories with music, stickers, polls,
//  link stickers, story highlights, expiry management.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation

struct StoryV2: Codable, Identifiable {
    let id: String
    let creatorId: String
    let mediaURL: String
    let mediaType: String
    let duration: TimeInterval
    let musicTrack: String?
    let stickers: [StorySticker]
    let poll: StoryPoll?
    let linkURL: String?
    let createdAt: Date
    let expiresAt: Date
    let viewCount: Int
    let isHighlight: Bool
    struct StorySticker: Codable { let type: String; let x: Double; let y: Double; let text: String?; let imageURL: String? }
    struct StoryPoll: Codable { let question: String; let options: [String]; let votes: [Int] }
}

@MainActor
final class StoriesV2Service: ObservableObject {
    static let shared = StoriesV2Service()
    private init() {}
    @Published private(set) var stories: [StoryV2] = []
    @Published private(set) var highlights: [StoryV2] = []

    func fetchStories(creatorId: String) async throws {
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawS: Decodable { let id: String; let media: String; let type: String; let duration: Double?; let music: String?; let link: String?; let created: String?; let expires: String?; let views: Int?; let highlight: Bool }
        struct Raw: Decodable { let stories: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "fetch_stories_v2", creatorId: creatorId))
        stories = (r.stories ?? []).map {
            StoryV2(id: $0.id, creatorId: creatorId, mediaURL: $0.media, mediaType: $0.type, duration: $0.duration ?? 15,
                musicTrack: $0.music, stickers: [], poll: nil, linkURL: $0.link,
                createdAt: $0.created.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date(),
                expiresAt: $0.expires.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date().addingTimeInterval(86400),
                viewCount: $0.views ?? 0, isHighlight: $0.highlight)
        }
        highlights = stories.filter { $0.isHighlight }
    }

    func createStory(creatorId: String, mediaURL: String, mediaType: String, duration: TimeInterval = 15, music: String?, link: String?) async throws -> StoryV2 {
        struct Req: Encodable { let task: String; let creatorId: String; let media: String; let type: String; let duration: Double; let music: String?; let link: String? }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "create_story_v2", creatorId: creatorId, media: mediaURL, type: mediaType, duration: duration, music: music, link: link))
        let story = StoryV2(id: r.id, creatorId: creatorId, mediaURL: mediaURL, mediaType: mediaType, duration: duration,
            musicTrack: music, stickers: [], poll: nil, linkURL: link, createdAt: Date(),
            expiresAt: Date().addingTimeInterval(86400), viewCount: 0, isHighlight: false)
        stories.append(story); return story
    }

    func addHighlight(storyId: String) async throws {
        struct Req: Encodable { let task: String; let storyId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "add_highlight", storyId: storyId))
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            let old = stories[idx]
            stories[idx] = StoryV2(id: old.id, creatorId: old.creatorId, mediaURL: old.mediaURL, mediaType: old.mediaType,
                duration: old.duration, musicTrack: old.musicTrack, stickers: old.stickers, poll: old.poll, linkURL: old.linkURL,
                createdAt: old.createdAt, expiresAt: old.expiresAt, viewCount: old.viewCount, isHighlight: true)
            highlights.append(stories[idx])
        }
    }
}
