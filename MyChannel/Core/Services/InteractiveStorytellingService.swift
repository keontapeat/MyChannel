//
//  InteractiveStorytellingService.swift
//  MyChannel
//
//  Phase 231: Interactive Storytelling Platform.
//  Branching episodes, persistent viewer state, creator narrative tooling.
//  Uses `super-ai-team` Cloud Run.
//

import Foundation

// MARK: - Models

struct StoryBranch: Codable, Identifiable {
    let id: String
    let episodeId: String
    let label: String
    let targetEpisodeId: String
    let condition: String?
    let order: Int
}

struct StoryEpisode: Codable, Identifiable {
    let id: String
    let storyId: String
    let title: String
    let videoId: String
    let branches: [StoryBranch]
    let isEnding: Bool
    let order: Int
}

struct ViewerStoryState: Codable, Identifiable {
    let id: String
    let userId: String
    let storyId: String
    let currentEpisodeId: String
    let visitedEpisodes: [String]
    let choices: [ChoiceRecord]
    let completedAt: Date?

    struct ChoiceRecord: Codable {
        let episodeId: String
        let branchId: String
        let chosenAt: Date
    }
}

// MARK: - Service

@MainActor
final class InteractiveStorytellingService: ObservableObject {
    static let shared = InteractiveStorytellingService()
    private init() {}

    @Published private(set) var episodes: [StoryEpisode] = []
    @Published private(set) var viewerState: ViewerStoryState?
    @Published var isCreating: Bool = false

    func fetchStory(storyId: String, userId: String) async throws {
        guard AppConfig.Features.enableInteractiveStorytelling else { return }
        struct Req: Encodable { let task: String; let storyId: String; let userId: String }
        struct RawBranch: Decodable { let id: String; let label: String; let target: String; let condition: String?; let order: Int }
        struct RawEp: Decodable { let id: String; let title: String; let video: String; let branches: [RawBranch]?; let ending: Bool; let order: Int }
        struct Raw: Decodable { let episodes: [RawEp]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "fetch_story", storyId: storyId, userId: userId)
        )
        episodes = (r.episodes ?? []).map {
            StoryEpisode(id: $0.id, storyId: storyId, title: $0.title, videoId: $0.video,
                         branches: ($0.branches ?? []).map { StoryBranch(id: $0.id, episodeId: $0.id, label: $0.label, targetEpisodeId: $0.target, condition: $0.condition, order: $0.order) },
                         isEnding: $0.ending, order: $0.order)
        }
    }

    func createEpisode(storyId: String, title: String, videoId: String, isEnding: Bool) async throws -> StoryEpisode {
        guard AppConfig.Features.enableInteractiveStorytelling else {
            return StoryEpisode(id: "", storyId: storyId, title: title, videoId: videoId, branches: [], isEnding: isEnding, order: 0)
        }
        isCreating = true
        defer { isCreating = false }
        struct Req: Encodable { let task: String; let storyId: String; let title: String; let videoId: String; let isEnding: Bool }
        struct Raw: Decodable { let id: String; let order: Int }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "create_episode", storyId: storyId, title: title, videoId: videoId, isEnding: isEnding)
        )
        let ep = StoryEpisode(id: r.id, storyId: storyId, title: title, videoId: videoId, branches: [], isEnding: isEnding, order: r.order)
        episodes.append(ep)
        return ep
    }

    func chooseBranch(userId: String, storyId: String, episodeId: String, branchId: String) async throws {
        guard AppConfig.Features.enableInteractiveStorytelling else { return }
        struct Req: Encodable { let task: String; let userId: String; let storyId: String; let episodeId: String; let branchId: String }
        struct Raw: Decodable { let next_episode: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "choose_branch", userId: userId, storyId: storyId, episodeId: episodeId, branchId: branchId)
        )
        if let next = r.next_episode {
            var visited = viewerState?.visitedEpisodes ?? []
            visited.append(episodeId)
            viewerState = ViewerStoryState(id: viewerState?.id ?? UUID().uuidString, userId: userId, storyId: storyId,
                                            currentEpisodeId: next, visitedEpisodes: visited,
                                            choices: (viewerState?.choices ?? []) + [ViewerStoryState.ChoiceRecord(episodeId: episodeId, branchId: branchId, chosenAt: Date())],
                                            completedAt: nil)
        }
    }
}
