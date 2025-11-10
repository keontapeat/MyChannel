//
//  GamingAgents.swift
//  MyChannel
//
//  5 Gaming AGI Agents for VS matches and competitions
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// Import shared agent types
// AgentMetrics, AgentStatus, etc. are now in SharedAgentTypes.swift

// MARK: - 1. Match Orchestrator

@MainActor
final class MatchOrchestrator: ObservableObject {
    
    static let shared = MatchOrchestrator()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var lastRunTime: Date?
    @Published var errorCount: Int = 0
    @Published var activeMatches: [String] = []
    
    let config: AGIAgentConfig = .init(
        id: "match-orchestrator",
        name: "Match Orchestrator",
        category: .gaming,
        status: .planned,
        description: "Manages all VS matches and ensures fair play",
        impactDescription: "+50% match quality and fairness",
        estimatedRevenue: "+$10M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Orchestrate VS matches and ensure fair gameplay",
        requiredDataSources: ["Match Data", "Player Stats", "Real-time Game Data"],
        outputFormat: "JSON match management commands",
        isEnabled: false,
        priority: 20,
        estimatedBuildTime: "4 weeks",
        runInterval: 60 // 1 minute - need fast response
    )
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Match Orchestrator] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
        print("🛑 [Match Orchestrator] Agent stopped")
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                lastRunTime = Date()
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                handleError(error)
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // 1. Check active matches for completion
        let snapshot = try await db.collection("vs-matches")
            .whereField("status", isEqualTo: "active")
            .getDocuments()
        
        print("🎮 [Match Orchestrator] Monitoring \(snapshot.documents.count) active matches")
        
        for doc in snapshot.documents {
            let matchId = doc.documentID
            let data = doc.data()
            
            guard let endTime = (data["endTime"] as? Timestamp)?.dateValue(),
                  let wagerAmount = data["wagerAmount"] as? Double,
                  let creator1Id = data["creator1Id"] as? String,
                  let creator2Id = data["creator2Id"] as? String else {
                continue
            }
            
            // 2. Check if match has ended
            if Date() >= endTime {
                let winner = try await determineWinner(matchId: matchId, data: data)
                let loser = winner == creator1Id ? creator2Id : creator1Id
                try await finalizeMatch(matchId: matchId, winnerId: winner, loserId: loser, wagerAmount: wagerAmount)
                metrics.revenue += wagerAmount * 0.1 // 10% platform fee
            }
        }
        
        // 3. Match creators looking for opponents
        try await matchmakeCreators()
        
        metrics.totalRuns += 1
        #endif
    }
    
    private func determineWinner(matchId: String, data: [String: Any]) async throws -> String {
        let category = data["category"] as? String ?? "views"
        let creator1Id = data["creator1Id"] as? String ?? ""
        let creator2Id = data["creator2Id"] as? String ?? ""
        let video1Id = data["video1Id"] as? String ?? ""
        let video2Id = data["video2Id"] as? String ?? ""
        
        // Get metrics based on category
        let score1 = try await getMatchScore(videoId: video1Id, category: category)
        let score2 = try await getMatchScore(videoId: video2Id, category: category)
        
        print("📊 [Match Orchestrator] Match \(matchId): \(score1) vs \(score2)")
        
        return score1 > score2 ? creator1Id : creator2Id
    }
    
    private func getMatchScore(videoId: String, category: String) async throws -> Int {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let doc = try await db.collection("videos").document(videoId).getDocument()
        let data = doc.data() ?? [:]
        
        switch category {
        case "views":
            return data["viewCount"] as? Int ?? 0
        case "likes":
            return data["likeCount"] as? Int ?? 0
        case "comments":
            return data["commentCount"] as? Int ?? 0
        default:
            return data["viewCount"] as? Int ?? 0
        }
        #else
        return 0
        #endif
    }
    
    private func finalizeMatch(matchId: String, winnerId: String, loserId: String, wagerAmount: Double) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Calculate payouts
        let platformFee = wagerAmount * 0.1
        let winnerPayout = (wagerAmount * 2) - platformFee
        
        // Update match
        try await db.collection("vs-matches").document(matchId).updateData([
            "status": "completed",
            "winnerId": winnerId,
            "winnerPayout": winnerPayout,
            "completedAt": FieldValue.serverTimestamp()
        ])
        
        // Release escrow to winner via MoneyEscrowService
        try await MoneyEscrowService.shared.releaseFunds(
            matchId: matchId,
            winnerId: winnerId,
            loserId: loserId,
            amount: winnerPayout
        )
        
        print("🏆 [Match Orchestrator] Match \(matchId) won by \(winnerId) - $\(Int(winnerPayout))")
        #endif
    }
    
    private func matchmakeCreators() async throws {
        // Find creators looking for opponents and match them
        print("🔍 [Match Orchestrator] Searching for match opportunities")
        // TODO: Implement matchmaking algorithm
    }
    
    private func handleError(_ error: Error) {
        errorCount += 1
        metrics.errorCount += 1
        print("🚨 [Match Orchestrator] Error: \(error.localizedDescription)")
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Match Orchestrator] Agent deallocated")
    }
}

