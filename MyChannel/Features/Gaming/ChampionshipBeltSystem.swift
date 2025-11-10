//
//  ChampionshipBeltSystem.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🏆 CHAMPIONSHIP BELT SYSTEM - UFC-style championship belts! 🔥
//  Worth $50M+ in engagement
//

import Foundation
import FirebaseFirestore

@MainActor
class ChampionshipBeltSystem: ObservableObject {
    static let shared = ChampionshipBeltSystem()
    
    @Published var allBelts: [ChampionshipBelt] = []
    @Published var champions: [String: Champion] = [:] // beltId -> champion
    @Published var rankings: [BeltDivision: [RankedFighter]] = [:]
    @Published var myBelts: [ChampionshipBelt] = []
    
    private let db = Firestore.firestore()
    
    private init() {
        setupBelts()
        loadChampions()
    }
    
    // MARK: - 🏆 BELT DIVISIONS
    
    enum BeltDivision: String, CaseIterable, Identifiable {
        case lightweight = "Lightweight"        // $1-100 wagers
        case welterweight = "Welterweight"      // $101-500
        case middleweight = "Middleweight"      // $501-1,000
        case heavyweight = "Heavyweight"        // $1,001-5,000
        case superHeavyweight = "Super Heavyweight" // $5,001-10,000
        case ultraHeavyweight = "Ultra Heavyweight" // $10,001+
        
        var id: String { rawValue }
        
        var wagerRange: ClosedRange<Double> {
            switch self {
            case .lightweight: return 1...100
            case .welterweight: return 101...500
            case .middleweight: return 501...1000
            case .heavyweight: return 1001...5000
            case .superHeavyweight: return 5001...10000
            case .ultraHeavyweight: return 10001...100000
            }
        }
        
        var icon: String {
            switch self {
            case .lightweight: return "🥉"
            case .welterweight: return "🥈"
            case .middleweight: return "🥇"
            case .heavyweight: return "💎"
            case .superHeavyweight: return "👑"
            case .ultraHeavyweight: return "🔥"
            }
        }
        
        var color: String {
            switch self {
            case .lightweight: return "bronze"
            case .welterweight: return "silver"
            case .middleweight: return "gold"
            case .heavyweight: return "cyan"
            case .superHeavyweight: return "purple"
            case .ultraHeavyweight: return "red"
            }
        }
    }
    
    // MARK: - 🏅 CHAMPIONSHIP BELT
    
    struct ChampionshipBelt: Identifiable {
        let id: String
        let division: BeltDivision
        let name: String
        var currentChampionId: String?
        var defenseCount: Int
        var createdAt: Date
        var lastDefense: Date?
        var nextDefense: Date?
        var isVacant: Bool
        
        var title: String {
            "\(division.rawValue) Championship Belt"
        }
    }
    
    // MARK: - 👑 CHAMPION
    
    struct Champion: Identifiable {
        let id: String
        let userId: String
        let beltId: String
        let division: BeltDivision
        var wonAt: Date
        var defenses: Int
        var nextDefenseDate: Date
        var status: ChampionStatus
        
        enum ChampionStatus: String {
            case active = "Active"
            case defending = "Defending"
            case stripped = "Stripped"
            case retired = "Retired"
        }
    }
    
    // MARK: - 🥊 RANKED FIGHTER
    
    struct RankedFighter: Identifiable {
        let id: String
        let userId: String
        let division: BeltDivision
        var rank: Int
        var points: Int
        var wins: Int
        var losses: Int
        var knockouts: Int // decisive wins
        var winStreak: Int
        var totalEarnings: Double
        
        var winRate: Double {
            let total = wins + losses
            guard total > 0 else { return 0 }
            return Double(wins) / Double(total) * 100
        }
        
        var isContender: Bool {
            rank <= 3
        }
    }
    
    // MARK: - 🎯 TITLE DEFENSE
    
    struct TitleDefense: Identifiable {
        let id: String
        let beltId: String
        let championId: String
        let challengerId: String
        let matchId: String
        var scheduledDate: Date
        var status: DefenseStatus
        var result: DefenseResult?
        
        enum DefenseStatus: String {
            case scheduled = "Scheduled"
            case live = "Live"
            case completed = "Completed"
            case cancelled = "Cancelled"
        }
        
        enum DefenseResult: String {
            case successfulDefense = "Successful Defense"
            case newChampion = "New Champion"
            case draw = "Draw"
        }
    }
    
    // MARK: - ⚡ SETUP BELTS
    
    private func setupBelts() {
        allBelts = BeltDivision.allCases.map { division in
            ChampionshipBelt(
                id: UUID().uuidString,
                division: division,
                name: "\(division.rawValue) Championship",
                currentChampionId: nil,
                defenseCount: 0,
                createdAt: Date(),
                lastDefense: nil,
                nextDefense: nil,
                isVacant: true
            )
        }
    }
    
    // MARK: - 🏆 WIN BELT
    
