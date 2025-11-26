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
class VersusMatchService: ObservableObject {
    static let shared = VersusMatchService()
    
    @Published var activeMatches: [VersusMatch] = []
    @Published var upcomingMatches: [VersusMatch] = []
    @Published var myMatches: [VersusMatch] = []
    @Published var featuredMatches: [VersusMatch] = []
    
    private let db = Firestore.firestore()
    private let escrowService = MoneyEscrowService.shared
    
    private init() {
        loadMatches()
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
        
        // Validate wager amount
        guard wagerAmount >= 1.0 && wagerAmount <= 100000 else {
            throw MatchError.invalidWagerAmount
        }
        
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
        
        // Return challenger's money
        try await escrowService.releaseFunds(
            matchId: matchId,
            winnerId: match.challengerId,
            loserId: match.opponentId,
            totalPot: match.wagerAmount
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
        
        // Calculate winnings (winner gets both wagers minus platform fee)
        let totalPot = match.wagerAmount * 2
        let platformFee = totalPot * 0.10 // 10% platform fee
        let winnerPayout = totalPot - platformFee
        
        // Release funds to winner
        try await escrowService.releaseFunds(
            matchId: matchId,
            winnerId: winnerId,
            loserId: loserId,
            totalPot: winnerPayout
        )
        
        // Update match
        try await db.collection("versus_matches").document(matchId).updateData([
            "status": VersusMatch.Status.completed.rawValue,
            "winnerId": winnerId,
            "loserId": loserId,
            "finalStats": try JSONEncoder().encode(finalStats).base64EncodedString(),
            "completedAt": Timestamp(date: Date()),
            "winnerPayout": winnerPayout,
            "platformFee": platformFee
        ])
        
        // Update player stats
        await updatePlayerStats(winnerId: winnerId, loserId: loserId, match: match)
        
        // Award championship points
        await awardChampionshipPoints(winnerId: winnerId, match: match)
        
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
        // Fetch matches where user is either challenger or opponent
        let snapshot = try await db.collection("versus_matches")
            .whereField("challengerId", isEqualTo: userId)
            .getDocuments()
        
        let snapshot2 = try await db.collection("versus_matches")
            .whereField("opponentId", isEqualTo: userId)
            .getDocuments()
        
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
        
        // Parse rules (simplified for now)
        let rules = VersusMatch.MatchRules(
            duration: 3600, // 1 hour
            category: category,
            winCondition: .mostViews
        )
        
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
        // Send push notification to opponent
        print("📨 Sending match invite to \(match.opponentId)")
        
        // TODO: Implement push notification
    }
    
    private func scheduleMatchStart(match: VersusMatch) async {
        print("⏰ Scheduling match start for \(match.scheduledDate)")
        
        // TODO: Schedule notification/reminder
    }
    
    private func monitorMatch(matchId: String) async {
        print("👀 Monitoring match \(matchId)")
        
        // TODO: Real-time monitoring of match stats
    }
    
    private func updatePlayerStats(winnerId: String, loserId: String, match: VersusMatch) async {
        print("📊 Updating player stats...")
        
        // Update winner stats
        try? await db.collection("player_stats").document(winnerId).setData([
            "wins": FieldValue.increment(Int64(1)),
            "totalEarnings": FieldValue.increment(Int64(match.wagerAmount)),
            "lastMatchDate": Timestamp(date: Date())
        ], merge: true)
        
        // Update loser stats
        try? await db.collection("player_stats").document(loserId).setData([
            "losses": FieldValue.increment(Int64(1)),
            "totalLosses": FieldValue.increment(Int64(match.wagerAmount)),
            "lastMatchDate": Timestamp(date: Date())
        ], merge: true)
    }
    
    private func awardChampionshipPoints(winnerId: String, match: VersusMatch) async {
        let points = calculateChampionshipPoints(for: match)
        
        print("🏆 Awarding \(points) championship points to \(winnerId)")
        
        try? await db.collection("championship_rankings").document(winnerId).setData([
            "points": FieldValue.increment(Int64(points)),
            "lastWin": Timestamp(date: Date())
        ], merge: true)
    }
    
    private func calculateChampionshipPoints(for match: VersusMatch) -> Int {
        // Higher wager = more points
        let basePoints = 100
        let wagerBonus = Int(match.wagerAmount / 10) // 1 point per $10
        
        return basePoints + wagerBonus
    }
    
    private func loadMatches() {
        Task {
            do {
                activeMatches = try await fetchActiveMatches()
                upcomingMatches = try await fetchUpcomingMatches()
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
    
    var errorDescription: String? {
        switch self {
        case .invalidWagerAmount:
            return "Wager amount must be between $1 and $100,000"
        case .matchNotFound:
            return "Match not found"
        case .insufficientFunds:
            return "Insufficient funds for wager"
        case .invalidData:
            return "Invalid match data"
        case .escrowFailed:
            return "Failed to hold funds in escrow"
        }
    }
}

