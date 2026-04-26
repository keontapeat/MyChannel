import Foundation

@MainActor
final class VideoDetailRecommendationService: ObservableObject {
    static let shared = VideoDetailRecommendationService()

    @Published private(set) var cachedRecommendations: [String: [Video]] = [:]

    private let redisCache = RedisCacheService.shared
    private var trackedImpressions: Set<String> = []

    private init() {}

    func recommendations(for video: Video, userId: String?, limit: Int = 20) async -> [Video] {
        let cacheKey = "video-detail-recs:\(video.id):\(userId ?? "anon")"

        if let inMemory = cachedRecommendations[cacheKey], !inMemory.isEmpty {
            return Array(inMemory.prefix(limit))
        }

        if let cached: [Video] = await redisCache.get(cacheKey, type: [Video].self), !cached.isEmpty {
            cachedRecommendations[cacheKey] = cached
            return Array(cached.prefix(limit))
        }

        if let serverRanked = try? await serverRecommendations(for: video, userId: userId, limit: limit), !serverRanked.isEmpty {
            cachedRecommendations[cacheKey] = serverRanked
            await redisCache.set(cacheKey, value: serverRanked, ttl: 300)
            return serverRanked
        }

        let pool = await VideoFirestoreService.shared.fetchAllPublicVideos(limit: 80)
        let subscriptions = AppState.shared.subscriptions
        let history = userId != nil ? await HistoryService.shared.fetch(userId: userId!, limit: 40) : []
        let watchedCreatorIds = Set(history.map { $0.creatorId }).union(subscriptions)
        let watchedCategoryIds = Set(history.map { $0.contentType.rawValue.lowercased() })
        let sourceTags = Set(video.tags.map { $0.lowercased() })

        let ranked = pool
            .filter { $0.id != video.id && $0.visibility == .public }
            .map { candidate in
                (candidate, score(candidate, source: video, watchedCreatorIds: watchedCreatorIds, watchedCategoryIds: watchedCategoryIds, sourceTags: sourceTags))
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.createdAt > rhs.0.createdAt
                }
                return lhs.1 > rhs.1
            }
            .map { $0.0 }