// MARK: - 2. Prize Pool Manager

@MainActor
final class PrizePoolManager: ObservableObject {
    
    static let shared = PrizePoolManager()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var totalPrizePool: Double = 0
    
    private var errorCount: Int = 0
    
    let config: AGIAgentConfig = .init(
        id: "prize-pool-manager",
        name: "Prize Pool Manager",
        category: .gaming,
        status: .planned,
        description: "Manages tournament prize pools and distributions",
        impactDescription: "+$15M revenue from tournaments",
        estimatedRevenue: "+$15M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Manage prize pools and distributions fairly",
        requiredDataSources: ["Tournament Data", "Payment Info", "Player Rankings"],
        outputFormat: "JSON prize distribution plan",
        isEnabled: false,
        priority: 21,
        estimatedBuildTime: "3 weeks",
        runInterval: 300
    )
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Prize Pool Manager] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                errorCount += 1
                metrics.errorCount += 1
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Calculate total prize pool from active tournaments
        let snapshot = try await db.collection("tournaments")
            .whereField("status", isEqualTo: "active")
            .getDocuments()
        
        var total = 0.0
        for doc in snapshot.documents {
            if let prizePool = doc.data()["prizePool"] as? Double {
                total += prizePool
            }
        }
        
        totalPrizePool = total
        metrics.revenue = total
        metrics.totalRuns += 1
        
        print("💰 [Prize Pool] Total active prize pool: $\(Int(total))")
        #endif
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Prize Pool Manager] Agent deallocated")
    }
}

// MARK: - 3. Anti-Cheat Guardian

@MainActor
final class AntiCheatGuardian: ObservableObject {
    
    static let shared = AntiCheatGuardian()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var suspiciousActivities: [SuspiciousActivity] = []
    
    private var errorCount: Int = 0
    
