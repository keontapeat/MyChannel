//
//  VersusMatchService.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  💰 REAL MONEY VS MATCHES - Let creators compete for cash!
//  UFC-style betting system worth $100M+ 🔥
//

import Foundation
import FirebaseFirestore

@MainActor
class VersusMatchService: ObservableObject, VersusMatching {
    static let shared = VersusMatchService()
    
    @Published var activeMatches: [VersusMatch] = []
    @Published var upcomingMatches: [VersusMatch] = []
    @Published var myMatches: [VersusMatch] = []
    @Published var featuredMatches: [VersusMatch] = []
    
    private let db = Firestore.firestore()
    @Injected private var escrowService: MoneyEscrowService
    
    /// Active match listeners, keyed by matchId, so we can avoid duplicate
    /// listeners and detach them (previously they leaked — attached, never removed).
    private var matchListeners: [String: ListenerRegistration] = [:]
    
    private init() {
        loadMatches()
    }
    
    deinit {
        matchListeners.values.forEach { $0.remove() }
    }
    
    // MARK: - 🎮 CREATE MATCH
    
    func createMatch(
        challengerId: String,
        opponentId: String,
        matchType: VersusMatch.MatchType,
        wagerAmount: Double,
        category: VersusMatch.Category,
        rules: VersusMatch.MatchRules,
        scheduledDate: Date
    ) async throws -> VersusMatch {
        
        print("🎮 Creating VS Match...")
        
        // Validate wager amount via shared policy (single source of truth)
        guard WagerPolicy.isValidWagerAmount(wagerAmount) else {
            throw MatchError.invalidWagerAmount
        }
        
        // 🔒 COMPLIANCE GATE — required before ANY money moves.
        // Enforces 18+, KYC (for $500+), terms acceptance, region allowlist,
        // account status, and daily wager limit. Throws ComplianceError (a
        // LocalizedError) surfaced to the UI. This is a client-side gate for UX;
        // the escrow Cloud Function MUST re-enforce these server-side (client
        // checks are never authoritative for money).
        _ = try await VSMatchComplianceService.shared.canUserWager(
            userId: challengerId,
            amount: wagerAmount
        )
        
        // 🤖 AI: Optimize match with Match Orchestrator Agent
        var optimizedRules = rules
        do {
            print("🤖 [Match Orchestrator] Optimizing match rules...")
            let orchestration = try await VertexAIAgentService.shared.orchestrateMatch(
                challengerId: challengerId,
                opponentId: opponentId,
                wagerAmount: wagerAmount
            )
            
            // Apply AI-optimized rules
            optimizedRules = VersusMatch.MatchRules(
                duration: orchestration.suggestedDuration,
                category: category,
                winCondition: rules.winCondition
            )
            
            print("✅ [Match Orchestrator] Match optimized: \(orchestration.suggestedDuration)s duration, fairness: \(orchestration.fairnessScore)")
        } catch {
            print("⚠️ [Match Orchestrator] AI unavailable, using default rules: \(error)")
            // Graceful degradation - continue with original rules
        }
        
        // Create match
        let match = VersusMatch(
            id: UUID().uuidString,
            challengerId: challengerId,
            opponentId: opponentId,
            matchType: matchType,
            wagerAmount: wagerAmount,
            category: category,
            rules: optimizedRules,
            status: .pending,
            createdAt: Date(),
            scheduledDate: scheduledDate
        )
        
        // Hold challenger's money in escrow
        try await escrowService.holdFunds(
            userId: challengerId,
            amount: wagerAmount,
            matchId: match.id
        )
        
        // Save to Firestore
        try await db.collection("versus_matches").document(match.id).setData([
            "challengerId": match.challengerId,
            "opponentId": match.opponentId,
            "matchType": match.matchType.rawValue,
            "wagerAmount": match.wagerAmount,
            "category": match.category.rawValue,
            "rules": try JSONEncoder().encode(match.rules).base64EncodedString(),
            "status": match.status.rawValue,
            "createdAt": Timestamp(date: match.createdAt),
            "scheduledDate": Timestamp(date: match.scheduledDate)
        ])
        
        print("✅ Match created! ID: \(match.id)")
        
        // Notify opponent
        await sendMatchInvite(match: match)
        
        return match
    }
    
    // MARK: - ✅ ACCEPT MATCH
    
