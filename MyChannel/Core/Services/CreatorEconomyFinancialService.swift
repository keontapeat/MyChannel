//
//  CreatorEconomyFinancialService.swift
//  MyChannel
//
//  Phase 277: Creator Economy Financial Dashboard
//  Tracks creator earnings, payouts, token economy, marketplace metrics
//

import Foundation
import Combine

@MainActor
class CreatorEconomyFinancialService: ObservableObject {
    static let shared = CreatorEconomyFinancialService()
    
    @Published private(set) var creatorEarnings: [CreatorEarnings] = []
    @Published private(set) var tokenMetrics: [TokenMetric] = []
    @Published private(set) var totalCreatorPayouts: Double = 0
    @Published private(set) var pendingPayouts: Int = 0
    
    struct CreatorEarnings: Identifiable, Codable {
        let id: String
        let creatorId: String
        let creatorName: String
        let earningsThisMonth: Double
        let earningsTotal: Double
        let payoutStatus: String
        let lastPayoutDate: Date?
        let nextPayoutDate: Date
    }
    
    struct TokenMetric: Identifiable, Codable {
        let id: String
        let tokenSymbol: String
        let totalSupply: Int
        let circulatingSupply: Int
        let currentPrice: Double
        let marketCap: Double
        let tradingVolume: Double
    }
    
    private init() {
        Task { await loadFinancialData() }
    }
    
    func loadFinancialData() async {
        guard AppConfig.Features.enableCreatorTokens else { return }
        
        struct Req: Encodable { let task: String }
        struct RawEarnings: Decodable { let id: String; let creatorId: String; let creatorName: String; let earningsThisMonth: Double; let earningsTotal: Double; let payoutStatus: String; let lastPayoutDate: String?; let nextPayoutDate: String }
        struct RawToken: Decodable { let id: String; let tokenSymbol: String; let totalSupply: Int; let circulatingSupply: Int; let currentPrice: Double; let marketCap: Double; let tradingVolume: Double }
        struct Raw: Decodable { let creatorEarnings: [RawEarnings]?; let tokenMetrics: [RawToken]?; let totalCreatorPayouts: Double?; let pendingPayouts: Int? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.creatorFundAllocator, path: "/predict",
                body: Req(task: "get_creator_economy_financials"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            creatorEarnings = (r.creatorEarnings ?? []).map {
                CreatorEarnings(
                    id: $0.id,
                    creatorId: $0.creatorId,
                    creatorName: $0.creatorName,
                    earningsThisMonth: $0.earningsThisMonth,
                    earningsTotal: $0.earningsTotal,
                    payoutStatus: $0.payoutStatus,
                    lastPayoutDate: $0.lastPayoutDate != nil ? decoder.date(from: $0.lastPayoutDate!) : nil,
                    nextPayoutDate: decoder.date(from: $0.nextPayoutDate) ?? Date()
                )
            }.sorted { $0.earningsThisMonth > $1.earningsThisMonth }
            
            tokenMetrics = (r.tokenMetrics ?? []).map {
                TokenMetric(
                    id: $0.id,
                    tokenSymbol: $0.tokenSymbol,
                    totalSupply: $0.totalSupply,
                    circulatingSupply: $0.circulatingSupply,
                    currentPrice: $0.currentPrice,
                    marketCap: $0.marketCap,
                    tradingVolume: $0.tradingVolume
                )
            }
            
            totalCreatorPayouts = r.totalCreatorPayouts ?? 0
            pendingPayouts = r.pendingPayouts ?? 0
            
        } catch {
            print("⚠️ [CreatorEconomyFinancial] Error: \(error)")
        }
    }
    
    func processPayout(creatorId: String) async throws {
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.creatorFundAllocator, path: "/predict",
            body: Req(task: "process_payout", creatorId: creatorId), timeout: 30)
        guard r.success == true else { throw NSError(domain: "CreatorEconomy", code: -1, userInfo: nil) }
        await loadFinancialData()
    }
}