    let config: AGIAgentConfig = .init(
        id: "anti-cheat-guardian",
        name: "Anti-Cheat Guardian",
        category: .gaming,
        status: .planned,
        description: "Detects and prevents cheating in VS matches",
        impactDescription: "Save $20M from prevented fraud",
        estimatedRevenue: "+$20M saved",
        vertexAIAgentId: nil,
        promptTemplate: "Detect and prevent cheating in real-time",
        requiredDataSources: ["Game Data", "Player Behavior", "Cheat Patterns"],
        outputFormat: "JSON anti-cheat report",
        isEnabled: false,
        priority: 22,
        estimatedBuildTime: "6 weeks",
        runInterval: 120 // 2 minutes
    )
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Anti-Cheat Guardian] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                handleError(error)
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Check active matches for suspicious patterns
        let snapshot = try await db.collection("vs-matches")
            .whereField("status", isEqualTo: "active")
            .getDocuments()
        
        print("🛡️ [Anti-Cheat] Scanning \(snapshot.documents.count) matches")
        
        for doc in snapshot.documents {
            let matchId = doc.documentID
            let data = doc.data()
            
            // Check for suspicious view patterns
            if let video1Id = data["video1Id"] as? String {
                let isSuspicious = try await detectSuspiciousActivity(videoId: video1Id, matchId: matchId)
                
                if isSuspicious {
                    try await flagMatch(matchId: matchId, reason: "Suspicious view patterns detected")
                    suspiciousActivities.append(SuspiciousActivity(
                        matchId: matchId,
                        reason: "Bot views detected",
                        severity: .high
                    ))
                }
            }
        }
        
        metrics.totalRuns += 1
        print("✅ [Anti-Cheat] Scan complete - \(suspiciousActivities.count) issues found")
        #endif
    }
    
    private func detectSuspiciousActivity(videoId: String, matchId: String) async throws -> Bool {
        // Check for:
        // 1. Sudden spike in views from single IP
        // 2. Bot-like viewing patterns
        // 3. Same users rapidly refreshing
        // 4. Unnatural engagement rates
        
        // Simplified detection for now
        let viewSpike = try await checkViewSpike(videoId: videoId)
        return viewSpike > 1000 // Suspicious if 1000+ views in minute
    }
    
    private func checkViewSpike(videoId: String) async throws -> Int {
        // Get view count change in last minute
        return 0 // TODO: Implement real-time view spike detection
    }
    
    private func flagMatch(matchId: String, reason: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("vs-matches").document(matchId).updateData([
            "flagged": true,
            "flagReason": reason,
            "flaggedAt": FieldValue.serverTimestamp(),
            "status": "under_review"
        ])
        
        print("🚨 [Anti-Cheat] Flagged match \(matchId): \(reason)")
        
        // Notify admins
        await notifyAdmins(matchId: matchId, reason: reason)
        #endif
    }
    
    private func notifyAdmins(matchId: String, reason: String) async {
        // TODO: Implement admin notification system
        print("🚨 [Anti-Cheat] Admin alert: Match \(matchId) flagged for: \(reason)")
        // await NotificationManager.shared.sendAdminAlert(
        //     title: "🚨 Match Flagged",
        //     message: "Match \(matchId) flagged for: \(reason)",
        //     priority: .high
        // )
    }
    
    private func handleError(_ error: Error) {
        errorCount += 1
        metrics.errorCount += 1
        print("🚨 [Anti-Cheat] Error: \(error.localizedDescription)")
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Anti-Cheat Guardian] Agent deallocated")
    }
}

// MARK: - 4. Tournament Scheduler

@MainActor
final class TournamentScheduler: ObservableObject {
    
    static let shared = TournamentScheduler()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var upcomingTournaments: [Tournament] = []
    
    private var errorCount: Int = 0
    
    let config: AGIAgentConfig = .init(
        id: "tournament-scheduler",
        name: "Tournament Scheduler",
        category: .gaming,
        status: .planned,
        description: "Schedules and manages tournaments automatically",
        impactDescription: "+300% tournament throughput",
        estimatedRevenue: "+$8M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Schedule and optimize tournament brackets",
        requiredDataSources: ["Player Availability", "Historical Data", "Prize Pools"],
        outputFormat: "JSON tournament schedule",
        isEnabled: false,
        priority: 23,
        estimatedBuildTime: "3 weeks",
        runInterval: 3600 // 1 hour
    )
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Tournament Scheduler] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                errorCount += 1
                metrics.errorCount += 1
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // 1. Check if we need to schedule new tournaments
        let now = Date()
        let nextWeek = now.addingTimeInterval(7 * 24 * 60 * 60)
        
        let snapshot = try await db.collection("tournaments")
            .whereField("startTime", isGreaterThan: now)
            .whereField("startTime", isLessThan: nextWeek)
            .getDocuments()
        
        // If less than 3 tournaments next week, schedule more
        if snapshot.documents.count < 3 {
            try await scheduleTournament()
        }
        
        // 2. Start tournaments that are ready
        try await startReadyTournaments()
        
        metrics.totalRuns += 1
        print("✅ [Tournament Scheduler] \(snapshot.documents.count) tournaments upcoming")
        #endif
    }
    
    private func scheduleTournament() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Schedule tournament for next weekend
        let nextSaturday = getNextSaturday()
        
        let tournament = Tournament(
            id: UUID().uuidString,
            name: "Weekend Championship",
            startTime: nextSaturday,
            prizePool: 10000, // $10,000
            maxParticipants: 32,
            category: "gaming"
        )
        
        try await db.collection("tournaments").document(tournament.id).setData([
            "name": tournament.name,
            "startTime": Timestamp(date: tournament.startTime),
            "prizePool": tournament.prizePool,
            "maxParticipants": tournament.maxParticipants,
            "category": tournament.category,
            "status": "scheduled"
        ])
        
        print("🏆 [Tournament Scheduler] Scheduled: \(tournament.name)")
        #endif
    }
    
    private func startReadyTournaments() async throws {
        // Start tournaments whose start time has arrived
        print("🎮 [Tournament Scheduler] Checking for tournaments to start")
    }
    
    private func getNextSaturday() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let daysUntilSaturday = (7 - weekday + 7) % 7 // Saturday is 7
        return calendar.date(byAdding: .day, value: daysUntilSaturday, to: now) ?? now
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Tournament Scheduler] Agent deallocated")
    }
}

