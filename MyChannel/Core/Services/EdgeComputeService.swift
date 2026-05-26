//
//  EdgeComputeService.swift
//  MyChannel
//
//  Phase 63: Edge compute rollout.
//  Routes feed personalization + trending reads through Cloudflare Workers
//  (edge caches) for <50ms TTFB. Falls back to the origin Cloud Run service
//  transparently on any error.
//

import Foundation

struct EdgeComputeFeedItem: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let title: String
    let thumbnailURL: URL?
    let creatorId: String
    let score: Double
}

struct EdgeFeedPage: Codable {
    let items: [EdgeComputeFeedItem]
    let nextCursor: String?
    let edgeRegion: String?
    let cacheStatus: String?     // "HIT", "MISS", "EXPIRED", etc.
}

@MainActor
final class EdgeComputeService: ObservableObject {
    static let shared = EdgeComputeService()
    private init() {}

    /// Worker endpoints. Update to the real deployed hostnames when Phase 63 ships.
    struct Endpoint {
        static let feed     = "https://edge.mychannel.live/feed"
        static let trending = "https://edge.mychannel.live/trending"
        static let home     = "https://edge.mychannel.live/home"
    }

    @Published private(set) var lastRegion: String?
    @Published private(set) var lastCacheStatus: String?

    // MARK: - Feed

    func edgeFeed(uid: String?, cursor: String?, limit: Int = 20) async -> EdgeFeedPage? {
        guard AppConfig.Features.enableEdgeCompute else { return nil }
        var comps = URLComponents(string: Endpoint.feed)!
        comps.queryItems = [
            URLQueryItem(name: "uid", value: uid),
            URLQueryItem(name: "cursor", value: cursor),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        req.timeoutInterval = 6

        do {
            let (data, resp) = try await URLSession.configured.data(for: req)
            if let http = resp as? HTTPURLResponse {
                lastRegion = http.value(forHTTPHeaderField: "cf-colo")
                lastCacheStatus = http.value(forHTTPHeaderField: "cf-cache-status")
            }
            return try JSONDecoder.iso.decode(EdgeFeedPage.self, from: data)
        } catch {
            return nil
        }
    }

    /// Warm the caller's edge cache after a profile/interest change.
    func purge(uid: String) async {
        guard AppConfig.Features.enableEdgeCompute else { return }
        guard let url = URL(string: "\(Endpoint.feed)/purge?uid=\(uid)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        _ = try? await URLSession.configured.data(for: req)
    }
}

private extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
