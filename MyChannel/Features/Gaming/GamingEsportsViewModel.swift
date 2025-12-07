//
//  GamingEsportsViewModel.swift
//  MyChannel
//
//  Created by AI Assistant
//

import Foundation
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class GamingEsportsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Tournaments
    @Published var featuredTournament: EsportsTournament?
    @Published var activeTournaments: [EsportsTournament] = []
    @Published var hasLiveTournaments = false
    
    // VS Matches
    @Published var activeMatches: [VSMatch] = []
    
    // Leaderboard
    @Published var leaderboardUsers: [LeaderboardUser] = []
    @Published var selectedPeriod: LeaderboardPeriod = .weekly
    
    // My Earnings
    @Published var totalEarnings: Double = 0
    @Published var availableBalance: Double = 0
    @Published var pendingBalance: Double = 0
    @Published var tournamentsWon: Int = 0
    @Published var vsWins: Int = 0
    @Published var totalMatches: Int = 0
    @Published var winRate: Int = 0
    @Published var recentTransactions: [EarningsTransaction] = []
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Services
    
    private let tournamentService = EsportsTournamentService.shared
    private let vsMatchService = VersusMatchService.shared
    private let walletService = VSMatchWalletService.shared
    private let userService = UserFirestoreService.shared
    
    // 🔥 NUCLEAR: AI Orchestrator with 7 specialized gaming agents
    // 🔥 FIX: Lazy initialization to prevent circular dependency crash
    private lazy var aiOrchestrator = GamingAIOrchestrator.shared
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif
    private var userCache: [String: User] = [:]
    
    // MARK: - Formatted Properties
    
    var formattedTotalEarnings: String {
        "$\(Int(totalEarnings).formatted())"
    }
    
    var formattedAvailableBalance: String {
        "$\(Int(availableBalance).formatted())"
    }
    
    var formattedPendingBalance: String {
        "$\(Int(pendingBalance).formatted())"
    }
    
    private var currentUserId: String? {
        AuthenticationManager.shared.currentUser?.id ?? AppState.shared.currentUser?.id
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTournaments() }
            group.addTask { await self.loadVSMatches() }
            let period = self.selectedPeriod
            group.addTask { await self.loadLeaderboard(for: period) }
            group.addTask { await self.loadEarnings() }
        }
    }
    
    private func loadTournaments() async {
        do {
            let tournaments = try await tournamentService.fetchActiveTournaments()
            activeTournaments = tournaments
            featuredTournament = try await tournamentService.fetchFeaturedTournament() ?? tournaments.first
            hasLiveTournaments = tournaments.contains { $0.isLive }
        } catch {
            print("⚠️ Failed to load tournaments: \(error)")
            let samples = Self.sampleTournaments()
            activeTournaments = samples.list
            featuredTournament = samples.featured
            hasLiveTournaments = samples.list.contains { $0.isLive }
        }
    }
    
    private func loadVSMatches() async {
        do {
            let matches = try await vsMatchService.fetchActiveMatches()
            let limited = matches.prefix(6)
            var prepared: [VSMatch] = []
            
            for match in limited {
                let challenger = await loadUser(id: match.challengerId)
                let opponent: User? = match.opponentId.isEmpty ? nil : await loadUser(id: match.opponentId)
                
                let uiMatch = VSMatch(
                    id: match.id,
                    challenger: challenger,
                    opponent: opponent,
                    category: match.category.rawValue,
                    wagerAmount: match.wagerAmount,
                    createdAt: match.createdAt,
                    verificationStatus: mapStatus(match.status),
                    needsProofSubmission: match.status == .completed && match.finalStats == nil
                )
                
                prepared.append(uiMatch)
            }
            
            activeMatches = prepared
        } catch {
            print("⚠️ Failed to load VS matches: \(error)")
            activeMatches = Self.sampleMatches()
        }
    }
    
    func refreshLeaderboard(for period: LeaderboardPeriod) async {
        await loadLeaderboard(for: period)
    }
    
    private func loadLeaderboard(for period: LeaderboardPeriod) async {
        #if canImport(FirebaseFirestore)
        do {
            let documentId = leaderboardDocumentId(for: period)
            var snapshot = try await db.collection("leaderboards")
                .document(documentId)
                .collection("rankings")
                .order(by: "rank", descending: false)
                .limit(to: 25)
                .getDocuments()
            
            // Fallback to global all-time rankings if the period is empty
            if snapshot.documents.isEmpty && documentId != "global" {
                snapshot = try await db.collection("leaderboards")
                    .document("global")
                    .collection("rankings")
                    .order(by: "rank", descending: false)
                    .limit(to: 25)
                    .getDocuments()
            }
            
            let users: [LeaderboardUser] = await snapshot.documents.asyncMap { doc in
                let data = doc.data()
                let wins = data["wins"] as? Int ?? 0
                let losses = data["losses"] as? Int ?? 0
                let matches = data["totalMatches"] as? Int ?? (wins + losses)
                let earnings = data["totalEarnings"] as? Double ?? 0
                let user = await self.loadUser(id: doc.documentID)
                
                return LeaderboardUser(
                    id: doc.documentID,
                    displayName: user.displayName.isEmpty ? user.username : user.displayName,
                    totalEarnings: earnings,
                    wins: wins,
                    matches: matches
                )
            }
            
            leaderboardUsers = users.isEmpty ? Self.sampleLeaderboard() : users
        } catch {
            print("⚠️ Failed to load leaderboard: \(error)")
            leaderboardUsers = Self.sampleLeaderboard()
        }
        #else
        leaderboardUsers = Self.sampleLeaderboard()
        #endif
    }
    
    private func loadEarnings() async {
        guard let userId = currentUserId else {
            applyEarningsFallback()
            return
        }
        
        do {
            let summary = try await walletService.fetchWalletSummary(userId: userId)
            totalEarnings = summary.totalEarnings
            availableBalance = summary.availableBalance
            pendingBalance = summary.pendingBalance
        } catch {
            print("⚠️ Failed to fetch wallet summary: \(error)")
            applyEarningsFallback()
        }
        
        await loadPlayerStats(userId: userId)
        await loadTransactions(userId: userId)
    }
    
    private func loadPlayerStats(userId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("player_stats").document(userId).getDocument()
            let data = doc.data() ?? [:]
            
            tournamentsWon = data["tournamentsWon"] as? Int
                ?? data["championships"] as? Int
                ?? tournamentsWon
            vsWins = data["wins"] as? Int ?? 0
            let losses = data["losses"] as? Int ?? 0
            totalMatches = data["totalMatches"] as? Int ?? (vsWins + losses)
            winRate = totalMatches > 0 ? Int((Double(vsWins) / Double(totalMatches)) * 100) : 0
        } catch {
            print("⚠️ Failed to load player stats: \(error)")
        }
        #endif
    }
    
    private func loadTransactions(userId: String) async {
        do {
            let transactions = try await walletService.getTransactionHistory(userId: userId, limit: 20)
            recentTransactions = transactions.map(convertTransaction)
        } catch {
            print("⚠️ Failed to load transactions: \(error)")
            if recentTransactions.isEmpty {
                recentTransactions = Self.sampleTransactions()
            }
        }
    }
    
    private func loadUser(id: String) async -> User {
        if let cached = userCache[id] {
            return cached
        }
        
        if let current = AuthenticationManager.shared.currentUser, current.id == id {
            userCache[id] = current
            return current
        }
        
        if let appStateUser = AppState.shared.currentUser, appStateUser.id == id {
            userCache[id] = appStateUser
            return appStateUser
        }
        
        if let remote = try? await userService.fetchUser(id: id) {
            userCache[id] = remote
            return remote
        }
        
        let placeholder = User(
            id: id,
            username: "player-\(id.prefix(6))",
            displayName: "Player \(id.prefix(4))",
            email: "\(id)@mychannel.live"
        )
        userCache[id] = placeholder
        return placeholder
    }
    
    private func convertTransaction(_ transaction: VSMatchTransaction) -> EarningsTransaction {
        EarningsTransaction(
            id: transaction.id,
            description: transaction.description.isEmpty ? defaultDescription(for: transaction.type) : transaction.description,
            amount: transaction.amount,
            date: transaction.createdAt,
            type: EarningsTransaction.TransactionType(vsType: transaction.type)
        )
    }
    
    private func mapStatus(_ status: VersusMatch.Status) -> MatchVerificationStatus {
        switch status {
        case .completed:
            return .verified
        case .disputed:
            return .disputed
        case .pending:
            return .pending
        case .accepted, .live:
            return .verified
        default:
            return .none
        }
    }
    
    private func applyEarningsFallback() {
        if totalEarnings == 0 {
            totalEarnings = 12_450
            availableBalance = 8_230
            pendingBalance = 4_220
        }
    }
    
    private func leaderboardDocumentId(for period: LeaderboardPeriod) -> String {
        switch period {
        case .daily: return "global-daily"
        case .weekly: return "global-weekly"
        case .monthly: return "global-monthly"
        case .allTime: return "global"
        }
    }
}