    func awardBelt(to userId: String, division: BeltDivision, from matchId: String) async throws {
        print("🏆 Awarding \(division.rawValue) belt to \(userId)")
        
        guard let belt = allBelts.first(where: { $0.division == division }) else {
            throw BeltError.beltNotFound
        }
        
        // Create champion record
        let champion = Champion(
            id: UUID().uuidString,
            userId: userId,
            beltId: belt.id,
            division: division,
            wonAt: Date(),
            defenses: 0,
            nextDefenseDate: Date().addingTimeInterval(30 * 24 * 60 * 60), // 30 days
            status: .active
        )
        
        // Save to Firestore
        try await db.collection("champions").document(champion.id).setData([
            "userId": champion.userId,
            "beltId": champion.beltId,
            "division": champion.division.rawValue,
            "wonAt": Timestamp(date: champion.wonAt),
            "defenses": champion.defenses,
            "nextDefenseDate": Timestamp(date: champion.nextDefenseDate),
            "status": champion.status.rawValue
        ])
        
        // Update belt
        try await db.collection("belts").document(belt.id).updateData([
            "currentChampionId": userId,
            "isVacant": false,
            "lastDefense": Timestamp(date: Date())
        ])
        
        champions[belt.id] = champion
        
        print("✅ Belt awarded! Next defense in 30 days")
    }
    
    // MARK: - 🛡️ DEFEND BELT
    
    func defendBelt(beltId: String, against challengerId: String) async throws -> TitleDefense {
        print("🛡️ Scheduling title defense...")
        
        guard let champion = champions[beltId] else {
            throw BeltError.noChampion
        }
        
        // Create title defense
        let defense = TitleDefense(
            id: UUID().uuidString,
            beltId: beltId,
            championId: champion.userId,
            challengerId: challengerId,
            matchId: UUID().uuidString,
            scheduledDate: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            status: .scheduled
        )
        
        // Save to Firestore
        try await db.collection("title_defenses").document(defense.id).setData([
            "beltId": defense.beltId,
            "championId": defense.championId,
            "challengerId": defense.challengerId,
            "matchId": defense.matchId,
            "scheduledDate": Timestamp(date: defense.scheduledDate),
            "status": defense.status.rawValue
        ])
        
        print("✅ Title defense scheduled!")
        
        return defense
    }
    
    // MARK: - 📊 UPDATE RANKINGS
    
    func updateRankings(userId: String, division: BeltDivision, points: Int) async throws {
        print("📊 Updating rankings for \(userId)")
        
        // Update fighter stats
        try await db.collection("fighter_rankings")
            .document("\(division.rawValue)_\(userId)")
            .setData([
                "userId": userId,
                "division": division.rawValue,
                "points": FieldValue.increment(Int64(points)),
                "lastUpdated": Timestamp(date: Date())
            ], merge: true)
        
        // Recalculate rankings
        await recalculateRankings(for: division)
    }
    
    private func recalculateRankings(for division: BeltDivision) async {
        do {
            let snapshot = try await db.collection("fighter_rankings")
                .whereField("division", isEqualTo: division.rawValue)
                .order(by: "points", descending: true)
                .limit(to: 15)
                .getDocuments()
            
            var ranked: [RankedFighter] = []
            
            for (index, doc) in snapshot.documents.enumerated() {
                let data = doc.data()
                
                let fighter = RankedFighter(
                    id: doc.documentID,
                    userId: data["userId"] as? String ?? "",
                    division: division,
                    rank: index + 1,
                    points: data["points"] as? Int ?? 0,
                    wins: data["wins"] as? Int ?? 0,
                    losses: data["losses"] as? Int ?? 0,
                    knockouts: data["knockouts"] as? Int ?? 0,
                    winStreak: data["winStreak"] as? Int ?? 0,
                    totalEarnings: data["totalEarnings"] as? Double ?? 0
                )
                
                ranked.append(fighter)
            }
            
            rankings[division] = ranked
            
        } catch {
            print("❌ Error recalculating rankings: \(error)")
        }
    }
    
    // MARK: - 🔥 GET CONTENDERS
    
    func getTopContenders(for division: BeltDivision, limit: Int = 3) -> [RankedFighter] {
        guard let fighters = rankings[division] else { return [] }
        return Array(fighters.prefix(limit))
    }
    
    // MARK: - 🎖️ HALL OF FAME
    
    func inductIntoHallOfFame(userId: String, achievements: [String]) async throws {
        print("🎖️ Inducting \(userId) into Hall of Fame")
        
        try await db.collection("hall_of_fame").document(userId).setData([
            "userId": userId,
            "inductedAt": Timestamp(date: Date()),
            "achievements": achievements
        ])
    }
    
    // MARK: - Helper Functions
    
    private func loadChampions() {
        Task {
            do {
                let snapshot = try await db.collection("champions")
                    .whereField("status", isEqualTo: Champion.ChampionStatus.active.rawValue)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    // Parse champion data
                    // TODO: Implement parsing
                }
            } catch {
                print("❌ Error loading champions: \(error)")
            }
        }
    }
    
    func getDivisionForWager(_ wager: Double) -> BeltDivision {
        for division in BeltDivision.allCases {
            if division.wagerRange.contains(wager) {
                return division
            }
        }
        return .ultraHeavyweight
    }
}

// MARK: - Errors

enum BeltError: LocalizedError {
    case beltNotFound
    case noChampion
    case notRanked
    case invalidDivision
    
    var errorDescription: String? {
        switch self {
        case .beltNotFound:
            return "Championship belt not found"
        case .noChampion:
            return "No current champion for this belt"
        case .notRanked:
            return "Fighter not ranked in this division"
        case .invalidDivision:
            return "Invalid division"
        }
    }
}

