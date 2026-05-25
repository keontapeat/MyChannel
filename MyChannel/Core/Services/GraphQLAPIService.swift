//
//  GraphQLAPIService.swift
//  MyChannel
//
//  Phase 3.1: GraphQL Federation API — single request for multiple services.
//  Reduces API round-trips from N requests to 1 for composite views.
//  Uses `mychannel-ai` Cloud Run as the federation gateway.
//

import Foundation
import Combine

// MARK: - GraphQL Types

struct GraphQLRequest: Encodable {
    let query: String
    let variables: [String: AnyCodable]?
    let operationName: String?
}

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
    
    struct GraphQLError: Decodable {
        let message: String?
        let path: [String]?
    }
    
    var hasErrors: Bool { !(errors ?? []).isEmpty }
}

/// Type-erasing wrapper for Any Codable values in GraphQL variables
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) { value = intVal }
        else if let doubleVal = try? container.decode(Double.self) { value = doubleVal }
        else if let boolVal = try? container.decode(Bool.self) { value = boolVal }
        else if let stringVal = try? container.decode(String.self) { value = stringVal }
        else { value = "" }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int { try container.encode(intVal) }
        else if let doubleVal = value as? Double { try container.encode(doubleVal) }
        else if let boolVal = value as? Bool { try container.encode(boolVal) }
        else if let stringVal = value as? String { try container.encode(stringVal) }
        else { try container.encode("") }
    }
}

// MARK: - Federation Query Builders

struct VideoDetailFederation: Codable {
    let video: VideoFederationData?
    let creator: CreatorFederationData?
    let comments: CommentsFederationData?
    let recommendations: RecommendationsFederationData?
    let analytics: VideoAnalyticsFederationData?
    
    struct VideoFederationData: Codable {
        let id: String; let title: String; let description: String
        let thumbnailUrl: String; let videoUrl: String; let hlsUrl: String?
        let duration: Double; let viewCount: Int; let likeCount: Int
        let category: String; let createdAt: String; let isLive: Bool
    }
    struct CreatorFederationData: Codable {
        let id: String; let username: String; let displayName: String
        let avatarUrl: String; let subscriberCount: Int; let isVerified: Bool
    }
    struct CommentsFederationData: Codable {
        let total: Int; let items: [CommentItem]?
        struct CommentItem: Codable { let id: String; let text: String; let author: String; let createdAt: String }
    }
    struct RecommendationsFederationData: Codable {
        let items: [RecItem]?
        struct RecItem: Codable { let id: String; let title: String; let thumbnailUrl: String; let viewCount: Int }
    }
    struct VideoAnalyticsFederationData: Codable {
        let retention: Double?; let avgWatchTime: Double?; let ctr: Double?
    }
}

struct HomeFeedFederation: Codable {
    let feed: [FeedSection]?
    let trending: [FeedVideoItem]?
    let subscriptions: [FeedVideoItem]?
    
    struct FeedSection: Codable {
        let title: String; let type: String; let items: [FeedVideoItem]?
    }
    struct FeedVideoItem: Codable {
        let id: String; let title: String; let thumbnailUrl: String
        let creatorName: String; let viewCount: Int; let duration: Double
    }
}

private struct GraphQLCloudRunBody: Encodable {
    let task: String
    let query: String
    let variables: String?
}

private struct GraphQLRawResponse: Decodable {
    let data: DataPayload?
    let errors: [ErrorResponse]?
    struct DataPayload: Decodable { let result: String? }
    struct ErrorResponse: Decodable { let message: String? }
}

// MARK: - GraphQL API Service

@MainActor
final class GraphQLAPIService: ObservableObject {
    static let shared = GraphQLAPIService()
    
    @Published var isLoading = false
    
    private let redisCache = RedisCacheService.shared
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = 10
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    // MARK: - 🔥 FEDERATED VIDEO DETAIL (1 request instead of 5)
    
