//
//  ExecutiveAnalyticsDeepDiveService.swift
//  MyChannel
//
//  Phase 891: Executive Analytics Deep Dive
//  Cohort analysis, LTV/CAC, funnel analytics, revenue per segment, competitive benchmark
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ExecutiveAnalyticsDeepDiveService: ObservableObject {
    static let shared = ExecutiveAnalyticsDeepDiveService()

    // MARK: - Domain Models

    struct CohortData: Identifiable, Codable {
        let id: String
        let cohortName: String
        let cohortDate: Date
        let users: Int
        let d1Retention: Double
        let d7Retention: Double
        let d30Retention: Double
        let avgLTV: Double
        let avgCAC: Double
        let ltvToCacRatio: Double
    }

    struct FunnelStep: Identifiable, Codable {
        let id: String
        let stepName: String
        let users: Int
        let conversionRate: Double
        let dropOffRate: Double
        let avgTimeMinutes: Double
    }

    struct SegmentRevenue: Identifiable, Codable {
        let id: String
        let segmentName: String
        let users: Int
        let revenuePerUser: Double
        let totalRevenue: Double
        let growthRate: Double
        let churnRate: Double
    }

    struct CompetitiveBenchmark: Identifiable, Codable {
        let id: String
        let metric: String
        let myChannel: Double
        let industryAvg: Double
        let topCompetitor: Double
        let gap: Double
        let trend: String
    }

    // MARK: - Published State

    @Published private(set) var cohorts: [CohortData] = []
    @Published private(set) var funnel: [FunnelStep] = []
    @Published private(set) var segmentRevenue: [SegmentRevenue] = []
    @Published private(set) var benchmarks: [CompetitiveBenchmark] = []
    @Published private(set) var overallLTV: Double = 0
    @Published private(set) var overallCAC: Double = 0
    @Published private(set) var ltvCacRatio: Double = 0
    @Published private(set) var marketPenetration: Double = 0

    private var db = Firestore.firestore()

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://exec-analytics-deep-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableExecutiveAnalyticsDeepDive else { return nil }
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
        guard AppConfig.Features.enableExecutiveAnalyticsDeepDive else { return }

        // Load cohorts from Firestore
        let cohortSnap = try? await db.collection("cohortAnalysis")
            .order(by: "cohortDate", descending: true)
            .limit(to: 12)
            .getDocuments()
        cohorts = cohortSnap?.documents.compactMap { doc in
            let d = doc.data()
            let ltv = d["avgLTV"] as? Double ?? 0
            let cac = d["avgCAC"] as? Double ?? 0
            return CohortData(
                id: doc.documentID,
                cohortName: d["cohortName"] as? String ?? "",
                cohortDate: (d["cohortDate"] as? Timestamp)?.dateValue() ?? Date(),
                users: d["users"] as? Int ?? 0,
                d1Retention: d["d1Retention"] as? Double ?? 0,
                d7Retention: d["d7Retention"] as? Double ?? 0,
                d30Retention: d["d30Retention"] as? Double ?? 0,
                avgLTV: ltv,
                avgCAC: cac,
                ltvToCacRatio: cac > 0 ? ltv / cac : 0
            )
        } ?? []

        overallLTV = cohorts.isEmpty ? 0 : cohorts.reduce(0.0) { $0 + $1.avgLTV } / Double(cohorts.count)
        overallCAC = cohorts.isEmpty ? 0 : cohorts.reduce(0.0) { $0 + $1.avgCAC } / Double(cohorts.count)
        ltvCacRatio = overallCAC > 0 ? overallLTV / overallCAC : 0

        // Cloud Run for funnel, segments, benchmarks
        if let result = await callCloudRun(endpoint: "deep-dive") {
            if let funnelData = result["funnel"] as? [[String: Any]] {
                funnel = funnelData.compactMap { d in
                    FunnelStep(
                        id: UUID().uuidString,
                        stepName: d["stepName"] as? String ?? "",
                        users: d["users"] as? Int ?? 0,
                        conversionRate: d["conversionRate"] as? Double ?? 0,
                        dropOffRate: d["dropOffRate"] as? Double ?? 0,
                        avgTimeMinutes: d["avgTimeMinutes"] as? Double ?? 0
                    )
                }
            }
            if let segments = result["segmentRevenue"] as? [[String: Any]] {
                segmentRevenue = segments.compactMap { d in
                    SegmentRevenue(
                        id: UUID().uuidString,
                        segmentName: d["segmentName"] as? String ?? "",
                        users: d["users"] as? Int ?? 0,
                        revenuePerUser: d["revenuePerUser"] as? Double ?? 0,
                        totalRevenue: d["totalRevenue"] as? Double ?? 0,
                        growthRate: d["growthRate"] as? Double ?? 0,
                        churnRate: d["churnRate"] as? Double ?? 0
                    )
                }
            }
            if let bench = result["benchmarks"] as? [[String: Any]] {
                benchmarks = bench.compactMap { d in
                    let mc = d["myChannel"] as? Double ?? 0
                    let ind = d["industryAvg"] as? Double ?? 0
                    return CompetitiveBenchmark(
                        id: UUID().uuidString,
                        metric: d["metric"] as? String ?? "",
                        myChannel: mc,
                        industryAvg: ind,
                        topCompetitor: d["topCompetitor"] as? Double ?? 0,
                        gap: mc - ind,
                        trend: d["trend"] as? String ?? "stable"
                    )
                }
            }
            marketPenetration = result["marketPenetration"] as? Double ?? 0
        }
    }
}
