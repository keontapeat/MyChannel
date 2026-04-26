//
//  AdvancedFraudDetectionService.swift
//  MyChannel
//
//  Phase 178: Advanced Fraud Detection.
//  View bot detection, click fraud prevention, creator protection.
//  Uses `trust-safety-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct FraudReport: Codable, Identifiable {
    let id: String
    let videoId: String
    let totalViews: Int
    let suspiciousViews: Int
    let botConfidence: Double
    let fraudType: FraudType
    let details: String
    let detectedAt: Date
}

enum FraudType: String, Codable {
    case viewBot, clickFarm, selfClicking, coordinatedAttack, adFraud, subscriberBot
}

struct ViewIntegrityScore: Codable, Identifiable {
    let id: String
    let videoId: String
    let legitimatePercent: Double
    let flaggedPercent: Double
    let removedViews: Int
    let scoreTimestamp: Date
}

// MARK: - Service

@MainActor
final class AdvancedFraudDetectionService: ObservableObject {
    static let shared = AdvancedFraudDetectionService()
    private init() {}

    @Published private(set) var reports: [FraudReport] = []
    @Published private(set) var integrityScore: ViewIntegrityScore?
    @Published var isScanning: Bool = false

    func scanVideo(videoId: String) async throws -> FraudReport {
        guard AppConfig.Features.enableAdvancedFraudDetection else {
            return FraudReport(id: "", videoId: videoId, totalViews: 0, suspiciousViews: 0,
                             botConfidence: 0, fraudType: .viewBot, details: "disabled", detectedAt: Date())
        }
        isScanning = true
        defer { isScanning = false }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let total: Int?; let suspicious: Int?; let confidence: Double?; let type: String?; let details: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "fraud_detection", videoId: videoId), timeout: 30
        )
        let report = FraudReport(
            id: UUID().uuidString, videoId: videoId,
            totalViews: r.total ?? 0, suspiciousViews: r.suspicious ?? 0,
            botConfidence: r.confidence ?? 0,
            fraudType: FraudType(rawValue: r.type ?? "") ?? .viewBot,
            details: r.details ?? "", detectedAt: Date()
        )
        reports.append(report)
        return report
    }

    func checkIntegrity(videoId: String) async throws -> ViewIntegrityScore {
        guard AppConfig.Features.enableAdvancedFraudDetection else {
            return ViewIntegrityScore(id: videoId, videoId: videoId, legitimatePercent: 100, flaggedPercent: 0, removedViews: 0, scoreTimestamp: Date())
        }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let legitimate: Double?; let flagged: Double?; let removed: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .trustSafetyAI, path: "/predict",
            body: Request(task: "view_integrity", videoId: videoId)
        )
        let score = ViewIntegrityScore(
            id: videoId, videoId: videoId,
            legitimatePercent: r.legitimate ?? 100, flaggedPercent: r.flagged ?? 0,
            removedViews: r.removed ?? 0, scoreTimestamp: Date()
        )
        integrityScore = score
        return score
    }
}
