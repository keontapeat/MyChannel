//
//  ProfileCommunityHubService.swift
//  MyChannel
//
//  Phase 253: Profile Community Hub.
//  Community posts, polls, announcements, pinned messages,
//  member-only discussions, moderator tools.
//  Uses `super-ai-team` + `mychannel-content` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileCommunityHubPost: Codable, Identifiable {
    let id: String
    let creatorId: String
    let type: PostType
    let content: String
    let mediaURLs: [String]
    let likes: Int
    let replies: Int
    let isPinned: Bool
    let isMembersOnly: Bool
    let createdAt: Date

    enum PostType: String, Codable { case text, image, poll, announcement, link }
}

struct CommunityPoll: Codable, Identifiable {
    let id: String
    let postId: String
    let question: String
    let options: [PollOption]
    let totalVotes: Int
    let endsAt: Date?

    struct PollOption: Codable {
        let label: String
        let votes: Int
        let pct: Double
    }
}

struct ModeratorAction: Codable, Identifiable {
    let id: String
    let moderatorId: String
    let targetPostId: String
    let action: String
    let reason: String
    let timestamp: Date
}

// MARK: - Service

@MainActor
final class ProfileCommunityHubService: ObservableObject {
    static let shared = ProfileCommunityHubService()
    private init() {}

    @Published private(set) var posts: [ProfileCommunityHubPost] = []
    @Published private(set) var polls: [CommunityPoll] = []

    func fetchPosts(creatorId: String, limit: Int = 20) async throws {
        guard AppConfig.Features.enableProfileCommunityHub else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let limit: Int }
        struct RawP: Decodable { let id: String; let type: String; let content: String; let media: [String]?; let likes: Int; let replies: Int; let pinned: Bool; let members_only: Bool; let created: String? }
        struct Raw: Decodable { let posts: [RawP]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "fetch_community_posts", creatorId: creatorId, limit: limit)
        )
        posts = (r.posts ?? []).map {
            ProfileCommunityHubPost(id: $0.id, creatorId: creatorId, type: .init(rawValue: $0.type) ?? .text,
                                    content: $0.content, mediaURLs: $0.media ?? [], likes: $0.likes, replies: $0.replies,
                                    isPinned: $0.pinned, isMembersOnly: $0.members_only,
                                    createdAt: $0.created.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date())
        }
    }

    func createPost(creatorId: String, type: ProfileCommunityHubPost.PostType, content: String, membersOnly: Bool) async throws -> ProfileCommunityHubPost {
        guard AppConfig.Features.enableProfileCommunityHub else {
            return ProfileCommunityHubPost(id: "", creatorId: creatorId, type: type, content: content,
                                           mediaURLs: [], likes: 0, replies: 0, isPinned: false, isMembersOnly: membersOnly, createdAt: Date())
        }
        struct Req: Encodable { let task: String; let creatorId: String; let type: String; let content: String; let members_only: Bool }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "create_community_post", creatorId: creatorId, type: type.rawValue, content: content, members_only: membersOnly)
        )
        let post = ProfileCommunityHubPost(id: r.id, creatorId: creatorId, type: type, content: content,
                                           mediaURLs: [], likes: 0, replies: 0, isPinned: false, isMembersOnly: membersOnly, createdAt: Date())
        posts.insert(post, at: 0)
        return post
    }

    func createPoll(creatorId: String, question: String, options: [String], duration: TimeInterval = 86400) async throws -> CommunityPoll {
        guard AppConfig.Features.enableProfileCommunityHub else {
            return CommunityPoll(id: "", postId: "", question: question,
                                   options: options.map { CommunityPoll.PollOption(label: $0, votes: 0, pct: 0) },
                                   totalVotes: 0, endsAt: Date().addingTimeInterval(duration))
        }
        struct Req: Encodable { let task: String; let creatorId: String; let question: String; let options: [String]; let duration: Double }
        struct RawOpt: Decodable { let label: String; let votes: Int; let pct: Double }
        struct Raw: Decodable { let id: String; let post_id: String; let options: [RawOpt]?; let total: Int?; let ends: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "create_community_poll", creatorId: creatorId, question: question, options: options, duration: duration)
        )
        let poll = CommunityPoll(id: r.id, postId: r.post_id, question: question,
                                   options: (r.options ?? []).map { CommunityPoll.PollOption(label: $0.label, votes: $0.votes, pct: $0.pct) },
                                   totalVotes: r.total ?? 0,
                                   endsAt: r.ends.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date().addingTimeInterval(duration))
        polls.append(poll)
        return poll
    }

    func moderatePost(moderatorId: String, postId: String, action: String, reason: String) async throws {
        guard AppConfig.Features.enableProfileCommunityHub else { return }
        struct Req: Encodable { let task: String; let moderatorId: String; let postId: String; let action: String; let reason: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "moderate_post", moderatorId: moderatorId, postId: postId, action: action, reason: reason)
        )
        if action == "remove" { posts.removeAll { $0.id == postId } }
    }
}
