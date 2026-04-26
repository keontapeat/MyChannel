//
//  MultimodalSearchV2Service.swift
//  MyChannel
//
//  Multimodal search: text + image + audio queries combined.
//  Uses `super-ai-team` Cloud Run for cross-modal embedding.
//

import Foundation

struct MultimodalSearchResult: Codable, Identifiable {
    let id: String
    let contentId: String
    let contentType: String
    let title: String
    let thumbnailURL: String?
    let relevanceScore: Double
    let matchReason: String
}

@MainActor
final class MultimodalSearchV2Service: ObservableObject {
    static let shared = MultimodalSearchV2Service()
    private init() {}
    @Published private(set) var results: [MultimodalSearchResult] = []

    func search(text: String?, imageURL: String?, audioURL: String?, limit: Int = 20) async throws {
        struct Req: Encodable { let task: String; let text: String?; let imageURL: String?; let audioURL: String?; let limit: Int }
        struct RawR: Decodable { let id: String; let content_id: String; let type: String; let title: String; let thumbnail: String?; let score: Double; let reason: String }
        struct Raw: Decodable { let results: [RawR]? }
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
            body: Req(task: "multimodal_search", text: text, imageURL: imageURL, audioURL: audioURL, limit: limit), timeout: 30)
        results = (r.results ?? []).map {
            MultimodalSearchResult(id: $0.id, contentId: $0.content_id, contentType: $0.type, title: $0.title,
                thumbnailURL: $0.thumbnail, relevanceScore: $0.score, matchReason: $0.reason)
        }
    }

    func searchByImage(imageData: Data) async throws -> [MultimodalSearchResult] {
        let b64 = imageData.base64EncodedString()
        struct Req: Encodable { let task: String; let imageBase64: String }
        struct RawR: Decodable { let id: String; let content_id: String; let type: String; let title: String; let score: Double; let reason: String }
        struct Raw: Decodable { let results: [RawR]? }
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict",
            body: Req(task: "search_by_image", imageBase64: b64), timeout: 30)
        return (r.results ?? []).map { MultimodalSearchResult(id: $0.id, contentId: $0.content_id, contentType: $0.type, title: $0.title, thumbnailURL: nil, relevanceScore: $0.score, matchReason: $0.reason) }
    }
}
