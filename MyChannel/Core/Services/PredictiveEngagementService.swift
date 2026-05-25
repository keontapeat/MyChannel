//
//  PredictiveEngagementService.swift
//  MyChannel
//
//  Predictive engagement: anticipate user actions, pre-load content,
//  smart notifications. Uses `analytics-predictor-ai` Cloud Run.
//

import Foundation

struct PredictedEngagementItem: Codable, Identifiable {
    let id: String
    let userId: String
    let predictedAction: String
    let confidence: Double
    let suggestedContentId: String?
    let suggestedContentType: String?
    let reason: String
    let expiresAt: Date
}

struct EngagementWindow: Codable {
    let userId: String
    let likelyOnline: Bool
    let peakHour: Int
    let avgSessionMinutes: Double
    let daysSinceLastVisit: Int
}

@MainActor
final class PredictiveEngagementService: ObservableObject {
    static let shared = PredictiveEngagementService()
    private init() {}
    @Published private(set) var predictions: [PredictedEngagementItem] = []

    func fetchPredictions(userId: String) async throws {
        struct Req: Encodable { let task: String; let userId: String }
        struct RawP: Decodable { let id: String; let action: String; let confidence: Double; let content_id: String?; let content_type: String?; let reason: String; let expires: String? }
        struct Raw: Decodable { let predictions: [RawP]? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_engagement_predictions", userId: userId))
        predictions = (r.predictions ?? []).map {
            PredictedEngagementItem(id: $0.id, userId: userId, predictedAction: $0.action, confidence: $0.confidence,
                                    suggestedContentId: $0.content_id, suggestedContentType: $0.content_type, reason: $0.reason,
                                    expiresAt: $0.expires.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date().addingTimeInterval(3600))
        }
    }

    func fetchEngagementWindow(userId: String) async throws -> EngagementWindow {
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let online: Bool?; let peak: Int?; let avg_minutes: Double?; let days_since: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "fetch_engagement_window", userId: userId))
        return EngagementWindow(userId: userId, likelyOnline: r.online ?? false, peakHour: r.peak ?? 20,
            avgSessionMinutes: r.avg_minutes ?? 30, daysSinceLastVisit: r.days_since ?? 0)
    }

    func prewarmContent(userId: String) async throws -> [String] {
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let content_ids: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(.cdnOptimizerv2, path: "/predict",
            body: Req(task: "prewarm_engagement_content", userId: userId))
        return r.content_ids ?? []
    }
}
