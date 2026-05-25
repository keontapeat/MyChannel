//
//  DecadeStrategyService.swift
//  MyChannel
//
//  Phase 120: Decade Strategy Reset.
//  KPI review, retire low-ROI bets, define Phase 121–200 roadmap.
//  Uses `ipo-readiness-ai` + `ma-intelligence-ai` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct KPISnapshot: Codable, Identifiable {
    let id: String
    let metricName: String
    let currentValue: Double
    let targetValue: Double
    let trend: KPITrend
    let snapshotDate: Date
}

enum KPITrend: String, Codable { case up, flat, down }

struct FeatureROI: Codable, Identifiable {
    let id: String
    let featureName: String
    let phase: Int
    let monthlyActiveUsers: Int
    let revenueDelta: Double
    let costPerMonth: Double
    let roi: Double               // revenueDelta / costPerMonth
    let recommendation: ROIAction
}

enum ROIAction: String, Codable { case keep, optimize, sunset, defer_ = "defer" }

struct RoadmapProposal: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let estimatedQuarters: Int
    let priority: Int
    let category: String
}

struct StrategySnapshot: Codable, Identifiable {
    let id: String
    let kpis: [KPISnapshot]
    let featureROIs: [FeatureROI]
    let nextRoadmap: [RoadmapProposal]
    let generatedAt: Date
}

// MARK: - Service

@MainActor
final class DecadeStrategyService: ObservableObject {
    static let shared = DecadeStrategyService()
    private init() {}

    @Published private(set) var latestSnapshot: StrategySnapshot?
    @Published private(set) var sunsetCandidates: [FeatureROI] = []

    func snapshotKPIs() async throws {
        guard AppConfig.Features.enableDecadeStrategy else { return }
        struct Request: Encodable { let task: String }
        struct RawKPI: Decodable { let name: String; let current: Double; let target: Double; let trend: String }
        struct Raw: Decodable { let kpis: [RawKPI]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .ipoReadinessAI,
            path: "/predict",
            body: Request(task: "kpi_snapshot")
        )
        let kpis = (r.kpis ?? []).map {
            KPISnapshot(id: UUID().uuidString, metricName: $0.name, currentValue: $0.current, targetValue: $0.target, trend: KPITrend(rawValue: $0.trend) ?? .flat, snapshotDate: Date())
        }

        // Combine with ROI + roadmap in full snapshot
        let rois = try await fetchFeatureROIs()
        let proposals = try await fetchRoadmapProposals()
        latestSnapshot = StrategySnapshot(id: UUID().uuidString, kpis: kpis, featureROIs: rois, nextRoadmap: proposals, generatedAt: Date())
        sunsetCandidates = rois.filter { $0.recommendation == .sunset }

        // Persist to Firestore
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("strategy_snapshots").document()
            .setData([
                "generatedAt": FieldValue.serverTimestamp(),
                "kpiCount": kpis.count,
                "sunsetCount": sunsetCandidates.count,
                "proposalCount": proposals.count
            ])
        #endif
    }

    private func fetchFeatureROIs() async throws -> [FeatureROI] {
        struct Request: Encodable { let task: String }
        struct RawROI: Decodable {
            let feature: String; let phase: Int; let mau: Int
            let revenue_delta: Double; let cost: Double; let roi: Double; let action: String
        }
        struct Raw: Decodable { let features: [RawROI]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .maIntelligence,
            path: "/predict",
            body: Request(task: "feature_roi_analysis")
        )
        return (r.features ?? []).map {
            FeatureROI(id: UUID().uuidString, featureName: $0.feature, phase: $0.phase, monthlyActiveUsers: $0.mau, revenueDelta: $0.revenue_delta, costPerMonth: $0.cost, roi: $0.roi, recommendation: ROIAction(rawValue: $0.action) ?? .keep)
        }
    }

    private func fetchRoadmapProposals() async throws -> [RoadmapProposal] {
        struct Request: Encodable { let task: String }
        struct RawProposal: Decodable { let title: String; let description: String; let quarters: Int; let priority: Int; let category: String }
        struct Raw: Decodable { let proposals: [RawProposal]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .ipoReadinessAI,
            path: "/predict",
            body: Request(task: "next_roadmap_proposals")
        )
        return (r.proposals ?? []).map {
            RoadmapProposal(id: UUID().uuidString, title: $0.title, description: $0.description, estimatedQuarters: $0.quarters, priority: $0.priority, category: $0.category)
        }
    }

    func retireLowROIFeatures() async throws -> [String] {
        guard AppConfig.Features.enableDecadeStrategy else { return [] }
        return sunsetCandidates.map(\.featureName)
    }
}
