//
//  UserSegmentationService.swift
//  MyChannel
//
//  User Segmentation Explorer - Custom segments, behavior analysis, campaign testing
//

import Foundation
import Combine

@MainActor
class UserSegmentationService: ObservableObject {
    static let shared = UserSegmentationService()
    
    @Published private(set) var customSegments: [UserSegment] = []
    @Published private(set) var segmentAnalysis: [SegmentAnalysis] = []
    
    struct UserSegment: Identifiable, Codable {
        let id: String
        let name: String
        let description: String
        let criteria: [SegmentCriteria]
        let userCount: Int
        let createdAt: Date
        let isActive: Bool
    }
    
    struct SegmentCriteria: Codable {
        let field: String
        let `operator`: String
        let value: String
    }
    
    struct SegmentAnalysis: Identifiable, Codable {
        let id: String
        let segmentId: String
        let segmentName: String
        let avgSessionTime: Double
        let retentionRate: Double
        let conversionRate: Double
        let topBehaviors: [String]
        let ltv: Double
    }
    
    private init() {
        Task { await loadSegments() }
    }
    
    func loadSegments() async {
        guard AppConfig.Features.enableUserSegmentation else { return }
        
        struct Req: Encodable { let task: String }
        struct RawSeg: Decodable { let id: String; let name: String; let description: String; let criteria: [SegmentCriteria]; let userCount: Int; let createdAt: String; let isActive: Bool }
        struct RawAnalysis: Decodable { let id: String; let segmentId: String; let segmentName: String; let avgSessionTime: Double; let retentionRate: Double; let conversionRate: Double; let topBehaviors: [String]; let ltv: Double }
        struct Raw: Decodable { let customSegments: [RawSeg]?; let segmentAnalysis: [RawAnalysis]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_user_segments"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            customSegments = (r.customSegments ?? []).map {
                UserSegment(
                    id: $0.id,
                    name: $0.name,
                    description: $0.description,
                    criteria: $0.criteria,
                    userCount: $0.userCount,
                    createdAt: decoder.date(from: $0.createdAt) ?? Date(),
                    isActive: $0.isActive
                )
            }
            
            segmentAnalysis = (r.segmentAnalysis ?? []).map {
                SegmentAnalysis(
                    id: $0.id,
                    segmentId: $0.segmentId,
                    segmentName: $0.segmentName,
                    avgSessionTime: $0.avgSessionTime,
                    retentionRate: $0.retentionRate,
                    conversionRate: $0.conversionRate,
                    topBehaviors: $0.topBehaviors,
                    ltv: $0.ltv
                )
            }
            
        } catch {
            print("⚠️ [UserSegmentation] Error: \(error)")
        }
    }
    
    func createSegment(name: String, description: String, criteria: [SegmentCriteria]) async throws -> String {
        struct Req: Encodable { let task: String; let name: String; let description: String; let criteria: [SegmentCriteria] }
        struct Raw: Decodable { let segmentId: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "create_user_segment", name: name, description: description, criteria: criteria), timeout: 30)
        guard let segId = r.segmentId else { throw NSError(domain: "UserSegmentation", code: -1, userInfo: nil) }
        await loadSegments()
        return segId
    }
    
    func analyzeSegment(segmentId: String) async throws {
        struct Req: Encodable { let task: String; let segmentId: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "analyze_segment", segmentId: segmentId), timeout: 30)
        guard r.success == true else { throw NSError(domain: "UserSegmentation", code: -1, userInfo: nil) }
        await loadSegments()
    }
}