    func acceptMatch(matchId: String, opponentId: String) async throws {
        print("✅ Accepting match...")
        
        guard let match = await fetchMatch(matchId: matchId) else {
            throw MatchError.matchNotFound
        }
        
        // 🔒 COMPLIANCE GATE — the opponent is also wagering real money by
        // accepting, so they must clear the same checks as the challenger
        // (18+, KYC for $500+, terms, region, account status, daily limit)
        // BEFORE their funds are held. Mirror server-side in the escrow function.
        _ = try await VSMatchComplianceService.shared.canUserWager(
            userId: opponentId,
            amount: match.wagerAmount
        )
        
        // Hold opponent's money in escrow
        try await escrowService.holdFunds(
            userId: opponentId,
            amount: match.wagerAmount,
            matchId: matchId
        )
        
        // Update match status
        try await db.collection("versus_matches").document(matchId).updateData([
            "status": VersusMatch.Status.accepted.rawValue,
            "acceptedAt": Timestamp(date: Date())
        ])
        
        print("✅ Match accepted! Both players' funds in escrow")
        
        // Schedule match start
        await scheduleMatchStart(match: match)
    }
    
    // MARK: - ❌ DECLINE MATCH
    
    func declineMatch(matchId: String) async throws {
        print("❌ Declining match...")
        
        guard let match = await fetchMatch(matchId: matchId) else {
            throw MatchError.matchNotFound
        }
        
        // Return the challenger's held funds. A declined match was never accepted,
        // so ONLY the challenger has funds in escrow — use refundFunds (cancels the
        // hold), NOT releaseFunds (which captures both legs and pays a "winner" and
        // would throw .noFundsHeld here since the opponent never funded escrow).
        try await escrowService.refundFunds(
            matchId: matchId,
            userId: match.challengerId
        )
        
        // Update status
        try await db.collection("versus_matches").document(matchId).updateData([
            "status": VersusMatch.Status.declined.rawValue,
            "declinedAt": Timestamp(date: Date())
        ])
        
        print("✅ Match declined, funds returned")
    }
    
    // MARK: - 🎬 START MATCH
    
    func startMatch(matchId: String) async throws {
        print("🎬 Starting match...")
        
        try await db.collection("versus_matches").document(matchId).updateData([
            "status": VersusMatch.Status.live.rawValue,
            "startedAt": Timestamp(date: Date())
        ])
        
        // Start monitoring for winner
        await monitorMatch(matchId: matchId)
    }
    
    // MARK: - 🏆 END MATCH
    
    func endMatch(
        matchId: String,
        winnerId: String,
        loserId: String,
        finalStats: VersusMatch.MatchStats
    ) async throws {
        
        print("🏆 Ending match...")
        
        guard let match = await fetchMatch(matchId: matchId) else {
            throw MatchError.matchNotFound
        }
        
        // Winnings preview in INTEGER CENTS (rounded). Only used for the local
        // release log — the authoritative payout is computed server-side from the
        // captured escrow legs, and winnerPayout/platformFee on the match doc are
        // written by /settle-match (those fields are admin/CF-write only now).
        let grossCents = MoneyMath.cents(fromDollars: match.wagerAmount) * 2
        let winnerPayout = MoneyMath.dollars(fromCents: MoneyMath.winnerPayoutCents(grossCents: grossCents))

        // 🔒 Server settles the match FIRST — it verifies the recorded
        // submissions and writes the authoritative status + winnerId. The client
        // can no longer declare the winner (rules block outcome-field writes).
        let settlement = try await escrowService.settleMatch(matchId: matchId)
        guard settlement.status == "completed", let verifiedWinnerId = settlement.winnerId else {
            // Sent to referee review — do not release funds.
            print("🔎 Match \(matchId) not auto-approved by server (status: \(settlement.status)) — awaiting review")
            stopMonitoring(matchId: matchId)
            throw MatchError.invalidData
        }
        let verifiedLoserId = settlement.loserId ?? loserId

        // Release funds to the SERVER-verified winner (backend derives amount +
        // destination from the recorded outcome + captured escrow legs).
        try await escrowService.releaseFunds(
            matchId: matchId,
            winnerId: verifiedWinnerId,
            loserId: verifiedLoserId,
            totalPot: winnerPayout
        )

        // Persist client-owned play stats only. Outcome + money fields
        // (status / winnerId / completedAt / winnerPayout / platformFee) are
        // written server-side by /settle-match.
        try await db.collection("versus_matches").document(matchId).updateData([
            "finalStats": try JSONEncoder().encode(finalStats).base64EncodedString()
        ])
        
        // 🔒 Player stats, earnings, and championship points are written
        // SERVER-SIDE by the escrow settlement function (/create-transfer), which
        // runs once per verified, paid-out match. We intentionally do NOT write
        // them from the client — client-writable stats were forgeable (a user
        // could inflate their own wins/earnings/points directly). Firestore rules
        // now make player_stats / championship_rankings admin-write only.
        
        // Match is over — detach its real-time listener so it doesn't leak.
        stopMonitoring(matchId: matchId)
        
        print("✅ Match completed! Winner: \(winnerId), Payout: $\(winnerPayout)")
    }
    
