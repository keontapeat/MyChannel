//
//  RelatedContextCardsService.swift
//  MyChannel
//
//  Phase 153: Related Context Cards.
//  Wikipedia/knowledge panel, fact-check overlays.
//  Uses `super-ai-team` Cloud Run.
//

import Foundation

// MARK: - Models

struct ContextCard: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let sourceURL: URL?
    let sourceName: String
    let imageURL: URL?
    let type: ContextCardType
    let timestampSec: Double?
    let relevanceScore: Double
}

enum ContextCardType: String, Codable, CaseIterable {
    case wikipedia, factCheck, news, product, location, person, organization
}

struct FactCheckResult: Codable, Identifiable {
    let id: String
    let claim: String
    let rating: String          // "true", "mostly true", "false", "unverified"
    let source: String
    let sourceURL: URL?
}

// MARK: - Service

@MainActor
final class RelatedContextCardsService: ObservableObject {
    static let shared = RelatedContextCardsService()
    private init() {}

    @Published private(set) var cards: [ContextCard] = []
    @Published private(set) var factChecks: [FactCheckResult] = []
    @Published var activeCard: ContextCard?

    func fetchCards(videoId: String) async throws {
        guard AppConfig.Features.enableRelatedContextCards else { return }
        struct Request: Encodable { let task: String; let videoId: String }
        struct RawCard: Decodable { let title: String; let summary: String; let url: String?; let source: String; let image: String?; let type: String; let timestamp: Double?; let score: Double }
        struct Raw: Decodable { let cards: [RawCard]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "context_cards", videoId: videoId), timeout: 30
        )
        cards = (r.cards ?? []).map {
            ContextCard(id: UUID().uuidString, title: $0.title, summary: $0.summary,
                       sourceURL: $0.url.flatMap(URL.init(string:)), sourceName: $0.source,
                       imageURL: $0.image.flatMap(URL.init(string:)),
                       type: ContextCardType(rawValue: $0.type) ?? .wikipedia,
                       timestampSec: $0.timestamp, relevanceScore: $0.score)
        }
    }

    func factCheck(videoId: String) async throws {
        guard AppConfig.Features.enableRelatedContextCards else { return }
        struct Request: Encodable { let task: String; let videoId: String }
        struct RawCheck: Decodable { let claim: String; let rating: String; let source: String; let url: String? }
        struct Raw: Decodable { let checks: [RawCheck]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "fact_check", videoId: videoId), timeout: 30
        )
        factChecks = (r.checks ?? []).map {
            FactCheckResult(id: UUID().uuidString, claim: $0.claim, rating: $0.rating,
                          source: $0.source, sourceURL: $0.url.flatMap(URL.init(string:)))
        }
    }

    func updateActive(currentTime: Double) {
        guard AppConfig.Features.enableRelatedContextCards else { return }
        activeCard = cards.first {
            guard let ts = $0.timestampSec else { return false }
            return currentTime >= ts && currentTime <= ts + 10
        }
    }
}
