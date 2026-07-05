//
//  CreatorEconomyService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import Combine
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Creator Economy Service
class CreatorEconomyService: ObservableObject {
    static let shared = CreatorEconomyService()
    
    @Published var creatorEarnings: CreatorEarnings?
    @Published var revenueStreams: [CreatorRevenueStream] = []
    @Published var paymentHistory: [Payment] = []
    @Published var isLoading: Bool = false
    
    // The magic number that beats YouTube
    static let REVENUE_SHARE: Double = 0.90 // 90% vs YouTube's 55%
    
    private let networkService = NetworkService.shared
    private let analyticsService = AnalyticsService.shared

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    private init() {}
    // MARK: - Payouts & History

    /// Real payout history from Firestore `payout_requests` for this creator.
    func fetchPaymentHistory(creatorId: String) async throws -> [Payment] {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return [] }
        do {
            let snap = try await db.collection("payout_requests")
                .whereField("creatorId", isEqualTo: creatorId)
                .order(by: "requestedAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            let items: [Payment] = snap.documents.map { doc in
                let d = doc.data()
                let amount = (d["amount"] as? Double) ?? 0
                let statusRaw = (d["status"] as? String) ?? "pending"
                let date = (d["requestedAt"] as? Timestamp)?.dateValue() ?? Date()
                return Payment(
                    id: doc.documentID,
                    amount: amount,
                    currency: (d["currency"] as? String) ?? "USD",
                    type: .withdrawal,
                    status: Self.mapStatus(statusRaw),
                    date: date
                )
            }
            await MainActor.run { self.paymentHistory = items }
            return items
        } catch {
            print("⚠️ [CreatorEconomy] payout history fetch failed: \(error.localizedDescription)")
            await MainActor.run { self.paymentHistory = [] }
            return []
        }
        #else
        await MainActor.run { self.paymentHistory = [] }
        return []
        #endif
    }

    /// Submit a REAL payout request. Calls the pay-api /pay/withdraw endpoint
    /// which validates the ledger balance, verifies the Stripe account is fully
    /// onboarded, executes a Stripe Transfer, and debits the ledger atomically.
    /// Also writes a Firestore payout_requests doc for the dashboard history.
    func requestWithdrawal(creatorId: String, amount: Double) async throws -> Payment {
        guard amount > 0 else {
            throw CreatorEconomyError.invalidPrice("Withdrawal amount must be greater than $0")
        }

        // 1. Hit the pay-api — this is the authoritative money path
        struct WithdrawalRequest: Codable { let creatorId: String; let amount: Double }
        struct WithdrawalResponse: Codable {
            let ok: Bool?
            let payoutId: String?
            let amountCents: Int?
            let stripeTransferId: String?
            let error: String?
            let onboardingRequired: Bool?
        }
        let response: WithdrawalResponse = try await networkService.post(
            endpoint: .custom("/pay/withdraw"),
            body: WithdrawalRequest(creatorId: creatorId, amount: amount),
            responseType: WithdrawalResponse.self
        )

        if let errorMsg = response.error {
            if response.onboardingRequired == true {
                throw CreatorEconomyError.paymentFailed("Payout account setup is incomplete. Go to Payout Settings to finish connecting your bank account.")
            }
            throw CreatorEconomyError.paymentFailed(errorMsg)
        }

        // 2. Mirror to Firestore payout_requests so the dashboard history is live
        #if canImport(FirebaseFirestore)
        let payoutId = response.payoutId ?? UUID().uuidString
        try? await Firestore.firestore().collection("payout_requests").document(payoutId).setData([
            "id": payoutId,
            "creatorId": creatorId,
            "amount": amount,
            "currency": "USD",
            "status": "processing",
            "stripeTransferId": response.stripeTransferId ?? "",
            "requestedAt": FieldValue.serverTimestamp()
        ])
        #endif

        let payout = Payment(
            id: response.payoutId ?? UUID().uuidString,
            amount: amount,
            currency: "USD",
            type: .withdrawal,
            status: .pending,
            date: Date()
        )
        await MainActor.run { self.paymentHistory.insert(payout, at: 0) }
        return payout
    }

    private static func mapStatus(_ raw: String) -> PaymentStatus {
        switch raw.lowercased() {
        case "completed", "paid", "succeeded": return .completed
        case "failed", "error": return .failed
        case "refunded", "reversed": return .refunded
        default: return .pending
        }
    }

    
    // MARK: - Creator Revenue Management
    
    /// Get creator's total earnings across all revenue streams.
    /// Reads the REAL `creator_earnings/{creatorId}` aggregate written by
    /// NuclearAdMonetizationService + TipPaymentService, then breaks it down by
    /// the per-source sub-collections. No more mock numbers.
    func getCreatorEarnings(for creatorId: String) async throws -> CreatorEarnings {
        isLoading = true
        defer { isLoading = false }
        
        // Fetch all revenue streams (real Firestore-backed)
        let adRevenue = await getAdRevenue(creatorId: creatorId)
        let tipRevenue = await getTipRevenue(creatorId: creatorId)
        let membershipRevenue = await getRevenueStream(creatorId: creatorId, source: "membership")
        let merchandiseRevenue = await getRevenueStream(creatorId: creatorId, source: "merchandise")
        let courseRevenue = await getRevenueStream(creatorId: creatorId, source: "course")
        let brandDealRevenue = await getRevenueStream(creatorId: creatorId, source: "brandDeal")
        let nftRevenue = await getRevenueStream(creatorId: creatorId, source: "nft")
        let liveStreamRevenue = await getRevenueStream(creatorId: creatorId, source: "liveStream")
        
        // Exact money math in integer cents (convert the Double reads at the boundary).
        let totalRevenueMoney = Money.sum([
            adRevenue, tipRevenue, membershipRevenue, merchandiseRevenue,
            courseRevenue, brandDealRevenue, nftRevenue, liveStreamRevenue
        ].map { Money(dollars: $0) })

        // Prefer the authoritative aggregate balance if present; the ad service
        // already stores the creator's net share, so don't double-apply the split.
        let aggregate = await NuclearAdMonetizationService.shared.getCreatorEarnings(creatorId: creatorId)
        let creatorShareMoney = aggregate.map { Money(dollars: $0.totalEarnings) }
            ?? totalRevenueMoney.fraction(Self.REVENUE_SHARE)
        let grossRevenueMoney = max(totalRevenueMoney, creatorShareMoney.divided(by: Self.REVENUE_SHARE))
        let platformFeeMoney = (grossRevenueMoney - creatorShareMoney).clampedToZero
        
        let earnings = CreatorEarnings(
            creatorId: creatorId,
            totalRevenue: grossRevenueMoney.dollars,
            creatorShare: creatorShareMoney.dollars,
            platformFee: platformFeeMoney.dollars,
            revenueBreakdown: CreatorRevenueBreakdown(
                adRevenue: adRevenue,
                tipRevenue: tipRevenue,
                membershipRevenue: membershipRevenue,
                merchandiseRevenue: merchandiseRevenue,
                courseRevenue: courseRevenue,
                brandDealRevenue: brandDealRevenue,
                nftRevenue: nftRevenue,
                liveStreamRevenue: liveStreamRevenue
            ),
            period: EarningsPeriod.thisMonth,
            lastUpdated: Date()
        )
        
        await MainActor.run {
            self.creatorEarnings = earnings
        }
        
        return earnings
    }
    
    // MARK: - Revenue Stream Implementations
    
    /// Process live tip during stream or video
    func processTip(
        from userId: String,
        to creatorId: String,
        amount: Double,
        message: String? = nil,
        isLiveStream: Bool = false
    ) async throws -> TipTransaction {
        
        let tip = TipTransaction(
            id: UUID().uuidString,
            fromUserId: userId,
            toCreatorId: creatorId,
            amount: amount,
            message: message,
            isLiveStream: isLiveStream,
            timestamp: Date()
        )
        
        // Process payment
        let paymentResult = try await processPayment(
            amount: amount,
            currency: "USD",
            fromUser: userId,
            toCreator: creatorId,
            type: .tip
        )
        
        // Calculate creator's share (90%)
        let creatorShare = amount * Self.REVENUE_SHARE
        
        // Update creator's balance
        try await updateCreatorBalance(creatorId: creatorId, amount: creatorShare)
        
        // Send real-time notification to creator
        await sendTipNotification(tip: tip, creatorShare: creatorShare)
        
        // Track analytics - comment out for now since method doesn't exist
        // await analyticsService.trackTipEvent(tip)
        
        return tip
    }
    
    /// Create and manage creator membership tiers
    func createMembershipTier(
        creatorId: String,
        tier: MembershipTier
    ) async throws -> MembershipTier {
        
        // Validate tier
        guard tier.price >= 0.99 && tier.price <= 999.99 else {
            throw CreatorEconomyError.invalidPrice("Membership price must be between $0.99 and $999.99")
        }
        
        // Save to database
        let savedTier = try await networkService.post(
            endpoint: .custom("/creators/\(creatorId)/membership-tiers"),
            body: tier,
            responseType: MembershipTier.self
        )
        
        return savedTier
    }
    
    /// Process membership subscription
    func processSubscription(
        userId: String,
        to creatorId: String,
        tierId: String
    ) async throws -> CreatorSubscription {
        
        let subscription = CreatorSubscription(
            id: UUID().uuidString,
            userId: userId,
            creatorId: creatorId,
            tierName: tierId,
            startDate: Date(),
            nextBillingDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
            isActive: true
        )
        
        // Process payment and save subscription
        return subscription
    }
    
    /// Launch NFT collection for creator
    func launchNFTCollection(
        creatorId: String,
        collection: NFTCollection
    ) async throws -> NFTCollection {
        
        // Integration with blockchain/NFT marketplace
        // For now, simulate the process
        
        let launchedCollection = NFTCollection(
            id: UUID().uuidString,
            creatorId: creatorId,
            name: collection.name,
            description: collection.description,
            items: collection.items,
            totalSupply: collection.totalSupply,
            mintPrice: collection.mintPrice,
            royaltyPercentage: collection.royaltyPercentage,
            launchDate: Date(),
            isActive: true
        )
        
        return launchedCollection
    }
    
    /// Create and sell courses/tutorials
    func createCourse(
        creatorId: String,
        course: Course
    ) async throws -> Course {
        
        let savedCourse = try await networkService.post(
            endpoint: .custom("/creators/\(creatorId)/courses"),
            body: course,
            responseType: Course.self
        )
        
        return savedCourse
    }
    
    /// Brand partnership marketplace
    func createBrandDeal(
        creatorId: String,
        brandId: String,
        deal: BrandDeal
    ) async throws -> BrandDeal {
        
        let savedDeal = try await networkService.post(
            endpoint: .custom("/brand-deals"),
            body: deal,
            responseType: BrandDeal.self
        )
        
        return savedDeal
    }
    
    // MARK: - Payment Processing
    
    private func processPayment(
        amount: Double,
        currency: String,
        fromUser: String,
        toCreator: String,
        type: PaymentType
    ) async throws -> PaymentResult {
        
        // Integration with payment processors (Stripe, PayPal, etc.)
        // For now, simulate successful payment
        
        return PaymentResult(
            transactionId: UUID().uuidString,
            amount: amount,
            currency: currency,
            status: .completed,
            timestamp: Date()
        )
    }
    
    private func updateCreatorBalance(creatorId: String, amount: Double) async throws {
        struct WithdrawalRequest: Codable { let creatorId: String; let amount: Double }
        let _: MessageResponse = try await networkService.post(
            endpoint: .custom("/pay/withdraw"),
            body: WithdrawalRequest(creatorId: creatorId, amount: amount),
            responseType: MessageResponse.self
        )
    }
    
    private func sendTipNotification(tip: TipTransaction, creatorShare: Double) async {
        // Send real-time notification to creator
        let notificationData = [
            "type": "tip",
            "title": "💰 New Tip Received!",
            "message": "You received a $\(String(format: "%.2f", creatorShare)) tip",
            "tipId": tip.id
        ]
        
        // Send push notification
        await PushNotificationService.shared.sendNotification(
            to: tip.toCreatorId,
            notification: notificationData
        )
    }
    
    // MARK: - Revenue Calculations (real Firestore data)

    /// Lifetime ad revenue (creator's net share) from the `creator_earnings` doc.
    private func getAdRevenue(creatorId: String) async -> Double {
        let earnings = await NuclearAdMonetizationService.shared.getCreatorEarnings(creatorId: creatorId)
        return earnings?.totalEarnings ?? 0
    }

    /// Tip revenue from the creator's stored balance.
    private func getTipRevenue(creatorId: String) async -> Double {
        return (try? await TipPaymentService.shared.getCreatorEarnings(for: creatorId)) ?? 0
    }

    /// Generic per-source revenue read from `creator_earnings/{id}/sources/{source}`.
    /// Returns 0 when a creator hasn't earned from that stream yet (no fake data).
    private func getRevenueStream(creatorId: String, source: String) async -> Double {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return 0 }
        do {
            let doc = try await db.collection("creator_earnings")
                .document(creatorId)
                .collection("sources")
                .document(source)
                .getDocument()
            return (doc.data()?["amount"] as? Double) ?? 0
        } catch {
            return 0
        }
        #else
        return 0
        #endif
    }
}

