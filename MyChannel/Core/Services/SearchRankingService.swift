//
//  SearchRankingService.swift
//  MyChannel
//
//  Phase 12: Wire search-ranking-ai Cloud Run for ML-powered search result reranking.
//

import Foundation

struct SearchRankingResult: Codable, Identifiable {
    let id: String     // videoId
    let score: Double
    let relevanceFactors: [String]?

    init(id: String, score: Double, relevanceFactors: [String]? = nil) {
        self.id = id; self.score = score; self.relevanceFactors = relevanceFactors
    }
}

@MainActor
final class SearchRankingService: ObservableObject {
    static let shared = SearchRankingService()
    private init() {}

    @Published var isRanking: Bool = false

    /// Rerank a set of video IDs by ML relevance to the query.
    func rerank(
        query: String,
        videoIds: [String],
        userId: String?,
        limit: Int = 30
    ) async -> [SearchRankingResult] {
        guard !videoIds.isEmpty else { return [] }
        isRanking = true
        defer { isRanking = false }

        struct Request: Encodable {
            let query: String
            let video_ids: [String]
            let user_id: String?
            let limit: Int
        }
        struct RawResult: Decodable {
            let video_id: String?
            let score: Double?
            let factors: [String]?
        }
        struct Response: Decodable {
            let results: [RawResult]?
        }

        let req = Request(query: query, video_ids: Array(videoIds.prefix(100)),
                          user_id: userId, limit: limit)

        do {
            let raw: Response = try await CloudRunAgentRouter.post(
                .searchRanking, path: "/predict", body: req, timeout: 15
            )
            return (raw.results ?? []).compactMap { r in
                guard let vid = r.video_id else { return nil }
                return SearchRankingResult(id: vid, score: r.score ?? 0, relevanceFactors: r.factors)
            }
        } catch {
            // Fallback: return original order with uniform scores
            return videoIds.enumerated().map { idx, vid in
                SearchRankingResult(id: vid, score: Double(videoIds.count - idx) / Double(videoIds.count))
            }
        }
    }

    /// Convenience: rerank Video objects in-place
    func rerankVideos(query: String, videos: [Video], userId: String?) async -> [Video] {
        let ranked = await rerank(query: query, videoIds: videos.map(\.id), userId: userId)
        let order = Dictionary(ranked.map { ($0.id, $0.score) }, uniquingKeysWith: { a, _ in a })
        return videos.sorted { (order[$0.id] ?? 0) > (order[$1.id] ?? 0) }
    }
}