// MARK: - Sample Helpers

private extension GamingEsportsViewModel {
    static func sampleTournaments() -> (list: [EsportsTournament], featured: EsportsTournament) {
        let tournaments = [
            EsportsTournament(
                id: "spring-championship",
                name: "Spring Championship",
                gameName: "Multi-Game",
                prizePool: 50_000,
                entryFee: 50,
                format: "Single Elimination",
                currentPlayers: 248,
                maxPlayers: 256,
                startDate: Date().addingTimeInterval(60 * 60 * 38),
                isLive: false
            ),
            EsportsTournament(
                id: "pro-league",
                name: "Pro League Finals",
                gameName: "Fortnite",
                prizePool: 75_000,
                entryFee: 100,
                format: "Single Elimination",
                currentPlayers: 32,
                maxPlayers: 128,
                startDate: Date().addingTimeInterval(60 * 60 * 125),
                isLive: false
            ),
            EsportsTournament(
                id: "masters",
                name: "Masters Tournament",
                gameName: "Valorant",
                prizePool: 100_000,
                entryFee: 150,
                format: "Double Elimination",
                currentPlayers: 256,
                maxPlayers: 256,
                startDate: Date().addingTimeInterval(-60 * 60 * 2),
                isLive: true
            )
        ]
        
        return (tournaments, tournaments[0])
    }
    