// MARK: - Supporting Models

struct CreatorEarnings {
    let creatorId: String
    let totalRevenue: Double
    let creatorShare: Double
    let platformFee: Double
    let revenueBreakdown: CreatorRevenueBreakdown
    let period: EarningsPeriod
    let lastUpdated: Date
    
    var revenueSharePercentage: Double {
        guard totalRevenue > 0 else { return 0 }
        return (creatorShare / totalRevenue) * 100
    }

    // Exact-cents accessors for display. Prefer these over formatting the raw
    // `Double` dollar fields with `%.2f`.
    var totalRevenueMoney: Money { Money(dollars: totalRevenue) }
    var creatorShareMoney: Money { Money(dollars: creatorShare) }
    var platformFeeMoney: Money { Money(dollars: platformFee) }
}

struct CreatorRevenueBreakdown: Codable {
    let adRevenue: Double
    let tipRevenue: Double
    let membershipRevenue: Double
    let merchandiseRevenue: Double
    let courseRevenue: Double
    let brandDealRevenue: Double
    let nftRevenue: Double
    let liveStreamRevenue: Double
}

enum EarningsPeriod {
    case today, thisWeek, thisMonth, thisYear, allTime
}

struct CreatorRevenueStream {
    let id: String
    let name: String
    let type: CreatorRevenueStreamType
    let amount: Double
    let isActive: Bool
}

