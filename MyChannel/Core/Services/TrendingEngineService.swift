//
//  TrendingEngineService.swift
//  MyChannel
//
//  Phase 13: Trending feed engine wired to trending-ml Cloud Run.
//  Geo-aware, category-aware, real-time freshness decay.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct TrendingItem: Identifiable, Codable, Hashable {
    let id: String
    let videoId: String
    let score: Double
    let category: String?
    let region: String?
    let velocity: Double?      // views/hour growth rate
    let peakPrediction: Date?
}

struct TrendingFeed: Codable {
    let items: [TrendingItem]
    let updatedAt: Date
    let region: String
}

// MARK: - Service

@MainActor
final class TrendingEngineService: ObservableObject {
    static let shared = TrendingEngineService()
    private init() {}

    @Published var feed: TrendingFeed?
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    private var cache: [String: (feed: TrendingFeed, fetchedAt: Date)] = [:]
    private let cacheTTL: TimeInterval = 300 // 5 min

    /// Fetch trending videos, optionally filtered by category and region.
    func fetchTrending(
        category: String? = nil,
        region: String = "US",
        limit: Int = 30
    ) async throws -> TrendingFeed {
        let cacheKey = "\(region)_\(category ?? "all")"
        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            feed = cached.feed
            return cached.feed
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        struct Request: Encodable {
            let region: String
            let category: String?
            let limit: Int
            let freshness_weight: Double
        }

        struct RawItem: Decodable {
            let video_id: String?
            let score: Double?
            let category: String?
            let region: String?
            let velocity: Double?
            let peak_prediction: Double? // unix
        }

        struct Response: Decodable {
            let trending: [RawItem]?
        }

        let req = Request(region: region, category: category, limit: limit, freshness_weight: 0.4)

        do {
            let raw: Response = try await CloudRunAgentRouter.post(
                .trendForecaster,
                path: "/predict",
                body: req,
                timeout: 20
            )

            let items: [TrendingItem] = (raw.trending ?? []).compactMap { r in
                guard let vid = r.video_id, !vid.isEmpty else { return nil }
                return TrendingItem(
                    id: UUID().uuidString,
                    videoId: vid,
                    score: r.score ?? 0,
                    category: r.category,
                    region: r.region ?? region,
                    velocity: r.velocity,
                    peakPrediction: r.peak_prediction.map { Date(timeIntervalSince1970: $0) }
                )
            }

            let result = TrendingFeed(items: items, updatedAt: Date(), region: region)
            cache[cacheKey] = (result, Date())
            feed = result
            return result
        } catch {
            // Fallback: fetch from Firestore trending collection
            let fallback = await firestoreFallback(region: region, limit: limit)
            feed = fallback
            return fallback
        }
    }

    // MARK: - Firestore Fallback

    private func firestoreFallback(region: String, limit: Int) async -> TrendingFeed {
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await Firestore.firestore().collection("videos")
                .whereField("visibility", isEqualTo: "public")
                .order(by: "viewCount", descending: true)
                .limit(to: limit)
                .getDocuments()

            let items: [TrendingItem] = snap.documents.enumerated().map { idx, doc in
                TrendingItem(
                    id: doc.documentID,
                    videoId: doc.documentID,
                    score: Double(snap.documents.count - idx),
                    category: doc.data()["category"] as? String,
                    region: region,
                    velocity: nil,
                    peakPrediction: nil
                )
            }
            return TrendingFeed(items: items, updatedAt: Date(), region: region)
        } catch {
            return TrendingFeed(items: [], updatedAt: Date(), region: region)
        }
        #else
        return TrendingFeed(items: [], updatedAt: Date(), region: region)
        #endif
    }
}
