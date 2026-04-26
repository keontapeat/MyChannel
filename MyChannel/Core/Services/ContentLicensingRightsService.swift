//
//  ContentLicensingRightsService.swift
//  MyChannel
//
//  Phase 272: Content Licensing and Rights Management
//  Manages content licensing, rights holders, royalty distribution
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class ContentLicensingRightsService: ObservableObject {
    static let shared = ContentLicensingRightsService()
    
    @Published private(set) var licensedContent: [LicensedContent] = []
    @Published private(set) var rightsHolders: [RightsHolder] = []
    @Published private(set) var royaltyPayouts: [RoyaltyPayout] = []
    @Published private(set) var pendingApprovals: Int = 0
    
    struct LicensedContent: Identifiable, Codable {
        let id: String
        let contentId: String
        let title: String
        let licenseType: String
        let rightsHolder: String
        let startDate: Date
        let endDate: Date?
        let territory: String
        let revenueShare: Double
        let status: String
    }
    
    struct RightsHolder: Identifiable, Codable {
        let id: String
        let name: String
        let organization: String
        let contentCount: Int
        let totalRoyalties: Double
        let lastPayoutDate: Date?
    }
    
    struct RoyaltyPayout: Identifiable, Codable {
        let id: String
        let rightsHolderId: String
        let amount: Double
        let period: String
        let status: String
        let processedDate: Date?
    }
    
    private init() {
        Task { await loadLicensingData() }
    }
    
    func loadLicensingData() async {
        guard AppConfig.Features.enableContentLicensingOutbound else { return }
        
        struct Req: Encodable { let task: String }
        struct RawContent: Decodable { let id: String; let contentId: String; let title: String; let licenseType: String; let rightsHolder: String; let startDate: String; let endDate: String?; let territory: String; let revenueShare: Double; let status: String }
        struct RawHolder: Decodable { let id: String; let name: String; let organization: String; let contentCount: Int; let totalRoyalties: Double; let lastPayoutDate: String? }
        struct RawPayout: Decodable { let id: String; let rightsHolderId: String; let amount: Double; let period: String; let status: String; let processedDate: String? }
        struct Raw: Decodable { let licensedContent: [RawContent]?; let rightsHolders: [RawHolder]?; let royaltyPayouts: [RawPayout]?; let pendingApprovals: Int? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
                body: Req(task: "get_licensing_data"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            licensedContent = (r.licensedContent ?? []).map {
                LicensedContent(
                    id: $0.id,
                    contentId: $0.contentId,
                    title: $0.title,
                    licenseType: $0.licenseType,
                    rightsHolder: $0.rightsHolder,
                    startDate: decoder.date(from: $0.startDate) ?? Date(),
                    endDate: $0.endDate != nil ? decoder.date(from: $0.endDate!) : nil,
                    territory: $0.territory,
                    revenueShare: $0.revenueShare,
                    status: $0.status
                )
            }
            
            rightsHolders = (r.rightsHolders ?? []).map {
                RightsHolder(
                    id: $0.id,
                    name: $0.name,
                    organization: $0.organization,
                    contentCount: $0.contentCount,
                    totalRoyalties: $0.totalRoyalties,
                    lastPayoutDate: $0.lastPayoutDate != nil ? decoder.date(from: $0.lastPayoutDate!) : nil
                )
            }
            
            royaltyPayouts = (r.royaltyPayouts ?? []).map {
                RoyaltyPayout(
                    id: $0.id,
                    rightsHolderId: $0.rightsHolderId,
                    amount: $0.amount,
                    period: $0.period,
                    status: $0.status,
                    processedDate: $0.processedDate != nil ? decoder.date(from: $0.processedDate!) : nil
                )
            }
            
            pendingApprovals = r.pendingApprovals ?? 0
            
        } catch {
            print("⚠️ [ContentLicensingRights] Error: \(error)")
        }
    }
    
    func approveLicense(contentId: String) async throws {
        struct Req: Encodable { let task: String; let contentId: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "approve_license", contentId: contentId), timeout: 20)
        guard r.success == true else { throw NSError(domain: "ContentLicensing", code: -1, userInfo: nil) }
        await loadLicensingData()
    }
}
