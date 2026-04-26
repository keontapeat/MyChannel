//
//  CreatorEconomyCommandService.swift
//  MyChannel
//
//  Phase 892: Creator Economy Command Dashboard
//  Creator health scores, revenue distribution, growth trajectories, at-risk creators
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CreatorEconomyCommandService: ObservableObject {
    static let shared = CreatorEconomyCommandService()

    // MARK: - Domain Models

    struct CreatorHealthScore: Identifiable, Codable {
        let id: String
        let creatorId: String
        let creatorName: String
        let engagementScore: Double
        let growthScore: Double
        let monetizationScore: Double
        let overallScore: Double
        let tier: CreatorTier
        let atRisk: Bool
        let riskFactors: [String]
        let monthlyRevenue: Double
        let subscriberCount: Int
        let uploadFrequency: Double
    }

    enum CreatorTier: String, Codable {
        case platinum = "PLATINUM"
        case gold = "GOLD"
        case silver = "SILVER"
        case bronze = "BRONZE"
        case emerging = "EMERGING"
    }

    struct RevenueDistribution: Identifiable, Codable {
        let id: String
        let tier: String
        let creatorCount: Int
        let totalRevenue: Double
        let avgRevenue: Double
        let revenueShare: Double
        let topCreatorRevenue: Double
    }

    struct GrowthTrajectory: Identifiable, Codable {
        let id: String
        let creatorId: String
        let creatorName: String
        let currentSubscribers: Int
        let projectedSubscribers30d: Int
        let growthVelocity: Double
        let trajectory: String
        let milestone: String?
    }

    struct CreatorMilestone: Identifiable, Codable {
        let id: String
        let creatorId: String
        let creatorName: String
        let milestone: String
        let reachedAt: Date
        let celebrationSent: Bool
    }

    // MARK: - Published State

    @Published private(set) var creatorHealth: [CreatorHealthScore] = []
    @Published private(set) var revenueDistribution: [RevenueDistribution] = []
    @Published private(set) var growthTrajectories: [GrowthTrajectory] = []
    @Published private(set) var recentMilestones: [CreatorMilestone] = []
    @Published private(set) var atRiskCreators: [CreatorHealthScore] = []
    @Published private(set) var totalCreatorRevenue: Double = 0
    @Published private(set) var avgSatisfaction: Double = 0
    @Published private(set) var creatorCount: Int = 0

    private var db = Firestore.firestore()

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://creator-economy-command-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableCreatorEconomyCommand else { return nil }
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableCreatorEconomyCommand else { return }

        // Load creator health scores from Firestore
        let snap = try? await db.collection("creatorHealthScores")
            .order(by: "overallScore", descending: true)
            .limit(to: 50)
            .getDocuments()
        creatorHealth = snap?.documents.compactMap { doc in
            let d = doc.data()
            guard let tier = CreatorTier(rawValue: d["tier"] as? String ?? "") else { return nil }
            return CreatorHealthScore(
                id: doc.documentID,
                creatorId: d["creatorId"] as? String ?? "",
                creatorName: d["creatorName"] as? String ?? "",
                engagementScore: d["engagementScore"] as? Double ?? 0,
                growthScore: d["growthScore"] as? Double ?? 0,
                monetizationScore: d["monetizationScore"] as? Double ?? 0,
                overallScore: d["overallScore"] as? Double ?? 0,
                tier: tier,
                atRisk: d["atRisk"] as? Bool ?? false,
                riskFactors: d["riskFactors"] as? [String] ?? [],
                monthlyRevenue: d["monthlyRevenue"] as? Double ?? 0,
                subscriberCount: d["subscriberCount"] as? Int ?? 0,
                uploadFrequency: d["uploadFrequency"] as? Double ?? 0
            )
        } ?? []

        atRiskCreators = creatorHealth.filter { $0.atRisk }
        totalCreatorRevenue = creatorHealth.reduce(0) { $0 + $1.monthlyRevenue }
        creatorCount = creatorHealth.count

        // Cloud Run for distribution, trajectories, milestones
        if let result = await callCloudRun(endpoint: "dashboard") {
            if let dist = result["revenueDistribution"] as? [[String: Any]] {
                revenueDistribution = dist.compactMap { d in
                    RevenueDistribution(
                        id: UUID().uuidString,
                        tier: d["tier"] as? String ?? "",
                        creatorCount: d["creatorCount"] as? Int ?? 0,
                        totalRevenue: d["totalRevenue"] as? Double ?? 0,
                        avgRevenue: d["avgRevenue"] as? Double ?? 0,
                        revenueShare: d["revenueShare"] as? Double ?? 0,
                        topCreatorRevenue: d["topCreatorRevenue"] as? Double ?? 0
                    )
                }
            }
            if let traj = result["growthTrajectories"] as? [[String: Any]] {
                growthTrajectories = traj.compactMap { d in
                    GrowthTrajectory(
                        id: UUID().uuidString,
                        creatorId: d["creatorId"] as? String ?? "",
                        creatorName: d["creatorName"] as? String ?? "",
                        currentSubscribers: d["currentSubscribers"] as? Int ?? 0,
                        projectedSubscribers30d: d["projectedSubscribers30d"] as? Int ?? 0,
                        growthVelocity: d["growthVelocity"] as? Double ?? 0,
                        trajectory: d["trajectory"] as? String ?? "stable",
                        milestone: d["milestone"] as? String
                    )
                }
            }
            avgSatisfaction = result["avgSatisfaction"] as? Double ?? 0
        }

        // Load recent milestones
        let milestoneSnap = try? await db.collection("creatorMilestones")
            .order(by: "reachedAt", descending: true)
            .limit(to: 10)
            .getDocuments()
        recentMilestones = milestoneSnap?.documents.compactMap { doc in
            let d = doc.data()
            return CreatorMilestone(
                id: doc.documentID,
                creatorId: d["creatorId"] as? String ?? "",
                creatorName: d["creatorName"] as? String ?? "",
                milestone: d["milestone"] as? String ?? "",
                reachedAt: (d["reachedAt"] as? Timestamp)?.dateValue() ?? Date(),
                celebrationSent: d["celebrationSent"] as? Bool ?? false
            )
        } ?? []
    }
}
