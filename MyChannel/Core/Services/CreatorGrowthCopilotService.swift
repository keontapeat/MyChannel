//
//  CreatorGrowthCopilotService.swift
//  MyChannel
//
//  Phase 114: Creator Growth Copilot.
//  Proactive insights on retention drops, thumbnail A/B testing, and audience overlap.
//

import Foundation
import Combine

struct CopilotInsight: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let metricImpact: Double // e.g. -15.0 for 15% drop
    let suggestedAction: String
    let severity: InsightSeverity
}

enum InsightSeverity: String, Codable {
    case info, warning, critical
}

struct GrowthDashboardData: Codable {
    let insights: [CopilotInsight]
    let overallHealthScore: Double
    let projectedSubscribers30Days: Int
}

@MainActor
final class CreatorGrowthCopilotService: ObservableObject {
    static let shared = CreatorGrowthCopilotService()
    private init() {}
    
    @Published private(set) var dashboardData: GrowthDashboardData?
    @Published private(set) var isAnalyzing = false
    
    func analyzeChannel(creatorId: String) async throws {
        guard AppConfig.Features.enableCreatorCopilot else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        struct Request: Encodable {
            let task: String
            let creatorId: String
        }
        
        struct RawInsight: Decodable {
            let title: String
            let description: String
            let metric_impact: Double
            let suggested_action: String
            let severity: String
        }
        
        struct RawDashboard: Decodable {
            let insights: [RawInsight]
            let health_score: Double
            let projected_subs: Int
        }
        
        let response: RawDashboard = try await CloudRunAgentRouter.post(
            .superAITeam, // Or a dedicated data science agent
            path: "/predict",
            body: Request(task: "analyze_channel_growth", creatorId: creatorId),
            timeout: 60
        )
        
        dashboardData = GrowthDashboardData(
            insights: response.insights.map { r in
                CopilotInsight(
                    id: UUID().uuidString,
                    title: r.title,
                    description: r.description,
                    metricImpact: r.metric_impact,
                    suggestedAction: r.suggested_action,
                    severity: InsightSeverity(rawValue: r.severity) ?? .info
                )
            },
            overallHealthScore: response.health_score,
            projectedSubscribers30Days: response.projected_subs
        )
    }
}