    // MARK: - 📊 FETCH MATCHES
    
    func fetchMatch(matchId: String) async -> VersusMatch? {
        do {
            let doc = try await db.collection("versus_matches").document(matchId).getDocument()
            guard let data = doc.data() else { return nil }
            
            return try parseMatch(from: data, id: doc.documentID)
        } catch {
            print("❌ Error fetching match: \(error)")
            return nil
        }
    }
    
    func fetchActiveMatches() async throws -> [VersusMatch] {
        let snapshot = try await db.collection("versus_matches")
            .whereField("status", in: ["live", "accepted"])
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try parseMatch(from: doc.data(), id: doc.documentID)
        }
    }
    
    func fetchUpcomingMatches() async throws -> [VersusMatch] {
        let snapshot = try await db.collection("versus_matches")
            .whereField("status", isEqualTo: "accepted")
            .order(by: "scheduledDate", descending: false)
            .limit(to: 50)
            .getDocuments()
        
        return try snapshot.documents.compactMap { doc in
            try parseMatch(from: doc.data(), id: doc.documentID)
        }
    }
    
    func fetchMyMatches(userId: String) async throws -> [VersusMatch] {
        // Fetch challenger and opponent matches in parallel
        async let challengerFetch = db.collection("versus_matches")
            .whereField("challengerId", isEqualTo: userId)
            .getDocuments()
        async let opponentFetch = db.collection("versus_matches")
            .whereField("opponentId", isEqualTo: userId)
            .getDocuments()
        
        let (snapshot, snapshot2) = try await (challengerFetch, opponentFetch)
        
        var matches = try snapshot.documents.compactMap { doc in
            try parseMatch(from: doc.data(), id: doc.documentID)
        }
        
        matches += try snapshot2.documents.compactMap { doc in
            try parseMatch(from: doc.data(), id: doc.documentID)
        }
        
        return matches.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - 🎯 HELPER FUNCTIONS
    
    private func parseMatch(from data: [String: Any], id: String) throws -> VersusMatch {
        guard let challengerId = data["challengerId"] as? String,
              let opponentId = data["opponentId"] as? String,
              let matchTypeString = data["matchType"] as? String,
              let matchType = VersusMatch.MatchType(rawValue: matchTypeString),
              let wagerAmount = data["wagerAmount"] as? Double,
              let categoryString = data["category"] as? String,
              let category = VersusMatch.Category(rawValue: categoryString),
              let statusString = data["status"] as? String,
              let status = VersusMatch.Status(rawValue: statusString),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let scheduledDate = (data["scheduledDate"] as? Timestamp)?.dateValue()
        else {
            throw MatchError.invalidData
        }
        
        // Decode stored rules; fall back to defaults if data is missing or malformed
        let rules: VersusMatch.MatchRules
        if let rulesString = data["rules"] as? String,
           let rulesData = Data(base64Encoded: rulesString),
           let decoded = try? JSONDecoder().decode(VersusMatch.MatchRules.self, from: rulesData) {
            rules = decoded
        } else {
            rules = VersusMatch.MatchRules(duration: 3600, category: category, winCondition: .mostViews)
        }
        
        return VersusMatch(
            id: id,
            challengerId: challengerId,
            opponentId: opponentId,
            matchType: matchType,
            wagerAmount: wagerAmount,
            category: category,
            rules: rules,
            status: status,
            winnerId: data["winnerId"] as? String,
            createdAt: createdAt,
            scheduledDate: scheduledDate,
            startedAt: (data["startedAt"] as? Timestamp)?.dateValue(),
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue()
        )
    }
    
    private func sendMatchInvite(match: VersusMatch) async {
        print("📨 Sending match invite to \(match.opponentId)")
        // Send FCM push notification via Firestore trigger
        // The on_video_ready / match notification is handled server-side.
        // Write a notification doc — the Cloud Function picks it up.
        try? await db.collection("notifications").addDocument(data: [
            "userId":   match.opponentId,
            "type":     "match_invitation",
            "title":    "VS Match Challenge",
            "body":     "You've been challenged to a VS Match!",
            "matchId":  match.id,
            "isRead":   false,
            "createdAt": Timestamp(date: Date()),
        ])
    }
    
    private func scheduleMatchStart(match: VersusMatch) async {
        print("⏰ Scheduling match start for \(match.scheduledDate)")
        // Write a scheduled notification doc that the Cloud Function picks up
        let scheduledDate = match.scheduledDate
        try? await db.collection("scheduled_notifications").addDocument(data: [
            "userId":      match.challengerId,
            "targetUsers": [match.challengerId, match.opponentId],
            "type":        "match_reminder",
            "title":       "VS Match Starting Soon",
            "body":        "Your match starts in 5 minutes!",
            "matchId":     match.id,
            "deliverAt":   Timestamp(date: scheduledDate.addingTimeInterval(-300)),
            "createdAt":   Timestamp(date: Date()),
        ])
    }
    
    private func monitorMatch(matchId: String) async {
        // Avoid stacking duplicate listeners for the same match.
        guard matchListeners[matchId] == nil else { return }
        print("👀 Monitoring match \(matchId)")
        // Attach a real-time listener to the match document. Retained so it can
        // be detached in stopMonitoring / deinit instead of leaking.
        let registration = db.collection("versus_matches").document(matchId)
            .addSnapshotListener { snap, _ in
                guard let data = snap?.data() else { return }
                print("🔴 [VersusMatchService] Match \(matchId) updated: status=\(data["status"] ?? "unknown")")
                // Notify any observers that the match was updated
                NotificationCenter.default.post(
                    name: Notification.Name("VSMatchUpdated"),
                    object: matchId,
                    userInfo: data
                )
            }
        matchListeners[matchId] = registration
    }
    
    /// Detach the real-time listener for a match (call when a match completes or
    /// its view goes away) to avoid leaking Firestore listeners.
    func stopMonitoring(matchId: String) {
        matchListeners[matchId]?.remove()
        matchListeners[matchId] = nil
    }
    
    // NOTE: Player stats, earnings, and championship points are now written
    // SERVER-SIDE in the escrow settlement Cloud Function (/create-transfer),
    // keyed idempotently per match. The former client-side updatePlayerStats /
    // awardChampionshipPoints / calculateChampionshipPoints helpers were removed
    // because client-writable outcomes were forgeable. Points formula lives in
    // the Cloud Function: 100 base + 1 point per $10 of the winner's wager.
    
    private func loadMatches() {
        Task {
            do {
                async let activeFetch = fetchActiveMatches()
                async let upcomingFetch = fetchUpcomingMatches()
                let (active, upcoming) = try await (activeFetch, upcomingFetch)
                activeMatches = active
                upcomingMatches = upcoming
            } catch {
                print("❌ Error loading matches: \(error)")
            }
        }
    }
}

