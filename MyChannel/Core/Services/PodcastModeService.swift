//
//  PodcastModeService.swift
//  MyChannel
//
//  Phase 68: Podcast mode.
//  Audio-only uploads, chapter-aware player, RSS export, searchable transcripts.
//  Uses the existing `AIChapterGeneratorService` + `podcast-ai` Cloud Run agent
//  for transcript segmentation, summaries, and RSS feed generation.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct PodcastModeEpisode: Codable, Identifiable, Equatable {
    let id: String
    let showId: String
    let creatorId: String
    let title: String
    let description: String?
    let audioURL: URL
    let coverImageURL: URL?
    let duration: TimeInterval
    let publishedAt: Date
    let chapters: [PodcastChapter]
    let transcriptURL: URL?     // SRT or WebVTT
    let explicit: Bool
    let season: Int?
    let episode: Int?
}

struct PodcastChapter: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let startSeconds: Double
    let endSeconds: Double
}

struct PodcastShow: Codable, Identifiable, Equatable {
    let id: String
    let creatorId: String
    let title: String
    let description: String
    let coverImageURL: URL?
    let category: String
    let language: String
    let explicit: Bool
    let rssURL: URL
}

@MainActor
final class PodcastModeService: ObservableObject {
    static let shared = PodcastModeService()
    private init() {}

    @Published private(set) var myShows: [PodcastShow] = []

    // MARK: - Show management

    func createShow(_ show: PodcastShow) async throws {
        guard AppConfig.Features.enablePodcastMode else { throw PodError.disabled }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("podcasts").document(show.id)
            .setData([
                "creatorId": show.creatorId,
                "title": show.title,
                "description": show.description,
                "coverImageURL": show.coverImageURL?.absoluteString as Any,
                "category": show.category,
                "language": show.language,
                "explicit": show.explicit,
                "rssURL": show.rssURL.absoluteString,
                "createdAt": FieldValue.serverTimestamp()
            ])
        myShows.append(show)
        #endif
    }

    // MARK: - Episode publish

    /// Register an audio-only upload as a podcast episode. The video pipeline
    /// already hosts audio in Storage; we just record it in a podcast-specific
    /// collection and kick off transcript + chapter generation server-side.
    func publishEpisode(_ ep: PodcastModeEpisode) async throws {
        guard AppConfig.Features.enablePodcastMode else { throw PodError.disabled }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("podcasts").document(ep.showId)
            .collection("episodes").document(ep.id)
            .setData([
                "creatorId": ep.creatorId,
                "title": ep.title,
                "description": ep.description as Any,
                "audioURL": ep.audioURL.absoluteString,
                "coverImageURL": ep.coverImageURL?.absoluteString as Any,
                "duration": ep.duration,
                "publishedAt": ep.publishedAt,
                "chapters": ep.chapters.map {
                    [
                        "id": $0.id,
                        "title": $0.title,
                        "startSeconds": $0.startSeconds,
                        "endSeconds": $0.endSeconds
                    ] as [String: Any]
                },
                "transcriptURL": ep.transcriptURL?.absoluteString as Any,
                "explicit": ep.explicit,
                "season": ep.season as Any,
                "episode": ep.episode as Any
            ])

        Task.detached {
            try? await self.kickoffPostProcess(showId: ep.showId, episodeId: ep.id, audioURL: ep.audioURL)
        }
        #endif
    }

    /// Trigger transcript + chapter gen + RSS rebuild server-side.
    private func kickoffPostProcess(showId: String, episodeId: String, audioURL: URL) async throws {
        struct Request: Encodable {
            let task: String
            let showId: String
            let episodeId: String
            let audioURL: String
        }
        _ = try await CloudRunAgentRouter.post(
            .podcastAI,
            path: "/predict",
            body: Request(
                task: "post_process",
                showId: showId,
                episodeId: episodeId,
                audioURL: audioURL.absoluteString
            )
        ) as _Ack
    }

    /// Fetch the canonical RSS feed URL for external podcast apps.
    func rssURL(for showId: String) -> URL? {
        URL(string: "https://podcasts.mychannel.live/\(showId).xml")
    }

    private struct _Ack: Decodable { let ok: Bool? }

    enum PodError: LocalizedError {
        case disabled
        var errorDescription: String? { "Podcast mode is disabled." }
    }
}