// MARK: - 5. Leaderboard Calculator

@MainActor
final class LeaderboardCalculator: ObservableObject {
    
    static let shared = LeaderboardCalculator()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var leaderboards: [String: [LeaderboardEntry]] = [:]
    
    private var errorCount: Int = 0
    
    let config: AGIAgentConfig = .init(
        id: "leaderboard-calculator",
        name: "Leaderboard Calculator",
        category: .gaming,
        status: .planned,
        description: "Calculates and updates all leaderboards and rankings",
        impactDescription: "+40% competitive engagement",
        estimatedRevenue: "+$5M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Calculate and rank players across all competitions",
        requiredDataSources: ["Match Results", "Player Stats", "Historical Rankings"],
        outputFormat: "JSON leaderboard data",
        isEnabled: false,
        priority: 24,
        estimatedBuildTime: "2 weeks",
        runInterval: 600 // 10 minutes
    )
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Leaderboard Calculator] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                errorCount += 1
                metrics.errorCount += 1
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // Calculate leaderboards for each division
        let divisions = ["lightweight", "welterweight", "middleweight", "heavyweight", "super-heavyweight", "ultra-heavyweight"]
        
        for division in divisions {
            let snapshot = try await db.collection("vs-matches")
                .whereField("division", isEqualTo: division)
                .whereField("status", isEqualTo: "completed")
                .order(by: "completedAt", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            // Calculate rankings based on wins, win rate, total earnings
            var rankings: [String: LeaderboardEntry] = [:]
            
            for doc in snapshot.documents {
                let data = doc.data()
                guard let winnerId = data["winnerId"] as? String else { continue }
                
                if var entry = rankings[winnerId] {
                    entry.wins += 1
                    entry.totalEarnings += (data["winnerPayout"] as? Double) ?? 0
                    rankings[winnerId] = entry
                } else {
                    rankings[winnerId] = LeaderboardEntry(
                        userId: winnerId,
                        rank: 0,
                        wins: 1,
                        losses: 0,
                        totalEarnings: (data["winnerPayout"] as? Double) ?? 0
                    )
                }
            }
            
            // Sort by wins and earnings
            let sorted = rankings.values.sorted { entry1, entry2 in
                if entry1.wins == entry2.wins {
                    return entry1.totalEarnings > entry2.totalEarnings
                }
                return entry1.wins > entry2.wins
            }.enumerated().map { (index, entry) -> LeaderboardEntry in
                var updated = entry
                updated.rank = index + 1
                return updated
            }
            
            leaderboards[division] = Array(sorted.prefix(15)) // Top 15
            
            // Save to Firestore
            try await saveLeaderboard(division: division, entries: sorted)
        }
        
        metrics.totalRuns += 1
        print("📊 [Leaderboard] Updated \(divisions.count) division leaderboards")
        #endif
    }
    
    private func saveLeaderboard(division: String, entries: [LeaderboardEntry]) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for entry in entries.prefix(15) {
            let ref = db.collection("leaderboards").document(division)
                .collection("rankings").document(entry.userId)
            
            batch.setData([
                "rank": entry.rank,
                "wins": entry.wins,
                "losses": entry.losses,
                "totalEarnings": entry.totalEarnings,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: ref)
        }
        
        try await batch.commit()
        #endif
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Leaderboard Calculator] Agent deallocated")
    }
}

// MARK: - Supporting Models

struct SuspiciousActivity: Identifiable {
    let id = UUID()
    let matchId: String
    let reason: String
    let severity: Severity
    
    enum Severity {
        case low, medium, high, critical
    }
}

struct Tournament: Identifiable {
    let id: String
    let name: String
    let startTime: Date
    let prizePool: Double
    let maxParticipants: Int
    let category: String
}

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let userId: String
    var rank: Int
    var wins: Int
    var losses: Int
    var totalEarnings: Double
}

// Note: AgentMetrics and AgentStatus are now in SharedAgentTypes.swift

