//
//  DynamicAdInsertionV2Service.swift
//  MyChannel
//
//  Phase 161: Dynamic Ad Insertion v2.
//  Server-side ad stitching, frequency capping AI, contextual targeting.
//  Uses `ad-targeting-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct SSAISession: Codable, Identifiable {
    let id: String
    let videoId: String
    let manifestURL: URL
    let adBreaks: [SSAIAdBreak]
    let trackingURLs: [String]
}

struct SSAIAdBreak: Codable, Identifiable {
    let id: String
    let offsetSec: Double
    let durationSec: Double
    let adCount: Int
    let type: AdBreakType
}

enum AdBreakType: String, Codable { case preroll, midroll, postroll }

struct SSAIFrequencyCap: Codable {
    let advertiserId: String
    let maxImpressions: Int
    let windowHours: Int
    let currentCount: Int
}

struct ContextualTarget: Codable, Identifiable {
    let id: String
    let category: String
    let keywords: [String]
    let sentimentScore: Double
    let brandSafetyTier: String
}

// MARK: - Service

@MainActor
final class DynamicAdInsertionV2Service: ObservableObject {
    static let shared = DynamicAdInsertionV2Service()
    private init() {}

    @Published private(set) var currentSession: SSAISession?
    @Published private(set) var frequencyCaps: [SSAIFrequencyCap] = []
    @Published var isAdPlaying: Bool = false

    func createSession(videoId: String, userId: String) async throws -> SSAISession? {
        guard AppConfig.Features.enableDynamicAdInsertionV2 else { return nil }
        struct Request: Encodable { let task: String; let videoId: String; let userId: String }
        struct RawBreak: Decodable { let offset: Double; let duration: Double; let count: Int; let type: String }
        struct Raw: Decodable { let session_id: String?; let manifest: String?; let breaks: [RawBreak]?; let tracking: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .advancedTargeting, path: "/predict",
            body: Request(task: "ssai_session", videoId: videoId, userId: userId)
        )
        let session = SSAISession(
            id: r.session_id ?? UUID().uuidString,
            videoId: videoId,
            manifestURL: URL(string: r.manifest ?? "")!,
            adBreaks: (r.breaks ?? []).map {
                SSAIAdBreak(id: UUID().uuidString, offsetSec: $0.offset, durationSec: $0.duration,
                           adCount: $0.count, type: AdBreakType(rawValue: $0.type) ?? .midroll)
            },
            trackingURLs: r.tracking ?? []
        )
        currentSession = session
        return session
    }

    func checkFrequencyCap(advertiserId: String) -> Bool {
        guard let cap = frequencyCaps.first(where: { $0.advertiserId == advertiserId }) else { return true }
        return cap.currentCount < cap.maxImpressions
    }

    func contextualTarget(videoId: String) async throws -> ContextualTarget? {
        guard AppConfig.Features.enableDynamicAdInsertionV2 else { return nil }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let category: String?; let keywords: [String]?; let sentiment: Double?; let safety: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .advancedTargeting, path: "/predict",
            body: Request(task: "contextual_target", videoId: videoId)
        )
        return ContextualTarget(id: UUID().uuidString, category: r.category ?? "",
                               keywords: r.keywords ?? [], sentimentScore: r.sentiment ?? 0,
                               brandSafetyTier: r.safety ?? "standard")
    }
}