    func fetchVideoDetail(videoId: String, userId: String? = nil) async throws -> VideoDetailFederation {
        // Check Redis cache
        if let cached: VideoDetailFederation = await redisCache.get("gql:video:\(videoId)", type: VideoDetailFederation.self) {
            return cached
        }
        
        let query = """
        query VideoDetail($videoId: ID!, $userId: ID) {
          video(id: $videoId) {
            id title description thumbnailUrl videoUrl hlsUrl
            duration viewCount likeCount category createdAt isLive
          }
          creator(videoId: $videoId) {
            id username displayName avatarUrl subscriberCount isVerified
          }
          comments(videoId: $videoId, limit: 20) {
            total items { id text author createdAt }
          }
          recommendations(videoId: $videoId, limit: 10) {
            items { id title thumbnailUrl viewCount }
          }
          analytics(videoId: $videoId, userId: $userId) {
            retention avgWatchTime ctr
          }
        }
        """
        
        let result: VideoDetailFederation = try await execute(
            query: query,
            variables: ["videoId": AnyCodable(videoId), "userId": userId.map { AnyCodable($0) }].compactMapValues { $0 }
        )
        
        // Cache for 5 minutes
        await redisCache.set("gql:video:\(videoId)", value: result, ttl: 300)
        return result
    }
    
    // MARK: - 🔥 FEDERATED HOME FEED (1 request instead of 3)
    
    func fetchHomeFeed(userId: String, limit: Int = 20) async throws -> HomeFeedFederation {
        // Check Redis cache
        if let cached: HomeFeedFederation = await redisCache.get("gql:feed:\(userId)", type: HomeFeedFederation.self) {
            return cached
        }
        
        let query = """
        query HomeFeed($userId: ID!, $limit: Int!) {
          feed(userId: $userId, limit: $limit) {
            title type items { id title thumbnailUrl creatorName viewCount duration }
          }
          trending(limit: $limit) {
            id title thumbnailUrl creatorName viewCount duration
          }
          subscriptions(userId: $userId, limit: $limit) {
            id title thumbnailUrl creatorName viewCount duration
          }
        }
        """
        
        let result: HomeFeedFederation = try await execute(
            query: query,
            variables: ["userId": AnyCodable(userId), "limit": AnyCodable(limit)]
        )
        
        // Cache for 2 minutes
        await redisCache.set("gql:feed:\(userId)", value: result, ttl: 120)
        return result
    }
    
    // MARK: - 🔥 GENERIC QUERY EXECUTION
    
    func execute<T: Decodable>(query: String, variables: [String: AnyCodable]? = nil, operationName: String? = nil) async throws -> T {
        isLoading = true
        defer { isLoading = false }
        
        let request = GraphQLRequest(query: query, variables: variables, operationName: operationName)
        
        // Route through Cloud Run federation gateway
        _ = try JSONEncoder().encode(request)
        
        let variablesJSON = variables.map { try? JSONEncoder().encode($0) }.flatMap { $0 }.flatMap { String(data: $0, encoding: .utf8) }

        // Use CloudRunAgentRouter for auth + routing
        let r: GraphQLRawResponse = try await CloudRunAgentRouter.post(
            .myChannelAI,
            path: "/predict",
            body: GraphQLCloudRunBody(task: "graphql_query", query: query, variables: variablesJSON),
            timeout: 15
        )
        
        if let errors = r.errors, !errors.isEmpty {
            let messages = errors.compactMap { $0.message }.joined(separator: "; ")
            throw GraphQLAPIError.queryError(messages)
        }
        
        guard let dataString = r.data?.result, let data = dataString.data(using: .utf8) else {
            throw GraphQLAPIError.noData
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Errors

enum GraphQLAPIError: LocalizedError {
    case queryError(String)
    case noData
    case networkError
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .queryError(let msg): return "GraphQL query error: \(msg)"
        case .noData: return "No data returned from GraphQL query"
        case .networkError: return "Network error contacting GraphQL gateway"
        case .parseError: return "Failed to parse GraphQL response"
        }
    }
}