// MARK: - Errors

enum MatchError: LocalizedError {
    case invalidWagerAmount
    case matchNotFound
    case insufficientFunds
    case invalidData
    case escrowFailed
    case userNotLoggedIn
    
    var errorDescription: String? {
        switch self {
        case .invalidWagerAmount:
            return NSLocalizedString(
                "match.error.invalidWagerAmount",
                value: "Wager amount must be between $1 and $100,000",
                comment: "VS Match invalid wager amount"
            )
        case .userNotLoggedIn:
            return NSLocalizedString(
                "match.error.userNotLoggedIn",
                value: "You must be logged in to create a match",
                comment: "VS Match auth required"
            )
        case .matchNotFound:
            return NSLocalizedString(
                "match.error.matchNotFound",
                value: "Match not found",
                comment: "VS Match missing"
            )
        case .insufficientFunds:
            return NSLocalizedString(
                "match.error.insufficientFunds",
                value: "Insufficient funds for wager",
                comment: "VS Match wallet balance"
            )
        case .invalidData:
            return NSLocalizedString(
                "match.error.invalidData",
                value: "Invalid match data",
                comment: "VS Match corrupt payload"
            )
        case .escrowFailed:
            return NSLocalizedString(
                "match.error.escrowFailed",
                value: "Failed to hold funds in escrow",
                comment: "VS Match escrow hold failed"
            )
        }
    }
}