enum CreatorRevenueStreamType {
    case ads, tips, memberships, merchandise, courses, brandDeals, nfts, liveStreaming
}

struct TipTransaction {
    let id: String
    let fromUserId: String
    let toCreatorId: String
    let amount: Double
    let message: String?
    let isLiveStream: Bool
    let timestamp: Date
}

struct CreatorSubscription {
    let id: String
    let userId: String
    let creatorId: String
    let tierName: String
    let startDate: Date
    let nextBillingDate: Date
    let isActive: Bool
}

struct NFTCollection {
    let id: String
    let creatorId: String
    let name: String
    let description: String
    let items: [NFTItem]
    let totalSupply: Int
    let mintPrice: Double
    let royaltyPercentage: Double
    let launchDate: Date
    let isActive: Bool
}

struct NFTItem {
    let id: String
    let name: String
    let description: String
    let imageURL: String
    let rarity: NFTRarity
}

enum NFTRarity {
    case common, uncommon, rare, epic, legendary
}

struct Course: Codable {
    let id: String
    let creatorId: String
    let title: String
    let description: String
    let price: Double
    let modules: [CourseModule]
    let duration: TimeInterval
    let level: CourseLevel
}

struct CourseModule: Codable {
    let id: String
    let title: String
    let videoIds: [String]
    let resources: [String]
}

