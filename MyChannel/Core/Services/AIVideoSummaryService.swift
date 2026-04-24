//
//  AIVideoSummaryService.swift
//  MyChannel
//
//  Phase 32: AI Video Summaries — TL;DW for any long video.

import Foundation

struct AIVideoSummary: Codable, Identifiable {
    let id: String
    let videoId: String
    let shortSummary: String
    let bulletPoints: [String]
    let keyMoments: [KeyMoment]
    let generatedAt: Date

    struct KeyMoment: Codable, Identifiable, Hashable {
        let id: String
        let timestamp: Double
        let title: String
        let description: String

        init(id: String = UUID().uuidString, timestamp: Double, title: String, description: String) {
            self.id = id; self.timestamp = timestamp; self.title = title; self.description = description
        }
    }

    init(id: String = UUID().uuidString, videoId: String, shortSummary: String,
         bulletPoints: [String], keyMoments: [KeyMoment], generatedAt: Date = Date()) {
        self.id = id; self.videoId = videoId; self.shortSummary = shortSummary
        self.bulletPoints = bulletPoints; self.keyMoments = keyMoments; self.generatedAt = generatedAt
    }
}

@MainActor
final class AIVideoSummaryService: ObservableObject {
    static let shared = AIVideoSummaryService()
    private init() {}

    @Published var isGenerating: Bool = false
    @Published var lastError: String?

    private var cache: [String: AIVideoSummary] = [:]

    func summarize(videoId: String, title: String, description: String, transcript: String? = nil,
                   durationSeconds: Double = 0) async throws -> AIVideoSummary {
        if let cached = cache[videoId] { return cached }

        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        struct Request: Encodable {
            let task: String
            let videoId: String
            let title: String
            let description: String
            let transcript: String?
            let durationSeconds: Double
        }
        struct RawMoment: Decodable {
            let timestamp: Double?
            let label: String?
        }
        struct Response: Decodable {
            let short_summary: String?
            let bullet_points: [String]?
            let key_moments: [RawMoment]?
        }

        let req = Request(task: "summarize_video", videoId: videoId, title: title,
                          description: description, transcript: transcript, durationSeconds: durationSeconds)

        do {
            let raw: Response = try await CloudRunAgentRouter.post(
                .superAITeam, path: "/predict", body: req, timeout: 30
            )
            let moments = (raw.key_moments ?? []).compactMap { m -> AIVideoSummary.KeyMoment? in
                guard let ts = m.timestamp, let lbl = m.label, !lbl.isEmpty else { return nil }
                return .init(timestamp: ts, title: lbl, description: "")
            }
            let summary = AIVideoSummary(
                videoId: videoId,
                shortSummary: raw.short_summary ?? "No summary available.",
                bulletPoints: raw.bullet_points ?? [],
                keyMoments: moments
            )
            cache[videoId] = summary
            return summary
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
}