        let result = Array(ranked.prefix(limit))
        cachedRecommendations[cacheKey] = result
        await redisCache.set(cacheKey, value: result, ttl: 300)
        return result
    }

    func prefetchNextPlayerItem(from videos: [Video]) {
        guard !videos.isEmpty else { return }
        let next = videos[0]
        VideoPlayerManager.prewarm(urlString: next.videoURL)

        let thumbnailURLs = videos.prefix(6).compactMap { URL(string: $0.thumbnailURL) }
        ImagePrefetcher.shared.prefetch(urls: thumbnailURLs)
    }

    func trackImpression(videoId: String, sourceVideoId: String, position: Int, userId: String?) async {
        let key = "\(sourceVideoId):\(videoId):\(position):\(userId ?? "anon")"
        guard !trackedImpressions.contains(key) else { return }
        trackedImpressions.insert(key)

        await AnalyticsService.shared.trackEvent("video_detail_recommendation_impression", parameters: [
            "videoId": videoId,
            "sourceVideoId": sourceVideoId,
            "position": position,
            "userId": userId ?? "anonymous"
        ])
    }

    func trackClick(videoId: String, sourceVideoId: String, position: Int, userId: String?) async {
        await AnalyticsService.shared.trackEvent("video_detail_recommendation_click", parameters: [
            "videoId": videoId,
            "sourceVideoId": sourceVideoId,
            "position": position,
            "userId": userId ?? "anonymous"
        ])
    }

    private func serverRecommendations(for video: Video, userId: String?, limit: Int) async throws -> [Video] {
        struct Request: Encodable {
            let task: String
            let videoId: String
            let creatorId: String
            let category: String
            let tags: [String]
            let userId: String?
            let subscriptions: [String]
            let limit: Int
        }

        struct RawVideo: Decodable {
            let id: String
            let title: String?
            let description: String?
            let thumbnailURL: String?
            let thumbnailUrl: String?
            let videoURL: String?
            let videoUrl: String?
            let duration: Double?
            let viewCount: Int?
            let likeCount: Int?
            let commentCount: Int?
            let createdAt: Date?
            let createdAtISO: String?
            let createdAtTimestamp: Double?
            let creatorId: String?
            let creatorUsername: String?
            let creatorDisplayName: String?
            let creatorProfileImageURL: String?
            let creatorProfileImageUrl: String?
            let creatorSubscriberCount: Int?
            let creatorVerified: Bool?
            let category: String?
            let tags: [String]?
            let isLiveStream: Bool?

            private enum CodingKeys: String, CodingKey {
                case id, title, description, duration, viewCount, likeCount, commentCount, category, tags, isLiveStream
                case thumbnailURL, thumbnailUrl, videoURL, videoUrl
                case createdAt, creatorId, creatorUsername, creatorDisplayName
                case creatorProfileImageURL, creatorProfileImageUrl, creatorSubscriberCount, creatorVerified
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                title = try container.decodeIfPresent(String.self, forKey: .title)
                description = try container.decodeIfPresent(String.self, forKey: .description)
                thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL)
                thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
                videoURL = try container.decodeIfPresent(String.self, forKey: .videoURL)
                videoUrl = try container.decodeIfPresent(String.self, forKey: .videoUrl)
                duration = try container.decodeIfPresent(Double.self, forKey: .duration)
                viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount)
                likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)
                commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount)
                creatorId = try container.decodeIfPresent(String.self, forKey: .creatorId)
                creatorUsername = try container.decodeIfPresent(String.self, forKey: .creatorUsername)
                creatorDisplayName = try container.decodeIfPresent(String.self, forKey: .creatorDisplayName)
                creatorProfileImageURL = try container.decodeIfPresent(String.self, forKey: .creatorProfileImageURL)
                creatorProfileImageUrl = try container.decodeIfPresent(String.self, forKey: .creatorProfileImageUrl)
                creatorSubscriberCount = try container.decodeIfPresent(Int.self, forKey: .creatorSubscriberCount)
                creatorVerified = try container.decodeIfPresent(Bool.self, forKey: .creatorVerified)
                category = try container.decodeIfPresent(String.self, forKey: .category)
                tags = try container.decodeIfPresent([String].self, forKey: .tags)
                isLiveStream = try container.decodeIfPresent(Bool.self, forKey: .isLiveStream)

                createdAt = try? container.decode(Date.self, forKey: .createdAt)
                createdAtISO = try? container.decode(String.self, forKey: .createdAt)
                createdAtTimestamp = try? container.decode(Double.self, forKey: .createdAt)
            }
        }

        struct Response: Decodable {
            let recommendations: [RawVideo]?
        }

        let response: Response = try await CloudRunAgentRouter.post(
            .recommendations,
            path: "/predict",
            body: Request(
                task: "video_detail_recommendations",
                videoId: video.id,
                creatorId: video.creator.id,
                category: video.category.rawValue,
                tags: video.tags,
                userId: userId,
                subscriptions: Array(AppState.shared.subscriptions),
                limit: limit
            ),
            timeout: 12
        )

        var seen = Set<String>()

        return (response.recommendations ?? []).compactMap { raw in
            let finalVideoURL = raw.videoURL ?? raw.videoUrl ?? ""
            guard !finalVideoURL.isEmpty, !raw.id.isEmpty, seen.insert(raw.id).inserted else { return nil }

            let createdAt: Date = {
                if let createdAt = raw.createdAt { return createdAt }
                if let timestamp = raw.createdAtTimestamp { return Date(timeIntervalSince1970: timestamp) }
                if let iso = raw.createdAtISO {
                    let formatter = ISO8601DateFormatter()
                    if let date = formatter.date(from: iso) { return date }
                }
                return Date()
            }()
            let creator = User(
                id: raw.creatorId ?? UUID().uuidString,
                username: raw.creatorUsername ?? "creator",
                displayName: raw.creatorDisplayName ?? "Creator",
                email: "",
                profileImageURL: raw.creatorProfileImageURL ?? raw.creatorProfileImageUrl,
                bio: nil,
                subscriberCount: raw.creatorSubscriberCount ?? 0,
                videoCount: 0,
                isVerified: raw.creatorVerified ?? false,
                isCreator: true,
                createdAt: createdAt
            )

            return Video(
                id: raw.id,
                title: raw.title ?? "",
                description: raw.description ?? "",
                thumbnailURL: raw.thumbnailURL ?? raw.thumbnailUrl ?? "",
                videoURL: finalVideoURL,
                duration: raw.duration ?? 0,
                viewCount: raw.viewCount ?? 0,
                likeCount: raw.likeCount ?? 0,
                commentCount: raw.commentCount ?? 0,
                createdAt: createdAt,
                creator: creator,
                category: VideoCategory(rawValue: raw.category ?? "") ?? .entertainment,
                tags: raw.tags ?? [],
                isLiveStream: raw.isLiveStream ?? false
            )
        }
    }

    private func score(_ candidate: Video, source: Video, watchedCreatorIds: Set<String>, watchedCategoryIds: Set<String>, sourceTags: Set<String>) -> Double {
        var value = 0.0

        if candidate.creator.id == source.creator.id { value += 120 }
        if candidate.category == source.category { value += 55 }
        if watchedCreatorIds.contains(candidate.creator.id) { value += 40 }
        if watchedCategoryIds.contains(candidate.category.rawValue.lowercased()) { value += 24 }
        if candidate.isLiveStream == source.isLiveStream { value += 12 }

        let sharedTags = sourceTags.intersection(Set(candidate.tags.map { $0.lowercased() })).count
        value += Double(sharedTags) * 14

        let recencyDays = Date().timeIntervalSince(candidate.createdAt) / 86_400
        value += max(0, 20 - recencyDays)
        value += min(Double(candidate.viewCount) / 25_000.0, 30)
        value += min(Double(candidate.likeCount) / 2_500.0, 18)

        let durationDelta = abs(candidate.duration - source.duration)
        value += max(0, 14 - durationDelta / 90)

        return value
    }
}