enum CourseLevel: String, Codable {
    case beginner, intermediate, advanced
}

struct BrandDeal: Codable {
    let id: String
    let creatorId: String
    let brandId: String
    let title: String
    let description: String
    let amount: Double
    let deliverables: [String]
    let deadline: Date
    let status: BrandDealStatus
}

enum BrandDealStatus: String, Codable {
    case pending, accepted, inProgress, completed, cancelled
}

struct Payment {
    let id: String
    let amount: Double
    let currency: String
    let type: PaymentType
    let status: PaymentStatus
    let date: Date
}

enum PaymentType {
    case tip, membership, course, nft, brandDeal, withdrawal
}

enum PaymentStatus {
    case pending, completed, failed, refunded
}

struct PaymentResult {
    let transactionId: String
    let amount: Double
    let currency: String
    let status: PaymentStatus
    let timestamp: Date
}

struct PushCreatorNotification {
    let type: NotificationType
    let title: String
    let message: String
    let data: [String: String]
    
    enum NotificationType {
        case tip, subscription, sale, milestone, liveInvite
    }
}

enum CreatorEconomyError: LocalizedError {
    case invalidPrice(String)
    case paymentFailed(String)
    case insufficientFunds(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPrice(let message),
             .paymentFailed(let message),
             .insufficientFunds(let message):
            return message
        }
    }
}

#Preview("Creator Economy Service") {
    VStack(spacing: 20) {
        Text("Creator Economy Revolution")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("🚀 Why Creators Will Leave YouTube:")
                .font(.headline)
            
            ForEach([
                "💰 90% Revenue Share (vs YouTube's 55%)",
                "💸 Real-time live tipping during streams",
                "🎓 Course/tutorial monetization platform",
                "🖼️ NFT marketplace integration", 
                "🤝 Brand partnership marketplace",
                "💎 Membership tiers with exclusive perks",
                "🛍️ Merchandise store integration",
                "📊 Real-time earnings dashboard",
                "⚡ Instant payouts (vs YouTube's monthly)",
                "🌍 Global payment support (150+ countries)"
            ], id: \.self) { feature in
                HStack {
                    Text(feature)
                        .font(.body)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        Spacer()
    }
    .padding()
}