    static func sampleMatches() -> [VSMatch] {
        [
            VSMatch(
                id: "match-1",
                challenger: User.sampleUsers[0],
                opponent: nil,
                category: "Gaming Views",
                wagerAmount: 100,
                createdAt: Date().addingTimeInterval(-60 * 15)
            ),
            VSMatch(
                id: "match-2",
                challenger: User.sampleUsers[1],
                opponent: User.sampleUsers[2],
                category: "Likes Battle",
                wagerAmount: 250,
                createdAt: Date().addingTimeInterval(-60 * 30)
            )
        ]
    }
    
    static func sampleLeaderboard() -> [LeaderboardUser] {
        [
            LeaderboardUser(id: "1", displayName: "ProGamer_2024", totalEarnings: 125_000, wins: 45, matches: 52),
            LeaderboardUser(id: "2", displayName: "ElitePlayer", totalEarnings: 98_500, wins: 38, matches: 48),
            LeaderboardUser(id: "3", displayName: "ChampionX", totalEarnings: 87_200, wins: 35, matches: 45),
            LeaderboardUser(id: "4", displayName: "SkillMaster", totalEarnings: 72_100, wins: 32, matches: 42),
            LeaderboardUser(id: "5", displayName: "TopTier", totalEarnings: 65_400, wins: 28, matches: 38)
        ]
    }
    
    static func sampleTransactions() -> [EarningsTransaction] {
        [
            EarningsTransaction(
                id: "sample-1",
                description: "Tournament Win - Spring Finals",
                amount: 2_500,
                date: Date().addingTimeInterval(-60 * 60 * 2),
                type: .win
            ),
            EarningsTransaction(
                id: "sample-2",
                description: "VS Match Win vs ProGamer",
                amount: 500,
                date: Date().addingTimeInterval(-60 * 60 * 5),
                type: .win
            )
        ]
    }
    
    func defaultDescription(for type: VSMatchTransactionType) -> String {
        switch type {
        case .deposit: return "Wallet Deposit"
        case .withdrawal: return "Withdrawal"
        case .win: return "Match Win"
        case .wager: return "Match Wager"
        case .refund: return "Refund"
        case .fee: return "Platform Fee"
        }
    }
    
    // MARK: - 🔥 AI-Powered Methods
    
    /// Create a fair VS match using AI orchestration
    func createAIOptimizedMatch(
        opponentId: String,
        wagerAmount: Double,
        category: String
    ) async throws -> AIMatchCreationResult {
        guard let userId = currentUserId else {
            throw MatchError.userNotLoggedIn
        }
        
        return try await aiOrchestrator.createFairMatch(
            challengerId: userId,
            opponentId: opponentId,
            wagerAmount: wagerAmount,
            category: category
        )
    }
    
    /// Generate AI-optimized tournament bracket
    func generateAITournamentBracket(
        players: [String],
        prizePool: Double,
        format: TournamentFormat
    ) async throws -> AITournamentBracket {
        return try await aiOrchestrator.generateTournamentBracket(
            players: players,
            prizePool: prizePool,
            format: format
        )
    }
    
    /// Verify match result with AI
    func verifyMatchWithAI(
        matchId: String,
        player1VideoURL: String,
        player2VideoURL: String,
        player1Score: Int,
        player2Score: Int
    ) async throws -> AIMatchVerificationResult {
        return try await aiOrchestrator.verifyMatchResult(
            matchId: matchId,
            player1VideoURL: player1VideoURL,
            player2VideoURL: player2VideoURL,
            player1Score: player1Score,
            player2Score: player2Score
        )
    }
    
    /// Get AI status for display
    internal var aiAgentsOnline: Int {
        aiOrchestrator.agentsActive
    }
    
    internal var aiTotalPredictions: Int {
        aiOrchestrator.totalPredictions
    }
    
    internal var isAIOnline: Bool {
        aiOrchestrator.isOnline
    }
}

// MARK: - Async Helpers

#if canImport(FirebaseFirestore)
private extension Array where Element == QueryDocumentSnapshot {
    func asyncMap<T>(_ transform: @escaping (QueryDocumentSnapshot) async -> T) async -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)
        
        for document in self {
            let value = await transform(document)
            results.append(value)
        }
        
        return results
    }
}
#endif

private extension EarningsTransaction.TransactionType {
    init(vsType: VSMatchTransactionType) {
        switch vsType {
        case .deposit, .refund:
            self = .deposit
        case .win:
            self = .win
        case .withdrawal:
            self = .withdrawal
        case .wager, .fee:
            self = .loss
        }
    }
}

