//
//  CreatorCoachService.swift
//  MyChannel
//
//  Phase 34: AI Creator Coach — generates weekly personalized reports for creators
//  using creator-coach-ai + viral-prediction + watch-time-optimizer Cloud Run services.
//

import Foundation

// MARK: - Models

struct CreatorWeeklyReport: Codable, Identifiable {
    let id: String
    let creatorId: String
    let weekStart: Date
    let weekEnd: Date

    let summary: String
    let strengths: [String]
    let opportunities: [String]
    let actions: [CoachAction]

    let topVideoIds: [String]
    let underperformingVideoIds: [String]

    let viralScoreForecast: Double?   // 0...1
    let retentionScoreForecast: Double? // 0...1

    init(
        id: String = UUID().uuidString,
        creatorId: String,
        weekStart: Date,
        weekEnd: Date,
        summary: String,
        strengths: [String],
        opportunities: [String],
        actions: [CoachAction],
        topVideoIds: [String],
        underperformingVideoIds: [String],
        viralScoreForecast: Double?,
        retentionScoreForecast: Double?
    ) {
        self.id = id
        self.creatorId = creatorId
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.summary = summary
        self.strengths = strengths
        self.opportunities = opportunities
        self.actions = actions
        self.topVideoIds = topVideoIds
        self.underperformingVideoIds = underperformingVideoIds
        self.viralScoreForecast = viralScoreForecast
        self.retentionScoreForecast = retentionScoreForecast
    }
}

struct CoachAction: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let priority: Priority

    enum Priority: String, Codable, Hashable {
        case high, medium, low
    }

    init(id: String = UUID().uuidString, title: String, detail: String, priority: Priority = .medium) {
        self.id = id
        self.title = title
        self.detail = detail
        self.priority = priority
    }
}

// MARK: - Service

@MainActor
final class CreatorCoachService: ObservableObject {
    static let shared = CreatorCoachService()
    private init() {}

    @Published var isGenerating: Bool = false
    @Published var lastReport: CreatorWeeklyReport?
    @Published var lastError: String?

    /// Generate a fresh weekly report for the given creator.
    func generateWeeklyReport(creatorId: String) async throws -> CreatorWeeklyReport {
        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        let (weekStart, weekEnd) = Self.currentWeekBounds()

        struct Request: Encodable {
            let task: String
            let creatorId: String
            let weekStartISO: String
            let weekEndISO: String
        }

        struct RawAction: Decodable {
            let title: String?
            let detail: String?
            let priority: String?
        }

        struct RawResponse: Decodable {
            let summary: String?
            let strengths: [String]?
            let opportunities: [String]?
            let actions: [RawAction]?
            let top_video_ids: [String]?
            let underperforming_video_ids: [String]?
            let viral_score_forecast: Double?
            let retention_score_forecast: Double?
        }

        let iso = ISO8601DateFormatter()
        let req = Request(
            task: "weekly_report",
            creatorId: creatorId,
            weekStartISO: iso.string(from: weekStart),
            weekEndISO: iso.string(from: weekEnd)
        )

        do {
            let raw: RawResponse = try await CloudRunAgentRouter.post(
                .creatorCoachAI,
                path: "/predict",
                body: req,
                timeout: 45
            )

            let actions: [CoachAction] = (raw.actions ?? []).compactMap { r in
                guard
                    let title = r.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !title.isEmpty
                else { return nil }
                let priority = CoachAction.Priority(rawValue: r.priority ?? "medium") ?? .medium
                return CoachAction(title: title, detail: r.detail ?? "", priority: priority)
            }

            let report = CreatorWeeklyReport(
                creatorId: creatorId,
                weekStart: weekStart,
                weekEnd: weekEnd,
                summary: raw.summary ?? "Your week at a glance.",
                strengths: raw.strengths ?? [],
                opportunities: raw.opportunities ?? [],
                actions: actions,
                topVideoIds: raw.top_video_ids ?? [],
                underperformingVideoIds: raw.underperforming_video_ids ?? [],
                viralScoreForecast: raw.viral_score_forecast,
                retentionScoreForecast: raw.retention_score_forecast
            )

            lastReport = report
            return report
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Helpers

    private static func currentWeekBounds(calendar: Calendar = .current, now: Date = Date()) -> (start: Date, end: Date) {
        let weekday = calendar.component(.weekday, from: now) // 1 = Sun
        let daysSinceMonday = ((weekday + 5) % 7) // 0 if Monday
        let startOfDay = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? now
        return (start, end)
    }
}
