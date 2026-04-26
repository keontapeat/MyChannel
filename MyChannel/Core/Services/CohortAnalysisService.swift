//
//  CohortAnalysisService.swift
//  MyChannel
//
//  Cohort Analysis Dashboard - Track user cohorts over time, retention by cohort
//

import Foundation
import Combine

@MainActor
class CohortAnalysisService: ObservableObject {
    static let shared = CohortAnalysisService()
    
    @Published private(set) var cohorts: [UserCohort] = []
    @Published private(set) var retentionMatrix: [[Double]] = []
    @Published private(set) var avgRetentionByPeriod: [Double] = []
    
    struct UserCohort: Identifiable, Codable {
        let id: String
        let name: String
        let cohortDate: Date
        let userCount: Int
        let retentionRates: [Double]
        let avgLTV: Double
    }
    
    private init() {
        Task { await loadCohortData() }
    }
    
    func loadCohortData() async {
        guard AppConfig.Features.enableAnalytics else { return }
        
        struct Req: Encodable { let task: String }
        struct RawCohort: Decodable { let id: String; let name: String; let cohortDate: String; let userCount: Int; let retentionRates: [Double]; let avgLTV: Double }
        struct Raw: Decodable { let cohorts: [RawCohort]?; let retentionMatrix: [[Double]]?; let avgRetentionByPeriod: [Double]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_cohort_analysis"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            cohorts = (r.cohorts ?? []).map {
                UserCohort(
                    id: $0.id,
                    name: $0.name,
                    cohortDate: decoder.date(from: $0.cohortDate) ?? Date(),
                    userCount: $0.userCount,
                    retentionRates: $0.retentionRates,
                    avgLTV: $0.avgLTV
                )
            }.sorted { $0.cohortDate > $1.cohortDate }
            
            retentionMatrix = r.retentionMatrix ?? []
            avgRetentionByPeriod = r.avgRetentionByPeriod ?? []
            
        } catch {
            print("⚠️ [CohortAnalysis] Error: \(error)")
        }
    }
}
